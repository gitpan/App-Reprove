package App::Reprove; # for CPAN indexer

use 5.010;
use autodie;
use common::sense;
use MooseX::Declare;

BEGIN {
	$App::Reprove::AUTHORITY = 'cpan:TOBYINK';
	$App::Reprove::VERSION   = '0.003';
}

class App::Reprove
	with MooseX::Getopt
{
	use Module::Reprove;
	use Object::AUTHORITY qw/AUTHORITY/;
	
	has [qw/author module release version/] => (
		is       => 'rw',
		isa      => 'Str|Undef',
		required => 0,
		);
		
	has [qw/verbose/] => (
		is       => 'rw',
		isa      => 'Bool',
		required => 0,
		);
		
	has reprover => (
		is       => 'ro',
		isa      => 'Module::Reprove',
		lazy     => 1,
		builder  => '_build_reprover',
		handles  => [qw/test_files manifest testdir/],
		);
	
	method BUILD
	{
		my ($release, $version, $author) = @{ $self->extra_argv };
		
		$self->author($author) unless defined $self->author;
		$self->version($version) unless defined $self->version;
		
		unless (defined $self->release or defined $self->module)
		{
			$release //= '';
			if ($release =~ /^::(.+)$/)
			{
				$self->module($1);
			}
			elsif ($release =~ /::/)
			{
				$self->module($release);
			}
			elsif (length $release)
			{
				$self->release($release);
			}
		}
		
		die "Need to provide module name, or release name plus version.\n"
			unless (defined $self->module or defined $self->release && $self->version);
	}
	
	sub does
	{
		my ($self, $role) = @_;
		return 1 if $role eq 'Module::Reprove';
		return $self->SUPER::does($role);
	}
	
	method _build_reprover
	{
		Module::Reprove->new(
			author    => defined $self->author ? (uc $self->author) : undef,
			module    => $self->module,
			release   => $self->release,
			version   => $self->version,
			verbose   => !!$self->verbose,
			);
	}
	
	method run
	{
		my $r = $self->reprover;
		printf("Reproving %s/%s (%s)\n", $r->release, $r->version, uc $r->author);
		printf("Using temp dir '%s'\n", $r->testdir->dirname) if $self->verbose;
		$r->run;
	}
}

1;

__END__

=head1 NAME

App::Reprove - command-line processing for Module::Reprove

=head1 SYNOPSIS

In "bin/reprove":

  #!/usr/bin/perl
  App::Reprove->new_with_options->run;

And at the command line:

  ./bin/reprove --verbose \
    --author="TOBYINK" \
    --release="Object-AUTHORITY" \
    --version="0.001"

=head1 DESCRIPTION

This module provides a C<< new_with_options >> constructor, courtesy of
L<MooseX::Getopt>, but otherwise mocks L<Module::Reprove> using delegation.

=head2 Constructors

=over

=item C<< new(%attributes) >>

=item C<< new_with_options() >>

=back

=head2 Attributes

=over

=item C<< release >>

=item C<< module >>

=item C<< version >>

=item C<< author >>

=item C<< verbose >>

=item C<< testdir >>

=back

=head2 Methods

=over

=item C<< does >>

Over-ridden from L<Moose::Object> to allow C<< App::Reprove->does('Module::Reprove') >>.

=item C<< test_files >>

=item C<< run >>

=back

=head1 BUGS

Please report any bugs to
L<http://rt.cpan.org/Dist/Display.html?Queue=App-Reprove>.

=head1 SEE ALSO

L<reprove>, L<Module::Reprove>.

=head1 AUTHOR

Toby Inkster E<lt>tobyink@cpan.orgE<gt>.

=head1 COPYRIGHT AND LICENCE

This software is copyright (c) 2011 by Toby Inkster.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 DISCLAIMER OF WARRANTIES

THIS PACKAGE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.

