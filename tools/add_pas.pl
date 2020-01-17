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
use Getopt::Long;
# We need to tell Perl where to find my graph modules.
# If this does not work, you can put the script together with Graph.pm and
# Node.pm in a folder of you choice, say, /home/joe/scripts, and then
# invoke Perl explicitly telling it where the modules are:
# perl -I/home/joe/scripts /home/joe/scripts/add_pas.pl inputfile.conllu
BEGIN
{
    use Cwd;
    my $path = $0;
    my $currentpath = getcwd();
    $currentpath =~ s/\r?\n$//;
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

sub usage
{
    # Example: /net/work/people/zeman/mrptask/tools/add_pas.pl --udpath /net/work/people/droganova/Data_for_Enhancer/final_2.4 --release http://hdl.handle.net/11234/1-2988 --folder UD_Czech-PUD --file cs_pud-ud-test.conllu |& less
    print STDERR ("Usage: perl add_pas.pl [--debug] [--udpath <path-to-all-ud-folders>] --release <handle-url> --folder UD_Language-TBK --file <conllufilename>\n");
}

$config{debug} = 0;
# The specification of the CoNLL-U Plus format (https://universaldependencies.org/ext-format.html)
# recommends using '*' for empty but known values, and '_' for unknown values
# (as in blind test data). It is used that way in the PARSEME initiative but
# it is not used that way in core UD (where '_' serves both purposes). I still
# don't know whether I like the '*' proposal and whether we actually need it.
# But we should fix it once we release the data.
$config{empty} = '_'; # '*'
$config{udpath} = '.';
GetOptions
(
    'debug' => \$config{debug},
    # We need the path to the folder with all UD repositories that are to be augmented.
    # We will get the treebank and file name separately and we will construct the full path ourselves.
    'udpath=s' => \$config{udpath},
    # We need to know the identifiers of the underlying UD release and file
    # because we must refer to them from every sentence.
    'release=s' => \$config{release}, # e.g. http://hdl.handle.net/11234/1-2837
    'folder=s'  => \$config{folder},  # e.g. UD_German-GSD
    'file=s'    => \$config{file},    # e.g. de_gsd-ud-train.conllu
    'eplus'     => \$config{eplus}, # should DEPS contain enhanced plus?
);
if($config{release} !~ m-^http://hdl.handle.net/-)
{
    usage();
    die("--release must provide the http://hdl.handle.net/ identifier of the underlying UD release");
}
if($config{folder} !~ m/^UD_[A-Z]/)
{
    usage();
    die("--folder must provide the name of the UD treebank repository");
}
if($config{file} !~ m/^[-a-z_]+\.conllu$/)
{
    usage();
    die("--file must provide the name of the source CoNLL-U file (without path)");
}
# This script uses the usual while(<>) to read input. Let's make sure that
# there is just one argument with the full path to the source file.
@ARGV = ("$config{udpath}/$config{folder}/$config{file}");

my %plus_enhancements;
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
# Report on the additional enhanced dependencies that we created during processing.
print STDERR ("Additional enhanced-plus dependency types we generated:\n");
my @plus_enhancements = sort(keys(%plus_enhancements));
foreach my $pe (@plus_enhancements)
{
    print STDERR ("$pe\t$plus_enhancements{$pe}\n");
}
print STDERR ("\n");
# Print the accummulated warnings.
my @warnings = sort {$warnings{$b} <=> $warnings{$a}} (keys(%warnings));
foreach my $warning (@warnings)
{
    print STDERR ("$warning ($warnings{$warning} ×)\n");
}
# Print the argument patterns regardless of predicate.
my @argpatterns = sort {my $r = $argpatterns{$b} <=> $argpatterns{$a}; unless($r) {$r = $a cmp $b } $r} (keys(%argpatterns));
print STDERR ("\nObserved argument patterns (regardless of predicate):\n");
foreach my $ap (@argpatterns)
{
    print STDERR ("$ap\t$argpatterns{$ap}\n");
}
# Print the predicates, pointing out compound predicates.
my @predicate_types = sort(keys(%predicates));
print STDERR ("\nObserved predicates:\n");
if(exists($predicates{plain}))
{
    my $n = scalar(keys(%{$predicates{plain}}));
    print STDERR ("plain\t$n\n");
}
foreach my $ptype (@predicate_types)
{
    unless($ptype eq 'plain')
    {
        my $n = scalar(keys(%{$predicates{$ptype}}));
        print STDERR ("$ptype\t$n\n");
    }
}
print STDERR ("\n");
foreach my $ptype (@predicate_types)
{
    my @predicates = sort(keys(%{$predicates{$ptype}}));
    foreach my $predicate (@predicates)
    {
        print STDERR ("$predicate\t$ptype\t$predicates{$ptype}{$predicate}\n");
    }
}
# Print the predicates together with their argument patterns.
my @pargpatterns = sort(keys(%pargpatterns));
print STDERR ("\nObserved predicate-argument patterns:\n");
foreach my $ap (@pargpatterns)
{
    print STDERR ("$ap\t$pargpatterns{$ap}\n");
}
# Print statistics of argument types and counts for each diathesis type.
my @diatypes = qw(active passive);
my @argtypes = qw(subj obj iobj oblagent xcomp);
foreach my $diatype (@diatypes)
{
    print STDERR ("\nNumber of $diatype verbal clauses: $arguments{$diatype}{pred}\n");
    foreach my $argtype (@argtypes)
    {
        my @counts = sort {$a <=> $b} (keys(%{$arguments{$diatype}{$argtype}}));
        foreach my $count (@counts)
        {
            print STDERR ("Number of $diatype verbal clauses with $count uncoordinated '$argtype' arguments: $arguments{$diatype}{$argtype}{$count}\n");
        }
    }
}



#------------------------------------------------------------------------------
# Processes one sentence after it has been read.
#------------------------------------------------------------------------------
sub process_sentence
{
    my @sentence = @_;
    my $graph = Graph::from_conllu_lines(@sentence);
    # We now have a complete representation of the graph and can do the actual work.
    # First, look for additional enhanced dependencies we may need.
    enhance_plus($graph);
    # Next, take the enhanced graph and look for predicates and their arguments.
    foreach my $node ($graph->get_nodes())
    {
        my $predicate = get_predicate($node);
        $node->set_predicate($predicate);
        my $argpattern = $config{empty};
        my @arguments;
        unless($predicate eq $config{empty})
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
    print_sentence($graph, $first_sentence, $config{eplus}, $config{debug});
}



#------------------------------------------------------------------------------
# Prints a graph in the CoNLL-U Plus format.
#------------------------------------------------------------------------------
sub print_sentence
{
    my $graph = shift;
    my $header = shift; # print the column headers? Only before the first sentence of a file.
    my $eplus = shift; # print our enhanced-plus graph? 0 => print the original contents of DEPS.
    my $debug = shift; # make columns wider using spaces? Put certain columns forward because they are more interesting?
    if($header)
    {
        if($debug)
        {
            print("\# global.columns = ID FORM DEEP:PRED DEEP:ARGS DEEP:ARGPATT FEATS HEAD DEPREL DEPS MISC LEMMA");
            if($eplus)
            {
                print(" DEEP:EPLUS");
            }
            print("\n");
        }
        else
        {
            print("\# global.columns = ID FORM LEMMA UPOS XPOS FEATS HEAD DEPREL DEPS MISC DEEP:PRED DEEP:ARGS\n");
        }
    }
    foreach my $comment (@{$graph->comments()})
    {
        # Comments are currently stored including the initial # character;
        # but line-terminating characters have been stripped.
        if($comment =~ m/^\#\s*sent_id\s*=\s*(\S+)/)
        {
            my $sent_id = $1;
            print("\# source_sent_id = conllu $config{release} $config{folder}/$config{file} $sent_id\n");
        }
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
            my @fields =
            (
                $node->id(),
                $node->form().(' ' x ($mlform-length($node->form()))),
                $node->upos(),
                $node->predicate().(' ' x ($mlpred-length($node->predicate()))),
                $arglinks.(' ' x ($mlargs-length($arglinks))),
                $node->argpattern().(' ' x ($mlpatt-length($node->argpattern()))), # místo nezajímavého $node->xpos(),
                $node->get_feats_string().(' ' x ($mlfeat-length($node->get_feats_string()))),
                $node->bparent(), $node->bdeprel(), $node->_deps(),
                $node->get_misc_string(),
                $node->lemma()
            );
            if($eplus)
            {
                push(@fields, $node->get_deps_string());
            }
            my $nodeline = join("\t", @fields);
            print("$nodeline\n");
        }
    }
    else
    {
        foreach my $node ($graph->get_nodes())
        {
            my $deps = $eplus ? $node->get_deps_string() : $node->_deps();
            my $nodeline = join("\t", ($node->id(),
                $node->form(), $node->lemma(), $node->upos(), $node->xpos(), $node->get_feats_string(),
                $node->bparent(), $node->bdeprel(), $deps, $node->get_misc_string(),
                $node->predicate(), $node->get_args_string()));
            print("$nodeline\n");
        }
    }
    print("\n");
}



#------------------------------------------------------------------------------
# Looks for additional enhancements that are not defined in the UD v2
# guidelines but may be useful for us to identify arguments of predicates.
#------------------------------------------------------------------------------
sub enhance_plus
{
    my $graph = shift;
    foreach my $node ($graph->get_nodes())
    {
        $plus_enhancements{'TOTAL NODES'}++;
        my $feats = $node->feats();
        # Infinitives.
        # We only recognize an infinitive if it has the feature VerbForm=Inf.
        ###!!! We currently do not look at markers or auxiliary dependents.
        ###!!! We also do not expect a multivalue in VerbForm (e.g. VerbForm=Inf,Part).
        if($feats->{VerbForm} eq 'Inf')
        {
            # Some languages have adverbial infinitival clauses (advcl).
            # For instance, Dutch:
            # "Om ongelukken te voorkomen heb ik mezelf gedwongen om me alleen nog met de koers bezig te houden."
            # Sometimes the clause becomes adnominal (acl) if it depends on a noun in a light verb construction.
            # For instance, Dutch:
            # "had moeite om zich te concentreren" (lit. "had trouble so himself to concentrate") ("struggled to concentrate")
            # Unfortunately, we cannot detect the light verb situation automatically.
            # An infinitive can modify a nominal without any relation to the verb
            # that governs the nominal: (Czech) "vydělávali na touze lidí zbohatnout".
            # Check whether the infinitive is attached to any of its parents as 'advcl'.
            ###!!! Zdá se, že někdy infinitiv v pozici advcl má svůj vlastní podmět! Jak to? (Dutch Alpino)
            my @iedges = @{$node->iedges()};
            foreach my $ie (@iedges)
            {
                if($ie->{deprel} =~ m/^advcl(:|$)/)
                {
                    # We assume that the infinitive has the same subject as the matrix clause.
                    # Find the subject of the matrix clause.
                    my $parent = $graph->get_node($ie->{id});
                    my @subjedges = grep {$_->{deprel} =~ m/^[nc]subj(:|$)/} (@{$parent->oedges()});
                    # If the list of subjects is not empty (actually we do not expect more than 1 subject unless there is coordination),
                    # create new edges between the infinitive and each subject.
                    foreach my $subjedge (@subjedges)
                    {
                        my $deprel = $subjedge->{deprel};
                        $deprel =~ s/:.*//;
                        $deprel .= ':advclsubj';
                        # New edge from the infinitive to the subject.
                        $graph->add_edge($node->{id}, $subjedge->{id}, $deprel);
                        $plus_enhancements{'infinitive-advcl-subj'}++;
                    }
                }
            }
        }
        # Participles.
        # We only recognize a participle if it has the feature VerbForm=Part.
        ###!!! We do not expect a multivalue in VerbForm (e.g. VerbForm=Inf,Part).
        elsif($feats->{VerbForm} eq 'Part')
        {
            my @iedges = @{$node->iedges()};
            foreach my $ie (@iedges)
            {
                ###!!! For now, exclude 'acl' because some of them are relative clauses and they have been enhanced already.
                if($ie->{deprel} =~ m/^(amod)(:|$)/)
                {
                    # We assume that the "subject" of the participle is the modified noun.
                    my $parent = $graph->get_node($ie->{id});
                    # Is it a passive participle?
                    ###!!! Currently we only examine the Voice=Pass feature.
                    ###!!! However, a participle may have no Voice feature, as in English, though it is used passively. We would need to estimate whether the verb is transitive.
                    my $is_passive = $feats->{Voice} eq 'Pass';
                    my $deprel = $is_passive ? 'nsubj:pass' : 'nsubj:partsubj';
                    $graph->add_edge($node->id(), $parent->id(), $deprel);
                    $plus_enhancements{'participle-amod-subj'}++;
                }
            }
        }
        # Converbs and gerunds.
        # We only recognize a converb or gerund by the value of its VerbForm feature.
        ###!!! We do not expect a multivalue in VerbForm (e.g. VerbForm=Conv,Part).
        if($feats->{VerbForm} =~ m/^(Conv|Ger)$/)
        {
            # Some languages use converbs as adverbial clauses (advcl).
            # Check whether the converb is attached to any of its parents as 'advcl'.
            my @iedges = @{$node->iedges()};
            foreach my $ie (@iedges)
            {
                if($ie->{deprel} =~ m/^advcl(:|$)/)
                {
                    # We assume that the converb has the same subject as the matrix clause.
                    # Find the subject of the matrix clause.
                    my $parent = $graph->get_node($ie->{id});
                    my @subjedges = grep {$_->{deprel} =~ m/^[nc]subj(:|$)/} (@{$parent->oedges()});
                    # If the list of subjects is not empty (actually we do not expect more than 1 subject unless there is coordination),
                    # create new edges between the converb and each subject.
                    foreach my $subjedge (@subjedges)
                    {
                        my $deprel = $subjedge->{deprel};
                        $deprel =~ s/:.*//;
                        $deprel .= ':advclsubj';
                        # New edge from the converb to the subject.
                        $graph->add_edge($node->id(), $subjedge->{id}, $deprel);
                        $plus_enhancements{'converb-advcl-subj'}++;
                    }
                }
            }
        }
    }
}



#------------------------------------------------------------------------------
# Returns the lemma-like identifier of a verbal predicate. For other nodes
# returns just '_'.
#------------------------------------------------------------------------------
sub get_predicate
{
    my $node = shift;
    my $predicate = $config{empty};
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
            # Collect statistics about unusual predicates. Collect them in a global hash.
            foreach my $extra (@explpv)
            {
                $predicates{$extra->{deprel}}{$predicate}++;
            }
        }
        else
        {
            # Also collect normal predicates in the global hash.
            $predicates{plain}{$predicate}++;
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
    # We want to be able to identify suspicious clauses with multiple instances
    # of the same type of argument. Therefore we have to filter out dependencies
    # propagated across coordination. However, when we will be actually marking
    # the arguments, we will want to include the conjuncts too!
    my @oedges_noconj = get_oedges_except_conj_propagated($node);
    my @oedges = @{$node->oedges()};
    my $is_passive_clause = any {$_->{deprel} =~ m/:pass(:|$)/} (@oedges);
    my $n_subj_act  = scalar(grep {$_->{deprel} =~ m/^[nc]subj(:|$)/ && $_->{deprel} ne 'nsubj:pass'} (@oedges_noconj));
    my $n_subj_pass = scalar(grep {$_->{deprel} =~ m/^[nc]subj:pass(:|$)/} (@oedges_noconj));
    my $n_dobj      = scalar(grep {$_->{deprel} =~ m/^(obj|ccomp)(:|$)/} (@oedges_noconj));
    my $n_iobj      = scalar(grep {$_->{deprel} =~ m/^iobj(:|$)/} (@oedges_noconj));
    my $n_agent     = scalar(grep {$_->{deprel} =~ m/^obl:agent(:|$)/} (@oedges_noconj));
    my $n_xcomp     = scalar(grep {$_->{deprel} =~ m/^xcomp(:|$)/} (@oedges_noconj));
    # Collect statistics in a global hash.
    if(!$is_passive_clause)
    {
        # First key: clause diathesis type
        # Second key: argument type
        # Third key: number of such arguments occurring with the current predicate (coordination counts as 1)
        # Value: number of times such a situation occurred
        $arguments{active}{pred}++; # this is just to count the occurrences of active verbal predicates
        $arguments{active}{subj}{$n_subj_act}++;
        $arguments{active}{obj}{$n_dobj}++;
        $arguments{active}{iobj}{$n_iobj}++;
        $arguments{active}{oblagent}{$n_agent}++;
        $arguments{active}{xcomp}{$n_xcomp}++;
    }
    else
    {
        $arguments{passive}{pred}++; # this is just to count the occurrences of active verbal predicates
        $arguments{passive}{subj}{$n_subj_pass}++;
        $arguments{passive}{obj}{$n_dobj}++;
        $arguments{passive}{iobj}{$n_iobj}++;
        $arguments{passive}{oblagent}{$n_agent}++;
        $arguments{passive}{xcomp}{$n_xcomp}++;
    }
    if($n_subj_act + $n_subj_pass > 1)
    {
        generate_warning("More than 1 subject, not in coordination.");
    }
    if($n_dobj > 1)
    {
        generate_warning("More than 1 direct object, not in coordination.");
    }
    if($n_iobj > 1)
    {
        generate_warning("More than 1 indirect object, not in coordination.");
    }
    if($n_agent > 1)
    {
        generate_warning("More than 1 oblique agent, not in coordination.");
    }
    if($n_xcomp > 1)
    {
        generate_warning("More than 1 open clausal complement, not in coordination.");
    }
    if($is_passive_clause && $n_subj_act > 0)
    {
        generate_warning("Non-passive subject in a passive clause.");
    }
    if($is_passive_clause && $n_dobj > 0)
    {
        generate_warning("Direct object in a passive clause.");
    }
    ###!!! In the future, we will look at obl:arg, too. However, we will have to
    ###!!! run it twice. First collect the surface frames of each predicate, then
    ###!!! define a canonical ordering so that the same argument always gets the
    ###!!! same number.
    unless($is_passive_clause)
    {
        # Subject of active clause is argument 1.
        my @subjects = grep {$_->{deprel} =~ m/^[nc]subj(:|$)/} (@oedges);
        if(scalar(@subjects) > 0)
        {
            @{$arguments[1]} = map {$_->{id}} (@subjects);
        }
        # Direct object of active clause is argument 2.
        # We treat ccomp as a clausal version of a direct object.
        my @dobjects = grep {$_->{deprel} =~ m/^(obj|ccomp)(:|$)/} (@oedges);
        if(scalar(@dobjects) > 0)
        {
            @{$arguments[2]} = map {$_->{id}} (@dobjects);
        }
        # Indirect object of active clause is argument 3.
        my @iobjects = grep {$_->{deprel} =~ m/^iobj(:|$)/} (@oedges);
        if(scalar(@iobjects) > 0)
        {
            @{$arguments[3]} = map {$_->{id}} (@iobjects);
        }
        # We make open clausal complement argument 4 to avoid conflict with indirect object,
        # although the examples of iobj and xcomp in the same clause that we observed so far
        # seem to be annotation errors.
        my @xcomps = grep {$_->{deprel} =~ m/^xcomp(:|$)/} (@oedges);
        if(scalar(@xcomps) > 0)
        {
            @{$arguments[4]} = map {$_->{id}} (@xcomps);
        }
    }
    else # detected passive clause
    {
        # Subject of passive clause is argument 2.
        my @subjects = grep {$_->{deprel} =~ m/^[nc]subj:pass(:|$)/} (@oedges);
        my @iobjects = grep {$_->{deprel} =~ m/^iobj(:|$)/} (@oedges);
        my @xcomps = grep {$_->{deprel} =~ m/^xcomp(:|$)/} (@oedges);
        my @agents = grep {$_->{deprel} =~ m/^obl:agent(:|$)/} (@oedges);
        if(scalar(@subjects) > 0)
        {
            @{$arguments[2]} = map {$_->{id}} (@subjects);
        }
        # Indirect object of passive clause is argument 3 (same as in active clause).
        if(scalar(@iobjects) > 0)
        {
            @{$arguments[3]} = map {$_->{id}} (@iobjects);
        }
        # We make open clausal complement argument 4 to avoid conflict with indirect object,
        # although the examples of iobj and xcomp in the same clause that we observed so far
        # seem to be annotation errors.
        if(scalar(@xcomps) > 0)
        {
            @{$arguments[4]} = map {$_->{id}} (@xcomps);
        }
        # Oblique agent in passive clause is argument 1.
        if(scalar(@agents) > 0)
        {
            @{$arguments[1]} = map {$_->{id}} (@agents);
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



#------------------------------------------------------------------------------
# Generates a warning about an unexpected situation. Either prints the warning
# immediately or just registers it so that we can print a summary at the end.
#------------------------------------------------------------------------------
sub generate_warning
{
    my $warning = shift;
    my $immediately = 0;
    if($immediately)
    {
        print STDERR ("WARNING: $warning\n");
    }
    else
    {
        # Register the warning in a global hash.
        $warnings{$warning}++;
    }
}
