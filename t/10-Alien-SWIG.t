#!perl -T
#
#   Alien::SWIG - Tests for main module
#
#   Copyright (c) 2011 Jason McManus
#

use Data::Dumper;
use File::Spec::Functions qw( catdir catfile );
use Test::More tests => 31;
use strict;
use warnings;

###
### Vars
###

use vars qw( $TRUE $FALSE $VERSION );
BEGIN {
    $VERSION = '0.01';
}

*TRUE      = \1;
*FALSE     = \0;

my $obj;

###
### Tests
###

# Uncomment for use tests
BEGIN {
    use_ok(
        'Alien::SWIG',
        qw( version path executable module_dir includes cmd_line ),
    ) or print "Bail out!";
}

################################################################
# Test: Functional interface works, and caches properly.
# Expected: PASS
is_deeply( $Alien::SWIG::CACHE, {}, 'Alien::SWIG::Cache empty' );

# Set up some junk
my $alien_swig_path = $INC{ catfile( 'Alien', 'SWIG.pm' ) };
$alien_swig_path    =~ s{\.pm$}{};
my $swigbase        = catdir( $alien_swig_path, 'swig' );

# Test version()
my $version = get_version( $swigbase );
is( version(), $version,                        'version()' );

# Test path()
is( path(), $swigbase,                          'path()' );

# Test executable()
my $bin = File::Spec->catfile( $swigbase, 'bin', 'swig' );
is( executable(), $bin,                         'executable()' );

# Text module_dir();
my $mod_dir = catdir( $swigbase, 'share', 'swig', $version );
is( module_dir(), $mod_dir,                     'module_dir()' );

# Test includes()
my @incs = (
    $mod_dir,
    catdir( $mod_dir, 'typemaps' ),
    catdir( $mod_dir, 'std' ),
    catdir( $mod_dir, 'perl5' ),
);
@incs = map { '-I' . $_ } @incs;
my $incs = join( ' ', @incs );
is_deeply( [ includes() ],  \@incs,             'includes() array' );
is( includes(),             $incs,              'includes() scalar' );

# Test cmd_line()
my $cmdline = catfile( $swigbase, 'bin', 'swig' ) . ' ' . join( ' ', @incs );
is( cmd_line(),             $cmdline,           'cmd_line()' );

# Test cache
is( $Alien::SWIG::CACHE->{'path'},       $swigbase,   'cache: path' );
is( $Alien::SWIG::CACHE->{'executable'}, $bin,        'cache: executable' );
is( $Alien::SWIG::CACHE->{'module_dir'}, $mod_dir,    'cache: module_dir' );
is( $Alien::SWIG::CACHE->{'version'},    $version,    'cache: version' );
is_deeply( $Alien::SWIG::CACHE->{'includes'}, \@incs, 'cache: includes' );

# Empty cache and test again
$Alien::SWIG::CACHE = {};
is_deeply( $Alien::SWIG::CACHE, {}, 'cache emptied' );

################################################################
# Test: Can instantiate object
# Expected: PASS
isa_ok( $obj = Alien::SWIG->new(),          'Alien::SWIG' );

################################################################
# Test: Object set SWIG_LIB envvar and cached module_dir
# Expected: PASS
isnt( $obj->{module_dir}, undef,            'module_dir cached' );
isnt( $ENV{SWIG_LIB},     undef,            'ENV{SWIG_LIB} is set' );

################################################################
# Test: Test all methods
# Expected: PASS

# Test $obj->version()
is( $obj->version(), $version,              '$obj->version()' );

# Test $obj->path()
is( $obj->path(), $swigbase,                '$obj->path()' );

# Test $obj->executable()
is( $obj->executable(), $bin,               '$obj->executable()' );

# Test $obj->module_dir()
is( $obj->module_dir(), $mod_dir,           '$obj->module_dir()' );

# Test $obj->includes()
is_deeply( [ $obj->includes() ], \@incs,    '$obj->includes() array' );
is( $obj->includes(),        $incs,         '$obj->includes() scalar' );

# Test $obj->cmd_line()
is( $obj->cmd_line(), $cmdline,             '$obj->cmd_line()' );

# Reach inside the object and make sure everything's cached correctly
is( $obj->{path},            $swigbase,     '$obj cache: path' );
is( $obj->{executable},      $bin,          '$obj cache: executable' );
is( $obj->{module_dir},      $mod_dir,      '$obj cache: module_dir' );
is( $obj->{version},         $version,      '$obj cache: version' );
is_deeply( $obj->{includes}, \@incs,        '$obj cache: includes' );

# Test: Check the actual value of SWIG_LIB var, now that we can
is( $ENV{SWIG_LIB}, $mod_dir,               'ENV{SWIG_LIB} is correct' );

# Always return true
1;

###
### Utility subs
###

sub get_version {
    my $path = shift;

    my $verfile = catfile( $path, 'swig-version.txt' );
    open my $fd, '<', $verfile or print "Bail out!", die;
    my $version = <$fd>;
    close( $fd );
    chomp $version;

    return( $version );
}

__END__
