package Node;

use utf8;
use namespace::autoclean;

use Moose;
use MooseX::SemiAffordanceAccessor; # attribute x is written using set_x($value) and read using x()
use List::MoreUtils qw(any);
use Graph;



has 'graph'   => (is => 'rw', isa => 'Graph', documentation => 'Refers to the graph (sentence) this node belongs to.');
has 'id'      => (is => 'rw', isa => 'Str', required => 1, documentation => 'The ID column in CoNLL-U file.');
has 'form'    => (is => 'rw', isa => 'Str', documentation => 'The FORM column in CoNLL-U file.');
has 'lemma'   => (is => 'rw', isa => 'Str', documentation => 'The LEMMA column in CoNLL-U file.');
has 'upos'    => (is => 'rw', isa => 'Str', documentation => 'The UPOS column in CoNLL-U file.');
has 'xpos'    => (is => 'rw', isa => 'Str', documentation => 'The XPOS column in CoNLL-U file.');
has 'feats'   => (is => 'rw', isa => 'HashRef', documentation => 'Hash holding the features from the FEATS column in CoNLL-U file.');
has 'misc'    => (is => 'rw', isa => 'ArrayRef', documentation => 'Array holding the attributes from the MISC column in CoNLL-U file.');
has '_head'   => (is => 'rw', isa => 'Str', documentation => 'Temporary storage for the HEAD column before the graph structure is built.');
has '_deprel' => (is => 'rw', isa => 'Str', documentation => 'Temporary storage for the DEPREL column before the graph structure is built.');
has '_deps'   => (is => 'rw', isa => 'Str', documentation => 'Temporary storage for the DEPS column before the graph structure is built.');
has 'iedges'  => (is => 'rw', isa => 'ArrayRef', default => sub {[]}, documentation => 'Array of records of incoming edges.');
has 'oedges'  => (is => 'rw', isa => 'ArrayRef', default => sub {[]}, documentation => 'Array of records of outgoing edges.');
has 'bparent' => (is => 'rw', isa => 'Str', documentation => 'Parent node in the basic tree.');
has 'bdeprel' => (is => 'rw', isa => 'Str', documentation => 'Type of relation between this node and its parent in the basic tree.');
has 'bchildren' => (is=>'rw', isa => 'ArrayRef', default => sub {[]}, documentation => 'Array of ids of children in the basic tree.');



#------------------------------------------------------------------------------
# Parses the string from the FEATS column of a CoNLL-U file and sets the feats
# hash accordingly. If the feats hash has been set previously, it will be
# discarded and replaced by the new one.
#------------------------------------------------------------------------------
sub set_feats_from_conllu
{
    confess('Incorrect number of arguments') if(scalar(@_) != 2);
    my $self = shift;
    my $feats = shift;
    unless($feats eq '_')
    {
        my @fvpairs = split(/\|/, $feats);
        my %feats;
        foreach my $fv (@fvpairs)
        {
            if($fv =~ m/^([A-Za-z\[\]]+)=([A-Za-z0-9,]+)$/)
            {
                my $f = $1;
                my $v = $2;
                if(exists($feats{$f}))
                {
                    print STDERR ("WARNING: Duplicite feature definition: '$f=$feats{$f}' will be overwritten with '$f=$v'.\n");
                }
                $feats{$f} = $v;
            }
            else
            {
                print STDERR ("WARNING: Unrecognized feature-value pair '$fv'.\n");
            }
        }
        # The feature hash may be empty due to input errors. Set it only if
        # there are meaningful values.
        if(scalar(keys(%feats))>0)
        {
            $self->set_feats(\%feats);
        }
    }
}



#------------------------------------------------------------------------------
# Parses the string from the MISC column of a CoNLL-U file and sets the misc
# array accordingly. If the misc array has been set previously, it will be
# discarded and replaced by the new one.
#------------------------------------------------------------------------------
sub set_misc_from_conllu
{
    confess('Incorrect number of arguments') if(scalar(@_) != 2);
    my $self = shift;
    my $misc = shift;
    # No CoNLL-U field can contain leading or trailing whitespace characters.
    # In particular, the linte-terminating LF character may have been forgotten
    # when the line was split into fields, but it is not part of the MISC field.
    $misc =~ s/^\s+//;
    $misc =~ s/\s+$//;
    unless($misc eq '_')
    {
        my @misc = split(/\|/, $misc);
        $self->set_misc(\@misc);
    }
}



#------------------------------------------------------------------------------
# Checks whether the node depends (directly or indirectly) on a given other
# node in the basic tree.
#------------------------------------------------------------------------------
sub basic_depends_on
{
    confess('Incorrect number of arguments') if(scalar(@_) != 2);
    my $self = shift;
    confess('Node is not member of a graph') if(!defined($self->graph()));
    my $aid = shift; # ancestor id
    my $pid = $self->bparent();
    return defined($pid) && ($pid==$aid || $self->graph()->get_node($pid)->basic_depends_on($aid));
}



