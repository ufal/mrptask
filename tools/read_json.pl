#!/usr/bin/env perl
# Reads the MRP JSON file.
# Copyright © 2019 Dan Zeman <zeman@ufal.mff.cuni.cz>
# License: GNU GPL

use utf8;
use open ':utf8';
binmode(STDIN, ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');
# JSON::Parse is a third-party module available from CPAN.
# If you have Perl without JSON::Parse, try:
#   cpanm JSON::Parse
# If you don't have cpanm, try:
#   cpan JSON::Parse
use JSON::Parse ':all';

# Individual input lines are complete JSON structures (sentence graphs).
# The entire file is not valid JSON because the lines are not enclosed in an array and there are no commas at the ends of lines.
while(<>)
{
    my $jgraph = parse_json($_);
    print("id = $jgraph->{id}\n");
    print("$jgraph->{input}\n");
    my @nodes = @{$jgraph->{nodes}};
    my $n = scalar(@nodes);
    my @snodes;
    foreach my $node (@nodes)
    {
        my @surfaces;
        foreach my $anchor (@{$node->{anchors}})
        {
            my $f = $anchor->{from};
            my $t = $anchor->{to};
            my $surface = substr($jgraph->{input}, $f, $t-$f);
            push(@surfaces, $surface);
        }
        push(@snodes, join('_', @surfaces));
    }
    print("There are $n nodes: ", join(', ', @snodes), "\n");
}



#------------------------------------------------------------------------------
# Finds tokenization consistent with the anchors of the nodes.
#------------------------------------------------------------------------------
sub get_tokens
{
    my $input = shift; # the input sentence, surface text
    my $nodes = shift; # arrayref, graph nodes
    my @input = split(//, $input);
    my @nodes = @{$nodes};
    my @covered; # flag for each character whether a node is anchored to it
    foreach my $node (@nodes)
    {
        foreach my $anchor (@{$node->{anchors}})
        {
            my $f = $anchor->{from};
            my $t = $anchor->{to};
            for(my $i = $f; $i <= $t; $i++)
            {
                if($covered[$i])
                {
                    print STDERR ("WARNING: Multiple nodes are anchored to character $i.\n");
                }
                $covered[$i]++;
            }
        }
    }
    my @paddings;
    my ($current_text, $current_from, $current_to);
    for(my $i = 0; $i <= $#input + 1; $i++)
    {
        if(($covered[$i] || $i > $#input) && defined($current_text))
        {
            $current_text =~ s/^\s+//;
            $current_text =~ s/\s+$//;
            $current_text =~ s/\s+/ /;
            unless($current_text eq '')
            {
                my %record =
                (
                    'text' => $current_text,
                    'from' => $current_from,
                    'to'   => $current_to
                );
                push(@paddings, \%record);
            }
            $current_text = undef;
            $current_from = undef;
            $current_to = undef;
        }
        if(!$covered[$i] && $i <= $#input)
        {
            if(!defined($current_from))
            {
                $current_from = $i;
            }
            $current_to = $i;
            $current_text .= $input[$i];
        }
    }
}
