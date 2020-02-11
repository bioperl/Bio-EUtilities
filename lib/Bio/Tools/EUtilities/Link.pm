package Bio::Tools::EUtilities::Link;

use utf8;
use strict;
use warnings;
use base qw(Bio::Tools::EUtilities Bio::Tools::EUtilities::EUtilDataI);
use Bio::Tools::EUtilities::Link::LinkSet;

# ABSTRACT: General API for accessing data retrieved from elink queries.
# AUTHOR:   Chris Fields <cjfields@bioperl.org>
# OWNER:    2006-2013 Chris Fields
# LICENSE:  Perl_5

=head1 SYNOPSIS

  ...TODO

=head1 DESCRIPTION

Bio::Tools::EUtilities::Link is a loadable plugin for Bio::Tools::EUtilities
that specifically handles NCBI elink-related data.

=cut

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
    my @ids = map {$_->to_literal()} $self->_node->findnodes('//IdUrlSet/Id');
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
    $self->parse_data() unless $self->data_parsed();
    my $eutil = $self->eutil();
    my @dbs = map {$_->to_literal()} $self->_node->findnodes('//DbName');
    return @dbs ;
}

# private EUtilDataI method

{
    # my %SUBCLASS = (
    #                 'LinkSetDb' => 'dblink',
    #                 'LinkSetDbHistory' => 'history',
    #                 'IdUrlSet' => 'urllink',
    #                 'IdCheckList' => 'idcheck',
    #                 'NoLinks' => 'nolinks',
    #                 );

sub parse_data {
    my $self = shift;
    # TODO: subclass the other utils, remove lots of if/elsif cruft
    # TDOD: move partial implementation (common code) into parent class
    return if $self->data_parsed();
    my $eutil = $self->eutil();
    my $xp = XML::LibXML->new();
    my $dom = $self->response  ? $xp->load_xml(string => $self->response->content) :
                   $self->_fh  ? $xp->load_xml(IO => $self->_fh)      :
        $self->throw('No response or stream specified');
    
    # Cache DOM
    $self->{_node} = $dom;
    $self->{'_parsed'} = 1;
    
    # divide up per linkset
    #if (!exists $data->{LinkSet}) {
    #    $self->warn("No linksets returned");
    #    return;
    #}
    if ($dom->exists('/eLinkResult/LinkSet')) {
        # kind of LinkSet do we have?
        
        for my $el ($dom->findnodes('/eLinkResult/LinkSet')) {
            
#            print STDERR "Names: ".join(',', map {$_->nodeName} @childnodes)."\n";
            my $subclass;
            # attempt to catch linkset errors
            #if (exists $ls->{ERROR}) {
            #    my ($error, $dbfrom) = ($ls->{ERROR},$ls->{DbFrom});
            #    $self->warn("NCBI LinkSet error: $dbfrom: $error\n");
            #    # try to save the rest of the data, if any
            #    next;
            #}
            # caching for efficiency; no need to recheck
            if (!exists $self->{'_subclass_type'}) {
                ($subclass) = grep { $el->exists(".//$_") } qw(LinkSetDb LinkSetDbHistory IdUrlSet IdCheckList);
                $subclass ||= 'NoLinks';
                $self->{'_subclass_type'} = $subclass;
            } else {
                $subclass = $self->{'_subclass_type'};
            }
            # split these up by ID, since using correspondence() clobbers them...
            if ($subclass eq 'IdUrlList' || $subclass eq 'IdCheckList') {
                #my $list = $subclass eq 'IdUrlList' ? 'IdUrlSet' :
                #    $subclass eq 'IdCheckList' && exists $ls->{$subclass}->{IdLinkSet} ? 'IdLinkSet' :
                #    'Id';
                #$ls->{$subclass} = $ls->{$subclass}->{$list};
            }
            # divide up linkset per link
            #print STDERR "XPath:.//$subclass\n";
            for my $ls_sub ($el->findnodes(".//$subclass")) {
                #for my $key (qw(WebEnv DbFrom IdList)) {
                #    $ls_sub->{$key} = $ls->{$key} if exists $ls->{$key};
                #}
                my $obj = Bio::Tools::EUtilities::Link::LinkSet->new(-eutil => 'elink',
                                                        -datatype => $subclass,
                                                        -verbose => $self->verbose);
                $obj->_add_data($ls_sub);
                push @{$self->{'_linksets'}}, $obj;
                # push only potential history-carrying objects into history queue
                if ($subclass eq 'LinkSetDbHistory') {
                    push @{$self->{'_histories'}}, $obj;
                }
            }
        }
    }
}

}

=head2 to_string

 Title    : to_string
 Usage    : $foo->to_string()
 Function : converts current object to string
 Returns  : none
 Args     : (optional) simple data for text formatting
 Note     : Used generally for debugging and for various print methods

=cut

sub to_string {
    my $self = shift;
    my $string = $self->SUPER::to_string;
    while (my $ls = $self->next_LinkSet) {
        $string .= $ls->to_string;
    }
    return $string;
}

1;
