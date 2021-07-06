#!/bin/env perl
use strict;
use warnings;

# script to fix GFF files like the one below so that load GFF3 works
# by Bruno Contreras Moreira EMBL-EBI 2020-1

die "# usage: $0 <GFF file>\n" if(!$ARGV[0]);

my ($feat_type);

#Tu1     IGDB_Final      gene    155428  159555  .       -       .       ID=TuG1812G0100000009.01;Name=TuG1812G0100000009.01;
#Tu1     IGDB_Final      mRNA    155428  159555  .       -       .       ID=TuG1812G0100000009.01.T01;Name=TuG1812G0100000009.01.T01;Parent=TuG1812G0100000009.01;
#Tu1     IGDB_Final      exon    159437  159555  .       -       .       ID=exon288580;Name=exon288580;Parent=TuG1812G0100000009.01.T01
#Tu1     IGDB_Final      exon    159289  159351  .       -       .       ID=exon288581;Name=exon288581;Parent=TuG1812G0100000009.01.T01
#...
#Tu1     IGDB_Final      exon    159437  159555  .       -       .       ID=exon288580;Name=exon288580;Parent=TuG1812G0100000009.01.T02
#Tu1     IGDB_Final      exon    159289  159351  .       -       .       ID=exon288581;Name=exon288581;Parent=TuG1812G0100000009.01.T02

my $count_cds = 0;
my $baseID;
open(GFF,'<',$ARGV[0]) || die "# ERROR: cannot read $ARGV[0]\n";
while(<GFF>){
	next if(/^#/);
	my @gffdata = split(/\t/,$_);

	if($gffdata[8] && $gffdata[8] =~ m/ID=/ || $gffdata[8] =~ m/Parent=/){ 
			
		$feat_type = $gffdata[2];	

		if($feat_type eq 'mRNA' || $feat_type eq 'transcript'){
            if($gffdata[8] =~ m/ID=([^;]+)/){ $baseID = $1 }
        }
		elsif($feat_type eq 'exon'){
			$gffdata[8] =~ s/ID=([^;]+)?;/ID=$baseID.$1;/;
        }
		elsif($feat_type eq 'CDS'){
			$gffdata[8] =~ s/ID=([^;]+)?;/ID=$baseID.$1;/;
		}
	}

	print join("\t",@gffdata);
}
close(GFF);

