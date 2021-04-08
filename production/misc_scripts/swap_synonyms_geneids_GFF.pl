#!/bin/env perl
use strict;
use warnings;

# script to fix GFF files like the one below so that gene_synonym is used instead of ID;
# gene_synonyms are then used to identify mRNA, exons and CDS features as well
# by Bruno Contreras Moreira EMBL-EBI 2021

die "# usage: $0 <GFF file>\n" if(!$ARGV[0]);

my ($feat_type,$ID,$synonymID,$mrnaID,$exonID,$cdsID);
my (%isoform, %cds, %exon);

#CM029878.1      Genbank gene    8400    9512    .       +       .       ID=gene-IGI04_039135;Name=IGI04_039135;Note=MBGP_ID A10p000010%3B Protein of unknown function;gbkey=Gene;gene_biotype=protein_coding;gene_synonym=A10p000010.1_BraROA;locus_tag=IGI04_039135
#CM029878.1      Genbank mRNA    8539    9399    .       +       .       ID=rna-gnl|WGS:JADBGQ|mrna.IGI04_039135;Parent=gene-IGI04_039135;gbkey=mRNA;locus_tag=IGI04_039135;orig_protein_id=gnl|WGS:JADBGQ|IGI04_039135;orig_transcript_id=gnl|WGS:JADBGQ|mrna.IGI04_039135;product=hypothetical protein
#CM029878.1      Genbank exon    8539    8617    .       +       .       ID=exon-gnl|WGS:JADBGQ|mrna.IGI04_039135-1;Parent=rna-gnl|WGS:JADBGQ|mrna.IGI04_039135;gbkey=mRNA;locus_tag=IGI04_039135;orig_protein_id=gnl|WGS:JADBGQ|IGI04_039135;orig_transcript_id=gnl|WGS:JADBGQ|mrna.IGI04_039135;product=hypothetical protein
#CM029878.1      Genbank exon    8810    9399    .       +       .       ID=exon-gnl|WGS:JADBGQ|mrna.IGI04_039135-2;Parent=rna-gnl|WGS:JADBGQ|mrna.IGI04_039135;gbkey=mRNA;locus_tag=IGI04_039135;orig_protein_id=gnl|WGS:JADBGQ|IGI04_039135;orig_transcript_id=gnl|WGS:JADBGQ|mrna.IGI04_039135;product=hypothetical protein
#CM029878.1      Genbank CDS     8539    8617    .       +       0       ID=cds-KAG5374539.1;Parent=rna-gnl|WGS:JADBGQ|mrna.IGI04_039135;Dbxref=NCBI_GP:KAG5374539.1;Name=KAG5374539.1;gbkey=CDS;locus_tag=IGI04_039135;orig_transcript_id=gnl|WGS:JADBGQ|mrna.IGI04_039135;product=hypothetical protein;protein_id=KAG5374539.1
#CM029878.1      Genbank CDS     8810    9399    .       +       2       ID=cds-KAG5374539.1;Parent=rna-gnl|WGS:JADBGQ|mrna.IGI04_039135;Dbxref=NCBI_GP:KAG5374539.1;Name=KAG5374539.1;gbkey=CDS;locus_tag=IGI04_039135;orig_transcript_id=gnl|WGS:JADBGQ|mrna.IGI04_039135;product=hypothetical protein;protein_id=KAG5374539.1

open(GFF,'<',$ARGV[0]) || die "# ERROR: cannot read $ARGV[0]\n";
while(<GFF>){

	next if(/^#/);
	my @gffdata = split(/\t/,$_);

	if(defined($gffdata[8])){ 
			
		$feat_type = $gffdata[2];	
		
		if($feat_type eq 'gene'){

			$ID = ''; # init
			if($gffdata[8] =~ m/^ID=([^;]+)/){ $ID = $1 }			

			if($gffdata[8] =~ m/gene_synonym=([^;]+)/){
				$synonymID = $1;
				$gffdata[8] =~ s/^ID=[^;]+/ID=$synonymID/;
				$gffdata[8] =~ s/gene_synonym=[^;]+/gene_synonym=$ID/;
			}
		}
		elsif($feat_type eq 'mRNA'){
			$isoform{ $synonymID }++;
			$mrnaID = $synonymID .'.'. $isoform{ $synonymID }; 
			$gffdata[8] =~ s/^ID=[^;]+/ID=$mrnaID/; 
			$gffdata[8] =~ s/Parent=[^;]+/Parent=$synonymID/;
		}
		elsif($feat_type eq 'exon'){		
			$exon{ $mrnaID }++;
			$exonID	= $mrnaID .'.exon'. $exon{ $mrnaID };
			$gffdata[8] =~ s/^ID=[^;]+/ID=$exonID/;
            $gffdata[8] =~ s/Parent=[^;]+/Parent=$mrnaID/;
		}
		elsif($feat_type eq 'CDS'){
			$cds{ $mrnaID }++;
			$cdsID = $mrnaID .'.cds'. $cds{ $mrnaID };
			$gffdata[8] =~ s/^ID=[^;]+/ID=$cdsID/;
			$gffdata[8] =~ s/Parent=[^;]+/Parent=$mrnaID/;
		}
	}

	print join("\t",@gffdata);
}
close(GFF);

