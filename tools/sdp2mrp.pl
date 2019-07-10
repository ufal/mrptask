#!/usr/bin/env perl
# Converts the SDP CoNLL-2008-like file to the MRP JSON format.
# Copyright © 2019 Dan Zeman <zeman@ufal.mff.cuni.cz>
# License: GNU GPL

use utf8;
use open ':utf8';
binmode(STDIN, ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');
use Getopt::Long;

sub usage
{
    print STDERR ("Usage: perl sdp2mrp.pl --framework (dm|psd) < input.sdp > output.mrp\n");
}

my $framework;
GetOptions
(
    'framework=s' => \$framework
);
if(!defined($framework) || $framework !~ m/^(dm|psd)$/)
{
    usage();
    die("Unknown framework '$framework'");
}

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



#------------------------------------------------------------------------------
# Processes the SDP graph that we just read.
#------------------------------------------------------------------------------
sub process_sentence
{
    my @sentence = @_;
    my $sid;
    my @matrix;
    my @tops;
    my @preds;
    foreach my $line (@sentence)
    {
        if($line =~ m/^\#\s*(\d+)$/)
        {
            $sid = $1;
        }
        elsif($line =~ m/^\d+\t/)
        {
            my @f = split(/\t/, $line);
            if($f[0] != scalar(@matrix)+1)
            {
                die("Unexpected node ID '$f[0]'");
            }
            push(@tops, $f[0]) if($f[4] eq '+');
            push(@preds, $f[0]) if($f[5] eq '+');
            push(@matrix, \@f);
        }
    }
    if(!defined($sid))
    {
        die("Unknown sentence id");
    }
    my $npred = scalar(@preds);
    # Collect edges.
    my @edges;
    foreach my $node (@matrix)
    {
        my $ndeps = scalar(@{$node})-7;
        if($ndeps != $npred)
        {
            die("The graph has $npred predicates but the current node has $ndeps ARG columns");
        }
        for(my $i = 0; $i <= $#preds; $i++)
        {
            my $label = $node->[7+$i];
            unless($label eq '_')
            {
                push(@edges, [$preds[$i], $node->[0], $label]);
            }
        }
    }
    # Write JSON (one line).
    print('{');
    print('"id": "'.$sid.'", ');
    print('"flavor": 0, "framework": "'.$framework.'", "version": 0.9, ');
    print('"time": "1989-11-17 (19:00)", ');
    my $input = escape_string(join(' ', map {$_->[1]} (@matrix)));
    print('"input": "'.$input.'", ');
    # Note that the array of top nodes may be empty. Normal DM or PSD graph
    # would always have at least one top node but the parser may have failed
    # to predict it.
    print('"tops": ['.join(', ', @tops).'], ');
    print('"nodes": [');
    my $first = 1;
    my $offset = 0;
    foreach my $node (@matrix)
    {
        if($first)
        {
            $first = 0;
        }
        else
        {
            print(', ');
        }
        print('{');
        print('"id": '.$node->[0].', ');
        print('"label": "'.escape_string($node->[1]).'", ');
        print('"properties": ["pos", "frame"], ');
        print('"values": ["'.escape_string($node->[3]).'", "'.escape_string($node->[6]).'"], ');
        print('"anchors": [{"from": '.$offset.', "to": '.($offset+length($node->[1])).'}]');
        print('}');
        $offset += length($node->[1])+1; # the "+1" accounts for the space after the token
    }
    print('], ');
    print('"edges": [');
    $first = 1;
    foreach my $edge (@edges)
    {
        if($first)
        {
            $first = 0;
        }
        else
        {
            print(', ');
        }
        print('{');
        print('"source": '.$edge->[0].', ');
        print('"target": '.$edge->[1].', ');
        print('"label": "'.escape_string($edge->[2]).'"');
        print('}');
    }
    print(']');
    print('}');
    print("\n");
}



#------------------------------------------------------------------------------
# Precedes every quotation mark by a backslash so that the string can be
# enclosed in quotation marks in JSON.
#------------------------------------------------------------------------------
sub escape_string
{
    my $string = shift;
    $string =~ s/"/\\"/g;
    return $string;
}
