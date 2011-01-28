/*
 *
 *  Alien::SWIG - junk interface file for swig live tests
 *
 *  Copyright (c) 2011 Jason McManus
 *
*/

%module TestModule

%perlcode {
our $VERSION = '42.137';
}

%{
#include "swigtest.h"
%}

void speak( void );
int the_answer( void );
long add( int a, int b );
long multiply( int a, int b );
int is_prime( int n );

/* END */
