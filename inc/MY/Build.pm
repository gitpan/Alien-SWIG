package MY::Build;
#
#   Alien::SWIG -- Installer to download or install SWIG
#
#   Copyright (c) 2011 Jason McManus
#

use Cwd;
use Config;
use File::Spec::Functions qw( catdir catfile );
use File::Copy qw( move );
use File::Path;
use ExtUtils::MakeMaker qw( prompt );   # Module::Build's prompt sucks
use base qw( Module::Build );
use strict;
use warnings;

use vars qw( $VERSION $TRUE $FALSE );
BEGIN {
    $VERSION = '0.02_02';
}
*TRUE  = \1;
*FALSE = \0;

#########################################################################
### Variables
#########################################################################

our $DEF_SWIG_VERSION = '2.0.1';

my $SWIG             = 'swig';
my $BASE_DL_URL      = 'http://downloads.sourceforge.net/swig/';
my $SWIG_VER_FILE    = 'swig_build_version';

# Weighted list: 2.0.1 will be tested 1/3 of the time, ~4.762% for others
my @known_vers = qw(
    1.3.28  1.3.29  1.3.30  1.3.31  1.3.32  1.3.33  1.3.34  1.3.35
    1.3.36  1.3.37  1.3.38  1.3.39  1.3.40  2.0.0
    2.0.1   2.0.1   2.0.1   2.0.1   2.0.1   2.0.1   2.0.1
);
my %known_vers = ();    # mapped on demand

#########################################################################
### Methods
#########################################################################

# XXX: There's supposed to be accessors, but docs are unclear and tests failed
sub get_mb_property
{
    my( $self, $prop_name ) = ( shift, shift );

    return( exists( $self->{'properties'}->{$prop_name} )
              ? $self->{'properties'}->{$prop_name}
              : undef );
}

sub ACTION_code {
    my $self = shift;
    $self->SUPER::ACTION_code;
    $|=1;

    # Build the package
    $self->fetch_swig()
        or $self->ask_to_try_again();
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

    return $self->read_swig_ver();
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
    return $BASE_DL_URL . $self->swig_archive();
}

# I think some CPANTesters (wisely) filter net access during testing.
sub ask_to_try_again
{
    my $self = shift;

    if( $self->swig_ver() ne $self->def_swig_ver() )
    {
        my $ans = prompt( sprintf( "Trouble downloading SWIG v%s; install" .
                                   " included %s version?",
                                   $self->swig_ver(),
                                   $self->def_swig_ver() ), 'yes' );
        if( $ENV{AUTOMATED_TESTING} or $ans =~ m/y/i )
        {
            # Frobnicate the version file
            $self->write_swig_ver_file( $self->def_swig_ver() );
            print "\n";
            return( $self->fetch_swig() );
        }
    }

    die sprintf( "Couldn't download SWIG v%s; cannot continue.",
                 $self->swig_ver() );
}

