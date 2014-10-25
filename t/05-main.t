#!perl

#use Test::More qw(no_plan);
use Test::More tests => 21;

#-----------------------------------------------------------------
# Return a fully qualified name of the given file in the test
# directory "t/data" - if such file really exists. With no arguments,
# it returns the path of the test directory itself.
# -----------------------------------------------------------------
use FindBin qw( $Bin );
use File::Spec;
sub test_file {
    my $file = File::Spec->catfile ('t', 'data', @_);
    return $file if -e $file;
    $file = File::Spec->catfile ($Bin, 'data', @_);
    return $file if -e $file;
    return File::Spec->catfile (@_);
}

# -----------------------------------------------------------------
# Tests start here...
# -----------------------------------------------------------------
ok(1);
use Proc::Async;
diag( "Main functions" );

my $extester = File::Spec->rel2abs (test_file ('extester'));

# job 1
my $jobid = Proc::Async->start ($extester);
ok ($jobid, "start(): Job ID not created");
my $wdir = Proc::Async->working_dir ($jobid);
ok (-e $wdir && -d $wdir, "Working directory failed");
my $cfgfile = File::Spec->catfile ($wdir, Proc::Async::CONFIG_FILE);
ok (-e $cfgfile && -f $cfgfile, "CONFIG_FILE failed");
is (Proc::Async->clean ($jobid), 4, "Removing 4 files failed");

# job 1
$jobid =
    Proc::Async->start ($extester,
                        qw{ -stdout OUT -stderr ERR -exit 5 -create a1.tmp=1 -create c/d/x/a2.tmp=2 -create empty/=0});
$wdir = Proc::Async->working_dir ($jobid);
my $count = 0;
while (not Proc::Async->is_finished ($jobid)) {
    sleep 1;
    last if $count++ > 10;   # precaution
}
is (Proc::Async->status ($jobid), Proc::Async::STATUS_TERM_BY_ERR, "Status failed");
is (Proc::Async->stdout ($jobid), "OUT\n", "STDOUT failed");
is (Proc::Async->stderr ($jobid), "ERR\n", "STDERR failed");
ok (join (',', Proc::Async->status ($jobid)) =~ m{exit code 5}, "Exit code failed");
my @files = Proc::Async->result_list ($jobid);
is (scalar @files, 2, "Result list failed");
foreach my $file (@files) {
    $fullfile = File::Spec->catfile ($wdir, $file);
    ok (-e $fullfile, "File $fullfile does not exist");
    ok (Proc::Async->result ($jobid, $file) =~ m{^1}, "$file does not start correctly");
}
my $empty = File::Spec->catfile ($wdir, 'empty');
ok (-e $empty && -d $empty, "Empty failed");
Proc::Async->clean ($jobid);

# job 3
$jobid = Proc::Async->start ("$extester -sleep 60");
ok (!Proc::Async->is_finished ($jobid), "Finished prematurely");
is (Proc::Async->signal ($jobid), 1, "Killed failed");
is (Proc::Async->signal ($jobid), 0, "Killed did not failed");
Proc::Async->clean ($jobid);

# job 4
$jobid = Proc::Async->start ("$extester -sleep 60");
ok (!Proc::Async->is_finished ($jobid), "Finished prematurely");
is (Proc::Async->signal ($jobid, 9), 1, "Killed failed");
is (Proc::Async->signal ($jobid, 9), 0, "Killed did not failed");
Proc::Async->clean ($jobid);


__END__
