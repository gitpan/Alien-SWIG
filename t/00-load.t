#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'Alien::SWIG' ) || print "Bail out!
";
}

diag( "Testing Alien::SWIG $Alien::SWIG::VERSION, Perl $], $^X" );
