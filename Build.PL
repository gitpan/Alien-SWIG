#
#   Alien::SWIG - Module::Build build script
#
#   Copyright (c) 2010-2011 Jason McManus
#

BEGIN
{
    # I have no interest; the build facilities looked too tedious to bother.
    die "No support for OS MSWin32.  Patches welcome."
        if( $^O eq 'MSWin32' );
}

use 5.006;
use Getopt::Long;
use ExtUtils::MakeMaker qw( prompt );   # Module::Build's prompt() sucks
use File::Spec::Functions qw( catdir catfile splitdir );
use strict;
use warnings;
use lib qw( inc lib );
use MY::Build;
$|=1;

###
### Vars
###

use vars qw( $VERSION $TRUE $FALSE );
$VERSION = '0.02_02';
*TRUE    = \1;
*FALSE   = \0;

my @delpaths    = qw(
    t/swig/TestModule.so
    t/swig/TestModule.pm
    t/swig/swigtest.o
    t/swig/swigtest_wrap.c
    t/swig/swigtest_wrap.o
    swig_build_version
    tmpinst
);

my %user_version = ();
my %pcre_opts    = ();
my $args = {};

###
### Main
###

#############################################################################
# Catch the kind CPANTesters and make them do more work
#############################################################################
if( $ENV{AUTOMATED_TESTING} )
{
    $args->{swig_version} = MY::Build->random_ver();
    print "\nHi, CPANTesters!  You are all awesome; thanks for being you.\n";
    print "We'll be testing SWIG v", $args->{swig_version}, " today.\n";
}
else
{
    # Check for ./Build --swigver=x.x.x args
    $args = check_args();
}

#############################################################################
# Set up some additional parameters if we're building an alternate version
#############################################################################

if( exists( $args->{swig_version} ) )
{
    # Check if we know about this version
    warn_if_unknown( $args->{swig_version} );

    push( @delpaths, 'swig-' . $args->{swig_version} );
    push( @delpaths, 'swig-' . $args->{swig_version} . '.tar.gz' )
        unless( $args->{swig_version} eq $MY::Build::DEF_SWIG_VERSION );
    $user_version{'swig_version'} = $args->{swig_version};
}


#############################################################################
#  PCRE Checks
#############################################################################

