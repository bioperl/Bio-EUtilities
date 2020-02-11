package Bio::Tools::EUtilities::Info::LinkInfo;

use utf8;
use strict;
use warnings;
use base qw(Bio::Root::Root Bio::Tools::EUtilities::EUtilDataI);

# ABSTRACT: Class for storing einfo link data.
# AUTHOR:   Chris Fields <cjfields@bioperl.org>
# OWNER:    2006-2013 Chris Fields
# LICENSE:  Perl_5

=head1 SYNOPSIS

    ## should not create instance directly; Bio::Tools::EUtilities does this ##

    # get a LinkInfo object using Bio:Tools::EUtilities
    print "Link name: ",$link->get_link_name,"\n";
    print "Link name: ",$link->get_link_menu_name,"\n";
    print "Link desc: ",$link->get_link_description,"\n";
    print "DBFrom: ",$link->get_dbfrom,"\n"; # database linked from
    print "DBTo: ",$link->get_dbto,"\n"; # database linked to

=head1 DESCRIPTION

This class handles data output (XML) from both einfo and elink, and centers on
describing data that either describes how NCBI databases are linked together
via link names, or how databases are linked to outside databases (LinkOut).

Further documentation for Link and Field subclass methods is included below.

For more information on einfo see:

   http://eutils.ncbi.nlm.nih.gov/entrez/query/static/einfo_help.html

=cut

=head2 new

 Title    : new
 Note     : *** should not be called by end-users ***
 Usage    : my $ct = Bio::Tools::EUtilities::Info::LinkInfo;
 Function : returns new LinkInfo instance
 Returns  : Bio::Tools::EUtilities::Info::LinkInfo instance
 Args     : none (all data added via _add_data, most methods are getters only)

=cut

sub new {
    my ($class, @args) = @_;
    my $self = $class->SUPER::new(@args);
    my $eutil = $self->_rearrange([qw(EUTIL)], @args);
    $eutil ||= 'einfo';
    $self->eutil($eutil);
    $self->datatype('linkinfo');
    return $self;
}

=head2 get_database

 Title    : get_database
 Usage    : my $db = $info->get_database;
 Function : returns single database name (eutil-compatible).  This is the
            queried database. For elinks (which have 'db' and 'dbfrom')
            this is equivalent to db/dbto (use get_dbfrom() to for the latter)
 Returns  : string
 Args     : none

=cut

sub get_database {
    my $self = shift;
    return ($self->_node->findnodes('./DbTo'))[0]->to_literal();
}

=head2 get_db (alias for get_database)

=cut

sub get_db {
    return shift->get_database;
}

=head2 get_dbto (alias for get_database)

=cut

sub get_dbto {
    return shift->get_database;
}

=head2 get_dbfrom

 Title    : get_dbfrom
 Usage    : my $origdb = $link->get_dbfrom;
 Function : returns referring database
 Returns  : string
 Args     : none
 Note     :

=cut

sub get_dbfrom {
    my $self = shift;
    return ($self->_node->findnodes('//DbInfo/DbName'))[0]->to_literal();
}

=head2 get_link_name

 Title    : get_link_name
 Usage    : $ln = $link->get_link_name;
 Function : returns raw link name (eutil-compatible)
 Returns  : string
 Args     : none

=cut

sub get_link_name {
    my $self = shift;
    if ($self->eutil eq 'elink') {
        return $self->{'_linkname'}
    } else {
        return ($self->_node->findnodes('./Name'))[0]->to_literal();
    }
}

=head2 get_link_description

 Title    : get_link_description
 Usage    : $desc = $link->get_link_description;
 Function : returns the (more detailed) link description
 Returns  : string
 Args     : none

=cut

sub get_link_description {
    my $self = shift;
    return ($self->_node->findnodes('./Description'))[0]->to_literal();
}

=head2 get_link_menu_name

 Title    : get_link_menu_name
 Usage    : my $mn = $link->get_link_menu_name;
 Function : returns formal menu name
 Returns  : string
 Args     : none

=cut

sub get_link_menu_name {
    my $self = shift;
    if ($self->eutil eq 'elink') {
        return $self->{'_menutag'};
    } else {
        return ($self->_node->findnodes('./MenuName'))[0]->to_literal();
    }    
}

=head2 get_priority

 Title    : get_priority
 Usage    : my $mn = $link->get_priority;
 Function : returns priority ranking
 Returns  : integer
 Args     : none
 Note     : only set when using elink and cmd set to 'acheck'

=cut

sub get_priority { return shift->{'_priority'} }

=head2 get_html_tag

 Title    : get_html_tag
 Usage    : my $tag = $link->get_html_tag;
 Function : returns HTML tag
 Returns  : string
 Args     : none
 Note     : only set when using elink and cmd set to 'acheck'

=cut

sub get_html_tag { return shift->{'_htmltag'} }

=head2 get_url

 Title    : get_url
 Usage    : my $url = $link->get_url;
 Function : returns URL string; note that the string isn't usable directly but
            has the ID replaced with the tag <@UID@>
 Returns  : string
 Args     : none
 Note     : only set when using elink and cmd set to 'acheck'

=cut

sub get_url { return shift->{'_url'} }

# private method

sub _add_data {
    my ($self, $el) = @_;
    $self->{_node} =$el;
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
    my $level = shift || 0;
    my $pad = 20 - $level;
    #        order     method                    name
    my %tags = (1 => ['get_link_name'         => 'Link Name'],
                2 => ['get_link_description'  => 'Description'],
                3 => ['get_dbfrom'            => 'DB From'],
                4 => ['get_dbto'              => 'DB To'],
                5 => ['get_link_menu_name'    => 'Menu Name'],
                6 => ['get_priority'          => 'Priority'],
                7 => ['get_html_tag'          => 'HTML Tag'],
                8 => ['get_url'               => 'URL'],
                );
    my $string = '';
    for my $tag (sort {$a <=> $b} keys %tags) {
        my ($m, $nm) = ($tags{$tag}->[0], $tags{$tag}->[1]);
        my $content = $self->$m();
        next unless $content;
        $string .= sprintf("%-*s%-*s%s\n",
            $level, '',
            $pad, $nm,
            $self->_text_wrap(':',
                 ' ' x ($pad).':',
                 $content ));
    }
    return $string;
}

1;
