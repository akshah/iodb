use strict;
use warnings;

use threads;
use Thread::Queue;

# Dummy work routine
sub run {
    my $arg = shift;
    #print($arg);
    my @v=split('\|',$arg);
    print "$v[0] and $v[1]\n";
    sleep 1;
}

for ( 1 .. 4 ) {

    # Read in dummy data
    my @xfoil_args;
    my $test='test';
    push(@xfoil_args,$test.'|'.'1');
    push(@xfoil_args,$test.'|'.'2');
    push(@xfoil_args,$test.'|'.'3');
    push(@xfoil_args,$test.'|'.'4');
    push(@xfoil_args,$test.'|'.'5');
    push(@xfoil_args,$test.'|'.'6');
    push(@xfoil_args,$test.'|'.'7');
    push(@xfoil_args,$test.'|'.'8');
    
    chomp @xfoil_args;
    #print(@xfoil_args,"\n");

    my $queue = Thread::Queue->new(@xfoil_args);
    # Create a bunch of threads to do the work
    my @threads;
    for ( 1 .. 4 ) {
        push @threads, threads->create(
            sub {
                print("In Threads");
                # Pull work from the queue, don't wait if its empty
                while ( my $xfoil_args = $queue->dequeue_nb ) {

                    # Do the work
                    run($xfoil_args);
                }

                # Yell when the thread is done
                #print "Queue empty\n";
            }
        );
    }

    # Wait for threads to finish
    $_->join for @threads;

}
