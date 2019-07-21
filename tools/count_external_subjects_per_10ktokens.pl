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
my $nxsubj;
print <<EOF
<style type="text/css">#treebanks {
  font-family: "Trebuchet MS", Arial, Helvetica, sans-serif;
  border-collapse: collapse;
  width: 100%;
}

#treebanks td, #treebanks th {
  border: 1px solid #ddd;
  padding: 8px;
}

#treebanks tr:nth-child(even){background-color: #f2f2f2;}

#treebanks tr:hover {background-color: #ddd;}

#treebanks th {
  padding-top: 12px;
  padding-bottom: 12px;
  text-align: left;
  background-color: #4CAF50;
  color: white;
}
</style>
EOF
;
print("<table id=\"treebanks\">\n");
print("  <tr><th>Treebank</th><th>Tokens</th><th>External subjects</th><th>Xsubj per 10k tokens</th></tr>\n");
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
    elsif(m/Controlled subject:\s*(\d+)/)
    {
        $nxsubj = $1;
        # Number of empty nodes always appears after number of tokens. So we can report now.
        my $ratio = sprintf("%d", $nxsubj/($ntokens/10000)+0.5);
        #print("$current_treebank\t$ntokens\t$nempty\t$ratio\n");
        print("  <tr><td>$current_treebank</td><td>$ntokens</td><td>$nxsubj</td><td>$ratio</td></tr>\n");
    }
}
print("</table>\n");
close(SRC);
