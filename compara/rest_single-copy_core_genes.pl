#!/usr/bin/env perl
use strict;
use warnings;

use Getopt::Long qw(:config no_ignore_case);
use Net::FTP;
use JSON qw(decode_json);
use Data::Dumper;
use Benchmark;
use Time::HiRes;
use HTTP::Tiny;

# Retrieves high-confidence single-copy orthologous genes/proteins shared by (plant) species in clade 
# by querying pre-computed data from Ensembl Genomes Compara with a reference genome.
# Multiple copies are optionally allowed for selected or all species.
#
# Based on scripts at
# https://github.com/Ensembl/ensembl-compara/blob/release/97/scripts/examples/
# https://github.com/Ensembl/ensembl-rest/wiki/Example-Perl-Client
#
# TODO: minimize multiple alignments 
#
# Bruno Contreras Moreira 2019

# Ensembl Genomes 
my @divisions  = qw( Plants Bacteria Fungi Vertebrates Protists Metazoa );
my $FTPURL     = 'ftp.ensemblgenomes.org'; 
my $COMPARADIR = '/pub/xxx/current/tsv/ensembl-compara/homologies';
my $RESTURL    = 'http://rest.ensembl.org';
my $INFOPOINT  = $RESTURL.'/info/genomes/division/';
my $TAXOPOINT  = $RESTURL.'/info/genomes/taxonomy/';
my $TREEPOINT  = $RESTURL.'/genetree/member/id/';

my $verbose    = 0;
my $division   = 'Plants';
my $taxonid    = 3700; # NCBI Taxonomy id, Brassicaceae=3700, Asterids=71274, Poaceae=4479
my $ref_genome = 'arabidopsis_thaliana'; # should be diploid and contained in $taxonid;
my $seqtype    = 'protein'; 
my $comparadir = '';
my $outfolder  = '';
my $out_genome = '';


my ($help,$sp,$show_supported);
my ($GOC,$WGA,$one2many,$LOWCONF) = (0,0,0,0);
my ($request,$response,$request_time,$last_request_time);
my (@multi_species, @ignore_species, %ignore, %polyploid, %division_supported);

GetOptions(	
	"help|?"       => \$help,
	"verbose|v"    => \$verbose,
	"supported|l"  => \$show_supported,
	"division|d=s" => \$division, 
	"clade|c=i"    => \$taxonid,
	"reference|r=s"=> \$ref_genome,
	"outgroup|o=s" => \$out_genome,
	"multicopy|m=s"=> \@multi_species,
	"ignore|i=s"   => \@ignore_species,
	"type|t=s"     => \$seqtype,
	"GOC|G=i"      => \$GOC,
	"WGA|W=i"      => \$WGA,
	"LC|L"         => \$LOWCONF,
	"folder|f=s"   => \$outfolder
) || help_message(); 

sub help_message {
	print "\nusage: $0 [options]\n\n".
		"-l list supported species_names         (optional, example: -l)\n".
		"-d Ensembl division                     (optional, default: -d $division)\n".
		"-c NCBI Taxonomy clade of interest      (optional, default: -c $taxonid)\n".
		"-r reference species_name               (optional, default: -r $ref_genome)\n".
		"-o outgroup species_name                (optional, example: -o brachypodium_distachyon)\n".
		"-m multi-copy species_name(s)           (optional, example: -m brassica_napus -m ... -m all)\n".
		"-i ignore species_name(s)               (optional, example: -i selaginella_moellendorffii -i ...)\n".
		"-f folder to output FASTA files         (optional, example: -f myfolder)\n".
		"-t sequence type [protein|cdna]         (optional, requires -f, default: -t protein)\n".
		"-L allow low-confidence orthologues     (optional, by default these are skipped)\n".
		"-v verbose                              (optional, example: -v\n";

	print "\nThe following options are only available for some clades:\n\n".
		"-G min Gene Order Conservation [0:100]  (optional, example: -G 75)\n".
		"   see modules/Bio/EnsEMBL/Compara/PipeConfig/EBI/Plants/ProteinTrees_conf.pm\n".
		"   at https://github.com/Ensembl/ensembl-compara\n\n".
		"-W min Whole Genome Align score [0:100] (optional, example: -W 75)\n".
		"   see ensembl-compara/scripts/pipeline/compara_plants.xml\n".
		"   at https://github.com/Ensembl/ensembl-compara\n\n";
	print "Read about GOC and WGA at:\n".
		"https://www.ensembl.org/info/genome/compara/Ortholog_qc_manual.html\n\n";

	print "Example calls:\n\n".
		" ./get_single-copy_core_genes.pl -f Brassicaceae\n".
		" perl get_single-copy_core_genes.pl -f Brassicaceae -t cdna -o theobroma_cacao\n".
		" perl get_single-copy_core_genes.pl -f poaceae -c 4479 -r oryza_sativa -WGA 75\n".
		" perl get_single-copy_core_genes.pl -f all -c 33090 -m all -r physcomitrella_patens\n";
		exit(0);
}

