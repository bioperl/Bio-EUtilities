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

=head1 Base Bio::Tools::EUtilies methods

=head2 parse_data

 Title    : parse_data
 Usage    : $parser->parse_data
 Function : direct call to parse data; normally implicitly called
 Returns  : none
 Args     : none

=cut

{

my %EUTIL_DATA = (
    'egquery'   => [],
    'espell'    => [qw(Original Replaced)],
    'esearch'   => [qw(Id ErrorList WarningList)],
    );

sub parse_data {
    my $self = shift;
    # TODO: subclass the other utils, remove lots of if/elsif cruft
    return if $self->data_parsed();
    my $eutil = $self->eutil();
    my $xp = XML::LibXML->new();
    my $dom = $self->response  ? $xp->load_xml(string => $self->response->content) :
                   $self->_fh  ? $xp->load_xml(IO => $self->_fh)      :
        $self->throw('No response or stream specified');
    
    # Cache DOM
    $self->{dom} = $dom;
    $self->{'_parsed'} = 1;
    
    
    # TODO: error handling
    ## The ERROR element is #PCDATA only, so it can only have one text
    ## element.  However, it can still have zero text elements in
    ## which case it will be a reference to an empty hash.
    #if (defined $dom->{ERROR} && ! ref($dom->{ERROR})) {
    #    ## Some errors may not be fatal but there doesn't seem to be a
    #    ## way for us to know.  So we warn.
    #    self->warn("NCBI $eutil error: " . $dom->{ERROR});
    #}
    #if ($dom->{InvalidIdList}) {
    #    $self->warn("NCBI $eutil error: Invalid ID List".$simple->{InvalidIdList});
    #    return;
    #}
    #if ($simple->{ErrorList} || $simple->{WarningList}) {
    #    my @errorlist = @{ $simple->{ErrorList} } if $simple->{ErrorList};
    #    my @warninglist = @{ $simple->{WarningList} } if $simple->{WarningList};
    #    my ($err_warn);
    #    for my $error (@errorlist) {
    #        my $messages = join("\n\t",map {"$_  [".$error->{$_}.']'}
    #                            grep {!ref $error->{$_}} keys %$error);
    #        $err_warn .= "Error : $messages";
    #    }
    #    for my $warn (@warninglist) {
    #        my $messages = join("\n\t",map {"$_  [".$warn->{$_}.']'}
    #                            grep {!ref $warn->{$_}} keys %$warn);
    #        $err_warn .= "Warnings : $messages";
    #    }
    #    chomp($err_warn);
    #    $self->warn("NCBI $eutil Errors/Warnings:\n".$err_warn)
    #    # don't return as some data may still be useful
    #}
    #delete $self->{'_response'} unless $self->cache_response;

    # History
    my $hist;
    if ($dom->exists( '//WebEnv' )) {
        my $cookie = Bio::Tools::EUtilities::History->new(-eutil => $eutil,
                            -verbose => $self->verbose);
        $cookie->_add_data($dom);
        push @{$self->{'_histories'}}, $cookie;
    }
    
    # GlobalQuery; we pass in the DOM elements
    if ($eutil eq 'egquery') {
        my %global_args;
        my $term = $self->get_term();
        #if (!$term and $self->parameter_base) {
        #    $term = $self->parameter_base->term();
        #}
        $global_args{'-term'} = $term if $term;
        for my $gquery ($dom->findnodes('//ResultItem')) {
            my $qd = Bio::Tools::EUtilities::Query::GlobalQuery->new(-eutil => 'egquery',
                                                        -datatype => 'globalquery',
                                                        -verbose => $self->verbose,
                                                        %global_args);
            $qd->_add_data($gquery);
            push @{ $self->{'_globalqueries'} }, $qd;
        }
    }    
    
    # TODO: remove lazy DOM parsing?  We store the DOM instance, not sure if this is really needed
}

}

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
    #print STDERR $self->{dom}->toString();
    my @ids = map {$_->to_literal()} $self->{dom}->findnodes('//IdList/Id');
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
    my @dbs;
    if ($eutil eq 'einfo' || $eutil eq 'espell') {
        return ($self->{dom}->findnodes('//Database'))[0]->to_literal();
    } elsif ($eutil eq 'egquery') {
        @dbs = map {$_->get_database} $self->get_GlobalQueries();
        #@dbs = map {$_->to_literal()} $self->{dom}->findnodes('//DbName');
    } elsif ( $eutil eq 'esearch') {
        # get the database from the passed parameter
        @dbs = $self->parameter_base() ? $self->parameter_base->db() : ();
    } else {
        # only unique dbs
        $self->throw("Unsupported eutil: $eutil")
    }
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
    my $eutil = $self->eutil();
    # egquery
    if ($self->eutil eq 'egquery') {
        if (!$db) {
            $self->warn('Must specify database to get count from');
            return;
        }
        my ($gq) = grep {$_->get_database eq $db} $self->get_GlobalQueries;
        $gq && return $gq->get_count;
        $self->warn("Unknown database $db");
        return;
    } elsif ($self->eutil eq 'esearch') {
        return ($self->{dom}->findnodes('//Count'))[0]->to_literal();
    } else {
        return
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
    my $eutil = $self->eutil;
    my $term;
    if ($eutil eq 'esearch') {
        $term = $self->parameter_base ? $self->parameter_base->term() : undef;
    } elsif ($eutil eq 'espell') {
        $term = ($self->{dom}->findnodes('//Query'))[0]->to_literal();
    } elsif ($eutil eq 'egquery') {
        $term = ($self->{dom}->findnodes('//Term'))[0]->to_literal();
        # Fallback if term is blank
        if (!$term) {
            $term = $self->parameter_base ? $self->parameter_base->term() : undef;
        }
    }
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
    my $eutil = $self->eutil;
    if ($eutil eq 'esearch') {
        return ($self->{dom}->findnodes('//Translation/From'))[0]->to_literal();
    }
    return;
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
    my $eutil = $self->eutil;
    if ($eutil eq 'esearch') {
        return ($self->{dom}->findnodes('//Translation/To'))[0]->to_literal();
    }
    return;
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
    my $eutil = $self->eutil;
    if ($eutil eq 'esearch') {
        return ($self->{dom}->findnodes('//RetStart'))[0]->to_literal();
    }
    return;
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
    my $eutil = $self->eutil;
    if ($eutil eq 'esearch')  {
        return ($self->{dom}->findnodes('//RetMax'))[0]->to_literal();
    }
    return;
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
    my $eutil = $self->eutil();
    if ($eutil eq 'esearch') {
        return ($self->{dom}->findnodes('//QueryTranslation'))[0]->to_literal();
    } else {
        return;
    }
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
    my $eutil = $self->eutil();
    if ($eutil eq 'espell') {
        return ($self->{dom}->findnodes('//CorrectedQuery'))[0]->to_literal();
    } else {
        return;
    }
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
    my $eutil = $self->eutil();
    if ($eutil eq 'espell') {
        my @terms = map {$_->to_literal()} $self->{dom}->findnodes('//SpelledQuery/Replaced');
        return @terms;
    }
    return;
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
