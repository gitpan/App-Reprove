package Module::Reprove; # for CPAN indexer

use 5.010;
use autodie;
use common::sense;
use MooseX::Declare;

BEGIN
{
	$Module::Reprove::AUTHORITY = 'cpan:TOBYINK';
	$Module::Reprove::VERSION   = '0.001';
}

class Module::Reprove
{
	use App::Prove qw//;
	use Class::Load qw/load_class/;
	use JSON qw/from_json/;
	use File::Basename qw/fileparse/;
	use File::pushd qw/pushd/;
	use File::Path qw/make_path/;
	use File::Spec qw//;
	use File::Temp qw//;
	use LWP::Simple qw/get/;
	use Module::Manifest qw//;
	use Object::AUTHORITY qw/AUTHORITY/;
	
	has author    => (is => 'ro', isa => 'Str', lazy => 1, builder => '_build_author');
	has release   => (is => 'ro', isa => 'Str', required => 1);
	has version   => (is => 'ro', isa => 'Str', required => 1);
	has manifest  => (is => 'ro', isa => 'ArrayRef[Str]', lazy => 1, builder => '_build_manifest');
	has testdir   => (is => 'ro', isa => 'File::Temp::Dir', lazy => 1, builder => '_build_testdir');
	has verbose   => (is => 'rw', isa => 'Bool', required => 1, default => 0);
	
	method BUILDARGS ($class: @args)
	{
		my %args;
		if (@args == 1 and ref $args[0])
		{
			%args = %{ $args[0] }
		}
		elsif (scalar(@args) % 2 == 0)
		{
			%args = @args;
		}
		else
		{
			confess "Called with the wrong number of arguments.";
		}
		
		if (defined $args{module} and not defined $args{version})
		{
			load_class($args{module});
			$args{version} = $args{module}->VERSION;
		}
		
		if (defined $args{module} and not defined $args{author})
		{
			load_class($args{module});
			if ($args{module}->can('AUTHORITY'))
			{
				($args{author}) =
					map { s/^cpan://; $_ }
					grep { /^cpan:/ }
					($args{module}->AUTHORITY);
			}
			else
			{
				no strict 'refs';
				my $auth = ${$args{module}.'::AUTHORITY'};
				if ($auth =~ /^cpan:(.+)$/)
				{
					$args{author} = $1;
				}
			}
		}
		
		if (defined $args{module} and not defined $args{release})
		{
			my $d = from_json(get(sprintf('http://api.metacpan.org/v0/module/%s', $args{module})));
			$args{release}  = $d->{distribution};
			$args{author} //= $d->{author};
		}
		
		if (defined $args{release} and not defined $args{author})
		{
			my $d = from_json(get(sprintf('http://api.metacpan.org/v0/release/%s', $args{release})));
			$args{author} //= $d->{author};
		}
		
		delete $args{module};
		$class->SUPER::BUILDARGS(%args);
	}
	
	method _url_for (Str $file)
	{
		sprintf(
			'http://api.metacpan.org/source/%s/%s-%s/%s',
			uc $self->author,
			$self->release,
			$self->version,
			$file,
			);
	}
	
	method _getfile_to_handle (Str $file, $fh)
	{
		print $fh get($self->_url_for($file));
	}
	
	method test_files
	{
		grep { m{^t/} } @{ $self->manifest };
	}
	
	method _build_author
	{
		my $d = from_json(get(
			sprintf('http://api.metacpan.org/v0/release/%s', $self->release)
			));
		$d->{author};
	}
	
	method _build_manifest
	{
		my $fh = File::Temp->new;
		binmode( $fh, ":utf8");
		$self->_getfile_to_handle('MANIFEST', $fh);
		close $fh;
		
		my $manifest = Module::Manifest->new;
		$manifest->open(manifest => $fh->filename);
		return [ $manifest->files ];
	}
	
	method _build_testdir
	{
		my $testdir = File::Temp->newdir;
		
		foreach my $file ($self->test_files)
		{
			my $dest = File::Spec->catfile($testdir->dirname, $file);
			
			my (undef, $d, undef) = fileparse($dest);
			make_path($d);
			
			open my $fh, '>', $dest;
			$self->_getfile_to_handle($file, $fh);
			close $fh;
		}
		
		return $testdir;
	}
	
	method _app_prove_args
	{
		't';
	}
	
	method run
	{
		my $chdir = pushd($self->testdir->dirname);
		my $app   = App::Prove->new;
		$app->process_args($self->_app_prove_args);
		$app->verbose(1) if $self->verbose;
		$app->run;
	}
}

1;

__END__

=head1 NAME

Module::Reprove - download a distribution's tests and prove them

=head1 SYNOPSIS

 my $test = CPAN::Retest->new(
    author  => 'TOBYINK',
    release => 'Object-AUTHORITY',
    version => '0.003',
    verbose => 1,
    );
 $test->run;

=head1 DESCRIPTION

This module downloads a distribution's test files (the contents of the C<t>
directory) and runs L<App::Prove> (part of L<Test::Harness>) on them.

It assumes that all the other files necessary for passing the test suite are
already available on your system, installed into locations where the test suite
will be able to find them. In particular, the libraries necessary to pass the
test suite must be installed.

It makes a number of assumptions about how a distribution's test cases are
structured, but these assumptions do tend to hold in most cases.

=head2 Constructor

=over

=item C<< new(%attributes) >>

Construct an object with given attributes. This is a Moose-based class.

=back

=head2 Attributes

=over

=item C<< release >>

Release name, e.g. "Moose" or "RDF-Trine". Required.

=item C<< version >>

Release version, e.g. "2.0001" or "0.136". Required.

=item C<< author >>

Release author's CPAN ID, e.g. "DOY" or "GWILLIAMS". If this is not provided,
it can usually be figured out using the MetaCPAN API, but it's a good idea
to provide it.

=item C<< verbose >>

Boolean indicating whether output should be verbose. Optional, defaults to false.

=item C<< manifest >>

An arrayref of strings, listing all the files in the distribution.
Don't provide this to the constructor - just allow Module::Reprove
to build it.

=item C<< testdir >>

A L<File::Temp::Dir> object pointing to a directory which contains
a subdirectory "t" full of test files. Don't provide this to the
constructor - just allow Module::Reprove to build it.

=back

There is also a pseudo-attribute C<< module >> which may be provided to the
constructor, and allows the automatic calculation of C<< release >>,
C<< version >> and C<< author >>. There is no getter/setter method for
C<< module >> though; it is not a true attribute.

=head2 Methods

=over

=item C<< test_files >>

Returns a list of test case files, based on the contents of the manifest.

=item C<< run >>

Runs the test using C<< App::Prove::run >> and returns whatever L<App::Prove>
would have returned, which is undocumented but appears to be false if there
are test failures, and true if all tests pass.

=back

=head1 BUGS

Please report any bugs to
L<http://rt.cpan.org/Dist/Display.html?Queue=App-Reprove>.

=head1 SEE ALSO

L<App::Prove>.

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

