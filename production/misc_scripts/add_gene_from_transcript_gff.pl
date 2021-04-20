#!/bin/env perl
use strict;
use warnings;

# add genes to a GFF file containing only transcript & exon features
# by Bruno Contreras Moreira EMBL-EBI 2021

if(!$ARGV[0]){ die "# usage: $0 <GFF>\n" }

my ($tparent, $tname, $gene, $transcript, %seen);

open(GFF,"<",$ARGV[0]) || die "# ERROR: cannot read $ARGV[0]\n";
while(<GFF>){

	#chr1H   BART1_0 transcript      41811   45327   1000    +       .       ID=BART1_0-u00001.path1;Name=BART1_0-u00001.001
	#chr1H   BART1_0 exon    41811   42213   1000    +       .       ID=BART1_0-u00001.path1.exon1;Parent=BART1_0-u00001.path1
	#chr1H   BART1_0 exon    42300   42338   1000    +       .       ID=BART1_0-u00001.path1.exon2;Parent=BART1_0-u00001.path1

	my @col = split(/\t/,$_);

	if(defined($col[2]) && $col[2] eq 'transcript'){
		
		$gene = $_;
		$transcript = $_;

		if($col[8] =~ m/ID=([^;]+)/){

			# create a new gene and make it parent of transcript
			$tname = $1;
			$tparent = (split(/\.path/,$tname))[0];
			
			$gene =~ s/\ttranscript\t/\tgene\t/;	
			$gene =~ s/ID=[^;]+;.*/ID=$tparent/;
			$transcript =~ s/Name=/Parent=$tparent;Name=/;
	
			# first print the new gene feature
			if(!$seen{$tparent}){
				print $gene;
				$seen{$tparent}++;
			}

			# now print transcript
			print $transcript;
		}
	
	} else {
		print;
	}

}
close(GFF);
