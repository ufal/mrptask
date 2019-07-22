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
print("  <tr><th>Treebank</th><th>Predicates</th><th>Plain</th><th>Non-plain</th></tr>\n");
foreach my $folder (@folders)
{
    open(LOG, "$path/$folder/all.log") or die("Cannot read $path/$folder/all.log: $!");
    my $on = 0;
    my %types;
    my $total = 0;
    while(<LOG>)
    {
        if(m/Observed predicates:/)
        {
            $on = 1;
        }
        elsif($on && m/^\s*$/)
        {
            $on = 0;
        }
        elsif($on)
        {
            s/\r?\n$//;
            my ($type, $count) = split(/\t/, $_);
            $types{$type} += $count;
            $total += $count;
        }
    }
    close(LOG);
    my $current_treebank = $folder;
    $current_treebank =~ s/^UD_//;
    $current_treebank =~ s/[-_]/ /g;
    my $nonplain = join(', ', map {"$_ $types{$_}"} (sort(grep {!m/^plain$/} (keys(%types)))));
    print("  <tr><td>$current_treebank</td><td>$total</td><td>$types{plain}</td><td>$nonplain</td></tr>\n");
}
print("</table>\n");
