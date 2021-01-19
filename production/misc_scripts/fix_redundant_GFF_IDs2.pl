#!/bin/env perl
use strict;
use warnings;

# script to fix GFF files like the one below so that load GFF3 works
# by Bruno Contreras Moreira EMBL-EBI 2021

die "# usage: $0 <GFF file> <prefix to find features to leave as is>\n" if(!$ARGV[0]);

my ($feat_type);

# check ID=names in GFF3 file to warn about gene:, mRNA:,... tags, which otherwise are added as stable_ids to db
#chr1    Liftoff gene    34660   40208   .       +       .       ID=gene:Zm00001d027230;biotype=protein_coding;description=Mitochondrial transcription termination factor family protein;gene_id=Zm00001d027230;logic_name=maker_gene;coverage=1.0;sequence_ID=1.0;extra_copy_number=0;copy_num_ID=gene:Zm00001d027230_0
#chr1    Liftoff mRNA    34660   40208   .       +       .       ID=transcript:Zm00001d027230_T001;Parent=gene:Zm00001d027230;biotype=protein_coding;transcript_id=Zm00001d027230_T001;extra_copy_number=0
#chr1    Liftoff exon    34660   35318   .       +       .       Parent=transcript:Zm00001d027230_T001;Name=Zm00001d027230_T001.exon1;constitutive=1;ensembl_end_phase=0;ensembl_phase=-1;exon_id=Zm00001d027230_T001.exon1;rank=1;extra_copy_number=0
#chr1    Liftoff CDS     34722   35318   .       +       .       ID=CDS:Zm00001d027230_P001;Parent=transcript:Zm00001d027230_T001;protein_id=Zm00001d027230_P001;extra_copy_number=0


open(GFF,'<',$ARGV[0]) || die "# ERROR: cannot read $ARGV[0]\n";
while(<GFF>){
	next if(/^#/);
	my @gffdata = split(/\t/,$_);

	if($gffdata[8] && 
		($gffdata[8] =~ m/ID=\w+:/ || $gffdata[8] =~ m/Parent=\w+:/)){ 

	# leave some features as is if requted
	if($ARGV[1] and $gffdata[8] =~ /$ARGV[1]/){
		print;
		next;
	}

		$feat_type = $gffdata[2];

		if($feat_type eq 'gene'){
			$gffdata[8] =~ s/gene://;					
		}
		elsif($feat_type eq 'mRNA' || $feat_type eq 'transcript'){
			$gffdata[8] =~ s/ID=mRNA:/ID=/;                              
			$gffdata[8] =~ s/ID=transcript:/ID=/;
			$gffdata[8] =~ s/Parent=gene:/Parent=/;
		}
		elsif($feat_type eq 'exon'){		
			$gffdata[8] =~ s/exon_id=/ID=/;
			$gffdata[8] =~ s/Parent=mRNA:/Parent=/;
			$gffdata[8] =~ s/Parent=transcript:/Parent=/;
		}
		elsif($feat_type eq 'CDS'){
            $gffdata[8] =~ s/Parent=mRNA:/Parent=/;
			$gffdata[8] =~ s/Parent=transcript:/Parent=/;
		}
	}

	print join("\t",@gffdata);
}
close(GFF);

