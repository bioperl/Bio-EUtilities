package Bio::EUtilities;

use strict;
use warnings;

1;

# ABSTRACT: BioPerl low-level API for retrieving and storing data from NCBI eUtils
# AUTHOR:   Chris Fields <cjfields@bioperl.org>
# OWNER:    Chris Fields
# LICENSE:  Perl_5

=head1 SYNOPSIS

See L<Bio::DB::EUtilities> for example usage with NCBI.

=head1 DESCRIPTION

This distribution encompasses a low-level API for interacting with (and storing)
information from) NCBI's eUtils interface.  See L<Bio::DB::EUtilities> for the
query API to retrieve data from NCBI, and L<Bio::Tools::EUtilities> for the general
class storage system. Note this may change to utilize the XML schema for each class at
some point, though we will attempt to retain current functionality for backward
compatibility unless this becomes problematic.

=cut

__END__
