package Bio::Tools::EUtilities::EUtilDataI;

use utf8;
use strict;
use warnings;
use base qw(Bio::Root::RootI);
use Text::Wrap qw(wrap);

# ABSTRACT: EUtil data object interface.
# AUTHOR:   Chris Fields <cjfields@bioperl.org>
# OWNER:    2006-2013 Chris Fields
# LICENSE:  Perl_5

=head1 SYNOPSIS

  # say you had some data in a hash ref ($data) and wanted to create hierarchies
  # of object using the same interface, starting with the topmost...

  # $object is a Bio::Tools::EUtilities::EUtilDataI instance

  $object->_add_data($data);

  # in _add_data()... sort through keys and create subobjects as needed

  if ($key eq 'foo') {
     my $sub = Bio::Tools::EUtilities::FooData->new(-eutil => 'efoo',
                                                    -type => 'foo');
     $sub->_add_data($subdata);
     # store into parent object as needed...
     ...
   }

   # access stored data

   while (my $sub = $parent->next_Foo) {...}


=head1 DESCRIPTION

This is a simple interface which allows creation of simple typed object
hierarchies. Single layers can be accessed via simple iterators (next_* methods)
or retrieved all at once (get_*) methods; nested data can be iterated through
nested iterators for each object, or retrieved using get_all_* methods.

This interface defines common methods required for all eutil data-holding
objects: _add_data(), eutil(), and type(). It also specifies inheriting
interface classes use at least one of three methods: get_ids(), get_term(), or
get_database(), which are the three types of data that eutils mainly centers on.

Generally, eutil() is the Bio::Tools::EUtilities parser used to set the data.
Similarly, datatype() is the specific data type for the class.

Implementations which rely on subclasses to store data and have iterators should
also define a generalized rewind() method that (by default) rewinds all
iterators to the start. Args passed can specify exactly which iterator to rewind
and (if possible) recursively rewind nested object iterators.

As the method implies, _add_data() is a private method that adds data chunks to
the object and sets internal parameters for the various data objects. Methods
corresponding to the data type simply return the set data or iterate through the
data sets if the values are more complex. Data can alternatively be passed
through the object constructor.

=cut

=head2 eutil

 Title    : eutil
 Usage    : $eutil->$foo->eutil
 Function : Get/Set eutil
 Returns  : string
 Args     : string (eutil)
 Throws   : on invalid eutil

=cut

{
    my %VALID_EUTILS = map {$_ => 1} qw(esearch epost espell egquery elink einfo esummary);

sub eutil {
    my ($self, $eutil) = @_;
    if ($eutil) {
        $self->throw("$eutil not supported") if !exists $VALID_EUTILS{$eutil};
        return $self->{'_eutil'} = $eutil;
    }
    return $self->{'_eutil'};
}

}

=head2 datatype

 Title   : type
 Usage   : $type = $qd->datatype;
 Function: retrieve simple data type object holds (linkset, docsum, item, etc)
 Returns : string (eutil name)
 Args    : none
 Note    : this is probably more useful for devs than for users as a way to keep
           track of the various types of modules used

=cut

sub datatype {
    my $self = shift;
    return $self->{'_type'} = shift if @_;
    return $self->{'_type'};
}

=head2 rewind

 Title    : rewind
 Usage    : $esum->rewind
 Function : rewinds the requested iterator
 Returns  : none
 Args     : [OPTIONAL] may include 'all', 'recursive', etc.

=cut

=head2 _add_data

 Title    : _add_data
 Usage    : $foo->_add_data($data)
 Function : adds data to current object as a chunk
 Returns  : none
 Args     : hash ref containing relevant data

=cut

sub _add_data {
    shift->throw_not_implemented;
}

=head2 to_string

 Title    : to_string
 Usage    : $foo->to_string()
 Function : converts current object to string
 Returns  : none
 Args     : (optional) simple data for text formatting
 Note     : Used generally for debugging and for the print_* methods

=cut

sub to_string {
    shift->throw_not_implemented;
}

=head2 _text_wrap

 Title    : _text_wrap
 Usage    : $foo->_text_wrap($string)
 Function : private internal wrapper for Text::Wrap::wrap
 Returns  : string
 Args     : string
 Note     : Internal use only.  Simple wrapper method.

=cut

sub _text_wrap {
    shift;
    return wrap(@_);
}

=head2 _node (experimental)

 Title    : node
 Usage    : $foo->node()
 Function : Get/Set XML::LibXML::Node implementation (generally a DOM or element) (experimental)
 Returns  : XML::LibXML element
 Args     : XML::LibXML element (optional)
 Note     : This is a highly experimental interface and may change substantially. You have been warned

=cut

sub _node {
    my ($self, $node) = @_;
    if ($node) {
        $self->{'_node'} = $node;
    }
    return $self->{'_node'};
}



1;
