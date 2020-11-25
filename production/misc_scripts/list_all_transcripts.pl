#!/usr/bin/env perl
use strict;
use warnings;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::DBSQL::DBAdaptor;
use feature qw /say/;

if(!$ARGV[1]){
	die "# usage: $0 <registry> <species>\n";
}

my ($regfile,$species) = @ARGV;

# Load the registry
my $registry = 'Bio::EnsEMBL::Registry';
$registry->load_all($regfile);
    
# fetch a gene by its stable identifier
my $sa = $registry->get_adaptor($species, "core", "Slice");

for my $slice (@{ $sa->fetch_all('toplevel', undef, 1, undef, undef) }) {
	for my $gene (@{ $slice->get_all_Genes(undef, undef, 1) }) {
		for my $transcript (@{ $gene->get_all_Transcripts }) {
			if (my $translation = $transcript->translation) {
				print $transcript->stable_id()."\n";
			}
		}
	}
}
