#!/usr/bin/env perl
# Reads the graph in the DEPS column of a CoNLL-U file and tests it on various graph properties.
# Copyright © 2019 Dan Zeman <zeman@ufal.mff.cuni.cz>
# License: GNU GPL

use utf8;
use open ':utf8';
binmode(STDIN, ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');

my %stats =
(
    'n_graphs' => 0,
    'n_nodes'  => 0,
    'n_empty_nodes' => 0,
    'n_overt_nodes' => 0,
    'n_edges'  => 0,
    'n_single' => 0,
    'n_in2plus' => 0,
    'n_top1'   => 0,
    'n_top2'   => 0,
    'n_indep'  => 0,
    'n_cyclic_graphs' => 0,
    'n_unconnected_graphs'  => 0,
    'gapping'               => 0,
    'conj_effective_parent' => 0,
    'conj_shared_dependent' => 0,
    'xsubj'                 => 0,
    'relcl'                 => 0,
    'case_deprel'           => 0
);
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
print("  $stats{n_overt_nodes} overt surface nodes\n");
print("  $stats{n_empty_nodes} empty nodes\n");
print("$stats{n_edges} edges (not counting dependencies on 0)\n");
print("$stats{n_single} singletons\n");
print("$stats{n_in2plus} nodes with in-degree greater than 1\n");
print("$stats{n_top1} top nodes only depending on 0\n");
print("$stats{n_top2} top nodes with in-degree greater than 1\n");
print("$stats{n_indep} independent non-top nodes (zero in, nonzero out)\n");
print("$stats{n_cyclic_graphs} graphs that contain at least one cycle\n");
print("$stats{n_unconnected_graphs} graphs with multiple non-singleton components\n");
print("Enhancements defined in Enhanced Universal Dependencies v2 (number of observed signals that the enhancement is applied):\n");
print("* Gapping:             $stats{gapping}\n");
print("* Coord shared parent: $stats{conj_effective_parent}\n");
print("* Coord shared depend: $stats{conj_shared_dependent}\n");
print("* Controlled subject:  $stats{xsubj}\n");
print("* Relative clause:     $stats{relcl}\n");
print("* Deprel with case:    $stats{case_deprel}\n");



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
    #print_sentence(@sentence) if(find_cycles(@nodes));
    find_cycles(@nodes);
    #print_sentence(@sentence) if(find_components(@nodes));
    find_components(@nodes);
    # Only for enhanced UD graphs:
    find_enhancements(@nodes);
}



#------------------------------------------------------------------------------
# Prints a sentence in the CoNLL-U format to the standard output.
#------------------------------------------------------------------------------
sub print_sentence
{
    my @sentence = @_;
    print(join("\n", @sentence), "\n\n");
}



#------------------------------------------------------------------------------
# Finds singletons, i.e., nodes that have no incoming or outgoing edges. Also
# finds various other special types of nodes.
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
        if($nodes[$i][0] =~ m/\./)
        {
            $stats{n_empty_nodes}++;
        }
        else
        {
            $stats{n_overt_nodes}++;
        }
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
        elsif($indegree==1 && $nodes[$i][10][0]{id} == 0)
        {
            $stats{n_top1}++;
        }
        elsif($indegree > 1)
        {
            $stats{n_in2plus}++;
            if(grep {$_->{id}==0} (@{$nodes[$i][10]}))
            {
                $stats{n_top2}++;
            }
        }
    }
}



