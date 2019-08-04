#!/usr/bin/env perl
# Runs add_pas.pl in a loop over all UD treebanks.
# Copyright © 2019 Dan Zeman <zeman@ufal.mff.cuni.cz>
# License: GNU GPL

use utf8;
use open ':utf8';
binmode(STDIN, ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');

my $projekty = 'C:/Users/Dan/Documents/Lingvistika/Projekty';
my $tools = "$projekty/mrptask/tools";
my $enhanced = "$projekty/mrptask/deepud/data/deepuddata/enhanced";
my $workdeep = "$projekty/wdeep";
opendir(DIR, $enhanced) or die("Cannot read folder $enhanced: $!");
my @folders = sort(grep {m/^UD_/} (readdir(DIR)));
closedir(DIR);
foreach my $folder (@folders)
{
    next unless($folder eq 'UD_English-EWT'); ###!!!
    opendir(DIR, "$enhanced/$folder") or die("Cannot read folder $enhanced/$folder: $!");
    my @files = grep {m/\.conllu$/} (readdir(DIR));
    closedir(DIR);
    foreach my $file (@files)
    {
        print STDERR ("$folder/$file\n");
        system("perl -I $tools $tools/add_pas.pl --udpath $enhanced --release http://hdl.handle.net/11234/1-2988 --folder $folder --file $file >$workdeep\\$folder\\${file}p 2>NIL:");
    }
    print STDERR ("$folder/all.log");
    system("perl -I $tools $tools/add_pas.pl --udpath $workdeep --release http://hdl.handle.net/11234/1-2988 --folder $folder --file all.conllu >NIL: 2>$workdeep\\$folder\\all.log");
}
