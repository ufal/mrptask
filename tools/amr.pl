#!/usr/bin/env perl
# AMR
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
    print STDERR ("Usage: perl amr.pl kira-andrey.mrp > output.mrp\n");
}
while(<SOURCE>)
{
    my $json = $_;
    #my $jgraph = parse_json($json);
    #my $id = $jgraph->{id};
    #die("Undefined source graph id") if(!defined($id));
    #die("Multiple source graphs with id '$id'") if(exists($source{$id}));
    #$source{$id} = $jgraph;
    $json =~ s/"source":.*"input":/"framework": "amr", "input":/;
    print($json);
}
