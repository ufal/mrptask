#!/usr/bin/env perl
# Reads the logs from adding predicate-argument structure to UD treebanks and
# aggregates the statistics over all treebanks.
# Copyright © 2019 Dan Zeman <zeman@ufal.mff.cuni.cz>
# License: GNU GPL

use utf8;
use open ':utf8';
binmode(STDIN, ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');

my $path = '/net/work/people/zeman/mrptask/deepud/data/deep';
opendir(DIR, $path) or die("Cannot read folder $path: $!");
my @folders = sort(grep {m/^UD_.+/} (readdir(DIR)));
closedir(DIR);
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
print("  <tr><th>Treebank</th><th>Total nodes</th><th>Infinitives per 100k nodes</th><th>Converbs per 100k nodes</th><th>Participles per 100k nodes</tr>\n");
foreach my $folder (@folders)
{
    open(LOG, "$path/$folder/all.log") or die("Cannot read $path/$folder/all.log: $!");
    my $total = 0;
    my $infinitive = 0;
    my $converb = 0;
    my $participle = 0;
    while(<LOG>)
    {
        # TOTAL NODES	254855
        # converb-advcl-subj	840
        # infinitive-advcl-subj	975
        # participle-amod-subj	600
        if(m/TOTAL NODES\s+(\d+)/)
        {
            $total = $1;
        }
        elsif(m/converb-advcl-subj\s+(\d+)/)
        {
            $converb = $1;
        }
        elsif(m/infinitive-advcl-subj\s+(\d+)/)
        {
            $infinitive = $1;
        }
        elsif(m/participle-amod-subj\s+(\d+)/)
        {
            $participle = $1;
        }
    }
    close(LOG);
    my $current_treebank = $folder;
    $current_treebank =~ s/^UD_//;
    $current_treebank =~ s/[-_]/ /g;
    $infinitive = sprintf("%d", ($infinitive/($total/100000))+0.5);
    $participle = sprintf("%d", ($participle/($total/100000))+0.5);
    $converb    = sprintf("%d", ($converb/($total/100000))+0.5);
    print("  <tr><td>$current_treebank</td><td>$total</td><td>$infinitive</td><td>$converb</td><td>$participle</td></tr>\n");
}
print("</table>\n");
