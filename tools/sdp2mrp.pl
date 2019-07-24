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
# JSON::Parse is a third-party module available from CPAN.
# If you have Perl without JSON::Parse, try:
#   cpanm JSON::Parse
# If you don't have cpanm, try:
#   cpan JSON::Parse
use JSON::Parse ':all';

sub usage
{
    print STDERR ("Usage: perl sdp2mrp.pl --framework (dm|psd) --source source.mrp < input.sdp > output.mrp\n");
    print STDERR ("    The source MRP file is needed because of input strings, source tokenization and anchoring of tokens in the input string.\n");
}

my $framework;
my $source; # path to the source file
GetOptions
(
    'framework=s' => \$framework,
    'source=s' => \$source
);
if(!defined($framework) || $framework !~ m/^(dm|psd|eds)$/)
{
    usage();
    die("Unknown framework '$framework'");
}
# Read the source file to the memory.
my %source;
if(defined($source))
{
    print STDERR ("Reading source...\n");
    open(SOURCE, $source) or die("Cannot open $source: $!");
    while(<SOURCE>)
    {
        my $json = $_;
        my $jgraph = parse_json($json);
        my $id = $jgraph->{id};
        die("Undefined source graph id") if(!defined($id));
        die("Multiple source graphs with id '$id'") if(exists($source{$id}));
        $source{$id} = $jgraph;
    }
    close(SOURCE);
    print STDERR ("... done\n");
}
# Get the current date and time. We will save it with every graph.
my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday) = localtime(time);
my $timestamp = sprintf("%04d-%02d-%02d (%02d:%02d)", 1900+$year, 1+$mon, $mday, $hour, $min);

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
        if($line =~ m/^\#\s*(\S+)$/)
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
            # The custom in MRP is to start node ids at 0. Not adhering is not penalized in evaluation, though (but we need it to find source anchors).
            push(@tops, $f[0]-1) if($f[4] eq '+');
            push(@preds, $f[0]) if($f[5] eq '+');
            push(@matrix, \@f);
        }
    }
    if(!defined($sid))
    {
        die("A graph in the SDP input lacks sentence id");
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
                die("Undefined predicate no. $i") if(!defined($preds[$i]) || $preds[$i]<1);
                push(@edges, [$preds[$i], $node->[0], $label]);
            }
        }
    }
    # Write JSON (one line).
    print('{');
    print('"id": "'.$sid.'", ');
    if($framework =~ m/^(dm|psd)$/)
    {
        print('"flavor": 0, "framework": "'.$framework.'", "version": 0.9, ');
    }
    elsif($framework eq 'eds')
    {
        print('"flavor": 1, "framework": "eds", "version": 0.9, ');
    }
    print('"time": "'.$timestamp.'", ');
    my $input;
    my @anchors;
    my @nodelabels;
    if(defined($source))
    {
        die("Unknown source for sentence '$sid'") if(!exists($source{$sid}));
        $input = escape_string($source{$sid}{input});
        my $nsrctok = scalar(@{$source{$sid}{nodes}});
        my $nnodes = scalar(@matrix);
        if($nsrctok != $nnodes)
        {
            die("The graph has $nnodes nodes but the source sentence has $nsrctok tokens");
        }
        my $i = 0;
        foreach my $srctoken (@{$source{$sid}{nodes}})
        {
            if($srctoken->{id} != $i)
            {
                die("Source node ids do not form a contiguous sequence starting at 0");
            }
            $nodelabels[$srctoken->{id}] = $srctoken->{label};
            $anchors[$srctoken->{id}] = $srctoken->{anchors};
            $i++;
        }
    }
    else
    {
        $input = escape_string(join(' ', map {$_->[1]} (@matrix)));
    }
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
        # The custom in MRP is to start node ids at 0. Not adhering is not penalized in evaluation, though (but we need it to find source anchors).
        print('"id": '.($node->[0]-1).', ');
        if(defined($source))
        {
            print('"label": "'.escape_string($nodelabels[$node->[0]-1]).'", ');
        }
        else
        {
            print('"label": "'.escape_string($node->[1]).'", ');
        }
        print('"properties": ["pos", "frame"], ');
        print('"values": ["'.escape_string($node->[3]).'", "'.escape_string($node->[6]).'"], ');
        if(defined($source))
        {
            print('"anchors": [');
            my @janchors;
            foreach my $anchor (@{$anchors[$node->[0]-1]})
            {
                my $janchor = '{';
                $janchor .= '"from": '.$anchor->{from}.', ';
                $janchor .= '"to": '.$anchor->{to};
                $janchor .= '}';
                push(@janchors, $janchor);
            }
            print(join(', ', @janchors));
            print(']');
        }
        else
        {
            print('"anchors": [{"from": '.$offset.', "to": '.($offset+length($node->[1])).'}]');
        }
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
        # The custom in MRP is to start node ids at 0. Not adhering is not penalized in evaluation, though (but we need it to find source anchors).
        print('"source": '.($edge->[0]-1).', ');
        print('"target": '.($edge->[1]-1).', ');
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
