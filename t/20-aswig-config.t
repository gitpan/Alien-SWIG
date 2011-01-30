#!perl
#
#   Alien::SWIG - Tests for aswig-config utility script
#
#   Copyright (c) 2011 Jason McManus
#

use Data::Dumper;
use File::Spec::Functions qw( catdir catfile rel2abs );
use Test::More tests => 64;
use Config ();
use FindBin;
use Cwd qw( abs_path );
use strict;
use warnings;

# Ours, already tested.
use Alien::SWIG;

###
### Vars
###

use vars qw( $TRUE $FALSE $VERSION );
BEGIN {
    $VERSION = '0.00_03';
}

*TRUE      = \1;
*FALSE     = \0;

my $PROGNAME = 'aswig-config';
my( $prog, $text, $rv, $stderr );

###
### Tests
###

################################################################
# Test: Can find script
# Expected: PASS
$prog = catfile( $FindBin::Bin, '..', 'bin', $PROGNAME );
ok( -x $prog, "$prog is executable" );

################################################################
# Test: Test all arguments
# Expected: PASS

### Test no args
( $text, $rv ) = call_prog( $prog );
is( $rv, 2, "$PROGNAME no args exitcode 2" );
like( $text, qr/Usage:/m, "$PROGNAME no args shows usage" );

### Test invalid arg
eval {
    close(STDERR);
    open(STDERR, '>', \$stderr);
    ( $text, $rv ) = call_prog( $prog, '--hovercraft' );
};
is( $@, '', "$PROGNAME invalid args runs" );
is( $rv, 3, "$PROGNAME invalid args exitcode 3" );
like( $text, qr/Usage:/m, "$PROGNAME invalid args shows usage" );

### Test --help
for( qw( -h -? --help --? ) )
{
    ( $text, $rv ) = call_prog( $prog, $_ );
    is( $rv, 0, "$PROGNAME $_ exitcode 2" );
    like( $text, qr/Usage:/m, "$PROGNAME $_ shows usage" );
}

# Set up some junk
my $alien_swig_path = $INC{"Alien/SWIG.pm"};
$alien_swig_path    =~ s{\.pm$}{};
my $swigbase        = catdir( $alien_swig_path, 'swig' );
my $version         = get_version( $swigbase );

#### Test version()
for( qw( -v --ver --version --swig_version --swigver ) )
{
    ( $text, $rv )      = call_prog( $prog, $_ );
    is( $rv, 0, "$PROGNAME $_ exitcode 0" );
    is( $text, $version, "$PROGNAME $_ correct" );
}

# Test path()
for( qw( -p --path --pa ) )
{
    ( $text, $rv )      = call_prog( $prog, $_ );
    is( $rv, 0, "$PROGNAME $_ exitcode 0" );
    is( $text, $swigbase, "$PROGNAME $_ correct" );
}

# Test executable()
my $bin = File::Spec->catfile( $swigbase, 'bin', 'swig' );
for( qw( -x -e --exec --executable ) )
{
    ( $text, $rv )      = call_prog( $prog, $_ );
    is( $rv, 0, "$PROGNAME $_ exitcode 0" );
    is( $text, $bin, "$PROGNAME $_ correct" );
}

# Test module_dir()
my $mod_dir = catdir( $swigbase, 'share', 'swig', $version );
for( qw( -m --mod --module_dir --moduledir --moddir --mods ) )
{
    ( $text, $rv )      = call_prog( $prog, $_ );
    is( $rv, 0, "$PROGNAME $_ exitcode 0" );
    is( $text, $mod_dir, "$PROGNAME $_ correct" );
}

# Test includes()
my @incs = (
    $mod_dir,
    catdir( $mod_dir, 'typemaps' ),
    catdir( $mod_dir, 'std' ),
    catdir( $mod_dir, 'perl5' ),
);
@incs = map { '-I' . $_ } @incs;
my $incs = ' ' . join( ' ', @incs ) . ' ';
for( qw( -i --inc --includes --incs ) )
{
    ( $text, $rv )      = call_prog( $prog, $_ );
    is( $rv, 0, "$PROGNAME $_ exitcode 0" );
    is( $text, $incs, "$PROGNAME $_ correct" );
}

# Test cmd_line()
my $cmdline = catfile( $swigbase, 'bin', 'swig' ) . ' ' . join( ' ', @incs );
for( qw( -c --cmdline --cmd_line ) )
{
    ( $text, $rv )      = call_prog( $prog, $_ );
    is( $rv, 0, "$PROGNAME $_ exitcode 0" );
    is( $text, $cmdline, "$PROGNAME $_ correct" );
}

#######################
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
    chomp $value;
    my $rv = $?;

    return( $value, $rv >> 8 );
}

__END__
