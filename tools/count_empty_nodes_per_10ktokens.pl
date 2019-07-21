#!/usr/bin/env perl
# Reads the statistics of enhanced graphs (/net/work/people/zeman/mrptask/deepud/data/properties-after-stanford-enhancer.txt)
# and provides other views of the numbers. The output is in HTML so that it can be copied to the web.
# Copyright © 2019 Dan Zeman <zeman@ufal.mff.cuni.cz>
# License: GNU GPL

use utf8;
use open ':utf8';
binmode(STDIN, ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');

my $srcpath = '/net/work/people/zeman/mrptask/deepud/data/properties-after-stanford-enhancer.txt';
open(SRC, $srcpath) or die("Cannot read $srcpath: $!");
my $current_treebank;
my $ntokens;
my $nempty;
print("<table>\n");
print("  <tr><th>Treebank</th><th>Tokens</th><th>Empty nodes</th><th>Empty per 10k tokens</th></tr>\n");
while(<SRC>)
{
    if(m:^/net/work/people/droganova/Data_for_Enhancer/final_2.4/UD_(.+)$:)
    {
        $current_treebank = $1;
        $current_treebank =~ s/[-_]/ /g;
    }
    elsif(m/(\d+) overt surface nodes/)
    {
        $ntokens = $1;
    }
    elsif(m/(\d+) empty nodes/)
    {
        $nempty = $1;
        # Number of empty nodes always appears after number of tokens. So we can report now.
        my $ratio = sprintf("%d", $nempty/($ntokens/10000)+0.5);
        #print("$current_treebank\t$ntokens\t$nempty\t$ratio\n");
        print("  <tr><td>$current_treebank</td><td>$ntokens</td><td>$nempty</td><td>$ratio</td></tr>\n");
    }
}
print("</table>\n");
close(SRC);
