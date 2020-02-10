package Bio::Tools::EUtilities::Info;

use utf8;
use strict;
use warnings;
use base qw(Bio::Tools::EUtilities Bio::Tools::EUtilities::EUtilDataI);
use Bio::Tools::EUtilities::Info::LinkInfo;
use Bio::Tools::EUtilities::Info::FieldInfo;

# ABSTRACT: Interface class for storing einfo data.
# AUTHOR:   Chris Fields <cjfields@bioperl.org>
# OWNER:    2006-2013 Chris Fields
# LICENSE:  Perl_5

=head1 SYNOPSIS

  #### should not create instance directly; Bio::Tools::EUtilities does this ####

  my $info = Bio::Tools::EUtilities->new(-eutil => 'einfo',
                                         -file => 'einfo.xml');
  # can also use '-response' (for HTTP::Response objects) or '-fh' (for filehandles)

  # print available databases (if data is present)

  print join(', ',$info->get_available_databases),"\n";

  # get database info

  my $db = $info->get_database; # in case you forgot...
  my $desc = $info->get_description;
  my $nm = $info->get_menu_name;
  my $ct = $info->get_record_count;
  my $dt = $info->get_last_update;

  # EUtilDataI interface methods

  my $eutil = $info->eutil;
  my $type = $info->datatype;

  # iterate through Field and Link objects

  while (my $field = $info->next_Field) {
      print "Field code: ",$field->get_field_code,"\n";
      print "Field name: ",$field->get_field_name,"\n";
      print "Field desc: ",$field->get_field_description,"\n";
      print "DB  : ",$field->get_database,"\n";
      print "Term ct   : ",$field->get_term_count,"\n";
      for my $att (qw(is_date is_singletoken is_hierarchy is_hidden is_numerical)) {
          print "\tField $att\n" if $field->$att;
      }
  }

  my @fields = $info->get_Fields; # grab them all (useful for grep)

  while (my $link = $info->next_LinkInfo) {
      print "Link name: ",$link->get_link_name,"\n";
      print "Link desc: ",$link->get_link_description,"\n";
      print "DBFrom: ",$link->get_dbfrom,"\n"; # same as get_database()
      print "DBTo: ",$link->get_dbto,"\n"; # database linked to
  }

  my @links = $info->get_LinkInfo; # grab them all (useful for grep)

  $info->rewind(); # rewinds all iterators
  $info->rewind('links'); # rewinds Link iterator
  $info->rewind('fields'); # rewinds Field iterator

=head1 DESCRIPTION

This class handles data output (XML) from einfo.

Einfo is capable of returning two types of information:

=over 3

=item * A list of all available databases (when called w/o parameters)

=item * Information about a specific database.

=back

The latter information includes the database description, record count, and
date/time stamp for the last update, among other things. It also includes a list
of fields (indices by which record data is stored which can be used in queries)
and links (crossrefs between related records in other databases at NCBI). Data
from the latter two are stored in two small subclasses (FieldInfo and LinkInfo)
which can be iterated through or retrieved all at once, as demonstrated above.
NOTE: Methods described for the LinkInfo and FieldInfo subclasses are unique to
those classes (as they retrieve data unique to those data types).

Further documentation for Link and Field subclass methods is included below.

For more information on einfo see:

   http://eutils.ncbi.nlm.nih.gov/entrez/query/static/einfo_help.html

=cut

=head2 rewind

 Title    : rewind
 Usage    : $info->rewind() # rewinds all (default)
            $info->rewind('links') # rewinds only links
 Function : 'rewinds' (resets) specified iterators (all if no arg)
 Returns  : none
 Args     : [OPTIONAL] String:
            'all'    - all iterators (default)
            'linkinfo'  - LinkInfo objects only
            'fieldinfo' - FieldInfo objects only

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
    $self->parse_data() unless $self->data_parsed();
    if (!$self->{dom}) {
        $self->throw("No XML document object found!")
    }
    my $eutil = $self->eutil();
    my @dbs = map {$_->to_literal()} $self->{dom}->findnodes('//DbName');
    return @dbs ;
}

=head1 Base Bio::Tools::EUtilies methods

=head2 parse_data

 Title    : parse_data
 Usage    : $parser->parse_data
 Function : direct call to parse data; normally implicitly called
 Returns  : none
 Args     : none

