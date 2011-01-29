package Alien::SWIG;
#
#   Alien::SWIG - Provides config info for SWIG configuration
#
#   Copyright (c) 2010-2011 Jason McManus
#
#   Full POD documentation after __END__
#

use File::Spec;
use Carp qw( croak confess );
use Config ();
use strict;
use warnings;

###
### Variables
###

use vars qw( @ISA @EXPORT_OK $VERSION $TRUE $FALSE );

BEGIN {
    require Exporter;
    @ISA        = qw( Exporter );
    @EXPORT_OK  = qw( path version executable module_dir includes cmd_line );
    $VERSION    = '0.00_02';
}

*TRUE     = \1;
*FALSE    = \0;

my $SWIG_VERFILE     = 'swig-version.txt';
my $SWIG_BINARY      = 'swig';

# Global cache; either points to object ref, or just used as is.
# XXX: This will explode upon multiple Alien::SWIG objects being created,
# but we'll worry about that if anyone ever needs to actually do that.
my $CACHE;

###
### Constructor
###

sub new
{
    my $class = shift;

    # Set up a default object
    my $self = {
        module_dir => module_dir(),
    };

    # Instantiate the object.  sort of.
    bless( $self, $class );

    # Direct the global cache to us (see note above)
    $CACHE = $self;

    # Set the SWIG_LIB envvar
    $ENV{SWIG_LIB} = $self->{module_dir};

    return( $self );
}

###
### Methods
###

sub path
{
    return( $CACHE->{path} )
        if( defined( $CACHE ) and exists( $CACHE->{path} ) );

    my $path = $INC{"Alien/SWIG.pm"};
    $path    =~ s{\.pm$}{};
    $path    = File::Spec->catfile( $path, 'swig' );

    croak( "Path $path\n doesn't appear to contain the SWIG installation;" .
           " please re-install Alien::SWIG.\n " )
        unless( -d $path and -r File::Spec->catfile( $path, $SWIG_VERFILE ) );

    $CACHE->{path} = $path
        if( defined( $CACHE ) );

    return( $path );
}

sub version
{
    return( $CACHE->{version} )
        if( defined( $CACHE ) and exists( $CACHE->{version} ) );

    my $verfile = File::Spec->catfile( path(), $SWIG_VERFILE );

    open my $fd, '<', $verfile or
       croak( "Cannot read SWIG version file; please re-install Alien::SWIG.\n " );
    my $version = do { local $/; <$fd> };
    close( $fd );
    chomp $version;

    croak( "Could not read version number; please re-install Alien::SWIG.\n " )
        unless( defined( $version ) );

    $CACHE->{version} = $version
        if( defined( $CACHE ) );

    return( $version );
}

sub includes
{
    my @includes;

    if( defined( $CACHE ) and exists( $CACHE->{includes} ) )
    {
        @includes = @{ $CACHE->{includes} };
    }
    else
    {
        my $base = File::Spec->catfile( path(), 'share', 'swig', version() );

        @includes = (
            $base,
            File::Spec->catfile( $base, 'typemaps' ),
            File::Spec->catfile( $base, 'std' ),
            File::Spec->catfile( $base, 'perl5' ),
        );
        for( @includes )
        {
            croak( "Cannot find $_ include directory under $base; please" .
                   " re-install Alien::SWIG.\n " )
                unless( -d $_ );
            $_ = '-I' . $_;             # modify inline
        }

        $CACHE->{includes} = \@includes
            if( defined( $CACHE ) );
    }

    return( wantarray
              ? @includes
              : join( ' ', @includes ) );
}

sub executable
{
    return( $CACHE->{executable} )
        if( defined( $CACHE ) and exists( $CACHE->{executable} ) );

    my $bin = File::Spec->catfile( path(), 'bin', $SWIG_BINARY );

    croak( "Cannot find or execute $bin; please re-install Alien::SWIG.\n " )
        unless( -x $bin );

    $CACHE->{executable} = $bin
        if( defined( $CACHE ) );

    return( $bin );
}

sub module_dir 
{
    return( $CACHE->{module_dir} )
        if( defined( $CACHE ) and exists( $CACHE->{module_dir} ) );

    my $base = File::Spec->catfile( path(), 'share', 'swig', version() );

    croak( "Module dir $base does not exist; please re-install Alien::SWIG.\n ")
        unless( -d $base );

    $CACHE->{module_dir} = $base
        if( defined( $CACHE ) );

    return( $base );
}

sub cmd_line
{
    return( join( ' ', executable(), includes() ) );
}


###
### "Private" methods
###

sub _get_config {
    my( $self, $config_item ) = ( shift, shift );

    my @garbage = Config::config_re( $config_item );

    return unless( scalar( @garbage ) );

    my $val = $garbage[0];
    $val =~ s/^.*?='(.*)'$/$1/;     # Config.pm is SO ANNOYING

    return( $val );
}

1;

__END__

=pod

=head1 NAME

Alien::SWIG - Provides installation and config information for SWIG

=head1 SYNOPSIS

    use Alien::SWIG;

    my $swig       = Alien::SWIG->new();

    my $path       = $swig->path();
    my $version    = $swig->version();
    my $executable = $swig->executable();
    my $includes   = $swig->includes();
    my $module_dir = $swig->module_dir();
    my $cmd_line   = $swig->cmd_line();

