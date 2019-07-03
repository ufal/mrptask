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
    get_tokens_for_graph($jgraph->{input}, $jgraph->{nodes});
}



#------------------------------------------------------------------------------
# Finds tokenization consistent with the anchors of the nodes.
#------------------------------------------------------------------------------
sub get_tokens_for_graph
{
    my $input = shift; # the input sentence, surface text
    my $nodes = shift; # arrayref, graph nodes
    my @input = split(//, $input);
    my @nodes = @{$nodes};
    # Global projection from characters to corresponding token objects.
    # N-th position in the array corresponds to the n-th input character.
    # The value at the n-th position is undefined if the character is not (yet) part of any token.
    # Otherwise it is a hash reference. The target hash is either a graph node,
    # or a simple surface token (padding) that is not part of the graph structure.
    my @gc2t = map {undef} (@input);
    foreach my $node (@nodes)
    {
        foreach my $anchor (@{$node->{anchors}})
        {
            # In JSON the range is right-open, i.e., 'to' is the first character after the span.
            # In contrast, we understand 'to' as the index of the last character that is included.
            my $f = $anchor->{from};
            my $t = $anchor->{to}-1;
            for(my $i = $f; $i <= $t; $i++)
            {
                if(defined($gc2t[$i]))
                {
                    print STDERR ("WARNING: Multiple nodes are anchored to character $i.\n");
                }
                $gc2t[$i] = $node;
            }
        }
    }
    my @paddings;
    my ($current_text, $current_from, $current_to);
    for(my $i = 0; $i <= $#input + 1; $i++)
    {
        if((defined($gc2t[$i]) || $i > $#input) && defined($current_text))
        {
            my $modified_text = $current_text;
            $modified_text =~ s/^\s+//;
            $modified_text =~ s/\s+$//;
            $modified_text =~ s/\s+/ /g;
            unless($modified_text eq '')
            {
                my @tokens = tokenize($modified_text);
                my ($t2c, $c2t);
                ($t2c, $c2t) = map_tokens_to_string($current_text, @tokens);
                # Sanity check.
                if(scalar(@{$c2t}) != $current_to-$current_from+1)
                {
                    die("Incorrect length of \$c2t");
                }
                # Project the local map to the global map.
                my @records;
                for(my $j = 0; $j <= $#tokens; $j++)
                {
                    my %record =
                    (
                        'text' => $tokens[$j],
                        'from' => $current_from + $t2c->[$j][0],
                        'to'   => $current_from + $t2c->[$j][1]
                    );
                    push(@records, \%record);
                    push(@paddings, \%record);
                }
                for(my $j = $current_from; $j <= $current_to; $j++)
                {
                    my $itok = $c2t[$j-$current_from];
                    if($itok>0)
                    {
                        $itok--;
                        $gc2t[$j] = $records[$itok];
                    }
                }
            }
            $current_text = undef;
            $current_from = undef;
            $current_to = undef;
        }
        if(!defined($gc2t[$i]) && $i <= $#input)
        {
            if(!defined($current_from))
            {
                $current_from = $i;
            }
            $current_to = $i;
            $current_text .= $input[$i];
        }
    }
    # Combine nodes and paddings in one array.
    my @tokens;
    foreach my $node (@nodes)
    {
        # Make sure we can tell apart nodes from paddings.
        $node->{is_node} = 1;
        $node->{start} = -1;
        my @surfaces;
        foreach my $anchor (@{$node->{anchors}})
        {
            my $f = $anchor->{from};
            my $t = $anchor->{to}-1;
            if($node->{start} == -1 || $node->{start} > $f)
            {
                $node->{start} = $f;
            }
            my $surface = substr($input, $f, $t-$f+1);
            push(@surfaces, $surface);
        }
        $node->{text} = join('_', @surfaces);
        push(@tokens, $node);
    }
    foreach my $padding (@paddings)
    {
        $padding->{is_node} = 0;
        $padding->{start} = $padding->{from};
        push(@tokens, $padding);
    }
    @tokens = sort {$a->{start} <=> $b->{start}} (@tokens);
    ###!!! It is yet to determine what we want to return from this function.
    my $n = scalar(@tokens);
    print STDERR ("There are $n tokens: ", join(' ', map {($_->{is_node} ? 'N' : 'P').':'.$_->{text}.':'.$_->{start}} (@tokens)), "\n");
}



#------------------------------------------------------------------------------
# Takes an input string and returns the list of tokens in the string. This is
# a naive tokenizer. We may want to replace it with something more sophistica-
# ted, such as reading tokenized output of UDPipe.
#------------------------------------------------------------------------------
sub tokenize
{
    my $string = shift;
    $string =~ s/(\pP)/ $1/g;
    $string =~ s/^\s+//s;
    $string =~ s/\s+$//s;
    $string =~ s/\s+/ /sg;
    my @tokens = split(/\s+/, $string);
    return @tokens;
}



#------------------------------------------------------------------------------
# Takes an input string and a list of tokens that constitute a tokenization of
# the input string. The tokens must be ordered as in the input string, and they
# must contain all non-whitespace characters of the string. The function
# returns for each token a from-to anchor (character indices, starting with 0).
# It also returns a list of inverse references, from each character to its
# token (token indices start with 1, and 0 is used for whitespace characters
# that do not correspond to any token).
#------------------------------------------------------------------------------
sub map_tokens_to_string
{
    my $string = shift;
    my @tokens = @_;
    my @anchors;
    my @c2t = map {0} (1..length($string));
    my $is = 0;
    for(my $i = 0; $i <= $#tokens; $i++)
    {
        # We rely on the fact that tokens cannot contain spaces (unlike in UD).
        if($tokens[$i] =~ m/\s/)
        {
            die("Token '$tokens[$i]' contains whitespace");
        }
        # Remove leading whitespace in the string.
        my $lsbefore = length($string);
        $string =~ s/^\s+//;
        my $lsafter = length($string);
        $is += $lsbefore-$lsafter;
        # Verify that the string now begins with the next token.
        my $l = length($tokens[$i]);
        my $strstart = substr($string, 0, $l);
        if($strstart ne $tokens[$i])
        {
            die("Mismatch: next token is '$tokens[$i]' but the remainder of the string is '$string'");
        }
        # Now we know the character span of the token in the string.
        my $f = $is;
        my $t = $is+$l-1;
        push(@anchors, [$f, $t]);
        my $itok = $i+1;
        for(my $j = $f; $j <= $t; $j++)
        {
            $c2t[$j] = $itok;
        }
        # Consume the token we just mapped.
        $string = substr($string, $l);
    }
    return (\@anchors, \@c2t);
}