if($help){ help_message() }

if($division){
	if(!grep(/$division/,@divisions)){
		die "# ERROR: accepted values for division are: ".join(',',@divisions)."\n"
	} else {
		$comparadir = $COMPARADIR;
		my $lcdiv = lc($division);
		$comparadir =~ s/xxx/$lcdiv/;
	}
}

if(@ignore_species){
	foreach my $sp (@ignore_species){
		$ignore{ $sp } = 1;
	}
	printf("\n# ignored species : %d\n\n",scalar(keys(%ignore)));
}

# species for which one2many orths are allowed, such as polyploid species
# with scaffold level assemblies or species with ancestral genome duplications
if(@multi_species){
	foreach my $sp (@multi_species){
		if($sp eq 'all'){
			$one2many = 1;
			%polyploid = ();
			$polyploid{ $sp } = 1;
			last;
		} else{ 
			$polyploid{ $sp } = 1;
		}
	}

	if($one2many){ print "\n# multi-copy species : all\n\n" }
	else{
		printf("\n# multi-copy species : %d\n\n",scalar(keys(%polyploid)));
	}
}

if($outfolder){
	if(-e $outfolder){ print "\n# WARNING : folder '$outfolder' exists, files might be overwritten\n\n" }
	else { 
		if(!mkdir($outfolder)){ die "# ERROR: cannot create $outfolder\n" }
	}

	if($seqtype ne 'protein' && $seqtype ne 'cdna'){
		die "# ERROR: accepted values for seqtype are: protein|cdna\n"
	}
}	

if($show_supported){ print "# $0 -l \n\n" }
else {
	print "# $0 -d $division -c $taxonid -r $ref_genome -o $out_genome ".
		"-f $outfolder -t $seqtype -G $GOC -W $WGA -L $LOWCONF\n\n";
}

my $start_time = new Benchmark();

# new object for REST requests
my $http = HTTP::Tiny->new();
my $global_headers = { 'Content-Type' => 'application/json' };
my $request_count = 0; # global counter to avoid overload

## 0) check supported species in division ##################################################

$request = $INFOPOINT."Ensembl$division?";

$response = perform_rest_action( $request, $global_headers );
my $infodump = decode_json($response);

foreach $sp (@{ $infodump }) {
	if($sp->{'has_peptide_compara'}){
		$division_supported{ $sp->{'name'} } = 1;
	}	
}

# list supported species and exit
if($show_supported){

	foreach $sp (sort(keys(%division_supported))){
		print "$sp\n";
	}
	exit;
}

# check outgroup is supported
if($out_genome && !$division_supported{ $out_genome }){
	die "# ERROR: genome $out_genome is not supported\n";
}

## 1) check species in clade ##################################################################

my $n_of_species = 0;
my (@supported_species, %supported, %core, %present);

$request = $TAXOPOINT."$taxonid?";

$response = perform_rest_action( $request, $global_headers );
$infodump = decode_json($response);

foreach $sp (@{ $infodump }) {
   if($sp->{'name'} && $division_supported{ $sp->{'name'} }){

		next if($ignore{ $sp->{'name'} });

		push(@supported_species, $sp->{'name'});
		$supported{ $sp->{'name'} } = 1;
		print "# ".$sp->{'name'}."\n" if($verbose);
   }
}

printf("# supported species in NCBI taxon %d : %d\n\n", $taxonid, scalar(@supported_species));

# check reference genome is supported and is not polyploid
if(!grep(/$ref_genome/,@supported_species)){
	die "# ERROR: cannot find $ref_genome within NCBI taxon $taxonid\n";
}
elsif($polyploid{ $ref_genome }){
	   die "# ERROR: $ref_genome is polyploid; reference genome must be diploid\n";
}

# add outgroup if required
if($out_genome){
	push(@supported_species,$out_genome);
	$supported{ $out_genome } = 1;
	print "# outgenome: $out_genome\n";
}

$n_of_species = scalar( @supported_species );
print "# total selected species : $n_of_species\n\n";

## 2) get orthologous (plant) genes shared by $ref_genome and other species ####################

# columns of TSV file 
my ($gene_stable_id,$prot_stable_id,$species,$identity,$homology_type,$hom_gene_stable_id,
   $hom_prot_stable_id,$hom_species,$hom_identity,$dn,$ds,$goc_score,$wga_coverage,
	$high_confidence,$homology_id);

