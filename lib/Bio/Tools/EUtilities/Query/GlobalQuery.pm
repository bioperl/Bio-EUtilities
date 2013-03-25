package Bio::Tools::EUtilities::Query::GlobalQuery;
use utf8;
use strict;
use warnings;
use base qw(Bio::Root::Root Bio::Tools::EUtilities::EUtilDataI);

# ABSTRACT: Container class for egquery data.
# AUTHOR:   Chris Fields <cjfields@bioperl.org>
# OWNER:    2006-2013 Chris Fields
# LICENSE:  Perl_5

=head1 SYNOPSIS

  #### should not create instance directly; Bio::Tools::EUtilities does this ####

  my $parser = Bio::Tools::EUtilities->new(-eutil => 'egquery',
                                           -term  => 'BRCA1');

  # $gquery is a Bio::Tools::EUtilities::Query::GlobalQuery
  while (my $gquery = $parser->next_GlobalQuery) {
     print $gquery->to_string."\n"; # stringify
     print "DB:".$gquery->get_db."\t".$gquery->get_count;
  }

=head1 DESCRIPTION

This is a simple container class for egquery data.  Currently this just contains
various accessors for the data, such as get_database(), get_count(), etc. for
each item in a global query.

=cut

sub new {
    my ($class, @args) = @_;
    my $self = $class->SUPER::new(@args);
    $self->eutil('egquery');
    $self->datatype('globalquery');
    return $self;
}

=head2 get_term

 Title   : get_term
 Usage   : $st = $qd->get_term;
 Function: retrieve the term for the global search
 Returns : string
 Args    : none

=cut

sub get_term {
    my ($self) = @_;
    return $self->{'_term'};
}

=head2 get_database

 Title   : get_database
 Usage   : $ct = $qd->get_database;
 Function: retrieve the database
 Returns : string
 Args    : none

=cut

sub get_database {
    my ($self) = @_;
    return $self->{'_dbname'};
}

=head2 get_count

 Title   : get_count
 Usage   : $ct = $qd->get_count;
 Function: retrieve the count for the database
 Returns : string
 Args    : none

=cut

sub get_count {
    my ($self) = @_;
    return $self->{'_count'};
}

=head2 get_status

 Title   : get_status
 Usage   : $st = $qd->get_status;
 Function: retrieve the query status for database in db()
 Returns : string
 Args    : none

=cut

sub get_status {
    my ($self) = @_;
    return $self->{'_status'};
}

=head2 get_menu_name

 Title   : get_menu_name
 Usage   : $ct = $qd->get_menu_name;
 Function: retrieve the full name for the database in db()
 Returns : string
 Args    : None

=cut

sub get_menu_name {
    my $self = shift;
    return $self->{'_menuname'};
}

# private method

sub _add_data {
    my ($self, $data) = @_;
    map {$self->{'_'.lc $_} = $data->{$_}} keys %$data;
}

=head2 to_string

 Title    : to_string
 Usage    : $foo->to_string()
 Function : converts current object to string
 Returns  : none
 Args     : (optional) simple data for text formatting
 Note     : Used generally for debugging and for the print_GlobalQuery method

=cut

sub to_string {
    my $self = shift;
    my $string .= sprintf("%-20s Total:%-10d Status:%s\n",
        $self->get_database,
        $self->get_count,
        $self->get_status);
    return $string;
}

1;
