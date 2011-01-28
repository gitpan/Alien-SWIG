package MY::Build;
#
#   Alien::SWIG -- Installer to download or install SWIG
#
#   Copyright (c) 2011 Jason McManus
#

use Cwd;
use Config ();
use File::Spec::Functions qw( catdir catfile );
use File::Copy qw( move );
use File::Path qw( make_path );
use base qw( Module::Build );
use strict;
use warnings;
use vars qw( $VERSION );
BEGIN {
    $VERSION = '0.00_01';
}

my $SWIG             = 'swig';
my $DEF_SWIG_VERSION = '2.0.1';

sub ACTION_code {
    my $self = shift;
    $self->SUPER::ACTION_code;
    $|=1;

    # See if we passed a different SWIG ver in during Build script creation
    # XXX: I think there's supposed to be accessors, but docs are unclear.
    $self->{'properties'}->{'swig_version'} = $DEF_SWIG_VERSION
        unless( exists( $self->{'properties'}->{'swig_version'} ) );

    # Build the package
    $self->fetch_swig();
    $self->extract_swig();
    $self->config_swig();
    $self->build_swig();
    $self->tmp_install_swig();
    $self->install_swig();
}

sub def_swig_ver {
    return $DEF_SWIG_VERSION;
}

sub swig_ver {
    my $self = shift;

    # XXX: I think there's supposed to be accessors, but docs are unclear.
    return $self->{'properties'}->{'swig_version'};     # Will this work?
}

sub swig_plus_ver {
    my $self = shift;

    return $SWIG . '-' . $self->swig_ver();
}

sub swig_archive {
    my $self = shift;
    return $self->swig_plus_ver() . '.tar.gz';
}

sub swig_dir {
    return $SWIG;
}

sub swig_target_dir {
#    my $archname = get_config( 'archname' );
#    return catdir( 'blib', 'arch', $archname, 'Alien', 'SWIG' );
    return catdir( 'blib', 'lib', 'Alien', 'SWIG', 'swig' );
}

sub swig_build_dir {
    my $self = shift;
    return $self->swig_plus_ver();
}

sub swig_ver_file {
    return $SWIG . '-version.txt';
}

sub swig_url {
    my $self = shift;
    return 'http://prdownloads.sourceforge.net/swig/'
            . $self->swig_archive();
}

sub fetch_swig {
    my $self = shift;

    # make-like simple check to see if we're done already
    return if( -f $self->swig_archive() );

    print 'Local copy of ', $self->swig_archive(), " not found.\n";
    print 'GET ', $self->swig_url(), '... ';

    # Grab the file
    require HTTP::Tiny;
    my $http = HTTP::Tiny->new();
    my $response = $http->get(
        $self->swig_url(),
        {
            headers => {
                Connection => 'close',
                Accept     => '*/*',
            }
        }
    );
    die sprintf( "\nUnable to fetch archive: %s %s\n",
                 $response->{status}, $response->{reason} )
        unless( $response->{success} );

    # Write it to disk
    open my $fd, '>', $self->swig_archive()
        or die "\nCannot write to " . $self->swig_archive() . ": $!";
    binmode( $fd );
    my $bytes = syswrite( $fd, $response->{content} );
    die "\nError writing to " . $self->swig_archive() . ": $!"
        unless( $bytes == length( $response->{content} ) );
    close( $fd );

    print "OK\n";
}

sub extract_swig {
    my $self = shift;

    # make-like simple check to see if we're done already
    return if( -d $self->swig_build_dir() );

    require Archive::Extract;
    no warnings 'once';
    $Archive::Extract::PREFER_BIN = 1;  # Archive::Zip has chmod perms issues
    use warnings;

    print 'EXTRACT ', $self->swig_archive(), '... ';
    my $zip;
    unless( $zip = Archive::Extract->new(
                            archive => $self->swig_archive() ) ) {
        die "unable to open SWIG archive.\n";
    }
    unless( $zip->extract( to => '.' ) ) {
        die "unable to extract SWIG archive.\n";
    }

    print "OK\n";
}

sub config_swig
{
    my $self = shift;

    # make-like simple check to see if config is done already
    return if( -f catfile( $self->swig_build_dir(), 'Makefile' ) );

    # Enter build dir
    print 'CONFIG ' . $self->swig_plus_ver() . "...\n";
    my $origdir = getcwd();
    my $bd = $self->swig_build_dir();
    chdir( $bd ) or die "Cannot chdir to $bd: $!";

    # XXX: This probably won't work with mst's local::lib
    my $sitelibexp = get_config( 'sitelibexp' );

    my @cmd = (
        './configure',
        '--prefix=' . catdir( $sitelibexp, 'Alien', 'SWIG' ),
        '--disable-ccache',
        '--with-perl',
        '--without-tcl',
        '--without-python',
        '--without-python3',
        '--without-octave',
        '--without-java',
        '--without-gcj',
        '--without-guile',
        '--without-mzscheme',
        '--without-ruby',
        '--without-php',
        '--without-php4',       # for some older version of SWIG
        '--without-ocaml',
        '--without-pike',
        '--without-chicken',
        '--without-csharp',
        '--without-lua',
        '--without-allegrocl',
        '--without-clisp',
        '--without-r',
        '--without-go',
# Disable until cpantesters reports come back
#        '--without-maximum-compile-warnings',
    );

    # ./configure
    $self->complain_about_disabled_languages_not_working();
    $self->my_system( @cmd );

    # Go home
    chdir( $origdir );

    print 'CONFIG ' . $self->swig_plus_ver() . " OK\n";

    return;
}