# get and parse TSV file
my (@sorted_ids);
my $stored_compara_file = download_TSV_file( $comparadir, $ref_genome );
open(TSV,"gzip -dc $stored_compara_file |") || die "# ERROR: cannot open $stored_compara_file\n";
while(<TSV>){
	
	($gene_stable_id,$prot_stable_id,$species,$identity,$homology_type,$hom_gene_stable_id,
	$hom_prot_stable_id,$hom_species,$hom_identity,$dn,$ds,$goc_score,$wga_coverage,    
	$high_confidence,$homology_id) = split(/\t/);

	next if(!$supported{ $hom_species } || $hom_species eq $ref_genome);

	next if($LOWCONF == 0 && $high_confidence == 0);

	next if($WGA && ($wga_coverage eq 'NULL' || $wga_coverage < $WGA));

	next if($GOC && ($goc_score eq 'NULL' || $goc_score < $GOC));

	if($homology_type eq 'ortholog_one2one' || 
		(($one2many || $polyploid{ $hom_species } ) && $homology_type eq 'ortholog_one2many') ) {

		# add $ref_genome protein 
		if(!$core{ $gene_stable_id }){ 

			push(@{ $core{ $gene_stable_id }{ $ref_genome } }, $prot_stable_id );

			$present{ $ref_genome }++;

			push(@sorted_ids, $gene_stable_id); # save cluster order
		}

		push(@{ $core{ $gene_stable_id }{ $hom_species } }, $hom_prot_stable_id );

		$present{ $hom_species }++;
	}
}
close(TSV);

# check GOC / WGA availability
foreach $hom_species (@supported_species){
	if(!defined( $present{ $hom_species } )&& $WGA){
		print "# WGA not available: $hom_species\n";
	} elsif(!defined( $present{ $hom_species } ) && $GOC){
		print "# GOC not available: $hom_species\n";
	}
}


## 3) print summary matrix of single-copy / core genes and compile sequence clusters #################

my $total_core_clusters = 0;
my ($pruned_species,$treedump,$acc,$seq,$line,$filename);

# prepare param to prune species in REST requests
if($outfolder){
	foreach $hom_species (@supported_species){
		$pruned_species .= "prune_species=$hom_species;";
	}
}	

foreach $gene_stable_id (@sorted_ids){

	next if(scalar(keys(%{ $core{ $gene_stable_id } })) < $n_of_species); 

	my (%valid_prots, %align);

	$filename = $gene_stable_id;
	if($outfolder){
		if($seqtype eq 'protein'){ $filename .= '.faa' }
		else{ $filename .= '.fna' }
	}

	# print matrix header
	if($total_core_clusters == 0){
		print "cluster";
		foreach $hom_species (@supported_species){
			print "\t$hom_species";
		} 
		print "\n";
	}
	
	# print a matrix row in TSV format
	print $filename;
	foreach $hom_species (@supported_species){ 

		printf("\t%s", join(',',@{ $core{ $gene_stable_id }{ $hom_species } }) );

		# store which prots come from each species
		foreach $hom_prot_stable_id (@{ $core{ $gene_stable_id }{ $hom_species } }){
			$valid_prots{ $hom_prot_stable_id } = $hom_species;
		}
	} print "\n";

	# retrieve cluster sequences
	if($outfolder){
	
		# check whether this cluster already exists
		if(-s "$outfolder/$filename"){
			$total_core_clusters++;
			next;
		}

		# make REST request and parse dumped JSON
		$request = "$TREEPOINT$gene_stable_id?compara=$division;aligned=1;sequence=$seqtype;$pruned_species";
		$response = perform_rest_action( $request, $global_headers );
		$treedump = Dumper( decode_json($response) ); 

		foreach $line (split(/\n/, $treedump ) ){
			if($line =~ m/'sequence' =>/){
				($seq,$acc) = ('','');
			}
			elsif($line =~ m/'seq' => '([^']+)'/){
				$seq = $1;
			}
			elsif($line =~ m/'accession' => '([^']+)'/ && $acc eq ''){
				$acc = $1;
				if($valid_prots{ $acc } ){
					$align{ $valid_prots{$acc} }{ $acc } = $seq;
					$valid_prots{$acc} .= " found";
				}
			}
		}

		# save cluster to file
		if(scalar(keys(%align)) == $n_of_species){ 

			# TODO : minimize MSA

			open(FASTA,">","$outfolder/$filename") || 
				die "# ERROR: cannot create $outfolder/$filename\n";

			foreach $hom_species (@supported_species){
				foreach $hom_prot_stable_id (@{ $core{ $gene_stable_id }{ $hom_species } }){
					print FASTA ">$hom_species $hom_prot_stable_id\n$align{ $hom_species }{ $hom_prot_stable_id }\n";
				}
			}	

			close(FASTA);
		} 
		else { # might occur with low-confidence orths in split trees and same supertree
			if($verbose){
				print "# WARNING: cannot retrieve aligned sequences for $gene_stable_id : ";
				foreach $acc (keys(%valid_prots)){
					next if($valid_prots{$acc} =~ m/ found/);
					print "# $acc $valid_prots{$acc},";
				} print "\n";
			}
		}
	}
	
	$total_core_clusters++; #last if($total_core_clusters == 1); # debug
}

