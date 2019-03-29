#!/usr/bin/env perl
# Converts a file from the SDP 2014/2015 tasks to a CoNLL-U-like format.
# Copyright © 2019 Dan Zeman <zeman@ufal.mff.cuni.cz>
# License: GNU GPL
# Usage: sdp2conllu.pl < all.sdp > all.conllu

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
    my $sidline = shift(@sentence);
    if($sidline !~ s/^\#(\d+)$/\# sent_id = $1/)
    {
        die("Unexpected sentence id line:\n$sidline\n");
    }
    print("$sidline\n");
    # Convert the list of lines to a matrix.
    my @matrix;
    my @predicates;
    foreach my $line (@sentence)
    {
        my @fields = split(/\t/, $line);
        push(@matrix, \@fields);
        # Remember indices of predicates so that we can later map to them.
        if($fields[5] eq '+')
        {
            push(@predicates, $fields[0]);
        }
    }
    # Convert the matrix to CoNLL-U and print it.
    foreach my $node (@matrix)
    {
        # The first four columns are ID FORM LEMMA TAG, i.e., just like in UD,
        # except that the tag is not UPOS but Penn Treebank. The seventh column
        # may contain identification of the corresponding frame/sense in a valency
        # dictionary; we will store it in the XPOS column.
        my @conllu = ($node->[0], $node->[1], $node->[2], $node->[3], $node->[6], '_', 0, 'dep');
        # Collect the parents of this node.
        my @parents;
        # The "top nodes" in SDP roughly correspond to root nodes in UD.
        if($node->[4] eq '+')
        {
            push(@parents, '0:root');
        }
        for(my $i = 7; $i <= $#{$node}; $i++)
        {
            next if($node->[$i] eq '_');
            if($i-7 > $#predicates)
            {
                print STDERR ("WARNING: $i-7 > $#predicates, the last predicate index");
            }
            if($node->[$i] =~ m/\|/)
            {
                print STDERR ("WARNING: relation label '$node->[$i]' contains a vertical bar");
            }
            push(@parents, $predicates[$i-7].':'.$node->[$i]);
        }
        my $parents = join('|', @parents);
        push(@conllu, $parents, '_');
        my $conllu = join("\t", @conllu);
        print("$conllu\n");
    }
    # Empty line after each sentence.
    print("\n");
}