=cut

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

    if ($dom->exists( '/eInfoResult/DbInfo/FieldList' )) {
        for my $el ($dom->findnodes('/eInfoResult/DbInfo/FieldList/Field')) {
            #if (exists $simple->{DbInfo}->{DbName}) {
            #    $chunk->{DbFrom} = $simple->{DbInfo}->{DbName};
            #}
            my $obj = "Bio::Tools::EUtilities::Info::FieldInfo"->new(
                                   -eutil => 'einfo',
                                   -type => 'FieldInfo',
                                   -verbose => $self->verbose);
            $obj->_add_data($el);
            push @{ $self->{'_fieldinfo'} }, $obj;
        }
    }
    
    if ($dom->exists( '/eInfoResult/DbInfo/LinkList' )) {
        for my $el ($dom->findnodes('/eInfoResult/DbInfo/LinkList/Link')) {
            #if (exists $simple->{DbInfo}->{DbName}) {
            #    $chunk->{DbFrom} = $simple->{DbInfo}->{DbName};
            #}
            my $obj = "Bio::Tools::EUtilities::Info::LinkInfo"->new(
                                   -eutil => 'einfo',
                                   -type => 'LinkInfo',
                                   -verbose => $self->verbose);
            $obj->_add_data($el);
            push @{ $self->{'_linkinfo'} }, $obj;
        }
    }    
}

# private EUtilDataI method

#sub _add_data {
#    my ($self, $simple) = @_;
#    if (exists $simple->{DbList} &&
#        exists $simple->{DbList}->{DbName}) {
#        $self->{'_available_databases'} = $simple->{DbList}->{DbName};
#    }
#    # start setting internal variables
#    if (exists $simple->{DbInfo}) {
#        for my $key (sort keys %{ $simple->{DbInfo} }) {
#            my $data =
#            ($key eq 'FieldList') ? $simple->{DbInfo}->{$key}->{Field} :
#            ($key eq 'LinkList' ) ? $simple->{DbInfo}->{$key}->{Link}  :
#            $simple->{DbInfo}->{$key};
#            if ($key eq 'FieldList' || $key eq 'LinkList') {
#                for my $chunk (@{$data}) {
#                    if (exists $simple->{DbInfo}->{DbName}) {
#                        $chunk->{DbFrom} = $simple->{DbInfo}->{DbName};
#                    }
#                    my $type = ($key eq 'FieldList') ? 'FieldInfo' : 'LinkInfo';
#                    my $obj = "Bio::Tools::EUtilities::Info::$type"->new(
#                                           -eutil => 'einfo',
#                                           -type => lc $type,
#                                        -verbose => $self->verbose);
#                    $obj->_add_data($chunk);
#                    push @{ $self->{'_'.lc $type} }, $obj;
#                }
#            } else {
#                $self->{'_'.lc $key} = $data;
#            }
#        }
#    } else {
#        map { $self->{'_'.lc $_} = $simple->{$_} unless ref $simple->{$_}} keys %$simple;
#    }
#}
#
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
    if (my @dbs = $self->get_databases) {
        $string .= sprintf("%-20s:%s\n\n", 'DB',
            $self->_text_wrap('', ' 'x20 .':', join(', ',@dbs)));
    }
    while (my $fi = $self->next_FieldInfo) {
        $string .= $fi->to_string."\n";
    }
    while (my $li = $self->next_LinkInfo) {
        $string .= $li->to_string."\n";
    }
    return $string;
}

=head1 Info-related methods

=head2 get_available_databases

 Title    : get_available_databases
 Usage    : my @dbs = $info->get_available_databases
 Function : returns list of available eutil-compatible database names
 Returns  : Array of strings
 Args     : none
 Notes    : only applicable for einfo.

=cut

sub get_available_databases {
    my $self = shift;
    $self->parse_data unless $self->data_parsed;
    ($self->{'_available_databases'}) ?
        return @{($self->{'_available_databases'})} :
        return ();
}

=head2 get_record_count

 Title    : get_record_count
 Usage    : my $ct = $eutil->get_record_count;
 Function : returns database record count
 Returns  : integer
 Args     : none
 Notes    : only applicable for einfo.

=cut

sub get_record_count {
    my $self = shift;
    $self->parse_data unless $self->data_parsed;
    my $ct;
    if ($self->{dom}->exists('/eInfoResult/DbInfo/Count')) {
        $ct = ($self->{dom}->findnodes('/eInfoResult/DbInfo/Count'))[0]->to_literal();
    }
    return $ct;
}

=head2 get_last_update

 Title    : get_last_update
 Usage    : my $time = $info->get_last_update;
 Function : returns string containing time/date stamp for last database update
 Returns  : integer
 Args     : none
 Notes    : only applicable for einfo.

=cut

sub get_last_update {
    my $self = shift;
    $self->parse_data unless $self->data_parsed;
    my $update;
    if ($self->{dom}->exists('/eInfoResult/DbInfo/LastUpdate')) {
        $update = ($self->{dom}->findnodes('/eInfoResult/DbInfo/LastUpdate'))[0]->to_literal();
    }
    return $update;
}

=head2 get_menu_name

 Title    : get_menu_name
 Usage    : my $nm = $info->get_menu_name;
 Function : returns string of database menu name
 Returns  : string
 Args     : none
 Notes    : only applicable for einfo.

=cut

