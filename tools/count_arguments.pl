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
  background-color: white;
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
my @headings = ();
foreach my $diatype (qw(active passive))
{
    # Repeat the name of the treebank and the total number of clauses at the
    # beginning of every diathesis type. The table is wide and the user will
    # not see the first column.
    push(@headings, 'Treebank');
    push(@headings, 'Clauses');
    push(@headings, "$diatype<br/>total");
    foreach my $argument (qw(subj obj iobj oblagent xcomp))
    {
        for(my $i = 0; $i <= 3; $i++)
        {
            my $ii = $i;
            $ii = '3+' if($i==3);
            push(@headings, "$diatype<br/>$ii&nbsp;$argument");
        }
    }
}
my $headings = join('</th><th>', @headings);
my $htmlheadings = "  <tr><th>$headings</th></tr>\n";
print($htmlheadings);
my $hcd = 5;
my $n_treebanks_with_passive_clauses = 0;
foreach my $folder (@folders)
{
    if($hcd==0)
    {
        print($htmlheadings);
        $hcd = 5;
    }
    open(LOG, "$path/$folder/all.log") or die("Cannot read $path/$folder/all.log: $!");
    my %types;
    my $total = 0;
    while(<LOG>)
    {
        s/\r?\n$//;
        if(m/^Number of (active|passive) verbal clauses: (\d+)$/)
        {
            my $diatype = $1;
            my $count = $2;
            $types{$diatype}{TOTAL} += $count;
            $total += $count;
        }
        elsif(m/^Number of (active|passive) verbal clauses with (\d+) uncoordinated '(.+)' arguments: (\d+)$/)
        {
            my $diatype = $1;
            my $argcount = $2;
            my $argument = $3;
            my $count = $4;
            $argcount = 3 if($argcount > 3);
            $types{$diatype}{$argument}{$argcount} += $count;
        }
    }
    close(LOG);
    my $current_treebank = $folder;
    $current_treebank =~ s/^UD_//;
    $current_treebank =~ s/[-_]/ /g;
    my @values = ();
    foreach my $diatype (qw(active passive))
    {
        push(@values, $current_treebank);
        push(@values, $total);
        push(@values, $types{$diatype}{TOTAL});
        foreach my $argument (qw(subj obj iobj oblagent xcomp))
        {
            for(my $i = 0; $i <= 3; $i++)
            {
                push(@values, $types{$diatype}{$argument}{$i});
            }
        }
    }
    my $values = join('</td><td>', @values);
    print("  <tr><td>$values</td></tr>\n");
    $n_treebanks_with_passive_clauses++ if($types{passive}{TOTAL} > 0);
    $hcd--;
}
print("</table>\n");
print STDERR ("$n_treebanks_with_passive_clauses treebanks contain at least one passive clause.\n");
