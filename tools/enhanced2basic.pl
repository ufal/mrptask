#!/usr/bin/env perl
# Copies dependencies from enhanced graph to basic tree as long as it stays a tree.
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
    # We now have a complete representation of the graph.
    # @tree is an array of node ids; $tree[$i]==$j means that node with id $i depends on node with id $j.
    my @tree;
    my @deprels;
    for(my $i = 0; $i <= $#nodes; $i++)
    {
        # Skip empty nodes.
        next if($nodes[$i][0] =~ m/\./);
        # Pick the first suitable parent.
        my $found = 0;
        foreach my $parentrecord (@{$nodes[$i][10]})
        {
            # Empty nodes are not suitable parents.
            next if($parentrecord->{id} =~ m/\./);
            # Does the potential parent already depend on me?
            my $depends_on_me = 0;
            for(my $j = $parentrecord->{id}; $j!=0; $j = $tree[$j])
            {
                die("PANIC!!!") if($j==$tree[$j]);
                if($j==$nodes[$i][0])
                {
                    $depends_on_me = 1;
                    last;
                }
            }
            if(!$depends_on_me)
            {
                $tree[$nodes[$i][0]] = $parentrecord->{id};
                $deprels[$nodes[$i][0]] = $parentrecord->{deprel};
                $found = 1;
                last;
            }
        }
        if(!$found)
        {
            $tree[$nodes[$i][0]] = 0;
            $deprels[$nodes[$i][0]] = 'dep';
        }
        $nodes[$i][6] = $tree[$nodes[$i][0]];
        $nodes[$i][7] = $deprels[$nodes[$i][0]];
    }
    # Print the modified sentence.
    foreach my $line (@sentence)
    {
        # If the line corresponds to a node, take the node data instead.
        if($line =~ m/^(\d+(\.\d+)?)\t/)
        {
            my $id = $1;
            my $node = $nodes[$id2i{$id}];
            my @fields = @{$node}[0..9];
            print(join("\t", @fields), "\n");
        }
        else # non-node line
        {
            print("$line\n");
        }
    }
    print("\n");
}
