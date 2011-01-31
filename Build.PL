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

use Getopt::Long;
use ExtUtils::MakeMaker qw( prompt );   # Module::Build's prompt() sucks
use File::Spec qw( catdir catfile );
use strict;
use warnings;
use lib qw( inc lib );
use MY::Build;

###
### Vars
###

use vars qw( $VERSION $TRUE $FALSE );
$VERSION = '0.02';
*TRUE    = \1;
*FALSE   = \0;

my $DEF_SWIG_VERSION = '2.0.1';

my @delpaths    = qw(
    t/swig/TestModule.so
    t/swig/TestModule.pm
    t/swig/swigtest.o
    t/swig/swigtest_wrap.c
    t/swig/swigtest_wrap.o
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
    print "We'll be testing SWIG v", $args->{swig_version}, " today.\n\n";
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
        unless( $args->{swig_version} eq $DEF_SWIG_VERSION );
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
# See if we have passed --with-pcre-* args; 
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
    my $pcre_exists = check_for_pcre( $args );
    unless( $pcre_exists )
    {
        print <<'PCRENOTE';

******************************************************************************

  Warning: PCRE not found!
  
  SWIG recommends PCRE (the "Perl-Compatible" Regex Library) for its source
  code parser and preprocessor.
  
  You can choose here to disable PCRE while building SWIG, but it is
  recommended that you get and install it before continuing.  There may be
  reduced functionality or performance when using SWIG without it.

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

    # Add user-requested swig version, if specified
    %user_version,

    # Disable PCRE, if we don't have it
    %pcre_opts,
);
$builder->create_build_script();

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
    my $pcre_exists = $FALSE;

    my $pcre_config = find_bin( 'pcre-config',
                                '/usr/bin', '/usr/local/bin' );

    return( $pcre_config ? $TRUE : $FALSE );
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
        my $testpath = File::Spec->catfile( $dir, $fname );
        $binpath = $testpath, last
            if( -f $testpath );
    }

    return( $binpath );
}

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

__END__
