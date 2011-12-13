use Test::More tests => 2;
use MooseX::Declare;

class Local::Test::Mocking::Module::Reprove
	extends Module::Reprove
{
	use IO::Scalar;
	
	has should_pass => (is => 'ro', default => 1);
	
	method _getfile_to_handle (Str $file, $fh)
	{
		if ($file eq 'MANIFEST')
		{
			print $fh "t/01mock.t\n";
		}
		elsif ($file eq 't/01mock.t')
		{
			printf $fh "use Test::More tests => 1;\n";
			printf $fh "ok(%d, 'Mock test');\n", $self->should_pass;
		}
		else
		{
			$self->SUPER::_getfile_to_handle($file, $fh);
		}
	}

	method _app_prove_args
	{
		return ('-Q', 't');
	}
	
	method dummy {}
}

my $r1 = Local::Test::Mocking::Module::Reprove->new(
	release     => 'Object::AUTHORITY',
	version     => '0.003',
	author      => 'TOBYINK',
	should_pass => 1,
	);
my $r2 = Local::Test::Mocking::Module::Reprove->new(
	release     => 'Object::AUTHORITY',
	version     => '0.003',
	author      => 'TOBYINK',
	should_pass => 0,
	);

ok($r1->run, "Real test: should pass");
diag "Ignore the warning about the 'mock test' failing.";
diag "The mock test is supposed to fail!";
ok(!$r2->run, "Real test: should fail");