sub get_menu_name {
    my $self = shift;
    $self->parse_data unless $self->data_parsed;
    my $menuname;
    if ($self->{dom}->exists('/eInfoResult/DbInfo/MenuName')) {
        $menuname = ($self->{dom}->findnodes('/eInfoResult/DbInfo/MenuName'))[0]->to_literal();
    }
    return $menuname;
}

=head2 get_description

 Title    : get_description
 Usage    : my $desc = $info->get_description;
 Function : returns database description
 Returns  : string
 Args     : none
 Notes    : only applicable for einfo.

=cut

sub get_description {
    my $self = shift;
    $self->parse_data unless $self->data_parsed;
    my $desc;
    if ($self->{dom}->exists('/eInfoResult/DbInfo/Description')) {
        return ($self->{dom}->findnodes('/eInfoResult/DbInfo/Description'))[0]->to_literal();
    }
    return $desc;
}

=head2 next_FieldInfo

 Title    : next_FieldInfo
 Usage    : while (my $field = $info->next_FieldInfo) {...}
 Function : iterate through FieldInfo objects
 Returns  : Field object
 Args     : none
 Notes    : only applicable for einfo. Uses callback() for filtering if defined
            for 'fields'

=cut

sub next_FieldInfo {
    my $self = shift;
    $self->parse_data unless $self->data_parsed;
    $self->{'_fieldinfo_it'} = $self->generate_iterator('fieldinfo')
        if (!exists $self->{'_fieldinfo_it'});
    $self->{'_fieldinfo_it'}->();
}

=head2 get_FieldInfo

 Title    : get_FieldInfo
 Usage    : my @fields = $info->get_FieldInfo;
 Function : returns list of FieldInfo objects
 Returns  : array (FieldInfo objects)
 Args     : none
 Notes    : only applicable for einfo.

=cut

sub get_FieldInfo {
    my $self = shift;
    $self->parse_data unless $self->data_parsed;
    return ref $self->{'_fieldinfo'} ? @{ $self->{'_fieldinfo'} } : return ();
}

*get_FieldInfos = \&get_FieldInfo;

=head2 next_LinkInfo

 Title    : next_LinkInfo
 Usage    : while (my $link = $info->next_LinkInfo) {...}
 Function : iterate through LinkInfo objects
 Returns  : LinkInfo object
 Args     : none
 Notes    : only applicable for einfo.  Uses callback() for filtering if defined
            for 'linkinfo'

=cut

sub next_LinkInfo {
    my $self = shift;
    $self->parse_data unless $self->data_parsed;
    $self->{'_linkinfo_it'} = $self->generate_iterator('linkinfo')
        if (!exists $self->{'_linkinfo_it'});
    $self->{'_linkinfo_it'}->();
}

=head2 get_LinkInfo

 Title    : get_LinkInfo
 Usage    : my @links = $info->get_LinkInfo;
 Function : returns list of LinkInfo objects
 Returns  : array (LinkInfo objects)
 Args     : none
 Notes    : only applicable for einfo.

=cut

sub get_LinkInfo {
    my $self = shift;
    $self->parse_data unless $self->data_parsed;
    return ref $self->{'_linkinfo'} ? @{ $self->{'_linkinfo'} } : return ();
}

*get_LinkInfos = \&get_LinkInfo;

=head2 print_FieldInfo

 Title    : print_FieldInfo
 Usage    : $info->print_FieldInfo();
            $info->print_FieldInfo(-fh => $fh, -cb => $coderef);
 Function : prints link data for each FieldInfo object. The default is generated
            via FieldInfo::to_string
 Returns  : none
 Args     : [optional]
           -file : file to print to
           -fh   : filehandle to print to (cannot be used concurrently with file)
           -cb   : coderef to use in place of default print method.  This is
                   passed in a FieldInfo object
           -wrap : number of columns to wrap default text output to (def = 80)
 Notes    : only applicable for einfo.  If -file or -fh are not defined,
            prints to STDOUT

=cut

sub print_FieldInfo {
    my ($self, @args) = @_;
    $self->_print_handler(@args, -type => 'FieldInfo');
}

=head2 print_LinkInfo

 Title    : print_LinkInfo
 Usage    : $info->print_LinkInfo();
            $info->print_LinkInfo(-fh => $fh, -cb => $coderef);
 Function : prints link data for each LinkInfo object. The default is generated
            via LinkInfo::to_string
 Returns  : none
 Args     : [optional]
           -file : file to print to
           -fh   : filehandle to print to (cannot be used concurrently with file)
           -cb   : coderef to use in place of default print method.  This is passed
                   in a LinkInfo object
           -wrap : number of columns to wrap default text output to (def = 80)
 Notes    : only applicable for einfo.  If -file or -fh are not defined,
            prints to STDOUT

=cut

sub print_LinkInfo {
    my ($self, @args) = @_;
    $self->_print_handler(@args, -type => 'LinkInfo');
}

1;
