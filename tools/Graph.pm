package Graph;

use utf8;
use namespace::autoclean;

use Carp;
use Moose;
use MooseX::SemiAffordanceAccessor; # attribute x is written using set_x($value) and read using x()
use List::MoreUtils qw(any);
use Node;



has 'comments' => (is => 'ro', isa => 'ArrayRef', default => sub {[]}, documentation => 'Sentence-level CoNLL-U comments.');
has 'nodes'    => (is => 'ro', isa => 'HashRef', default => sub {my $self = shift; {0 => new Node('id' => 0, 'graph' => $self)}});



#------------------------------------------------------------------------------
# Checks whether there is a node with the given id.
#------------------------------------------------------------------------------
sub has_node
{
    confess('Incorrect number of arguments') if(scalar(@_) != 2);
    my $self = shift;
    my $id = shift;
    confess('Undefined id') if(!defined($id));
    return exists($self->nodes()->{$id});
}



#------------------------------------------------------------------------------
# Returns node with the given id. If there is no such node, returns undef.
#------------------------------------------------------------------------------
sub get_node
{
    confess('Incorrect number of arguments') if(scalar(@_) != 2);
    my $self = shift;
    my $id = shift;
    confess('Undefined id') if(!defined($id));
    return $self->has_node($id) ? $self->nodes()->{$id} : undef;
}



#------------------------------------------------------------------------------
# Returns node with the given id. If there is no such node, returns undef.
# This method is just an alias for get_node().
#------------------------------------------------------------------------------
sub node
{
    my $self = shift;
    my $id = shift;
    return $self->get_node($id);
}



#------------------------------------------------------------------------------
# Returns the list of all nodes except the artificial root node with id 0. The
# list is ordered by node ids.
#------------------------------------------------------------------------------
sub get_nodes
{
    confess('Incorrect number of arguments') if(scalar(@_) != 1);
    my $self = shift;
    my @list = map {$self->get_node($_)} (sort
    {
        Node::cmpids($a, $b)
    }
    (grep {$_ ne '0'} (keys(%{$self->nodes()}))));
    return @list;
}



#------------------------------------------------------------------------------
# Adds a node to the graph. The node must have a non-empty id that has not been
# used by any other node previously added to the graph.
#------------------------------------------------------------------------------
sub add_node
{
    confess('Incorrect number of arguments') if(scalar(@_) != 2);
    my $self = shift;
    my $node = shift;
    my $id = $node->id();
    if(!defined($id))
    {
        confess('Cannot add node with undefined ID');
    }
    if($self->has_node($id))
    {
        confess("There is already a node with ID $id in the graph");
    }
    $self->nodes()->{$id} = $node;
    $node->set_graph($self);
}



#------------------------------------------------------------------------------
# Adds an edge between two nodes that are already in the graph.
#------------------------------------------------------------------------------
sub add_edge
{
    confess('Incorrect number of arguments') if(scalar(@_) != 4);
    my $self = shift;
    my $srcid = shift;
    my $tgtid = shift;
    my $deprel = shift;
    my $srcnode = $self->get_node($srcid);
    my $tgtnode = $self->get_node($tgtid);
    confess("Unknown node '$srcid'") if(!defined($srcnode));
    confess("Unknown node '$tgtid'") if(!defined($tgtnode));
    # Outgoing edge from the source (parent).
    my %oe =
    (
        'id'     => $tgtid,
        'deprel' => $deprel
    );
    # Incoming edge to the target (child).
    my %ie =
    (
        'id'     => $srcid,
        'deprel' => $deprel
    );
    # Check that the same edge does not exist already.
    push(@{$srcnode->oedges()}, \%oe) unless(any {$_->{id} eq $tgtid && $_->{deprel} eq $deprel} (@{$srcnode->oedges()}));
    push(@{$tgtnode->iedges()}, \%ie) unless(any {$_->{id} eq $srcid && $_->{deprel} eq $deprel} (@{$tgtnode->iedges()}));
}



__PACKAGE__->meta->make_immutable();

1;



=for Pod::Coverage BUILD

=encoding utf-8

=head1 NAME

Graph

=head1 DESCRIPTION

A C<Graph> holds a list of nodes and can return the C<Node> based on its
C<ID> (the first column in a CoNLL-U file, can be integer or a decimal number).
Edges are stored in nodes.

=head1 ATTRIBUTES

=over

=item comments

A read-only attribute (filled during construction) that holds the sentence-level
comments from the CoNLL-U file.

=item nodes

A hash (reference) that holds the individual L<Node> objects, indexed by their
ids from the first column of the CoNLL-U file.

=back

=head1 METHODS

=over

=item $graph->has_node ($id);

Returns a nonzero value if there is a node with the given id in the graph.

=item @nodes = $graph->get_nodes ();

Returns the list of all nodes except the artificial root node with id 0. The
list is ordered by node ids.

=item $graph->add_node ($node);

Adds a node (a L<Node> object) to the graph. The node must have a non-empty id
that has not been used by any other node previously added to the graph.

=item $graph->add_edge ($source_id, $target_id, $relation_label);

Adds an edge between two nodes that are already in the graph.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2019, 2020 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
