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
my $nsp;
my $nsd;
print("<table>\n");
print("  <tr><th>Treebank</th><th>Tokens</th><th>Shared parents</th><th>Shared dependents</th><th>Shared parents per 10k tokens</th></tr>\n");
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
    elsif(m/Coord shared parent: (\d+)/)
    {
        # Shared parent counts if I have two or more parents, one of them is via conj and its parent is my second parent.
        # We increment for each conjunct except the first conjunct.
        # If every coordination has just two conjuncts, $nsp will equal to the number of coordinations.
        $nsp = $1;
    }
    elsif(m/Coord shared depend: (\d+)/)
    {
        # Shared dependent counts if I have two or more parents, and one of them is connected to another via conj.
        # It is possible that coordination has no shared dependents at all; but a shared dependent cannot occur without coordination.
        $nsd = $1;
        # Number of shared dependents always appears last. So we can report now.
        my $ratio = sprintf("%d", $nsp/($ntokens/10000)+0.5);
        #print("$current_treebank\t$ntokens\t$nempty\t$ratio\n");
        print("  <tr><td>$current_treebank</td><td>$ntokens</td><td>$nsp</td><td>$nsd</td><td>$ratio</td></tr>\n");
    }
}
print("</table>\n");
close(SRC);