#------------------------------------------------------------------------------
# Finds directed cycles. Does not try to count all cycles; stops after finding
# the first cycle in the graph.
#------------------------------------------------------------------------------
sub find_cycles
{
    my @nodes = @_;
    # @queue is the list of unprocessed partial paths. In the beginning, there
    # is one path for every node of the graph, and the path initially contains
    # only that node.
    my @stack = map {[$_]} (@nodes);
    my %processed_node_ids;
    while(my $curpath = pop(@stack))
    {
        # @curpath is the array of nodes that are in the current path.
        # Adding a node that is already in the path would mean that the path contains a cycle.
        my @curpath = @{$curpath};
        # $curnode is the last node of the current path. We will process all its children.
        my $curnode = $curpath[-1];
        # Do not process the node if it has been processed previously.
        unless(exists($processed_node_ids{$curnode->[0]}))
        {
            my @curidpath = map {$_->[0]} (@curpath);
            #print STDERR ("Processing path ", join(',', @curidpath), "\n");
            # Find all children of the last node in the current path. For each of them
            # create an extension of the current path and add it to the queue of paths.
            my @children = @{$curnode->[11]};
            foreach my $childrecord (@children)
            {
                #print STDERR ("Child id=$childrecord->{id} i=$childrecord->{i} deprel=$childrecord->{deprel}\n");
                my $childnode = $nodes[$childrecord->{i}];
                my $childid = $childnode->[0];
                if(grep {$_==$childid} (@curidpath))
                {
                    $stats{n_cyclic_graphs}++;
                    return 1;
                }
                my @extpath = @curpath;
                push(@extpath, $childnode);
                push(@stack, \@extpath);
            }
            # $curnode has been processed.
            # We do not have to process it again if we arrive at it via another path.
            # We will not miss a cycle that goes through that $curnode.
            # Note: We could not do this if we used a queue instead of a stack!
            $processed_node_ids{$curnode->[0]}++;
        }
    }
}



#------------------------------------------------------------------------------
# Finds non-singleton components, i.e., whether the graph is connected.
#------------------------------------------------------------------------------
sub find_components
{
    my @nodes = @_;
    my %component_node_ids;
    my $component_size = 0;
    foreach my $node (@nodes)
    {
        my $indegree = scalar(@{$node->[10]});
        my $outdegree = scalar(@{$node->[11]});
        # Ignore singletons.
        unless($indegree+$outdegree==0)
        {
            # Did we find a non-singleton component previously?
            if($component_size==0)
            {
                # Collect all nodes in the current component.
                my @nodes_to_process = ($node);
                my %processed_node_ids;
                while(my $curnode = pop(@nodes_to_process))
                {
                    next if(exists($processed_node_ids{$curnode->[0]}));
                    foreach my $parentrecord (@{$curnode->[10]})
                    {
                        unless($parentrecord->{id}==0 || exists($processed_node_ids{$parentrecord->{id}}))
                        {
                            push(@nodes_to_process, $nodes[$parentrecord->{i}]);
                        }
                    }
                    foreach my $childrecord (@{$curnode->[11]})
                    {
                        unless(exists($processed_node_ids{$childrecord->{id}}))
                        {
                            push(@nodes_to_process, $nodes[$childrecord->{i}]);
                        }
                    }
                    $processed_node_ids{$curnode->[0]}++;
                }
                %component_node_ids = %processed_node_ids;
                $component_size = scalar(keys(%component_node_ids));
            }
            # If there is already a component, any subsequent non-singleton node
            # is either part of it or of some other component. The only thing
            # we are interested in is to see whether there is a second component.
            else
            {
                if(!exists($component_node_ids{$node->[0]}))
                {
                    $stats{n_unconnected_graphs}++;
                    return 1;
                }
            }
        }
    }
}



#==============================================================================
# Statistics specific to the Enhanced Universal Dependencies v2.
# 1. Ellipsis (gapping).
# 2. Coordination (propagation of dependencies to conjuncts).
# 3. Control verbs.
# 4. Relative clauses.
# 5. Case markers added to dependency relation types.
#==============================================================================



#------------------------------------------------------------------------------
# Returns the type (label) of the relation between parent $p and child $c.
# Returns undef if the two nodes are not connected with an edge. It is assumed
# that there is at most one relation between any two nodes. Although
# technically it is possible to represent multiple relations in the enhanced
# graph, the guidelines do not support it. The nodes $p and $c are identified
# by their indices in the list of nodes of the graph.
#------------------------------------------------------------------------------
sub relation
{
    my $p = shift;
    my $c = shift;
    my @nodes = @_;
    my @children = @{$nodes[$p][11]};
    my @matching_children = grep {$_->{i} == $c} (@children);
    if(scalar(@matching_children)==0)
    {
        return undef;
    }
    else
    {
        if(scalar(@matching_children)>1)
        {
            print STDERR ("WARNING: Enhanced graph should not connect the same two nodes twice.\n");
        }
        return $matching_children[0]->{deprel};
    }
}



