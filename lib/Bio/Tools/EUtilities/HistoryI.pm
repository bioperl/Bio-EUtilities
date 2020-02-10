package Bio::Tools::EUtilities::HistoryI;

use utf8;
use strict;
use warnings;
use base qw(Bio::Tools::EUtilities::EUtilDataI);

# ABSTRACT: Simple extension of EUtilDataI interface class for classes which hold NCBI server history data.
# AUTHOR:   Chris Fields <cjfields@bioperl.org>
# OWNER:    2006-2013 Chris Fields
# LICENSE:  Perl_5

=head1 SYNOPSIS

  #should work for any class which is-a HistoryI

  if ($obj->has_History) {
      # do something here
  }

  ($webenv, $querykey) = $obj->history;

  $obj->history($webenv, $querykey);

  $webenv = $obj->get_webenv;

  $query_key = $obj->get_query_key;

=head1 DESCRIPTION

This class extends methods for any EUtilDataI implementation allow instances to
dealwith NCBI history data (WebEnv and query_key).  These can be used as
parameters for further queries against data sets stored on the NCBI server, much
like NCBI's Entrez search history. These are important when one wants to run
complex queries using esearch, retrieve related data using elink, and retrieve
large datasets using epost/efetch.

The simplest implementation is Bio::Tools::EUtilities::History, which holds the
history data for epost.  See also Bio::Tools::EUtilities::Query (esearch) and
Bio::Tools::EUtilities::LinkSet (elink), which also implement HistoryI.

=cut

=head2 history

 Title    : history
 Usage    : my ($webenv, $qk) = $hist->history
 Function : Get/Set two-element list of webenv() and query_key()
 Returns  : array
 Args     : two-element list of webenv, querykey

=cut

sub history {
    my $self = shift;
    $self->parse_data if ($self->can('parse_data') && !$self->data_parsed);
    return ($self->get_webenv, $self->get_query_key);
}

=head2 get_webenv

 Title    : get_webenv
 Usage    : my $webenv = $hist->get_webenv
 Function : returns web environment key needed to retrieve results from
            NCBI server
 Returns  : string (encoded key)
 Args     : none

=cut

sub get_webenv {
    my $self = shift;
    $self->parse_data if ($self->can('parse_data') && !$self->data_parsed);
    return ($self->{el}->findnodes('.//WebEnv'))[0]->to_literal();
}

=head2 get_query_key

 Title    : get_query_key
 Usage    : my $qk = $hist->get_query_key
 Function : returns query key (integer) for the history number for this session
 Returns  : integer
 Args     : none

=cut

sub get_query_key {
    my $self = shift;
    $self->parse_data if ($self->can('parse_data') && !$self->data_parsed);
    return ($self->{el}->findnodes('.//QueryKey'))[0]->to_literal();
}

1;
__END__
