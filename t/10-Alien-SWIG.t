#!perl -T
#
#   Alien::SWIG - Tests for main module
#
#   Copyright (c) 2011 Jason McManus
#

use Data::Dumper;
use File::Spec::Functions qw( catdir catfile );
use Test::More tests => 15;
use Config ();
use strict;
use warnings;

###
### Vars
###

use vars qw( $TRUE $FALSE $VERSION );
BEGIN {
    $VERSION = '0.00_03';
}

*TRUE      = \1;
*FALSE     = \0;

my $obj;

###
### Tests
###

# Uncomment for use tests
BEGIN {
    use_ok( 'Alien::SWIG' ) or print "Bail out!";
}

################################################################
# Test: Can instantiate object
# Expected: PASS
isa_ok( $obj = Alien::SWIG->new(), 'Alien::SWIG' );


################################################################
# Test: Object set SWIG_LIB envvar and cached module_dir
# Expected: PASS
isnt( $obj->{module_dir}, undef, 'module_dir cached' );
isnt( $ENV{SWIG_LIB},     undef, 'ENV{SWIG_LIB} is set' );

################################################################
# Test: Test all methods
# Expected: PASS

# Set up some junk
my $alien_swig_path = $INC{"Alien/SWIG.pm"};
$alien_swig_path    =~ s{\.pm$}{};
my $swigbase        = catdir( $alien_swig_path, 'swig' );

# Test version()
my $version = get_version( $swigbase );
is( $obj->version(), $version, 'version()' );

# Test path()
is( $obj->path(), $swigbase,    'path()' );

# Test executable()
my $bin = File::Spec->catfile( $swigbase, 'bin', 'swig' );
is( $obj->executable(), $bin,    'executable()' );

# Test module_dir()
my $mod_dir = catdir( $swigbase, 'share', 'swig', $version );
is( $obj->module_dir(), $mod_dir, 'module_dir()' );

# Test: Check the actual value of SWIG_LIB var
is( $ENV{SWIG_LIB}, $mod_dir, 'ENV{SWIG_LIB} is correct' );

# Test includes()
my @incs = (
    $mod_dir,
    catdir( $mod_dir, 'typemaps' ),
    catdir( $mod_dir, 'std' ),
    catdir( $mod_dir, 'perl5' ),
);
@incs = map { '-I' . $_ } @incs;
is_deeply( [ $obj->includes() ], \@incs, 'includes()' );

# Test cmd_line()
my $cmdline = catfile( $swigbase, 'bin', 'swig' ) . ' ' . join( ' ', @incs );
is( $obj->cmd_line(), $cmdline, 'cmd_line()' );

# Reach inside the object and make sure everything's cached correctly
is( $obj->{path},            $swigbase, 'path cache correct' );
is( $obj->{executable},      $bin,      'executable cache correct' );
is( $obj->{module_dir},      $mod_dir,  'module_dir cache correct' );
is_deeply( $obj->{includes}, \@incs,    'includes cache correct' );

# Always return true
1;

###
### Utility subs
###

sub get_config {
    my @junk = Config::config_re( $_[0] );

    return unless( scalar( @junk ) );

    my $val = $junk[0];
    $val =~ s/^.*?='(.*)'$/$1/;     # Config.pm is SO ANNOYING
    return( $val );
}

sub get_version {
    my $path = shift;

    my $verfile = catfile( $path, 'swig-version.txt' );
    open my $fd, '<', $verfile or print "Bail out!", die;
    my $version = <$fd>;
    chomp $version;
    close( $fd );

    return( $version );
}

__END__