# See if we have said to disable PCRE, 
if( exists( $args->{'without-pcre'} ) )
{
    $pcre_opts{'without-pcre'} = delete( $args->{'without-pcre'} );
    warn "\nWarning: Disabling PCRE is not recommended. " .
         " Continuing anyway, boss!\n\n";
}
# See if we have explicitly passed --with-pcre-* args, and just trust them.
elsif( exists( $args->{'with-pcre-prefix'} ) or
    exists( $args->{'with-pcre-exec-prefix'} ) )
{
    $pcre_opts{'with-pcre-prefix'} = delete( $args->{'with-pcre-prefix'} )
         if( exists( $args->{'with-pcre-prefix'} ) );
    $pcre_opts{'with-pcre-exec-prefix'} = delete( $args->{'with-pcre-exec-prefix'})
         if( exists( $args->{'with-pcre-exec-prefix'} ) );
}
# Check for PCRE, or warn user if not found
else
{
    ( my $pcre_exists, $args ) = check_for_pcre( $args );
    unless( $pcre_exists )
    {
        print <<'PCRENOTE';

******************************************************************************

  Warning: PCRE not found!
  
  SWIG recommends PCRE (the "Perl-Compatible" Regex Library) for its source
  code parser and preprocessor.
  
  You can choose here to disable PCRE while building SWIG, but it is
  recommended that you get and install it before continuing.  There will
  be no support for regular expressions when using SWIG without it.

  It can be downloaded here: http://www.pcre.org/, or probably found in
  your distribution's package repository.

  (AUTHOR'S NOTE: This Perl module doesn't need PCRE; it's purely for SWIG.)

******************************************************************************

PCRENOTE

        # let CPANTesters disable it automatically
#        my $default = $ENV{AUTOMATED_TESTING} ? 'yes' : 'no';
        my $default = 'yes';
        my $resp = prompt( 'Do you wish to disable PCRE (not recommended) ?',
                           $default );

        # Had bug that looked fine in 0.01; just make it more explicit
        if( $ENV{AUTOMATED_TESTING} or $resp =~ m/y/i ) 
        {
            $pcre_opts{'without-pcre'} = $TRUE
        }
        else
        {
            die "\nPCRE not found and not disabled; cannot continue.\n ";
        }
    }
}


#############################################################################
# Create our Build script
#############################################################################
my $builder = MY::Build->new(
    module_name         => 'Alien::SWIG',
    license             => 'perl',
    dist_author         => q{Jason McManus <infidel AT cpan.org>},
    dist_version_from   => 'lib/Alien/SWIG.pm',
    create_makefile_pl  => 'small',
    requires            => {
        perl                => '5.6.0',
    },
    build_requires => {
        'Archive::Extract'      => 0,
        'Test::More'            => 0,
        'HTTP::Tiny'            => 0,
        'Getopt::Long'          => 0,
        'ExtUtils::MakeMaker'   => 0,   # for prompt, because M::B's sucks
    },
    add_to_cleanup      => [ 'Alien-SWIG-*', 'swig-2.0.1', @delpaths ],

    # Disable PCRE, if we don't have it
    %pcre_opts,
);

# Make 'Build'
$builder->create_build_script();

# Write the separate swig version file
$builder->write_swig_ver_file( $args->{swig_version} );

# Thank you, drive through.
exit( 0 );

#############################################################################
### Utility subs
#############################################################################

# Check for a --swigver argument
sub check_args
{
    my $opts = {};

    # XXX: processing args this way because we're using pass_through
    my $argsub = sub {
        die "--$_[0] requires an argument"
            unless( length( $_[1] ) );
        $opts->{$_[0]} = $_[1];
    };

    Getopt::Long::Configure( 'pass_through' );  # hush
    GetOptions(
        $opts,
        # specify alternate SWIG ver
        'swig_version|swigversion|version:s' => $argsub,
        # pass these to swig's configure script
        'with-pcre-prefix:s'                 => $argsub,
        'with-pcre-exec-prefix:s'            => $argsub,
        'without-pcre',
    ) or die;

    return $opts;
}

# SWIG recommends PCRE be installed, and configure fails if it's not there
# and --disable-pcre is not passed, so check for it.
sub check_for_pcre
{
    my $args = shift;

    # Set up some extra places to look
    my @extra_paths = ( catdir( '/', 'usr', 'bin' ),
                        catdir( '/', 'usr', 'local', 'bin' ) );
    if( $^O eq 'MSWin32' )
    {
        my $vol = $ENV{SystemDrive};
        push( @extra_paths, map { catdir( $vol, $_ ) } @extra_paths )
            if( $vol );
    }

    push( @extra_paths,
          $args->{'with-pcre-prefix'},
          catdir( $args->{'with-pcre-prefix'}, 'bin' ) )
       if( exists( $args->{'with-pcre-prefix' } ) );
    push( @extra_paths,
          $args->{'with-pcre-exec-prefix'},
          catdir( $args->{'with-pcre-exec-prefix'}, 'bin' ) )
       if( exists( $args->{'with-pcre-exec-prefix' } ) );

    my $pcre_config = find_bin( 'pcre-config', @extra_paths );

    my $pcre_exists = $pcre_config ? $TRUE : $FALSE;

    # XXX: Remove this after you figure out what's up in Ticket #46 ?
    if( $pcre_exists and $^O =~ /FreeBSD/i )
#    if( $pcre_exists )
    {
        print "\nFreeBSD detected.  Doing more extensive PCRE checks...\n\n";
        my( $pcre_prefix, $pcre_exec_prefix, $without_pcre )
            = query_pcre_config( $pcre_config );
        $args->{'with-pcre-prefix'} = $pcre_prefix
            if( $pcre_prefix );
        $args->{'with-pcre-exec-prefix'} = $pcre_exec_prefix
            if( $pcre_exec_prefix );
        $args->{'without-pcre'} = $TRUE
            if( $without_pcre );
        $pcre_exists = $without_pcre ? $FALSE : $TRUE;
    }

    return( $pcre_exists, $args );
}

# Find the specified $fname in all dirs in $ENV{PATH}
sub find_bin
{
    my( $fname, @extra_paths ) = @_;

    my $path_sep = MY::Build->get_config_var( 'path_sep' ) || ':';

    my @bindirs = split( $path_sep, $ENV{PATH} );
    push( @bindirs, @extra_paths );

    my $binpath = '';
    for my $dir ( @bindirs )
    {
        my $testpath = catfile( $dir, $fname );
        $binpath = $testpath, last
            if( -f $testpath );
    }

    return( $binpath );
}

# Warn if the SWIG version is not in our known list
sub warn_if_unknown
{
    my $ver = shift;

    if( MY::Build->is_known_ver( $ver ) )
    {
        printf "\nReconfiguring for SWIG version $ver...\n\n";
    }
    else
    {
        warn sprintf( "\nWarning: %s is not a known SWIG version." .
                     "  Known working versions are:\n\n",
                     $ver );
        warn sprintf( "%s\n\n(We'll try it anyway.  But don't say I didn't" .
                     " warn you.)\n\n",
                     MY::Build->formatted_known_vers() );
    }
}

# XXX: Remove this when you figure out what's up in Ticket #46 ?
sub query_pcre_config
{
    my( $pcre ) = @_;
    my( $pcre_prefix, $pcre_exec_prefix );

    ###
    # Get output from pcre-config
    print "Interrogating '$pcre'...\n--------------------------------------\n";
    for my $arg ( qw( --version --prefix --exec-prefix --libs
                      --libs-posix --libs-cpp --cflags --cflags-posix ) )
    {
        printf( "  %20s : ", $arg );
        my( $resp, $rv, $except ) = call_prog( $pcre, $arg );
        print '[' . $rv . '] ';
        print( ( ( $rv != 0 ) ? "'$except'" : "'$resp'" ) . "\n" );
        $pcre_prefix = $resp
            if( $arg =~ /\Qprefix/ );
        $pcre_exec_prefix = $resp
            if( $arg =~ /\Qexec-prefix/ );
    }
    print "\n";

    ###
    # Try to locate pcre.h
    print "Checking for pcre.h...\n--------------------------\n";
    # Set up some places to look
    my @includes = ( catdir( '/', 'usr', 'include' ),
                     catdir( '/', 'usr', 'local', 'include' ) );
    if( $^O eq 'MSWin32' )
    {
        my $vol = $ENV{SystemDrive};
        push( @includes, map { catdir( $vol, $_ ) } @includes )
            if( $vol );
    }

    # Get the base dir of pcre-config, without trailing bin/
    my @pcre_path = splitdir( $pcre );
    pop( @pcre_path );
    pop( @pcre_path ) if( $pcre_path[$#pcre_path] =~ /^bin$/ );
    push( @includes, catdir( @pcre_path, 'include' ) );
    # uniqueify includes search path
    my %seen = ();
    @includes = grep { ! $seen{ $_ }++ } @includes;

    # Finally, try to find pcre.h
    my $pcre_h = '';
    for( @includes ) {
        printf " %20s : ", $_;
        my $check = catdir( $_, 'pcre.h' );
        if( -f $check )
        {
            $pcre_h = $check;
            print $pcre_h . "\n";
            last;
        }
        print "No.\n";
    }
    print "pcre.h not found in [ @includes ]!\n"
        unless( $pcre_h );
    print "\n";

    return( $pcre_prefix, $pcre_exec_prefix, $pcre_h ? $FALSE : $TRUE );
}

# XXX: Remove this when you figure out what's up in ticket #46 ?
sub call_prog
{
    my $value;

    eval { $value = qx( @_ 2>&1 ); };

    chomp $value;
    my $rv = $?;
    my $e = $@;
    $e = 'Bad argument' if( $rv != 0 and $e eq '' );

    return( $value, $rv >> 8, $e );
}

__END__