sub fetch_swig {
    my $self = shift;

    # make-like simple check to see if we're done already
    return $TRUE if( -f $self->swig_archive() );

    print 'Local copy of ', $self->swig_archive(), " not found.\n";
    print 'GET ', $self->swig_url(), '... ';

    # Grab the file
    require HTTP::Tiny;
    my $http = HTTP::Tiny->new( timeout => 30 );
    my $response = $http->get(
        $self->swig_url(),
        {
            headers => {
                Connection => 'close',
                Accept     => '*/*',
            }
        }
    );

    unless( $response->{success} )
    {
        my $content = ( exists( $response->{content} ) and
                        defined( $response->{content} ) and
                        length( $response->{content} ) )
                          ? substr( $response->{content}, 0, 8*1024 )
                          : "empty";
        chomp $content;
        warn sprintf( "\nUnable to fetch archive: %s %s; Content was%s\n",
               $response->{status}, $response->{reason},
               ":\n'" . $content . "'\n" );

        warn sprintf( <<'MOCK_THE_USER',
You specified SWIG version '%s', which is not a known working version.

I always tell 'em, like my great-grandfather used to say, "Choose a known
working SWIG version, or suffer the consequences!"  But do they LISTEN?
NO, OF COURSE NOT!  Now see what happens?!?

Maybe you should try one of these:

%s

MOCK_THE_USER
                      # continuation of sprintf args
                      $self->get_mb_property( 'swig_version' ),
                      $self->formatted_known_vers )
            unless( $self->is_known_ver( $self->swig_ver() ) );
        return $FALSE;
    }


    # Write it to disk
    open my $fd, '>', $self->swig_archive()
        or die "\nCannot write to " . $self->swig_archive() . ": $!";
    binmode( $fd );
    my $bytes = syswrite( $fd, $response->{content} );
    die "\nError writing to " . $self->swig_archive() . ": $!"
        unless( $bytes == length( $response->{content} ) );
    close( $fd );

    print "OK\n";

    return $TRUE;
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
    my $sitelibexp = $self->get_config_var( 'sitelibexp' );

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

    # Check for --without-pcre
    if( $self->get_mb_property( 'without-pcre' ) )
    {
        push( @cmd, '--without-pcre' );
    }
    # Check for --with-pcre-[exec-]prefix
    elsif( $self->get_mb_property( 'with-pcre-prefix' ) or
           $self->get_mb_property( 'with-pcre-exec-prefix' ) )
    {
        push( @cmd, '--with-pcre-prefix=' .
                    $self->get_mb_property( 'with-pcre-prefix' ) )
            if( $self->get_mb_property( 'with-pcre-prefix' ) );
        push( @cmd, '--with-pcre-exec-prefix=' .
                    $self->get_mb_property( 'with-pcre-exec-prefix' ) )
            if( $self->get_mb_property( 'with-pcre-exec-prefix' ) );
    }

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
    my $sitelibexp = $self->get_config_var( 'sitelibexp' );
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
    my $sitelibexp = $self->get_config_var( 'sitelibexp' );
    my $srcbase    = catdir( 'tmpinst',
                                         $sitelibexp,
                                         'Alien',
                                         'SWIG' );
    my $src1  = catdir( $srcbase, 'bin' );
    my $src2  = catdir( $srcbase, 'share' );
    my $dest1 = catdir( $destbase, 'bin' );
    my $dest2 = catdir( $destbase, 'share' );

    # Finally, move the junk autoconf just misinstalled to its 2nd temp loc
    mkpath( $destbase );
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
    my $rv = $?;

    if ($rv == -1) {
        die "SYSTEM: cmd '@_': failed to execute: '$!'\n";
    }
    elsif ($rv & 127) {
        die sprintf( "SYSTEM: cmd '@_': died with signal %d, %s coredump\n",
                     ( $rv & 127 ),
                     ( $rv & 128 ) ? 'with' : 'without' );
    }
    elsif( ( $rv >> 8 ) > 0 ) {
        # XXX: Remove this after figuring out what's going on w/ Ticket #39 ?
        if( $^O =~ /Solaris/i )
        {
            printf( "SYSTEM: cmd '%s': FAIL (rv %d)\n", $_[0], $rv >> 8 );
            print "Solaris detected; dumping Makefile:\n-----------\n";
            my $cwd = getcwd();
            open my $fh, '<', 'Makefile' or die "Can't open $cwd/Makefile: $!";
            print $_ while( <$fh> );
            close( $fh );
            die "\n----------\nCannot continue with broken Makefile.\n";
        }
        else
        {
            die sprintf( "SYSTEM: cmd '%s': FAIL (rv %d)\n", $_[0], $rv >> 8 );
        }
    }
    else {
        printf( "SYSTEM: cmd '%s': OK (rv %d)\n", $_[0], $rv >> 8 );
    }

    return( $rv >> 8 );
}

# Retrieve a var from the ginormous %Config hash
sub get_config_var
{
    shift;  # Get rid of class/$obj junk
    my $var = shift;

    return exists( $Config{$var} )
             ? $Config{$var}
             : undef;
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

# XXX: See these post on the swig-user mailing list for why this is here:
# https://sourceforge.net/mailarchive/message.php?msg_id=26967542
# https://sourceforge.net/mailarchive/message.php?msg_id=26978599
sub complain_about_disabled_languages_not_working
{
    # Pffffft.
    print "*"x75, "\n";
    print "  The SWIG build process doesn't actually disable multi-language support.\n";
    print "   These options are left in, hoping that someday it'll actually work.\n\n";
    print "  More info:\n";
    print "    https://sourceforge.net/mailarchive/message.php?msg_id=26967542\n";
    print "    https://sourceforge.net/mailarchive/message.php?msg_id=26978599\n";
    print "*"x75, "\n";

    return;
}

#
# These are used in Build.PL
#

sub cache_known_vers
{
    %known_vers = map { $_ => 1 } @known_vers
        unless( keys( %known_vers ) );

    return;
}

sub is_known_ver
{
    shift;  # ignore first arg, class method
    my $ver = shift;
    return $FALSE unless( defined( $ver ) );

    cache_known_vers();

    return( exists( $known_vers{$ver} ) ? $TRUE : $FALSE );
}

sub known_vers
{
    return( @known_vers );
}

sub formatted_known_vers
{
    my $s = '';
    my $c = 0;
    cache_known_vers();
    for my $v ( sort keys( %known_vers ) )
    {
        $s .= '  ' unless( $c % 9 );
        $s .= sprintf "%-8s", $v;
        $s .= "\n" unless( ++$c % 9 );
    }
    return( $s );
}

sub random_ver
{
    return( $known_vers[rand @known_vers] );
}

sub write_swig_ver_file
{
    shift;  # Get rid of class/object
    my $ver = shift;
    $ver = def_swig_ver() unless( defined( $ver ) );

    open my $fh, '>', $SWIG_VER_FILE or return;
    print $fh $ver;
    close $fh;

    return;
}

sub read_swig_ver
{
    open my $fh, '<', $SWIG_VER_FILE
        or return def_swig_ver();

    my $ver = <$fh>;
    close( $fh );
    chomp $ver;
    $ver = def_swig_ver() unless( defined( $ver ) );

    return $ver;
}

1;

__END__
