#!perl
#
#   Alien::SWIG - Tests for swig executable itself
#
#   Copyright (c) 2011 Jason McManus
#

use Data::Dumper;
use File::Spec::Functions qw( catdir catfile rel2abs );
use Test::More tests => 17;
use ExtUtils::Embed ();
use Config ();
use FindBin;
use Cwd qw( abs_path getcwd );
use strict;
use warnings;
use lib qw( swig );

# Ours, already tested.
use Alien::SWIG;

###
### Vars
###

use vars qw( $TRUE $FALSE $VERSION );
BEGIN {
    $VERSION = '0.00_02';
}

*TRUE      = \1;
*FALSE     = \0;

my $swig = Alien::SWIG->new();
my( $text, $rv, @cmd );
my $interface = 'swigtest.i';

###
### Tests
###

################################################################
# Test: Can run swig
# Expected: PASS

my $prog = $swig->executable();
( $text, $rv ) = call_prog( $prog, '-help' );
is( $rv, 0, 'swig -help rv 0' );
like( $text, qr/General Options/m, 'swig -help correct' );

################################################################
# Test: Expected version
# Expected: PASS

my $version = $swig->version();
( $text, $rv ) = call_prog( $prog, '-version' );
is( $rv, 0, 'swig -version rv 0' );
my( $swig_ver ) = ( $text =~ m#SWIG Version (\d.*?)\s#m );
is( $swig_ver, $version, "swig -version correctly $version" );
diag( 'SWIG version ' . $swig_ver );

################################################################
# Test: SWIG can process input files correctly
# Expected: PASS

# -outdir
my $origdir = getcwd();
chdir( catdir( $FindBin::Bin, 'swig' ) );
my $cmdline = $swig->cmd_line();
( $text, $rv ) = call_prog( $cmdline, '-perl5', $interface );
is( $rv, 0, "swig -perl5 $interface rv 0" );
is( $text, '', "swig -perl5 $interface no errors" );

# Grab some compiler junk from perl
my $cc         = get_config( 'cc' );
my $ccopts     = ExtUtils::Embed::ccopts();
my $cccdlflags = get_config( 'cccdlflags' );

my $ld         = get_config( 'ld' ) || $cc;
my $lddlflags  = get_config( 'lddlflags' );
my $ccdlflags  = get_config( 'ccdlflags' );
my $dlext      = get_config( 'dlext' );

#############################################################################
# A brief interlude while we attempt to compile and link the SWIG interface
# Probably ok. We wouldn't get this far if the toolchain was broken, anyway

# Compile swigtest.c
@cmd = ( $cc, $cccdlflags, '-c', 'swigtest.c', '-o', 'swigtest.o' );
#diag( "@cmd" );
( $text, $rv ) = call_prog( @cmd );
die "\$CC swigtest.c failed: Command was: '@cmd'; SWIG may still work."
    unless( $rv == 0 );

# Compile swigtest_wrap.c
@cmd = ( $cc, $cccdlflags, $ccopts, '-c', 'swigtest_wrap.c',
                                    '-o', 'swigtest_wrap.o' );
#diag( "@cmd" );
( $text, $rv ) = call_prog( @cmd );
die "\$CC swigtest_wrap.c failed: Command was: '@cmd'; SWIG may still work."
    unless( $rv == 0 );

# Link TestModule.so
@cmd = ( $ld, $ccdlflags, $lddlflags, '-o', 'TestModule.' . $dlext,
                                      'swigtest.o', 'swigtest_wrap.o' );
#diag( "@cmd" );
( $text, $rv ) = call_prog( @cmd );
die "\$LD TestModule.$dlext failed: Command was: '@cmd'; SWIG may still work."
    unless( $rv == 0 );

# We should be all nice and compiled now.
################################################################

################################################################
# Test: SWIG can process input files correctly
# Expected: PASS

eval { require TestModule; };
is( $@, '', 'require TestModule worked' );

# See that the linked procedures are callable
can_ok( 'TestModule', 'speak' );
can_ok( 'TestModule', 'the_answer' );
can_ok( 'TestModule', 'add' );
can_ok( 'TestModule', 'multiply' );
can_ok( 'TestModule', 'is_prime' );

# See that they work sanely
is( TestModule::the_answer(),           42,    'the_answer() = 42' );
is( TestModule::add( 42, 137 ),        179,    'add( 42, 137 ) = 179' );
is( TestModule::multiply( 42, 137 ),  5754,    'multiply( 42, 137 ) = 5754' );
is( TestModule::is_prime( 137 ),         1,    'is_prime( 137 ) = true' );
is( TestModule::is_prime( 42 ),          0,    'is_prime( 42 ) = false' );


# Cleanup

chdir( $origdir );

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

sub call_prog
{
    my $prog = shift;

    my $value = qx( $prog @_ );
    chomp $value if( defined( $value ) );
    my $rv = $?;

    return( $value, $rv >> 8 );
}

__END__
