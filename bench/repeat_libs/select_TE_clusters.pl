#!/usr/bin/perl
use strict;
use warnings;

# 3) get representative TE sequences for all non-ambiguous clusters and 
# output them in FASTA format and with headers compatible with RepeatMasker, such as: 
# >NonLTR-1_CR#LINE @Chlamydomonas  [S:] RepbaseID: NonLTR-1_CR
# >NLA#SINE/tRNA-Core-RTE @Capra_hircus  [S:40,50] RepbaseID: NLA
# >L1_CP#LINE/L1 @Conilurus_penicillatus  [S:55] RepbaseID: L1_CP
# >IS150#ARTEFACT @root  [S:10]

# Note that ClassI/II labels are not used; if you need them read 
# https://www.ncbi.nlm.nih.gov/pmc/articles/PMC4008368
# https://www.researchgate.net/publication/221693700_Transposable_Elements_and_Their_Identification 

my $clusterdir = 'TE_clusters/';
my $aligndir   = 'TE_alignments/';

# names of TEs (found as [lib] is clusters) and 
# original, compressed files to get the full headers 
my %TElibs = (
	'SINEs.plants.fna.gz', 'repeats/SINEs.plants.fna.gz',
	'mipsREdat_9.3p_ALL.fasta.gz', 'repeats/mipsREdat_9.3p_ALL.fasta.gz',
	'trep-db_nr_Rel-19.fasta.gz', 'repeats/trep-db_nr_Rel-19.fasta.gz',
	'repetDB.Mar2020.fna.gz', 'repeats/repetDB.Mar2020.fna.gz',
	'maizeTE11122019.fna.gz', 'repeats/maizeTE11122019.fna.gz',
	'rice6.9.5.liban.fna.gz', 'repeats/rice6.9.5.liban.fna.gz',
	'SoyBaseTE.fna.gz', 'repeats/SoyBaseTE.fna.gz',
	'TAIR10_TE.fna.gz', 'repeats/TAIR10_TE.fna.gz',
	'sunflowerTE.fna.gz', 'repeats/sunflowerTE.fna.gz',
	'melonV4_teannot_refTEs.fa.gz', 'repeats/melonV4_teannot_refTEs.fa.gz',
	'RosaTE.fna.gz', 'repeats/RosaTE.fna.gz',
	'sunrep1.0.fna.gz', 'repeats/sunrep1.0.fna.gz'
); 

# numbers are columns: taxonomy, full header (id) , classification, respectively
# set to -1 if void
my %TEtsvs = (
	'repetDB.Mar2020.fna.gz', [ 'repeats/repetDB.Mar2020.tsv', 0, 1, 5 ],
	'melonV4_teannot_refTEs.fa.gz', [ 'repeats/melonV4_teannot_refTEs_classif.txt', -1, 0, 5 ]
);

# Wicker classification synonyms from
# repetDB (http://urgi.versailles.inra.fr/repetdb)
# and https://genomebiology.biomedcentral.com/articles/10.1186/s13059-018-1479-0/tables/1
my %synonyms = (
	'DTA' => 'hAT',
	'DTH' => 'Harbinger',
	'DTM' => 'Mutator',
	'DTT' => 'TIR/Tc1-Mariner',
	'DTX' => 'TIR',
	'DTC' => 'TIR/CACTA',
	'DHX' => 'Helitron',
	'DXX' => 'DNAtransposon',
	'RIL' => 'LINE',
	'RIX' => 'LINE',
	'RLC' => 'LTR/Copia',
	'RLG' => 'LTR/Gypsy',
	'RLR' => 'Retrovirus',
	'RLX' => 'LTR',
	'RSX' => 'SINE',
	'RXX' => 'Retrotransposons',
	'XXX' => 'Unclassified',
	'noCat' => 'Unclassified'
);

my %lib_synonyms;
$lib_synonyms{'sunflowerTE.fna.gz.nucl'}{'non'} = 'SINE';

#my $DIFFLENRATIO = 0.50; # length diff to consider short redundant TEs, not used
my $VERBOSE = 0;

my ($inputlog,$skipfile,$outfile);
if(!$ARGV[2]){ die "usage: $0 <log.annot> <clusters2skip> <nrTElib.fasta\n" }
else { 
	($inputlog,$skipfile,$outfile) = @ARGV;
}