#------------------------------------------------------------------------------
# Tries to detect various types of enhancements defined in Enhanced UD v2.
#------------------------------------------------------------------------------
sub find_enhancements
{
    my @nodes = @_;
    for(my $i = 0; $i <= $#nodes; $i++)
    {
        my $curnode = $nodes[$i];
        my @parents = @{$curnode->[10]};
        my @children = @{$curnode->[11]};
        # Element of @parents or @children is a record (hash reference) with the following fields:
        # id (the first column), i (index in @nodes), deprel (string)
        # The presence of an empty node signals that gapping is resolved.
        if($curnode->[0] =~ m/\./)
        {
            $stats{gapping}++;
            ###!!! We may want to check other attributes of gapping resolution:
            ###!!! 1. there should be no 'orphan' relations in the enhanced graph.
            ###!!! 2. the empty node should be attached as conjunct to a verb. Perhaps it should also have a copy of the verb's form lemma, tag and features.
            ###!!! 3. the empty node should have at least two non-functional children (subj, obj, obl, advmod, ccomp, xcomp, advcl).
        }
        # Parent propagation in coordination: 'conj' (always?) accompanied by another relation.
        # Shared child propagation: node has at least two parents, one of them is 'conj' of the other.
        ###!!! We may also want to check whether there are any contentful dependents of a first conjunct that are not shared.
        if(scalar(@parents) >= 2 &&
           scalar(grep {$_->{deprel} =~ m/^conj(:|$)/} (@parents)) > 0 &&
           scalar(grep {$_->{deprel} !~ m/^conj(:|$)/} (@parents)) > 0)
        {
            $stats{conj_effective_parent}++;
        }
        if(scalar(@parents) >= 2)
        {
            # Find grandparents such that their relation to the parent is 'conj' and my relation to the parent is not 'conj'.
            my %gpconj;
            foreach my $parentrecord (@parents)
            {
                if($parentrecord->{deprel} !~ m/^conj(:|$)/)
                {
                    my @grandparents = @{$nodes[$parentrecord->{i}][10]};
                    foreach my $grandparentrecord (@grandparents)
                    {
                        if($grandparentrecord->{deprel} =~ m/^conj(:|$)/)
                        {
                            $gpconj{$grandparentrecord->{id}}++;
                        }
                    }
                }
            }
            # Is one of those grandparents also my non-conj parent?
            my $found = 0;
            foreach my $parentrecord (@parents)
            {
                if($parentrecord->{deprel} !~ m/^conj(:|$)/ && exists($gpconj{$parentrecord->{id}}))
                {
                    $found = 1;
                    last;
                }
            }
            if($found)
            {
                $stats{conj_shared_dependent}++;
            }
        }
        # Subject propagation through xcomp: at least two parents, I am subject
        # or object of one, and subject of the other. The latter parent is xcomp of the former.
        my @subjpr = grep {$_->{deprel} =~ m/^nsubj(:|$)/} (@parents);
        my @xcompgpr;
        foreach my $pr (@subjpr)
        {
            my @xgpr = grep {$_->{deprel} =~ m/^xcomp(:|$)/} (@{$nodes[$pr->{i}][10]});
            push(@xcompgpr, @xgpr);
        }
        my @coreprxgpr = grep {my $r = relation($_->{i}, $i, @nodes); defined($r) && $r =~ m/^(nsubj|obj|iobj)(:|$)/} (@xcompgpr);
        if(scalar(@coreprxgpr) > 0)
        {
            $stats{xsubj}++;
        }
        # Relative clauses: the ref relation; a cycle containing acl:relcl
        my @refpr = grep {$_->{deprel} =~ m/^ref(:|$)/} (@parents);
        if(scalar(@refpr) > 0)
        {
            $stats{relcl}++;
        }
        # Adpositions and case features in enhanced relations.
        ###!!! Non-ASCII characters, underscores, or multiple colons in relation labels signal this enhancement.
        ###!!! However, none of them is a necessary condition. We can have a simple 'obl:between'.
        ###!!! We would probably have to look at the basic dependency and compare it with the enhanced relation.
        my @unusual = grep {$_->{deprel} =~ m/(:.*:|[^a-z:])/} (@parents);
        if(scalar(@unusual) > 0)
        {
            $stats{case_deprel}++;
        }
        else
        {
            my $basic_parent = $curnode->[6];
            my $basic_deprel = $curnode->[7];
            my @matchingpr = grep {$_->{id} == $basic_parent} (@parents);
            my @extendedpr = grep {$_->{deprel} =~ m/^$basic_deprel:.+/} (@matchingpr);
            if(scalar(@extendedpr) > 0)
            {
                $stats{case_deprel}++;
            }
        }
    }
}
