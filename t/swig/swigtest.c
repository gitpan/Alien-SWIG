/*
 *
 *  Alien::SWIG - junk library for swig live tests
 *
 *  Copyright (c) 2011 Jason McManus
 *
*/

#include <stdio.h>
#include <math.h>

void speak( void )
{
    printf( "\nMy hovercraft is full of eels!\n\n" );
}

int the_answer( void )
{
    return 42;
}

long add( int a, int b )
{
    return a + b;
}

long multiply( int a, int b )
{
    return a * b;
}

int is_prime( int n )
{
    int i, prime = 1;
    for( i = 2; i <= sqrt( n ); i++ )
        if( 0 == ( n % i ) )
            prime = 0;
    return prime;
}

/* END */
