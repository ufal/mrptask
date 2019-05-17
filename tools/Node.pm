package Node;

use utf8;
use namespace::autoclean;

use Moose;
use MooseX::SemiAffordanceAccessor; # attribute x is written using set_x($value) and read using x()
use List::MoreUtils qw(any);



has 'id'    => (is => 'rw', isa => 'Str', required => 1, documentation => 'The ID column in CoNLL-U file.');
has 'form'  => (is => 'rw', isa => 'Str', documentation => 'The FORM column in CoNLL-U file.');
has 'lemma' => (is => 'rw', isa => 'Str', documentation => 'The LEMMA column in CoNLL-U file.');
has 'upos'  => (is => 'rw', isa => 'Str', documentation => 'The UPOS column in CoNLL-U file.');
has 'xpos'  => (is => 'rw', isa => 'Str', documentation => 'The XPOS column in CoNLL-U file.');



__PACKAGE__->meta->make_immutable();

1;



=for Pod::Coverage BUILD

=encoding utf-8

=head1 NAME

Node

=head1 DESCRIPTION

A C<Graph> holds a list of nodes and can return the C<Node> based on its
C<ID> (the first column in a CoNLL-U file, can be integer or a decimal number).
Edges are stored in nodes.

=head1 ATTRIBUTES

=over

=item parent

Refers to the parent C<Phrase>, if any.

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
