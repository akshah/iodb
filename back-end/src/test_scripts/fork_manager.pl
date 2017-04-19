use Parallel::ForkManager;

my $process_count = 2;

sub run {
    print("In Run\n");
}


my @entries;
push(@entries,'test1');
push(@entries,'test2');
push(@entries,'test3');
push(@entries,'test4');
push(@entries,'test5');

my $pm = Parallel::ForkManager->new($process_count);


foreach my $b ( @entries ) {
    print " processing: $b\n";

    my $pid = $pm->start and next;
    run();
    $pm->finish;
}
