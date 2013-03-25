package Bio::Tools::EUtilities::Summary::ItemContainerI;
use utf8;
use strict;
use warnings;
use base qw(Bio::Tools::EUtilities::EUtilDataI);

# ABSTRACT: Abtract interface methods for accessing Item information from any Item-containing class. This pertains to either DocSums or to Items themselves (which can be layered).
# AUTHOR:   Chris Fields <cjfields@bioperl.org>
# OWNER:    2006-2013 Chris Fields
# LICENSE:  Perl_5

=head1 SYNOPSIS

  # Implement ItemContainerI

  # $foo is any ItemContainerI (current implementations are DocSum and Item itself)

  while (my $item = $foo->next_Item) { # iterate through contained Items
     # do stuff here
  }

  @items = $foo->get_Items;  # all Items in the container (hierarchy intact)
  @items = $foo->get_all_Items;  # all Items in the container (flattened)
  @items = $foo->get_Items_by_name('bar'); # Specifically named Items
  ($content) = $foo->get_contents_by_name('bar'); # content from specific Items
  ($type) = $foo->get_type_by_name('bar'); # data type from specific Items

=head1 DESCRIPTION

DocSum data, as returned from esummary, normally is a simple list of
item-content-content_type groups. However, items can also contain nested data to
represent more complex data (such as structural data). This interface describes
the basic methods to generically retrieve the next layer of Item data. For
convenience classes may describe more specific methods, but they should be
defined in terms of this interface and it's methods.

=cut

=head2 next_Item

 Title    : next_Item
 Usage    : while (my $item = $docsum->next_Item) {...}
 Function : iterates through Items (nested layer of Item)
 Returns  : single Item
 Args     : [optional] single arg (string)
            'flatten' - iterates through a flattened list ala
                          get_all_DocSum_Items()

=cut

sub next_Item {
    my ($self, $request) = @_;
    unless ($self->{"_items_it"}) {
        my @items = ($request && $request eq 'flatten') ?
                    $self->get_all_Items :
                    $self->get_Items ;
        $self->{"_items_it"} = sub {return shift @items}
    }
    $self->{'_items_it'}->();
}

=head2 get_Items

 Title    : get_Items
 Usage    : my @items = $docsum->get_Items
 Function : returns list of, well, Items
 Returns  : array of Items
 Args     : none

=cut

sub get_Items {
    my $self = shift;
    return ref $self->{'_items'} ? @{ $self->{'_items'} } : return ();
}

=head2 get_all_Items

 Title    : get_all_Items
 Usage    : my @items = $docsum->get_all_Items
 Function : returns flattened list of all Item objects (Items, ListItems,
            StructureItems)
 Returns  : array of Items
 Args     : none
 Note     : items are added top-down (similar order to using nested calls)
            in original list order.

             1         2        7        8
           Item  -   Item  -  Item  -  Item ...
                     |
                    | 3        6
                 ListItem - ListItem
                   |
                  | 4          5
               Structure - Structure

=cut

sub get_all_Items {
    my $self = shift;
    unless ($self->{'_ordered_items'}) {
        for my $item ($self->get_Items) {
            push @{$self->{'_ordered_items'}}, $item;
            for my $ls ($item->get_ListItems) {
                push @{$self->{'_ordered_items'}}, $ls;
                for my $st ($ls->get_StructureItems) {
                    push @{$self->{'_ordered_items'}}, $st;
                }
            }
        }
    }
    return @{$self->{'_ordered_items'}};
}

=head2 get_all_names

 Title    : get_all_names
 Usage    : my @names = get_all_names()
 Function : Returns an array of names for all Item(s) in DocSum.
 Returns  : array of unique strings
 Args     : none

=cut

sub get_all_names {
    my ($self) = @_;
    my %tmp;
    my @data = grep {!$tmp{$_}++}
        map {$_->get_name} $self->get_all_Items;
    return @data;
}

=head2 get_Items_by_name

 Title    : get_Items_by_name
 Usage    : my @items = get_Items_by_name('CreateDate')
 Function : Returns named Item(s) in DocSum (indicated by passed argument)
 Returns  : array of Item objects
 Args     : string (Item name)

=cut

sub get_Items_by_name {
    my ($self, $key) = @_;
    return unless $key;
    my @data = grep {$_->get_name eq $key}
        $self->get_all_Items;
    return @data;
}

=head2 get_contents_by_name

 Title    : get_contents_by_name
 Usage    : my ($data) = $eutil->get_contents_by_name('CreateDate')
 Function : Returns content for named Item(s) in DocSum (indicated by
            passed argument)
 Returns  : array of values (type varies per Item)
 Args     : string (Item name)

=cut

sub get_contents_by_name {
    my ($self, $key) = @_;
    return unless $key;
    my @data = map {$_->get_content}
        grep {$_->get_name eq $key}
        $self->get_all_Items;
    return @data;
}

=head2 get_type_by_name

 Title    : get_type_by_name
 Usage    : my $data = get_type_by_name('CreateDate')
 Function : Returns data type for named Item in DocSum (indicated by
            passed argument)
 Returns  : scalar value (string) if present
 Args     : string (Item name)

=cut

sub get_type_by_name {
    my ($self, $key) = @_;
    return unless $key;
    my ($it) = grep {$_->get_name eq $key} $self->get_all_Items;
    return $it->get_type;
}

1;
