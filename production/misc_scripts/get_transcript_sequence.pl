#!/usr/bin/env perl
use strict;
use warnings;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::DBSQL::DBAdaptor;
use feature qw /say/;

# Retrieves FASTA cDNA sequences of all protein-coding transcripts.
# Alternatively, if a stable_id is passed to select transcript, 
# CDS, exon and peptide sequences are also produced

if(!$ARGV[1]){
	die "# usage: $0 <registry> <species> [transcript stable_id]\n";
}

my ($regfile,$species,$stable_id) = @ARGV;

# Load the registry
my $registry = 'Bio::EnsEMBL::Registry';
$registry->load_all($regfile);
    
my $t_adaptor = $registry->get_adaptor($species, "core", "Transcript");

# get all protein-coding (default) or selected transcript stable_id
my @transcripts;

if($stable_id){
	my $transcript = $t_adaptor->fetch_by_stable_id($stable_id);
	push(@transcripts, $transcript);
} else{
	@transcripts = @{ $t_adaptor->fetch_all_by_biotype('protein_coding') };
}

foreach my $transcript (@transcripts) {

	printf(">%s cDNA\n%s\n",$transcript->stable_id(),$transcript->spliced_seq());

	if($stable_id) {

		printf(">%s CDS\n%s\n",$transcript->stable_id(),$transcript->translateable_seq());
	
		foreach my $exon ( @{ $transcript->get_all_Exons() } ) {
			print  ">exon: ", $exon->start(), " ", $exon->end(), "\n";
		}

		printf(">%s pep\n%s\n",$transcript->stable_id(),$transcript->translate()->seq());
	}
}
