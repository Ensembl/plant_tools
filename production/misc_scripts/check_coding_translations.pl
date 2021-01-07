#!/usr/bin/env perl

use strict;
use warnings;
use Bio::EnsEMBL::Registry;
use Bio::SeqIO;

# Dumps FASTA peptide sequences of canonical transcripts of genes
# two optional args:
# iii) type of schema, typically: core|otherfeatures
# iv) logic_name of analysis to be selected

my ($reg_conf, $species);
my $schema_type = 'core';
my $logic_name = 'all';

if(!$ARGV[1]){ die "# usage: $0 <reg_file> <species_name> [core|otherfeatures] [logic_name]\n" }
else{
	$reg_conf= $ARGV[0];
	$species = $ARGV[1];
}

if($ARGV[2]){
	$schema_type = $ARGV[2];
}
if($ARGV[3]){
	$logic_name = $ARGV[3];
}

print "# $0 $reg_conf $species $schema_type $logic_name\n\n";

#################################

my $registry = 'Bio::EnsEMBL::Registry';
$registry->load_all($reg_conf);

my $ga = $registry->get_adaptor( $species, $schema_type, "gene");

my $genes = $ga->fetch_all_by_biotype('protein_coding'); 

my ($n_of_coding_genes, $gene, $tr) = (0);
foreach $gene (@$genes) {
	
	# check logic_name if required
	if($logic_name ne 'all'){
		next if($gene->analysis()->logic_name() ne $logic_name);
	}

	$tr = $gene->canonical_transcript();
	next if(!defined($tr->translate()));
	
	printf(">%s %s %s\n%s\n", 
		$gene->stable_id(),
		$tr->stable_id(),
		$gene->analysis()->logic_name(),
		$tr->translate()->seq() );

	$n_of_coding_genes++;
}

