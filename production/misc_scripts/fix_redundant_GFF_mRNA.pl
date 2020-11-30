#!/bin/env perl
use strict;
use warnings;

# script to fix GFF files like the one below so that load GFF3 works
# by Bruno Contreras Moreira EMBL-EBI 2020

die "# usage: $0 <GFF file>\n" if(!$ARGV[0]);

my ($feat_type);

#1  EVM     gene    15553   18345   .       +       .       ID=RHC01H1G0002.2;Name=RHC01H1G0002.2;
#1  EVM     mRNA    15553   18345   .       +       .       ID=RHC01H1G0002.2;Parent=RHC01H1G0002.2;
#1  EVM     exon    15553   15909   .       +       .       ID=RHC01H1G0002.2.exon;Parent=RHC01H1G0002.2;
#1  EVM     CDS     15553   15909   .       +       0       ID=RHC01H1G0002.2.cds;Parent=RHC01H1G0002.2;
#1  EVM     exon    16471   16674   .       +       .       ID=RHC01H1G0002.2.exon;Parent=RHC01H1G0002.2;
#1  EVM     CDS     16471   16674   .       +       0       ID=RHC01H1G0002.2.cds;Parent=RHC01H1G0002.2;

my ($ID,$mrnaID,$exonID,$cdsID,%isoform) = ('','','','');

open(GFF,'<',$ARGV[0]) || die "# ERROR: cannot read $ARGV[0]\n";
while(<GFF>){

	if(/^#/){
		print;
		next;
	}

	my @gffdata = split(/\t/,$_);

	if($gffdata[8]){ 
		
		$feat_type = $gffdata[2];	

		if($feat_type eq 'gene'){
			$ID = ''; # init
			if($gffdata[8] =~ m/ID=([^;]+)/){ $ID = $1 }					
		}
		elsif($feat_type eq 'mRNA'){
			$isoform{ $ID }++;
            $mrnaID = $ID .'.'. $isoform{ $ID };
			$gffdata[8] =~ s/ID=[^;]+/ID=$mrnaID/; 
		}
		elsif($feat_type eq 'exon'){
			$exonID = $mrnaID.'.exon';
			$isoform{ $exonID }++;
			$exonID .= '.'. $isoform{ $exonID }; 
			$gffdata[8] =~ s/ID=[^;]+/ID=$exonID/;
			$gffdata[8] =~ s/Parent=[^;\n]+/Parent=$mrnaID/;
    	}
		elsif($feat_type eq 'CDS'){
			$cdsID = $mrnaID.'.cds';
			$isoform{ $cdsID }++;
			$cdsID .= '.'. $isoform{ $cdsID };
			$gffdata[8] =~ s/ID=[^;]+/ID=$cdsID/;
			$gffdata[8] =~ s/Parent=[^;]\n+/Parent=$mrnaID/;
		}
	}

	print join("\t",@gffdata);
}
close(GFF);


