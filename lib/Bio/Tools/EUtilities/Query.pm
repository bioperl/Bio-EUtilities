package Bio::Tools::EUtilities::Query;

use utf8;
use strict;
use warnings;
use Bio::Tools::EUtilities::Query::GlobalQuery;
use Bio::Tools::EUtilities::History;
use Scalar::Util;
use base qw(Bio::Tools::EUtilities);

# ABSTRACT: Parse and collect esearch, epost, espell, egquery information.
# AUTHOR:   Chris Fields <cjfields@bioperl.org>
# OWNER:    2006-2013 Chris Fields
# LICENSE:  Perl_5

=head1 SYNOPSIS

  ### should not create instance directly; Bio::Tools::EUtilities does this ###

  # can also use '-response' (for HTTP::Response objects) or '-fh' (for
  # filehandles)

  my $info = Bio::Tools::EUtilities->new(-eutil => 'esearch',
                                         -file => 'esearch.xml');

  # esearch

  # esearch with history

  # egquery

  # espell (just for completeness, really)

=head1 DESCRIPTION

Pluggable module for handling query-related data returned from eutils.

=cut

=head1 Bio::Tools::EUtilities::Query methods

=cut

# private EUtilDataI method

{
my %TYPE = (
    'espell'    => 'spelling',
    'esearch'   => 'singledbquery',
    'egquery'   => 'multidbquery',
    'epost'     => 'history'
    );

=head2 get_ids

 Title    : get_ids
 Usage    : my @ids = $parser->get_ids
 Function : returns array of requested IDs (see Notes for more specifics)
 Returns  : array
 Args     : [conditional] not required except when running elink queries against
            multiple databases. In case of the latter, the database name is
            optional but recommended when retrieving IDs as the ID list will
            be globbed together. In such cases, if a db name isn't provided a
            warning is issued as a reminder.
 Notes    : esearch    : returned ID list
            elink      : returned ID list (see Args above for caveats)
            all others : from parameter_base->id or undef

=cut

sub get_ids {
    my ($self, $request) = @_;
    $self->parse_data unless $self->data_parsed;
    my @ids = ();
    return @ids
}

=head2 get_databases

 Title    : get_databases
 Usage    : my @dbs = $parser->get_databases
 Function : returns list of databases
 Returns  : array of strings
 Args     : none
 Notes    : This is guaranteed to return a list of databases. For a single
            database use the convenience method get_db/get_database

            egquery    : list of all databases in the query
            einfo      : the queried database, or the available databases
            espell     : the queried database
            elink      : collected from each LinkSet
            all others : from parameter_base->db or undef

=cut

sub get_databases {
    my ($self) = @_;
    my $eutil = $self->eutil();
    $self->parse_data() unless $self->data_parsed();
    if (!$self->{dom}) {
        $self->throw("No XML document object found!")
    }
    my @dbs = map {$_->to_literal()} $self->{dom}->findnodes('//Database');
    #if ($eutil eq 'einfo' || $eutil eq 'espell') {
    #    #@dbs = $self->{'_dbname'} ||
    #    #$self->{'_database'} ||
    #    #$self->get_available_databases;
    #} elsif ($eutil eq 'egquery') {
    #    # @dbs = map {$_->get_database} ($self->get_GlobalQueries);
    #    @dbs = map {$_->to_literal()} $self->{dom}->findnodes('//Database');
    #} else {
    #    # only unique dbs
    #    $self->die("Unsupported eutil: $eutil")
    #}
    return @dbs;
}

=head1 Query-related methods

=head2 get_count

 Title    : get_count
 Usage    : my $ct = $parser->get_count
 Function : returns the count (hits for a search)
 Returns  : integer
 Args     : [CONDITIONAL] string with database name - used to retrieve
            count from specific database when using egquery
 Notes    : egquery    : count for specified database (specified above)
            esearch    : count for last search
            all others : undef

=cut

sub get_count {
    my ($self, $db) = @_;
    $self->parse_data unless $self->data_parsed;
    # egquery
    if ($self->datatype eq 'multidbquery') {
        if (!$db) {
            $self->warn('Must specify database to get count from');
            return;
        }
        my ($gq) = grep {$_->get_database eq $db} $self->get_GlobalQueries;
        $gq && return $gq->get_count;
        $self->warn("Unknown database $db");
        return;
    } else {
        return $self->{'_count'} || scalar($self->get_ids);
    }
}

=head2 get_term

 Title    : get_term
 Usage    : $st = $qd->get_term;
 Function : retrieve the term for the global search
 Returns  : string
 Args     : none
 Notes    : egquery    : search term
            espell     : search term
            esearch    : from parameter_base->term or undef
            all others : undef

=cut

sub get_term {
    my ($self, @args) = @_;
    $self->parse_data unless $self->data_parsed;
    my $term = ($self->{dom}->findnodes('//Query'))[0]->to_literal();
    #$self->{'_term'}  ? $self->{'_term'}  :
    #$self->{'_query'} ? $self->{'_query'} :
    #$self->parameter_base ? $self->parameter_base->term :
    return $term;
}

=head2 get_translation_from

 Title   : get_translation_from
 Usage   : $string = $qd->get_translation_from();
 Function: portion of the original query replaced with translated_to()
 Returns : string
 Args    : none
 Note    : only applicable for esearch

=cut

sub get_translation_from {
    my $self = shift;
    $self->parse_data unless $self->data_parsed;
    return ($self->{dom}->findnodes('//Foo'))[0]->to_literal();
}

=head2 get_translation_to

 Title   : get_translation_to
 Usage   : $string = $qd->get_translation_to();
 Function: replaced string used in place of the original query term in translation_from()
 Returns : string
 Args    : none
 Note    : only applicable for esearch

=cut

sub get_translation_to {
    my $self = shift;
    $self->parse_data unless $self->data_parsed;
    return ($self->{dom}->findnodes('//CorrectedQuery'))[0]->to_literal();
}

=head2 get_retstart

 Title    : get_retstart
 Usage    : $start = $qd->get_retstart();
 Function : retstart setting for the query (either set or NCBI default)
 Returns  : Integer
 Args     : none
 Notes    : esearch    : retstart
            esummary   : retstart
            all others : from parameter_base->retstart or undef

=cut

sub get_retstart {
    my $self = shift;
    $self->parse_data unless $self->data_parsed;
    return $self->{'_retstart'};
}

=head2 get_retmax

 Title    : get_retmax
 Usage    : $max = $qd->get_retmax();
 Function : retmax setting for the query (either set or NCBI default)
 Returns  : Integer
 Args     : none
 Notes    : esearch    : retmax
            esummary   : retmax
            all others : from parameter_base->retmax or undef

=cut

sub get_retmax {
    my $self = shift;
    $self->parse_data unless $self->data_parsed;
    return $self->{'_retmax'};
}

=head2 get_query_translation

 Title   : get_query_translation
 Usage   : $string = $qd->get_query_translation();
 Function: returns the translated query used for the search (if any)
 Returns : string
 Args    : none
 Notes   : only applicable for esearch.  This is the actual term used for
           esearch.

=cut

sub get_query_translation {
    my $self = shift;
    $self->parse_data unless $self->data_parsed;
    return $self->{'_querytranslation'};
}

=head2 get_corrected_query

 Title    : get_corrected_query
 Usage    : my $cor = $eutil->get_corrected_query;
 Function : retrieves the corrected query when using espell
 Returns  : string
 Args     : none
 Notes    : only applicable for espell.

=cut

sub get_corrected_query {
    my $self = shift;
    $self->parse_data unless $self->data_parsed;
    return ($self->{dom}->findnodes('//CorrectedQuery'))[0]->to_literal();
}

=head2 get_replaced_terms

 Title    : get_replaced_terms
 Usage    : my $term = $eutil->get_replaced_terms
 Function : returns array of strings replaced in the query
 Returns  : string
 Args     : none
 Notes    : only applicable for espell

=cut

sub get_replaced_terms {
    my $self = shift;
    $self->parse_data unless $self->data_parsed;
    my @terms = map {$_->to_literal()} $self->{dom}->findnodes('//SpelledQuery/Replaced');
    return @terms;
}

=head2 next_GlobalQuery

 Title    : next_GlobalQuery
 Usage    : while (my $query = $eutil->next_GlobalQuery) {...}
 Function : iterates through the queries returned from an egquery search
 Returns  : GlobalQuery object
 Args     : none
 Notes    : only applicable for egquery

=cut

sub next_GlobalQuery {
    my $self = shift;
    $self->parse_data unless $self->data_parsed;
    $self->{'_globalqueries_it'} = $self->generate_iterator('globalqueries')
        if (!exists $self->{'_globalqueries_it'});
    $self->{'_globalqueries_it'}->();
}

=head2 get_GlobalQueries

 Title    : get_GlobalQueries
 Usage    : @queries = $eutil->get_GlobalQueries
 Function : returns list of GlobalQuery objects
 Returns  : array of GlobalQuery objects
 Args     : none
 Notes    : only applicable for egquery

=cut

sub get_GlobalQueries {
    my $self = shift;
    $self->parse_data unless $self->data_parsed;
    ref $self->{'_globalqueries'} ? return @{ $self->{'_globalqueries'} } : return ();
}

=head2 print_GlobalQueries

 Title    : print_GlobalQueries
 Usage    : $docsum->print_GlobalQueries();
            $docsum->print_GlobalQueries(-fh => $fh, -callback => $coderef);
 Function : prints item data for all global queries.  The default printing
            method is each item per DocSum is printed with relevant values if
            present in a simple table using Text::Wrap.
 Returns  : none
 Args     : [optional]
           -file : file to print to
           -fh   : filehandle to print to (cannot be used concurrently with file)
           -cb   : coderef to use in place of default print method.  This is passed
                   in a GlobalQuery object;
           -wrap : number of columns to wrap default text output to (def = 80)
 Notes    : only applicable for esummary.  If -file or -fh are not defined,
            prints to STDOUT

=cut

sub print_GlobalQueries {
    my ($self, @args) = @_;
    $self->_print_handler(@args, -type => 'GlobalQuery');
}

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
    my $self = shift;
    my %data = (
        'DB'    => [1, join(', ',$self->get_databases) || ''],
        'Query' => [2, $self->get_term || ''],
        'IDs'   => [4, join(', ',$self->get_ids) || ''],
    );
    my $string = $self->SUPER::to_string;
    if ($self->eutil eq 'esearch') {
        $data{'Count'} = [3, $self->get_count ];
        $data{'Translation From'} = [5, $self->get_translation_from || ''];
        $data{'Translation To'} = [6, $self->get_translation_to || ''];
        $data{'RetStart'} = [7, $self->get_retstart];
        $data{'RetMax'} = [8, $self->get_retmax];
        $data{'Translation'} = [9, $self->get_query_translation || ''];
    }
    if ($self->eutil eq 'espell') {
        $data{'Corrected'} = [3, $self->get_corrected_query || ''];
        $data{'Replaced'} = [4, join(',',$self->get_replaced_terms) || ''];
    }
    for my $k (sort {$data{$a}->[0] <=> $data{$b}->[0]} keys %data) {
        $string .= sprintf("%-20s:%s\n",$k, $self->_text_wrap('',' 'x 20 .':', $data{$k}->[1]));
    }
    while (my $h = $self->next_History) {
        $string .= $h->to_string;
    }
    while (my $gq = $self->next_GlobalQuery) {
        $string .= $gq->to_string;
    }
    return $string;
}

1;
