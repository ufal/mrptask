#!/usr/bin/env perl
# Reads CoNLL-U with enhanced dependencies. Infers predicate-argument structure and prints it in new columns (CoNLL-U-Plus).
# Copyright © 2019 Dan Zeman <zeman@ufal.mff.cuni.cz>
# License: GNU GPL

use utf8;
use open ':utf8';
binmode(STDIN, ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');
use List::MoreUtils qw(any);
###!!! We need to tell Perl where to find my graph modules. But we should
###!!! modify it so that it works on any computer!
BEGIN
{
    use Cwd;
    my $path = $0;
    my $currentpath = getcwd();
    $libpath = $currentpath;
    if($path =~ m:/:)
    {
        $path =~ s:/[^/]*$:/:;
        chdir($path);
        $libpath = getcwd();
        chdir($currentpath);
    }
    $libpath =~ s/\r?\n$//;
    #print STDERR ("libpath=$libpath\n");
}
use lib $libpath;
use Graph;
use Node;

my @sentence;
while(<>)
{
    if(m/^\s*$/)
    {
        process_sentence(@sentence);
        @sentence = ();
    }
    else
    {
        s/\r?\n$//;
        push(@sentence, $_);
    }
}
# In case of incorrect files that lack the last empty line:
if(scalar(@sentence) > 0)
{
    process_sentence(@sentence);
}



#------------------------------------------------------------------------------
# Processes one sentence after it has been read.
#------------------------------------------------------------------------------
sub process_sentence
{
    my @sentence = @_;
    my $graph = new Graph;
    # Get rid of everything except the node lines. But include empty nodes!
    my @nodelines = grep {m/^\d+(\.\d+)?\t/} (@sentence);
    foreach my $nodeline (@nodelines)
    {
        my @fields = split(/\t/, $nodeline);
        my $node = new Node('id' => $fields[0], 'form' => $fields[1], 'lemma' => $fields[2], 'upos' => $fields[3], 'xpos' => $fields[4],
                            '_head' => $fields[6], '_deprel' => $fields[7], '_deps' => $fields[8]);
        $node->set_feats_from_conllu($fields[5]);
        $node->set_misc_from_conllu($fields[9]);
        $graph->add_node($node);
    }
    # Once all nodes have been added to the graph, we can draw edges between them.
    foreach my $node ($graph->get_nodes())
    {
        $node->set_basic_dep_from_conllu();
        $node->set_deps_from_conllu();
    }
    # We now have a complete representation of the graph and can do the actual work.
    foreach my $node ($graph->get_nodes())
    {
        my $predicate = '_';
        my @arguments;
        # At present we only look at verbal predicates.
        if($node->upos() eq 'VERB')
        {
            # The predicate could be identified by a reference to a frame in a valency lexicon.
            # We do not have a lexicon and we simply use the lemma.
            $predicate = $node->lemma();
            if(defined($predicate) && $predicate ne '' && $predicate ne '_')
            {
                ###!!! Later on, we will look at obl:arg, nsubj:pass, obl:agent etc.
                ###!!! For now, we only look at nsubj, obj, and iobj.
                ###!!! Only look at active clauses now!
                my @passive = grep {$_->{deprel} =~ m/:pass$/} (@{$node->oedges()});
                unless(scalar(@passive) > 0)
                {
                    # There should be at most one subject. In an active clause, we will make it argument 1.
                    my @subjects = grep {$_->{deprel} =~ m/^[nc]subj(:|$)/ && $_->{deprel} ne 'nsubj:pass'} (@{$node->oedges()});
                    my $n = scalar(@subjects);
                    if($n > 1)
                    {
                        print STDERR ("WARNING: Cannot deal with more than 1 subject.\n");
                    }
                    elsif($n == 1)
                    {
                        $arguments[1] = $subjects[0]->{id};
                    }
                    # There should be at most one direct object. In an active clause, we will make it argument 2.
                    my @dobjects = grep {$_->{deprel} =~ m/^obj(:|$)/} (@{$node->oedges()});
                    $n = scalar(@dobjects);
                    if($n > 1)
                    {
                        print STDERR ("WARNING: Cannot deal with more than 1 direct object.\n");
                    }
                    elsif($n == 1)
                    {
                        $arguments[2] = $dobjects[0]->{id};
                    }
                    # There should be at most one indirect object. In an active clause, we will make it argument 3.
                    my @iobjects = grep {$_->{deprel} =~ m/^iobj(:|$)/} (@{$node->oedges()});
                    $n = scalar(@iobjects);
                    if($n > 1)
                    {
                        print STDERR ("WARNING: Cannot deal with more than 1 indirect object.\n");
                    }
                    elsif($n == 1)
                    {
                        $arguments[3] = $iobjects[0]->{id};
                    }
                }
            }
        }
        # Print the node including additional columns.
        my @arglinks;
        for(my $i = 0; $i <= $#arguments; $i++)
        {
            if(defined($arguments[$i]))
            {
                my $arglink = "arg$i:$arguments[$i]";
                push(@arglinks, $arglink);
            }
        }
        my $arglinks = scalar(@arglinks) > 0 ? join('|', @arglinks) : '_';
        my $nodeline = join("\t", ($node->id(), $node->form(), $node->lemma(), $node->upos(), $node->xpos(), $node->feats(), $node->_head(), $node->_deprel(), $node->_deps(), $node->misc(), $predicate, $arglinks));
        print("$nodeline\n");
    }
    print("\n");
}
