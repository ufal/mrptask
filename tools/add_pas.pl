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

my %argpatterns;
my %pargpatterns;
my @sentence;
my $first_sentence = 1;
while(<>)
{
    if(m/^\s*$/)
    {
        process_sentence(@sentence);
        @sentence = ();
        $first_sentence = 0;
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
###!!! What do we want to print: %argpatterns, or %pargpatterns?
my @argpatterns = sort {my $r = $argpatterns{$b} <=> $argpatterns{$a}; unless($r) { $a cmp $b } $r} (keys(%argpatterns));
print STDERR ("Observed argument patterns:\n");
foreach my $ap (@argpatterns)
{
    print STDERR ("$ap\t$argpatterns{$ap}\n");
}
my @pargpatterns = sort(keys(%pargpatterns));
print STDERR ("Observed argument patterns:\n");
foreach my $ap (@pargpatterns)
{
    print STDERR ("$ap\t$pargpatterns{$ap}\n");
}



#------------------------------------------------------------------------------
# Processes one sentence after it has been read.
#------------------------------------------------------------------------------
sub process_sentence
{
    my @sentence = @_;
    my $graph = new Graph;
    foreach my $line (@sentence)
    {
        if($line =~ m/^\#/)
        {
            push(@{$graph->comments()}, $line);
        }
        elsif($line =~ m/^\d/)
        {
            my @fields = split(/\t/, $line);
            my $node = new Node('id' => $fields[0], 'form' => $fields[1], 'lemma' => $fields[2], 'upos' => $fields[3], 'xpos' => $fields[4],
                                '_head' => $fields[6], '_deprel' => $fields[7], '_deps' => $fields[8]);
            $node->set_feats_from_conllu($fields[5]);
            $node->set_misc_from_conllu($fields[9]);
            $graph->add_node($node);
        }
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
        my $predicate = get_predicate($node);
        $node->set_predicate($predicate);
        my $argpattern = '_';
        my @arguments;
        unless($predicate eq '_')
        {
            $argpattern = get_argpattern($node, $predicate);
            @arguments = get_arguments($node);
        }
        $node->set_argpattern($argpattern);
        for(my $i = 0; $i <= $#arguments; $i++)
        {
            if(defined($arguments[$i]))
            {
                my %arglink =
                (
                    'deprel' => "arg$i",
                    'id'     => $arguments[$i]
                );
                push(@{$node->argedges()}, \%arglink);
            }
        }
    }
    print_sentence($graph, $first_sentence, 1);
}



#------------------------------------------------------------------------------
# Prints a graph in the CoNLL-U Plus format.
#------------------------------------------------------------------------------
sub print_sentence
{
    my $graph = shift;
    my $header = shift; # print the column headers? Only before the first sentence of a file.
    my $debug = shift; # make columns wider using spaces? Put certain columns forward because they are more interesting?
    if($header)
    {
        if($debug)
        {
            print("\# global.columns = ID FORM PRED ARGS ARGPATT FEATS HEAD DEPREL DEPS MISC LEMMA\n");
        }
        else
        {
            print("\# global.columns = ID FORM LEMMA UPOS XPOS FEATS HEAD DEPREL DEPS MISC PRED ARGS\n");
        }
    }
    foreach my $comment (@{$graph->comments()})
    {
        # Comments are currently stored including the initial # character;
        # but line-terminating characters have been stripped.
        print("$comment\n");
    }
    my $mlform = 0;
    my $mlpred = 0;
    my $mlargs = 0;
    my $mlpatt = 0;
    my $mlfeat = 0;
    if($debug)
    {
        foreach my $node ($graph->get_nodes())
        {
            my $arglinks = $node->get_args_string();
            my $feats = $node->get_feats_string();
            # We will use the lengths of form and lemma in human-readable output format.
            $mlform = length($node->form()) if(length($node->form()) > $mlform);
            $mlpred = length($node->predicate()) if(length($node->predicate()) > $mlpred);
            $mlargs = length($arglinks) if(length($arglinks) > $mlargs);
            $mlpatt = length($node->argpattern()) if(length($node->argpattern()) > $mlpatt);
            $mlfeat = length($feats) if(length($feats) > $mlfeat);
        }
        foreach my $node ($graph->get_nodes())
        {
            my $arglinks = $node->get_args_string();
            ###!!! In the final product, we will want to print the new columns at the end of the line.
            ###!!! However, for better readability during debugging, I am temporarily moving them closer to the beginning.
            my $nodeline = join("\t", ($node->id(),
                $node->form().(' ' x ($mlform-length($node->form()))),
                $node->upos(),
                $node->predicate().(' ' x ($mlpred-length($node->predicate()))),
                $arglinks.(' ' x ($mlargs-length($arglinks))),
                $node->argpattern().(' ' x ($mlpatt-length($node->argpattern()))), # místo nezajímavého $node->xpos(),
                $node->get_feats_string().(' ' x ($mlfeat-length($node->get_feats_string()))),
                $node->bparent(), $node->bdeprel(), $node->get_deps_string(),
                $node->get_misc_string(),
                $node->lemma()
                ));
            print("$nodeline\n");
        }
    }
    else
    {
        foreach my $node ($graph->get_nodes())
        {
            my $nodeline = join("\t", ($node->id(),
                $node->form(), $node->lemma(), $node->upos(), $node->xpos(), $node->get_feats_string(),
                $node->bparent(), $node->bdeprel(), $node->get_deps_string(), $node->get_misc_string(),
                $node->predicate(), $node->get_args_string()));
            print("$nodeline\n");
        }
    }
    print("\n");
}



#------------------------------------------------------------------------------
# Returns the lemma-like identifier of a verbal predicate. For other nodes
# returns just '_'.
#------------------------------------------------------------------------------
sub get_predicate
{
    my $node = shift;
    my $predicate = '_';
    # We will skip verbs that are attached as compound to something else.
    # For example, in Dutch "laten zien" (2 verbs), "zien" is attached as compound to "laten".
    my $is_compound = any {$_->{deprel} =~ m/^compound(:|$)/} (@{$node->iedges()});
    # The predicate could be identified by a reference to a frame in a valency lexicon.
    # We do not have a lexicon and we simply use the lemma.
    my $lemma = $node->lemma();
    if($node->upos() eq 'VERB' && defined($lemma) && $lemma ne '' && $lemma ne '_' && !$is_compound)
    {
        $predicate = $lemma;
        # Pronominal (inherently reflexive) verbs have the reflexive marker
        # as a part of their predicate identity. Same for verbal particles,
        # light verb and serial verb compounds.
        my @explpv = grep {$_->{deprel} =~ m/^(expl:pv|compound(:.+)?)$/} (@{$node->oedges()});
        my $graph = $node->graph();
        if(scalar(@explpv) >= 1)
        {
            ###!!! Language-specific: In German and Dutch, compound:prt should be
            ###!!! inserted as a prefix of the infinitive. Any other compounds,
            ###!!! as well as the reflexive sich/zich, should still go as additional
            ###!!! words after the infinitive.
            $predicate .= ' '.join(' ', map {lc($graph->node($_->{id})->form())} (@explpv));
        }
    }
    return $predicate;
}



#------------------------------------------------------------------------------
# Collects deprels that are probably arguments. Saves them as a pattern in a
# global hash. Returns the pattern so that it can be explicitly printed in the
# output file. The patterns can be used for debugging and also to establish
# an automatic frame inventory.
#------------------------------------------------------------------------------
sub get_argpattern
{
    my $node = shift;
    my $predicate = shift;
    # Investigation: what patterns of argumental deprels do we observe?
    my @oedges = get_oedges_except_conj_propagated($node);
    my @argedges = grep {$_->{deprel} =~ m/^(([nc]subj|obj|iobj|[cx]comp)(:|$)|obl:(arg|agent)$)/} (@oedges);
    # Certain enhanced relation subtypes are not relevant for us here.
    @argedges = map {$_->{deprel} =~ s/:(xsubj|relsubj|relobj)//; $_} (@argedges);
    my $arguments = join(' ', sort (map {$_->{deprel}} (@argedges)));
    # We want to be able to quickly find argumentless predicates in the data
    # in order to debug. Therefore we use <NOARG> instead of an underscore.
    $arguments = '<NOARG>' if($arguments eq '');
    $argpatterns{$arguments}++;
    my $predi_cate = $predicate;
    $predi_cate =~ s/\s+/_/g;
    my $pargpattern = "$predi_cate $arguments";
    $pargpatterns{$pargpattern}++;
    return $pargpattern;
}



#------------------------------------------------------------------------------
# Identifies arguments of verbal predicates.
#------------------------------------------------------------------------------
sub get_arguments
{
    my $node = shift;
    my @arguments;
    my @oedges = get_oedges_except_conj_propagated($node);
    ###!!! Later on, we will look at obl:arg, nsubj:pass, obl:agent etc.
    ###!!! For now, we only look at nsubj, obj, and iobj.
    ###!!! Only look at active clauses now!
    my @passive = grep {$_->{deprel} =~ m/:pass(:|$)/} (@oedges);
    unless(scalar(@passive) > 0)
    {
        # There should be at most one subject. In an active clause, we will make it argument 1.
        my @subjects = grep {$_->{deprel} =~ m/^[nc]subj(:|$)/ && $_->{deprel} ne 'nsubj:pass'} (@oedges);
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
        my @dobjects = grep {$_->{deprel} =~ m/^obj(:|$)/} (@oedges);
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
        my @iobjects = grep {$_->{deprel} =~ m/^iobj(:|$)/} (@oedges);
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
    else # detected passive clause
    {
        # A passive subject is argument 2. But if the subject is not
        # labeled with the ':pass' subtype, it is suspicious.
        my @passsubjects = grep {$_->{deprel} =~ m/^[nc]subj:pass(:|$)/} (@oedges);
        my @actsubjects = grep {$_->{deprel} =~ m/^[nc]subj(:|$)/ && $_->{deprel} !~ m/^[nc]subj:pass(:|$)/} (@oedges);
        my @dobjects = grep {$_->{deprel} =~ m/^obj(:|$)/} (@oedges);
        my @iobjects = grep {$_->{deprel} =~ m/^iobj(:|$)/} (@oedges);
        my @agents = grep {$_->{deprel} =~ m/^obl:agent(:|$)/} (@oedges);
        if(scalar(@actsubjects) > 0)
        {
            print STDERR ("WARNING: Subject of passive clause is labeled '$actsubjects[0]{deprel}'.\n");
        }
        if(scalar(@dobjects) > 0)
        {
            print STDERR ("WARNING: Cannot deal with direct object in a passive clause.\n");
        }
        my $n = scalar(@passsubjects);
        if($n > 1)
        {
            print STDERR ("WARNING: Cannot deal with more than 1 subject.\n");
        }
        elsif($n == 1)
        {
            $arguments[2] = $passsubjects[0]->{id};
        }
        $n = scalar(@iobjects);
        if($n > 1)
        {
            print STDERR ("WARNING: Cannot deal with more than 1 indirect object.\n");
        }
        elsif($n == 1)
        {
            $arguments[3] = $iobjects[0]->{id};
        }
        $n = scalar(@agents);
        if($n > 1)
        {
            print STDERR ("WARNING: Cannot deal with more than 1 oblique agent.\n");
        }
        elsif($n == 1)
        {
            $arguments[1] = $agents[0]->{id};
        }
    }
    return @arguments;
}



#------------------------------------------------------------------------------
# Returns enhanced children of a node that are not also attached as children of
# another child of that node via the 'conj' relation.
#------------------------------------------------------------------------------
sub get_oedges_except_conj_propagated
{
    my $node = shift;
    my @oe = @{$node->oedges()};
    my @result;
    foreach my $oe (@oe)
    {
        my @cie = grep {my $c = $_; $c->{deprel} =~ m/^conj(:|$)/ && any {$_->{id} eq $c->{id}} (@oe)} (@{$node->graph()->node($oe->{id})->iedges()});
        unless(scalar(@cie) > 0)
        {
            push(@result, $oe);
        }
    }
    return @result;
}