sub build_swig
{
    my $self = shift;

    # make-like simple check to see if build is done already
    return if( -f catfile( $self->swig_build_dir(), 'swig' ) );

    # make
    print 'BUILD ' . $self->swig_plus_ver() . "...\n";
    my $origdir = getcwd();
    my $bd = $self->swig_build_dir();
    chdir( $bd ) or die "Cannot chdir to $bd: $!";

    $self->complain_about_disabled_languages_not_working();
    $self->my_system( 'make' );

    # Go home
    chdir( $origdir );

    print 'BUILD ' . $self->swig_plus_ver() . " OK\n";

    return;
}

sub tmp_install_swig {
    my $self = shift;

    # make-like simple check to see if tmpinstall is done already
    # 1. First check if install_swig() is already done (since we MOVE files)
    my $destbase = $self->swig_target_dir();
    return if( -d catdir( $destbase, 'bin' ) and
               -d catdir( $destbase, 'share' ) );
    # 2. Next check if we ourselves are done.
    my $sitelibexp = get_config( 'sitelibexp' );
    my $aswig = catdir( 'tmpinst', $sitelibexp, 'Alien', 'SWIG' );
    return if(
             -d 'tmpinst' and
             -d catdir( 'tmpinst', $sitelibexp ) and
             -d catdir( $aswig, 'bin' ) and
             -f catdir( $aswig, 'bin', 'swig' ) and
             -d catdir( $aswig, 'share' ) and
             -d catdir( $aswig, 'share', 'swig' ) and
             -d catdir( $aswig, 'share', 'swig', $self->swig_ver )
    );

    print 'TMPINST ' . $self->swig_plus_ver() . " to tmpinst...\n";
    $self->complain_about_disabled_languages_not_working();

    my $origdir = getcwd();
    my $bd = $self->swig_build_dir();
    chdir( $bd ) or die "\nTMPINST: Cannot chdir to $bd: $!";

    # make DESTDIR=../blib/blahblah install
    my $DESTDIR = catdir( '..', 'tmpinst' );
    $self->my_system( 'make', 'DESTDIR=' . $DESTDIR, 'install' );

    # Return to the main CPAN build dir
    chdir( $origdir );

    print 'TMPINST ' . $self->swig_plus_ver() . " to tmpinst OK\n";

    return;
}

sub install_swig
{
    my $self = shift;

    # make-like simple check to see if install is done already
    my $destbase = $self->swig_target_dir();
    return if( -d catdir( $destbase, 'bin' ) and
               -d catdir( $destbase, 'share' ) );

    print 'TMPINST ' . $self->swig_plus_ver() . " rebase...\n";

    # Build some paths
    my $sitelibexp = get_config( 'sitelibexp' );
    my $srcbase    = catdir( 'tmpinst',
                                         $sitelibexp,
                                         'Alien',
                                         'SWIG' );
    my $src1  = catdir( $srcbase, 'bin' );
    my $src2  = catdir( $srcbase, 'share' );
    my $dest1 = catdir( $destbase, 'bin' );
    my $dest2 = catdir( $destbase, 'share' );

    # Finally, move the junk autoconf just misinstalled to its 2nd temp loc
    make_path( $destbase );
#    move( $src1, $finaldest )
    rename( $src1, $dest1 )
        or die "\nTMPINST: Cannot move $src1 to $dest1: $!";
#    move( $src2, $finaldest )
    rename( $src2, $dest2 )
        or die "\nTMPINST: Cannot move $src2 to $dest2: $!";

    # Create the version file
    $self->create_ver_file( $destbase );

    print 'TMPINST ' . $self->swig_plus_ver() . " rebase OK\n";

    return;
}

### Utility methods

sub my_system
{
    my $self = shift;

    print "SYSTEM: cmd '@_'\n";
    system( @_ );

    if ($? == -1) {
        die "SYSTEM: cmd '@_': failed to execute: $!\n";
    }
    elsif ($? & 127) {
        die sprintf "SYSTEM: cmd '@_': died with signal %d, %s coredump\n",
                    ($? & 127),
                    ($? & 128) ? 'with' : 'without';
    }
    else {
        printf "SYSTEM: cmd '%s': OK (rv %d)\n",
               $_[0],
               $? >> 8;
    }

    return;
}

sub get_config {
    my @junk = Config::config_re( $_[0] );

    return unless( scalar( @junk ) );

    my $val = $junk[0];
    $val =~ s/^.*?='(.*)'$/$1/;     # Config.pm is SO ANNOYING
    return( $val );
}

sub create_ver_file {
    my( $self, $path ) = ( shift, shift );

    my $verfile = catfile( $path, $self->swig_ver_file() );

    open my $fh, '>', $verfile
        or die "Cannot create $verfile: $!";
    print $fh $self->swig_ver() . "\n"
        or die "Cannot write to $verfile: $!";
    close( $fh );

    return;
}

sub complain_about_disabled_languages_not_working
{
    # Pffffft.
    print "*"x75, "\n";
    print "  The SWIG build process doesn't actually disable other language support.\n";
    print "   These options are left in, hoping that someday it'll actually work.\n";
    print "*"x75, "\n";

    return;
}

1;

__END__
