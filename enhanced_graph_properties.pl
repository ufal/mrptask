#!/usr/bin/env perl
# Reads the graph in the DEPS column of a CoNLL-U file and tests it on various graph properties.
# Copyright © 2019 Dan Zeman <zeman@ufal.mff.cuni.cz>
# License: GNU GPL

use utf8;
use open ':utf8';
binmode(STDIN, ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');

my @sentence;
while(<>)
{
    if(m/^\s*$/)
    {
        process_sentence(@sentence);
        @sentence = ();
    }
    else
    {
        s/\r?\n$//;
        push(@sentence, $_);
    }
}
# In case of incorrect files that lack the last empty line:
if(scalar(@sentence) > 0)
{
    process_sentence(@sentence);
}
# Print the statistics.
print("$stats{n_graphs} graphs\n");
print("$stats{n_nodes} nodes\n");
print("$stats{n_edges} edges (not counting '0:root')\n");
print("$stats{n_single} singletons\n");
print("$stats{n_in2plus} nodes with in-degree greater than 1\n");
print("$stats{n_indep} independent non-top nodes (zero in, nonzero out)\n");



#------------------------------------------------------------------------------
# Processes one sentence after it has been read.
#------------------------------------------------------------------------------
sub process_sentence
{
    my @sentence = @_;
    # Get rid of everything except the node lines. But include empty nodes!
    my @nodes = grep {m/^\d+(\.\d+)?\t/} (@sentence);
    my %id2i;
    for(my $i = 0; $i <= $#nodes; $i++)
    {
        my @fields = split(/\t/, $nodes[$i]);
        $nodes[$i] = \@fields;
        # Node ids do not necessarily correspond to their index in the array. Get the mapping.
        $id2i{$fields[0]} = $i;
    }
    # Additional, structured fields for each node:
    # $node->[10] => [list of {parents}]
    # $node->[11] => [list of {children}]
    for(my $i = 0; $i <= $#nodes; $i++)
    {
        my $deps = $nodes[$i][8];
        $deps = '' if($deps eq '_');
        my @deps = split(/\|/, $deps);
        foreach my $dep (@deps)
        {
            if($dep =~ m/^(\d+(?:\.\d+)?):(.+)$/)
            {
                my $h = $1;
                my $d = $2;
                # Store the parent in my column [10].
                my %pr =
                (
                    'id' => $h,
                    'i'  => $id2i{$h},
                    'deprel' => $d
                );
                push(@{$nodes[$i][10]}, \%pr);
                # Store me as a child in the parent's column [11] (unless the parent is 0:root).
                unless($h==0)
                {
                    my %cr =
                    (
                        'id' => $nodes[$i][0],
                        'i'  => $i,
                        'deprel' => $d
                    );
                    push(@{$nodes[$id2i{$h}][11]}, \%cr);
                }
            }
            else
            {
                print STDERR ("WARNING: Cannot understand dep '$dep'\n");
            }
        }
    }
    # We now have a complete representation of the graph and can run various
    # functions that will examine it and collect statistics about it.
    find_singletons(@nodes);
}



#------------------------------------------------------------------------------
# Finds singletons, i.e., nodes that have no incoming or outgoing edges.
#------------------------------------------------------------------------------
sub find_singletons
{
    my @nodes = @_;
    # Remember the total number of graphs.
    $stats{n_graphs}++;
    for(my $i = 0; $i <= $#nodes; $i++)
    {
        # Remember the total number of nodes.
        $stats{n_nodes}++;
        my $indegree = scalar(@{$nodes[$i][10]});
        my $outdegree = scalar(@{$nodes[$i][11]});
        # Count edges except the '0:root' edge.
        $stats{n_edges} += $outdegree;
        if($indegree==0 && $outdegree==0)
        {
            $stats{n_single}++;
        }
        elsif($indegree==0 && $outdegree >= 1)
        {
            # This node is not marked as "top node" because then it would have
            # the incoming edge '0:root' and its in-degree would be 1.
            $stats{n_indep}++;
        }
        elsif($indegree > 1)
        {
            $stats{n_in2plus}++;
        }
    }
}