#------------------------------------------------------------------------------
# Links the node with its parent according to the basic tree. Both the node
# and its parent must be already added to a graph, and the parent must not
# already depend on the node.
#------------------------------------------------------------------------------
sub set_basic_dep_from_conllu
{
    confess('Incorrect number of arguments') if(scalar(@_) != 1);
    my $self = shift;
    confess('Node is not member of a graph') if(!defined($self->graph()));
    my $head = $self->_head();
    my $deprel = $self->_deprel();
    unless(!defined($head) || $head eq '' || $head eq '_')
    {
        # This method is designed for one-time use in the beginning.
        # Therefore we assume that the basic parent has not been set previously.
        # (Otherwise we would have to care first about removing any link to us
        # from the current parent.)
        if(defined($self->bparent()))
        {
            confess('Basic parent already exists');
        }
        if(!$self->graph()->has_node($head))
        {
            confess("Basic dependency '$deprel' from a non-existent node '$head'");
        }
        if($head == $self->id())
        {
            confess("Cannot attach node '$head' to itself in the basic tree");
        }
        if($self->graph()->get_node($head)->basic_depends_on($self->id()))
        {
            my $id = $self->id();
            confess("Cannot attach node '$id' to '$head' in the basic tree because it would make a cycle");
        }
        $self->set_bparent($head);
        $self->set_bdeprel($deprel);
        push(@{$self->graph()->get_node($head)->bchildren()}, $self->id());
    }
}



#------------------------------------------------------------------------------
# Parses the string stored in _deps and creates the corresponding edges. The
# node must be already added to a graph, and all nodes referenced in the edges
# must also be added to the same graph.
#------------------------------------------------------------------------------
sub set_deps_from_conllu
{
    confess('Incorrect number of arguments') if(scalar(@_) != 1);
    my $self = shift;
    confess('Node is not member of a graph') if(!defined($self->graph()));
    my $deps = $self->_deps();
    unless(!defined($deps) || $deps eq '' || $deps eq '_')
    {
        my @deps = split(/\|/, $deps);
        foreach my $dep (@deps)
        {
            if($dep =~ m/^(\d+(?:\.\d+)?):(.+)$/)
            {
                my $h = $1;
                my $d = $2;
                # Check that the referenced parent node exists.
                if(!$self->graph()->has_node($h))
                {
                    confess("Incoming dependency '$d' from a non-existent node '$h'");
                }
                # Store the parent in my incoming edges.
                my %pr =
                (
                    'id'     => $h,
                    'deprel' => $d
                );
                # Check that the same edge (including label) does not already exist.
                if(any {$_->{id} == $h && $_->{deprel} eq $d} (@{$self->iedges()}))
                {
                    print STDERR ("WARNING: Ignoring repeated declaration of edge '$h --- $d ---> $self->{id}'.\n");
                }
                else
                {
                    push(@{$self->iedges()}, \%pr);
                    # Store me as a child in the parent's object.
                    my %cr =
                    (
                        'id'     => $self->id(),
                        'deprel' => $d
                    );
                    push(@{$self->graph()->get_node($h)->oedges()}, \%cr);
                }
            }
            else
            {
                print STDERR ("WARNING: Cannot understand dep '$dep'\n");
            }
        }
    }
}



#------------------------------------------------------------------------------
# Returns the number of incoming edges.
#------------------------------------------------------------------------------
sub get_in_degree
{
    confess('Incorrect number of arguments') if(scalar(@_) != 1);
    my $self = shift;
    return scalar(@{$self->iedges()});
}



#------------------------------------------------------------------------------
# Returns the number of outgoing edges.
#------------------------------------------------------------------------------
sub get_out_degree
{
    confess('Incorrect number of arguments') if(scalar(@_) != 1);
    my $self = shift;
    return scalar(@{$self->oedges()});
}



__PACKAGE__->meta->make_immutable();

1;



=for Pod::Coverage BUILD

=encoding utf-8

=head1 NAME

Node

=head1 DESCRIPTION

A C<Node> corresponds to a line in a CoNLL-U file: a word, an empty node, or
even a multi-word token.

=head1 ATTRIBUTES

=over

=item id

The ID of the node. Column 0 of the line.

=back

=head1 METHODS

=over

=item $phrase->set_parent ($nonterminal_phrase);

Sets a new parent for this phrase. The parent phrase must be a L<nonterminal|Treex::Core::Phrase::NTerm>.
This phrase will become its new I<non-head> child.
The new parent may also be undefined, which means that the current phrase will
be disconnected from the phrase structure (but it will keeep its own children,
if any).
The method returns the old parent.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2019 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
