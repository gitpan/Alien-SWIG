#
# Alien::SWIG - Module::Build build script
#
# Copyright (c) 2010-2011 Jason McManus
#
use Getopt::Long;
use strict;
use warnings;
use lib qw( inc lib );
use MY::Build;

###
### Vars
###

my $DEF_SWIG_VERSION = '2.0.1';

my @delpaths    = qw(
    t/swig/TestModule.so
    t/swig/TestModule.pm
    t/swig/swigtest.o
    t/swig/swigtest_wrap.c
    t/swig/swigtest_wrap.o
    tmpinst
);
my @tester_vers = qw(
    1.3.28  1.3.29  1.3.30  1.3.31  1.3.32  1.3.33  1.3.34  1.3.35
    1.3.36  1.3.37  1.3.38  1.3.39  1.3.40  2.0.0   2.0.1
);

my %user_version = ();
my $args = {
    swig_version => $DEF_SWIG_VERSION,
};

###
### Main
###

# Catch the kind CPANTesters and make them do more work
if( $ENV{AUTOMATED_TESTING} )
{
    $args->{swig_version} = $tester_vers[rand @tester_vers];
    print "\nHi, CPANTesters!  You are all awesome; thanks for being you.\n";
    print "We'll be testing SWIG v", $args->{swig_version}, " today.\n\n";
}
else
{
    # Check for ./Build --swigver=x.x.x args
    $args = check_args();
}

# Set up some additional parameters if we're building an alternate version
if( exists( $args->{swig_version} ) )
{
    push( @delpaths, 'swig-' . $args->{swig_version} );
    push( @delpaths, 'swig-' . $args->{swig_version} . '.tar.gz' )
        unless( $args->{swig_version} eq $DEF_SWIG_VERSION );
    $user_version{'swig_version'} = $args->{swig_version};
}

# Create our Build script
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
        'Archive::Extract'  => 0,
        'Test::More'        => 0,
        'HTTP::Tiny'        => 0,
    },
    add_to_cleanup      => [ 'Alien-SWIG-*', 'swig-2.0.1', @delpaths ],

    # Add user-requested swig version, if specified
    %user_version,
);
$builder->create_build_script();

# Thank you, drive through.
exit( 0 );

###
### Utility subs
###

# Check for a --swigver argument
sub check_args
{
    my $opts = {};
    Getopt::Long::Configure( 'pass_through' );  # hush
    GetOptions(
        $opts,
        'swig_version|swigversion|version:s'    # specify alternate SWIG ver
    );

    return $opts;
}

__END__