=head1 DESCRIPTION

This module automates the installation of SWIG - The Simplified Wrapper
and Interface Generator, building from source code (downloading if necessary),
and provides accessor functions to describe its location, module paths, etc.

This module comes distributed with and installs SWIG version B<2.0.1> by
default, but you can specify a different version to build and install, and
it will do its best to find, download, build, and install that version, as
long as it's available in the SWIG SourceForge repository at
L<http://sourceforge.net/projects/swig/files/swig/>.

Please see L<Alien> for an explanation of the Alien namespace.

=head1 BUILD ARGUMENTS

You can specify an alternate version of SWIG to build and install by using
the C<--swigver=X.X.X> argument to C<Build.PL>, e.g.:

    perl Build.PL --swigver=1.3.40
    ./Build
    ./Build test
    ./Build install

This would download swig-1.3.40.tar.gz and build and install that, instead.

This module has been tested with SWIG versions B<1.3.28 - 2.0.1>.  I don't
think anything prior to that will work with it, due to the lack of typemaps
before then.

=head1 CONSTRUCTOR

=head2 new()

    my $swig = Alien::SWIG->new();

Create a new Alien::SWIG object for querying the installed configuration.

B<ARGUMENTS:> None.

B<RETURNS:> blessed C<$object>, or C<undef> on failure.

=head1 METHODS

=head2 path()

    my $path = $swig->path();

Get the base install path of the SWIG installation.

B<ARGUMENTS:> None.

B<RETURNS:> Directory C<$name>, with no trailing path separator.

=head2 version()

    my $version = $swig->version();

Get the version of the copy of SWIG that was installed.

(Not to be confused with L<Alien::SWIG> C<$VERSION>, which is
this Perl wrapper's version number.)

B<ARGUMENTS:> None.

B<RETURNS:> The SWIG C<$version> as a string, e.g. C<'2.0.1'>.

=head2 executable()

    my $executable = $swig->executable();

Get the location of the C<swig> executable program, that was compiled
during the installation of this module.

B<ARGUMENTS:> None.

B<RETURNS:> Absolute path to C<swig>, ready for executing.

=head2 includes()

    # As string
    my $includes = $swig->includes();

    # As list
    my @includes = $swig->includes();

Get the SWIG C<-I> include directives needed to run SWIG against the installed
version.  C<swig> has the base path compiled into it, but if for any reason
the path doesn't work, you can use this to manually specify the C<-I>
directives.

B<ARGUMENTS:> None.

B<RETURNS:> Depending on context, returns a C<$scalar> containing all the
paths joined with spaces, as C<-I/path>, or an C<@array> containing all the
paths, as C<-I/path>, one-per-element.

=head2 module_dir()

    my $module_dir = $swig->module_dir();

Get the base directory of the installed SWIG modules.  This can be used to
set the C<SWIG_LIB> environment variable, as detailed in the SWIG docs.

B<ARGUMENTS:> None.

B<RETURNS:> Absolute C<$path> to modules base directory.

=head2 cmd_line()

    my $cmd_line = $swig->cmd_line();

Get a full, working command line, with all the -I directives included, that
you can use to run the installed copy of SWIG.

B<ARGUMENTS:> None.

B<RETURNS:> C<$string> containing a runnable command, with all -I directives
appended.

=head1 EXPORTS

    use Alien::SWIG qw( path version executable module_dir includes );

This module OPTIONALLY exports the following subs:

=over 4

=item * L</"path()">

=item * L</"version()">

=item * L</"executable()">

=item * L</"includes()">

=item * L</"module_dir()">

=item * L</"cmd_line()">

=back

=head1 SEE ALSO

L<http://www.swig.org/> - SWIG, the Simplified Wrapper and Interface Generator

L<http://swig.org/doc.html> - The SWIG Documentation

The F<bin/> directory of this module's distribution

=head1 AUTHORS

Jason McManus, C<< <infidel at cpan.org> >>

=head1 ACKNOWLEDGEMENTS

Many of the build scripts in this module were modelled on L<Alien::IE7>.

=head1 BUGS

=over 4

=item * C<configure> in SWIG doesn't disable multiple language support.

As of 2.0.1, and back as far as this module works with, the C<configure>
script in all SWIG versions support C<--disable-LANG> options for all of
the other languages, but they don't actually seem to disable the other
languages, only the checks during C<make check>.  Not my fault.

See this mailing list post if you'd like more information:
L<https://sourceforge.net/mailarchive/forum.php?thread_name=4D444651.8050303%40fultondesigns.co.uk&forum_name=swig-user>

This module already passes the options, so if it becomes possible at some
point, it will work automagically.

=back

Please report any bugs or feature requests to
C<bug-alien-swig at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Alien-SWIG>.  The authors will be notified, and then you'll
automatically be notified of progress on your bug as changes are made.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Alien::SWIG

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Alien-SWIG>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Alien-SWIG>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Alien-SWIG>

=item * Search CPAN

L<http://search.cpan.org/dist/Alien-SWIG/>

=back

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2011 Jason McManus

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut

# END
