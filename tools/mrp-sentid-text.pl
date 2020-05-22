#!/usr/bin/env perl
# Reads the MRP JSON file.
# See http://mrp.nlpl.eu/index.php?page=4#format for a short description of the JSON graph format.
# See http://alt.qcri.org/semeval2015/task18/index.php?id=data-and-tools for the specification of the SDP 2015 file format.
# Copyright © 2020 Dan Zeman <zeman@ufal.mff.cuni.cz>
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

# Individual input lines are complete JSON structures (sentence graphs).
# The entire file is not valid JSON because the lines are not enclosed in an array and there are no commas at the ends of lines.
my %hash;
while(<>)
{
    my $jgraph = parse_json($_);
    my $sid = $jgraph->{id};
    my $text = $jgraph->{input};
    print("$sid\t$text\n");
}