# parse TE lib headers
my ($fullheader,%TE_FASTA_headers);
foreach my $lib (keys(%TElibs)){
	open(LIB,"zcat $TElibs{$lib} |") || die "# error: cannot read $TElibs{$lib}\n";
	while(<LIB>){
		if(/^>(.*)/){
			$fullheader = $1;

			# lib-specific header fixes
			if($lib eq 'repetDB.Mar2020.fna.gz'){ $fullheader =~ s/\s\-$// }

			push(@{ $TE_FASTA_headers{$lib} }, $fullheader); #print "$fullheader\n" if($lib =~ /maize/);;
		}
	}
	close(LIB);	
	printf("# library %s: %d sequences\n",
		$lib,scalar(@{ $TE_FASTA_headers{$lib} }));
}


# parse TE annotation TSV files
my ($taxon,$class,%TE_annot);
foreach my $lib (keys(%TEtsvs)){

	my ($tsvfile,$taxoncol,$idcol,$classcol) = @{ $TEtsvs{$lib} };

	if($idcol != -1 && $classcol != -1) {
		open(TSV,"<",$tsvfile) || die "# error: cannot read $tsvfile\n";
		while(<TSV>){
			my @data = split(/\t/,$_);

			# save class (these regex work for RepetDB)
			# ""
			# Class I : ? : ?
			# Class I : DIRS : ?
			# Class II : ? : ?
			# Class II : Crypton : ?
			# Class II : TIR : EnSpm/CACTA...
			# ? : DIRS | TIR : ?
			if($data[$classcol] eq '""'){
            $class = 'Unclassified';
            if(defined($data[$classcol+1]) && $data[$classcol+1] eq 'PotentialHostGene'){
               $class = 'PotentialHostGene'
            }
         }
			else{
				if($data[$classcol] =~ /:/){
					my @cldata = split(/ : /,$data[$classcol]);
					# skip 1st elem, not in RepBase FASTA headers
					if($cldata[1] eq '?'){ $class = 'Unclassified' }
					else{ 
						$class = $cldata[1];
						if($cldata[2] ne '?'){ $class .= "/$cldata[2]" }
						$class =~ s/\s+//g;
					}
				} else {
					$class = $data[$classcol];
				}
			}

			$TE_annot{$lib}{$data[$idcol]}{'class'} = $class;
      
			# save taxon (these regex work for RepetDB)	
			if($taxoncol != -1){ 
				$taxon = $data[$taxoncol];
				$TE_annot{$lib}{$data[$idcol]}{'taxon'} = $taxon;
			} #print "|$data[$idcol]|$class|$taxon|\n";
		}
		close(TSV);  
	}
} 

# read list with cluster names to skip
my %skip;
open(LIST,"<",$skipfile) || die "# error: cannot read $skipfile\n";
while(<LIST>){
	if(/^(\S+)/){ $skip{$1} = 1 }
}
close(LIST);
printf("\n# clusters to remove: %d\n\n",scalar(keys(%skip)));


# loop through cluster files and output selected TE seqs
my $n_of_TE_clusters = 0;
my $n_of_TE_seqs = 0;
my ($file,$header,$newheader,$filtheader,$libname,$fullname,$TEok,$len1st);
my (%stats_lib,%stats_class);

open(OUTFASTA,">",$outfile) || die "# error: cannot create $outfile\n"; 

open(LOG,"<",$inputlog) || die "# error: cannot read $inputlog\n";
while(<LOG>){

	if(/^(\d+_\S+?.fna)/){
		$file = $1;

		if($skip{$file}){ 
			warn "# skip cluster: $file\n" if($VERBOSE);
			next;
		}

		#next if($file ne '218005_OTG08741.fna');
		#next if($file ne '309858_vuna_AC193505-121#LTR-unknown.fna'); # debugging

		# select best sequence(s) from cluster with 1 or more seqs
		# i) pre-aligned clusters contain 1+ seqs, the 1st being the best representative;
		# however, sometimes the 1st is a long seq that covers all the others
		# in the cluster
		# ii) some clusters will contain a single sequence 
		if(-s $aligndir.$file){

			my (%clustseq,%clustlen,%clustlib,%clustfulllib,%clustfull,@clustord);
			open(FASTA,"<",$aligndir.$file) || die "# error: cannot read $aligndir$file\n";
			while(my $line = <FASTA>){
				if($line =~ /^>/){
					if($line =~ /^>([^\[\s]+)\s*\[([^\]]+)/){ 

						# note header was shortened in script #1 annot_TEs.pl
						($header,$libname) = ($1, $2); 
					
						# is this a TE sequence?	
						$fullname = $libname;
						if(defined($TElibs{$libname})){ $TEok = 1 }
						elsif(defined($TElibs{$libname.'.fasta.gz'})){
							$TEok = 1;
							$fullname .= '.fasta.gz';
						}
						elsif(defined($TElibs{$libname.'.fna.gz'})){ 
							$TEok = 1; 
							$fullname .= '.fna.gz';
						}
						else{ $TEok = 0 }						
		
						if($TEok){		
							#shorten libname
							$libname =~ s/\.f[astan\.gz]+$//;
				
							# get full header
							$filtheader = $header;
							$filtheader =~ s/PHG_//;
							$fullheader = '';
							foreach my $h (grep(/$filtheader/,@{ $TE_FASTA_headers{$fullname} })){
								$fullheader = $h;			
							} #print "$header | $fullheader | $libname | $TEok\n";

							push(@clustord,$header);
							$clustlib{$header} = $libname;
							$clustfulllib{$header} = $fullname;
							$clustfull{$header} = $fullheader;
						}
					}
					else { die "# error: cannot parse $line\n" } # should not happen
				}
				else {
					next if($TEok == 0);
					chomp($line);

					$clustseq{$header} .= $line;
					$clustlen{$header} += length($line); 			 		
				}				
			}
			close(FASTA);

			# skip cluster if no TEs found
			next if(scalar(@clustord) == 0 );

			## take 1st sequence in cluster by default
			$header = $clustord[0];
			$newheader = '';
			$len1st = $clustlen{$header};
			$taxon  = 'root';
			$class  = 'Unclassified';

			# guess TE class and taxonomy of this TE sequence
			# mips: >XXX_1220|Actinidia_deliciosa_460|Satellite|01.02.50.99|3627|Actinidia
			# repet: >RLG-solo-LTR_denovoMDO_kr-B-G10838-Map14 -> check TSV
			# repet: >DHX-incomp_MCL1219_Brap_TEdenovo-B-R11034-Map4 -> check TSV
			# trep: >DHH_Mpol_A_RND-1 Metrosideros polymorpha; DNA-transposon, Helitron, Helitron; ...
			# SINE: >SolS-VII [Wenke 2011] Solanacea/Planta

			if($clustfulllib{$header} eq 'SINEs.plants.fna.gz'){
				$class = 'SINE';
				if($clustfull{$header} =~ m/\]\s+(.*)?\/Planta/){
					$taxon = $1;
				}	
			} 
			elsif($clustfulllib{$header} eq 'mipsREdat_9.3p_ALL.fasta.gz'){
				my @tmpdata = split(/\|/,$clustfull{$header});
				$class = $tmpdata[2];
				$taxon = $tmpdata[5];
			}
			elsif($clustfulllib{$header} eq 'trep-db_nr_Rel-19.fasta.gz'){
				my @tmpdata = split(/;/,$clustfull{$header});
				
				#DNA-transposon, Helitron, Helitron
				#DNA-transposon, TIR, CACTA
				#DNA-transposon, TIR, Harbinger...
				#DNA-transposon, unknown, unknown		
				#Retrotransposon, LTR, Copia,...
				#Retrotransposon, LTR, unknown
				#Retrotransposon, non-LTR (SINE), Chronos, ...
				#Retrotransposon, non-LTR (SINE), unknown
				#unknown, unknown, unknown
				my @cldata = split(/,/,$tmpdata[1]);
            # skip 1st elem, not in RepBase FASTA headers
            if(!defined($cldata[1]) || $cldata[1] =~ 'unknown'){ $class = 'Unclassified' }
            else{
					$class = $cldata[1];
					if($cldata[2] !~ 'unknown'){ $class .= "/$cldata[2]" }
					$class =~ s/\s+//g;
            }
					
				if($tmpdata[0] =~ m/\S+\s+([^;]+)/){ $taxon = $1 }
         }
			elsif($clustfulllib{$header} eq 'repetDB.Mar2020.fna.gz'){
				# this actually needs extra data from TSV file
			
				# retrieve class annotation
				$class = $TE_annot{$clustfulllib{$header}}{$clustfull{$header}}{'class'};

				# retrive taxon 
				if($TE_annot{$clustfulllib{$header}}{$clustfull{$header}}{'taxon'}){
					$taxon = $TE_annot{$clustfulllib{$header}}{$clustfull{$header}}{'taxon'}
				}
         }
			elsif($clustfulllib{$header} eq 'maizeTE11122019.fna.gz'){
				#Hip6_5#DNA/Helitron			
				($newheader,$class) = split(/#/,$header);
				$class =~ s/\/unknown//;
				$taxon = 'Zea_mays';
			}
			elsif($clustfulllib{$header} eq 'rice6.9.5.liban.fna.gz'){
				#RST-Osativa-Cluster_4#SINE/unknown
				($newheader,$class) = split(/#/,$header);
				$class =~ s/\/unknown//;	
				$taxon = 'Oryza_sativa';
         }
			elsif($clustfulllib{$header} eq 'SoyBaseTE.fna.gz'){
				#DHH_uuu_Gm1-1:SoyBaseTE#Helitron/Helitron
				($newheader,$class) = split(/#/,$header);
				$newheader = (split(/:/,$newheader))[0];
            $class =~ s/\/unknown//;
				$taxon = 'Glycine_max';
         }
			elsif($clustfulllib{$header} eq 'TAIR10_TE.fna.gz'){
				#AT1TE52125:TAIR10#LTR/Gypsy			
				($newheader,$class) = split(/#/,$header);
            $newheader = (split(/:/,$newheader))[0];
            $class =~ s/\/unknown//;
				$taxon = 'Arabidopsis_thaliana';
         }
			elsif($clustfulllib{$header} eq 'sunflowerTE.fna.gz' ||
					$clustfulllib{$header} eq 'sunrep1.0.fna.gz'){
				#>Ha10_34085618_34086926:Sunflower#DTA
				#>1:SUNREP#RLG
				($newheader,$class) = split(/#/,$header);
            $newheader = (split(/:/,$newheader))[0];

				# only sunflower has a specific rule defined above
				if($lib_synonyms{$clustfulllib{$header}}{$class}){
					$class =~ $lib_synonyms{$clustfulllib{$header}}{$class};
				} 

				if($class =~ /helitron\d+/){
					$class = 'Helitron';
				}

            $taxon = 'Helianthus_annuus';
			}
			elsif($clustfulllib{$header} eq 'RosaTE.fna.gz'){
				#>Chr00-19138857-19140663:RosaTE#XXX
				($newheader,$class) = split(/#/,$header);
            $newheader = (split(/:/,$newheader))[0];

				$class = $synonyms{$class} || $class;
				$taxon = 'Rosa_chinensis'; 
         }
			elsif($clustfulllib{$header} eq 'melonV4_teannot_refTEs.fa.gz'){
				# this actually needs extra data from TSV file
				$class = $TE_annot{$clustfulllib{$header}}{$clustfull{$header}}{'class'} || 'Unclassified';
				$taxon = 'Cucumis_melo';
			}

			# final fixes
			$class = $synonyms{$class} || $class; 
			$taxon =~ s/\.//g;
         $taxon =~ s/\s+/_/g;

			# skip sequences annotated as PHG (Potential Host Gene)
			if($class =~ /PHG/ || $class =~ /PotentialHost/){
				next;
			}

			# actually add this header to output file
			if($newheader ne ''){
				print OUTFASTA ">$newheader:$clustlib{$header}#$class \@$taxon [S:]\n";
			} else {
				print OUTFASTA ">$header:$clustlib{$header}#$class \@$taxon [S:]\n";
			}

			# add sequence to output file
			$clustseq{$header} =~ s/\-//g;
			print OUTFASTA uc($clustseq{$header})."\n";

			# log
			if($newheader ne ''){
				print "$newheader:$clustlib{$header}#$class \@$taxon : $clustlen{$header} : $file\n";
			} else {
				print "$header:$clustlib{$header}#$class \@$taxon : $clustlen{$header} : $file\n";
			}

			$stats_class{$class}++;
			$stats_lib{$clustlib{$header}}++;
			
			$n_of_TE_seqs++;

			# UNTESTED: 2nd sequence only if $DIFFLENRATIO shorter,
			# avoids missing boa fide TE components clustered with large TE complexes
			#foreach $header (@clustord){
			#	if($clustlen{$header} < $DIFFLENRATIO * $len1st){
			#		#print "$file $header $clustlib{$header} $clustlen{$header} $len1st\n";
			#		$n_of_TE_seqs++;
			#		last;
			#	}
			#}
		}
		else { die "# error: cannot find (pre-aligned) cluster $file\n" }			

		$n_of_TE_clusters++;
	}		
}
close(LOG);

close(OUTFASTA); 

# print overall stats to log
print "# clusters=$n_of_TE_clusters sequences=$n_of_TE_seqs\n";

foreach $libname (sort {$stats_lib{$b}<=>$stats_lib{$a}} keys(%stats_lib)){
	printf("%s\t%d\n",$libname,$stats_lib{$libname});
} print "\n";

foreach $class (sort {$stats_class{$b}<=>$stats_class{$a}} keys(%stats_class)){
   printf("%s\t%d\n",$class,$stats_class{$class});
} 