print "\n# total single-copy core clusters : $total_core_clusters\n\n";

# print diagnostics
if($total_core_clusters == 0){

	print "# diagnostic stats (species\tclusters)\n\n";

	foreach $hom_species (@supported_species){ $present{ $hom_species } = 0 unless($present{ $hom_species }) }

	foreach $hom_species (sort {$present{$a}<=>$present{$b}} (@supported_species)){
		printf("%s %d\n",	$hom_species, $present{ $hom_species } );
	}
}

my $end_time = new Benchmark();
print "\n# runtime: ".timestr(timediff($end_time,$start_time),'all')."\n";

###################################################################################################

# download compressed TSV file from FTP site, renames it 
# and saves it in current folder; uses FTP globals defined above
sub download_TSV_file {

	my ($dir,$ref_genome) = @_;
	my ($compara_file,$stored_compara_file) = ('','');

	print "# connecting to $FTPURL ...\n";

	if(my $ftp = Net::FTP->new($FTPURL,Passive=>1,Debug =>0,Timeout=>60)){
		$ftp->login("anonymous",'-anonymous@') ||
			die "# cannot login ". $ftp->message();
		$ftp->cwd($dir) ||
		   die "# ERROR: cannot change working directory to $dir ". $ftp->message();
		$ftp->cwd($ref_genome) ||
			die "# ERROR: cannot find $ref_genome in $dir ". $ftp->message();

		# find out which file is to be downloaded and 
		# work out its final name with $ref_genome in it
		foreach my $file ( $ftp->ls() ){
			if($file =~ m/protein_default.homologies.tsv.gz/){
				$compara_file = $file;
				$stored_compara_file = $compara_file;
				$stored_compara_file =~ s/tsv.gz/$ref_genome.tsv.gz/;
				last;
			}
		}
		
		# download that TSV file
		unless(-s $stored_compara_file){
			$ftp->binary();
			my $downsize = $ftp->size($compara_file);
			$ftp->hash(\*STDOUT,$downsize/20) if($downsize);
			printf("# downloading %s (%1.1fMb) ...\n",$compara_file,$downsize/(1024*1024));
			print "# [        50%       ]\n# ";
			if(!$ftp->get($compara_file)){
				die "# ERROR: failed downloading $compara_file\n";
			}

			# rename file to final name
			rename($compara_file, $stored_compara_file);
			print "# using $stored_compara_file\n\n";
		} else {
			print "# re-using $stored_compara_file\n\n";
		}
	} else { die "# ERROR: cannot connect to $FTPURL , please try later\n" }

	return $stored_compara_file;
}


# uses global $request_count
sub perform_rest_action {
	my ($url, $headers) = @_;
	$headers ||= {};
	$headers->{'Content-Type'} = 'application/json' unless exists $headers->{'Content-Type'};

	if($request_count == 15) { # check every 15
		my $current_time = Time::HiRes::time();
		my $diff = $current_time - $last_request_time;

		# if less than a second then sleep for the remainder of the second
		if($diff < 1) {
			Time::HiRes::sleep(1-$diff);
		}
		# reset
		$last_request_time = Time::HiRes::time();
		$request_count = 0;
	}

	my $response = $http->get($url, {headers => $headers});
	my $status = $response->{status};
	
	if(!$response->{success}) {
		# check for rate limit exceeded & Retry-After (lowercase due to our client)
		if(($status == 429 || $status == 599) && exists $response->{headers}->{'retry-after'}) {
			my $retry = $response->{headers}->{'retry-after'};
			Time::HiRes::sleep($retry);
			# afterr sleeping see that we re-request
			return perform_rest_action($url, $headers);
		}
		else {
			my ($status, $reason) = ($response->{status}, $response->{reason});
			die "# ERROR: failed REST request $url\n# Status code: ${status}\n# Reason: ${reason}\n# Please re-run";
		}
	}

	$request_count++;

	if(length($response->{content})) { return $response->{content} } 
	else { return '' }	
}

