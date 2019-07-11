#!/usr/bin/env perl
# Collects statistics about the corpora prepared for a Deep UD release.
# Based on the script 'check_files.pl' from the UD tools repository.
# Copyright © 2019 Dan Zeman <zeman@ufal.mff.cuni.cz>
# License: GNU GPL

use utf8;
use open ':utf8';
binmode(STDIN, ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');
# The module 'udlib' is available in the UD tools repository. It must be in $PERL5LIB.
# (One copy on the ÚFAL network is /net/work/people/zeman/unidep/tools.)
use udlib;

# We need a mapping from the English names of the languages (as they appear in folder names) to their ISO codes and families.
# We must supply a YAML file from the docs-automation UD repository.
my $languages_from_yaml = udlib::get_language_hash('/net/work/people/zeman/unidep/docs-automation/codes_and_flags.yaml');
# This script expects to be invoked in the folder in which all the UD_folders
# are placed.
opendir(DIR, '.') or die('Cannot read the contents of the working folder');
my @folders = sort(grep {-d $_ && m/^UD_[A-Z]/} (readdir(DIR)));
closedir(DIR);
my %iso3codes;
foreach my $folder (@folders)
{
    # The name of the folder: 'UD_' + language name + optional treebank identifier.
    # Example: UD_Ancient_Greek-PROIEL
    my ($language, $treebank) = udlib::decompose_repo_name($folder);
    if(defined($language))
    {
        if(exists($languages_from_yaml->{$language}))
        {
            my $langcode = $languages_from_yaml->{$language}{lcode};
            my $iso3code = $languages_from_yaml->{$language}{iso3};
            $iso3codes{$iso3code}++;
        }
        else
        {
            print STDERR ("WARNING: Unknown language '$language'\n");
        }
    }
    else
    {
        print STDERR ("WARNING: Unknown language for folder '$folder'\n");
    }
}
my @iso3codes = sort(keys(%iso3codes));
my $n = scalar(@iso3codes);
print("Found $n languages. Their ISO 639-3 codes are:\n");
print(join(' ', @iso3codes)."\n");
