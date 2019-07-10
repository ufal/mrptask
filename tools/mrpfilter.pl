#!/usr/bin/env perl
# Takes two MRP files: source and target. Assumes that target is subset of source
# in terms of sentence ids (while the annotation can differ). Prints those graphs
# from source that also appear in target, in the order in which they appear in
# target.
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
    print STDERR ("Usage: perl mrpfilter.pl --source source.mrp < target.mrp > filtered.mrp\n");
}

my $source; # path to the source file
GetOptions
(
    'source=s' => \$source
);
if(!defined($source))
{
    usage();
    die("Unknown path to the source file");
}

# Read the source file to the memory.
print STDERR ("Reading source...\n");
open(SOURCE, $source) or die("Cannot open $source: $!");
my %source;
while(<SOURCE>)
{
    my $json = $_;
    my $jgraph = parse_json($json);
    my $id = $jgraph->{id};
    die("Undefined source graph id") if(!defined($id));
    die("Multiple source graphs with id '$id'") if(exists($source{$id}));
    $source{$id} = $json;
}
close(SOURCE);
print STDERR ("... done\n");

# Read the target file and print the corresponding source graphs.
print STDERR ("Reading target...\n");
while(<>)
{
    my $json = $_;
    my $jgraph = parse_json($json);
    my $id = $jgraph->{id};
    die("No source graph for target id '$id'") if(!exists($source{$id}));
    print($source{$id});
}
print STDERR ("... done\n");
