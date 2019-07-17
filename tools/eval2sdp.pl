#!/usr/bin/env perl
# Converts input evaluation files (MRP JSON) to the SDP format.
# Reads the UDPipe-preprocessed input file (udpipe.mrp). The file input.mrp is not needed now,
# although it contains the extra attribute "targets". But targets cannot be encoded in SDP, and we will generate all targets for all sentences anyways.
# See http://mrp.nlpl.eu/index.php?page=4#format for a short description of the JSON graph format.
# See http://alt.qcri.org/semeval2015/task18/index.php?id=data-and-tools for the specification of the SDP 2015 file format.
# Copyright © 2019 Dan Zeman <zeman@ufal.mff.cuni.cz>
# License: GNU GPL

use utf8;
use open ':utf8';
binmode(STDIN, ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');
use Getopt::Long;
use Carp;
# JSON::Parse is a third-party module available from CPAN.
# If you have Perl without JSON::Parse, try:
#   cpanm JSON::Parse
# If you don't have cpanm, try:
#   cpan JSON::Parse
use JSON::Parse ':all';

sub usage
{
    print STDERR ("Usage: perl eval2sdp.pl < data/udpipe.mrp > data/eval.sdp\n");
    print STDERR ("       --cpn ... instead of SDP, output a CPN file required by one of the parsers\n");
}

# Individual input lines are complete JSON structures (sentence graphs).
# The entire file is not valid JSON because the lines are not enclosed in an array and there are no commas at the ends of lines.
while(<>)
{
    my $jgraph = parse_json($_);
    my @tokens = sort {$a->{id} <=> $b->{id}} (@{$jgraph->{nodes}});
    # Map node ids to node objects.
    my %nodeidmap;
    foreach my $node (@{$jgraph->{nodes}})
    {
        $nodeidmap{$node->{id}} = $node;
    }
    # For each node, save the incoming edges.
    foreach my $edge (@{$jgraph->{edges}})
    {
        my $parent = $nodeidmap{$edge->{source}};
        my $child = $nodeidmap{$edge->{target}};
        die if(!defined($parent));
        die if(!defined($child));
        # A node is predicate if it has outgoing edges.
        $parent->{is_pred} = 1;
        my %record =
        (
            'parent' => $parent,
            'label'  => $edge->{label}
        );
        push(@{$child->{iedges}}, \%record);
    }
    # For each predicate, remember its order among predicates.
    my $predord = 0;
    foreach my $node (@{$jgraph->{nodes}})
    {
        if($node->{is_pred})
        {
            $node->{predord} = $predord++;
        }
    }
    my $npred = $predord;
    # Print the sentence graph in the SDP 2015 format.
    print("\#$jgraph->{id}\n");
    #print("\# text = $jgraph->{input}\n"); # this is not part of the SDP format
    for(my $i = 0; $i <= $#tokens; $i++)
    {
        # MRP graphs number their nodes from 0 but in SDP, node ids must start from 1.
        my $id = $tokens[$i]{id} + 1;
        # $tokens[$i]{label} is often but not always the surface word form.
        # In some cases it underwent normalization, so we should use the input
        # string and the anchors instead.
        my $form = '';
        foreach my $anchor (@{$tokens[$i]{anchors}})
        {
            my $f = $anchor->{from};
            my $t = $anchor->{to};
            if($t <= $f)
            {
                die("Anchor to <= anchor from");
            }
            if($t < 0 || $t > length($jgraph->{input})+1)
            {
                die("Anchor to out of range");
            }
            $form .= substr($jgraph->{input}, $f, $t-$f);
        }
        if($form eq '')
        {
            die("Token (node) does not correspond to any surface characters");
        }
        # While we may have tokens with spaces, the SDP format cannot accommodate them.
        $form =~ s/\s//g;
        $form = '_' if($form eq '');
        my $lemma = '_';
        my $pos = '_';
        for(my $j = 0; $j <= $#{$tokens[$i]{properties}}; $j++)
        {
            if($tokens[$i]{properties}[$j] eq 'lemma')
            {
                $lemma = $tokens[$i]{values}[$j];
            }
            elsif($tokens[$i]{properties}[$j] eq 'xpos')
            {
                $pos = $tokens[$i]{values}[$j];
            }
        }
        if($cpn)
        {
            # Sample of a CPN file:
            # /home/droganova/work/Data_for_Enhancer/NeurboParser/semeval2015_data/train/en.sb.bn.cpn
            # We are reading a UDPipe-predicted dependency tree.
            # Every node except the root should have just one incoming edge.
            my $head = 0;
            my $deprel = 'root';
            if(scalar(@{$tokens[$i]{iedges}}) > 0)
            {
                $head = $tokens[$i]{iedges}[0]{parent}{id};
                $deprel = $tokens[$i]{iedges}[0]{label};
            }
            print("$pos\t$head\t$deprel\n");
        }
        else
        {
            my $top = ($tokens[$i]{is_node} && grep {$_ == $tokens[$i]{id}} (@{$jgraph->{tops}})) ? '+' : '-';
            my $pred = $tokens[$i]{is_pred} ? '+' : '-';
            my $frame = '_';
            my @iemap = map {'_'} (1..$npred);
            if($tokens[$i]{is_node})
            {
                foreach my $iedge (@{$tokens[$i]{iedges}})
                {
                    my $pord = $iedge->{parent}{predord};
                    die if(!defined($pord));
                    die if($iemap[$pord] ne '_');
                    $iemap[$pord] = $iedge->{label};
                }
            }
            my $args = '';
            if(scalar(@iemap) > 0)
            {
                $args = "\t".join("\t", @iemap);
            }
            print("$id\t$form\t$lemma\t$pos\t$top\t$pred\t$frame$args\n");
        }
    }
    print("\n");
}
