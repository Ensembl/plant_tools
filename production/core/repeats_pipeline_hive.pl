#!/bin/env perl
use strict;
use warnings;
use Getopt::Long qw(:config no_ignore_case);

# This script submits repeat pipeline job(s) to hive
#
# It uses env $USER to create hive job names and assumes Ensembl-version API
# is loaded in @INC / $PERL5LIB
#
# Only 1 job / per user allowed, as it creates a hive db called 
# $ENV{'USER'}."_dna_features_$ensembl_version";
#
# Documentation at:
# https://www.ebi.ac.uk/seqdb/confluence/display/EnsGen/DNA+Features+Pipeline
# https://www.ebi.ac.uk/seqdb/confluence/display/EnsGen/A+review+of+repeat+libraries+for+plants
#
# Common problems & solutions:
#
# i) pipeline_db created by init_pipeline does not match -v => 
# 		git checkout release/XX in ensembl repo
# ii) AnalysisSetup fails while connecting to ensembl_production => 
# 		fix registry 
#
## check user arguments ######################################################
##############################################################################

my $hive_db_cmd = 'mysql-ens-hive-prod-2-ensrw';
my $libpath = '/nfs/production/flicek/ensembl/shared_data/repeats_libraries/plants/';
my $nrTEplants_lib = $libpath . 'nrTEplants/nrTEplantsJune2020.fna'; 

my ($rerun,$overwrite,$nrTEplants,$sensitivity) = (0,0,0,'');
my ($help,$reg_file,@species,$species_cmd,$ensembl_version,$pipeline_dir);
my ($hive_args,$hive_url,$hive_db,$prodbname);      

GetOptions(	
	"help|?"      => \$help,
	"overwrite|w" => \$overwrite, 
	"rerun|r"     => \$rerun,
	"version|v=s" => \$ensembl_version,
	"species|s=s" => \@species,
	"hivecmd|H=s" => \$hive_db_cmd,    
	"regfile|R=s" => \$reg_file,
	"pipedir|P=s" => \$pipeline_dir,
	"prodb|D=s"   => \$prodbname,
	"nrplants|n"  => \$nrTEplants,
	"sensitivity|T=s" => \$sensitivity
) || help_message(); 

if($help){ help_message() }

sub help_message {
	print "\nusage: $0 [options]\n\n".
		"-s species_name(s)                          (required, example: -s arabidopsis_thaliana -s zea_mays)\n".
		"-v E! release match PERL5LIB & core name    (required, example: -v 104)\n".
		"-R registry file, can be env variable       (required, example: -R \$p2panreg)\n".
		"-P folder to put pipeline files, can be env (required, example: -P \$reptmp)\n".
		"-D ensembl_production db name               (required, example: -D ensembl_production)\n".	
		"-H hive database command                    (optional, default: $hive_db_cmd)\n".
		"-n use nrTEplants library                   (optional, default: REdat)\n".
		"-S RepeatMasker sensitivity of -n           (optional, example: -S low|medium|high)\n".
		"-w over-write db (hive_force_init)          (optional, useful when a previous run failed)\n".
		"-r re-run jump to beekeper.pl               (optional, default: run init script from scratch)\n\n";
	exit(0);
}

if($ensembl_version){
	# check Ensembl API is in env
	if(!grep(/ensembl-hive\/modules/,@INC)){
		die "# EXIT : cannot find ensembl-hive/modules in \$PERL5LIB / \@INC\n"
	}
}
else{ die "# EXIT : need a valid Ensembl release, such as -v 105\n" } 

if(@species){
	foreach my $sp (@species){ 
		$species_cmd .= "--species $sp "; 
	}
} 
else{ die "# EXIT : need a valid -s species, such as -s arabidopsis_thaliana -s brachypodium_distachyon\n" }

if(!$reg_file || !-e $reg_file){ die "# EXIT : need a valid -R file, such as -R \$p2panreg\n" }

if(!$pipeline_dir || !-e $pipeline_dir){ die "# EXIT : need a valid -P path, such as -P \$reptmp\n" }

if(!$prodbname){ die "# EXIT : need a valid -D value, such as -D ensembl_production\n" }

if($rerun && $overwrite){
	die "# cannot take both -r and -w, please choose one\n"
}

chomp( $hive_args = `$hive_db_cmd details script` );
$hive_db = $ENV{'USER'}."_dna_features_$ensembl_version"; 
chomp( $hive_url  = `$hive_db_cmd --details url` );
$hive_url .= $hive_db; 

## Run init script and produce a hive_db with all tasks to be carried out
#########################################################################

my $initcmd = "init_pipeline.pl Bio::EnsEMBL::EGPipeline::PipeConfig::DNAFeatures_conf ".
	"$hive_args ".
	"--registry $reg_file ".
	"--pipeline_dir $pipeline_dir ".
	"--production_db $prodbname ".
	"$species_cmd ".
	"--hive_force_init $overwrite ";

if(defined($sensitivity) && $sensitivity ne ''){
	$initcmd .= "-repeatmasker_sensitivity all=$sensitivity ";
}

if($nrTEplants){
	$initcmd .= "-repeatmasker_library all=$nrTEplants_lib ";
	$initcmd .= "-repeatmasker_logic_name all=repeatmask_nrplants ";

	if(defined($sensitivity) && $sensitivity ne ''){
		$initcmd .= "-repeatmasker_sensitivity all=$sensitivity ";
	}
} else {
	$initcmd .= "--redatrepeatmasker 1 ";
}



if($rerun == 0){
	print "# $initcmd\n\n";

	open(INITRUN,"$initcmd |") || die "# ERROR: cannot run $initcmd\n";
	while(<INITRUN>){
		print;
	}	
	close(INITRUN);
}

## Send jobs to hive 
######################################################################### 

print "# hive job URL: $hive_url";

system("beekeeper.pl -url '$hive_url;reconnect_when_lost=1' -sync");
system("runWorker.pl -url '$hive_url;reconnect_when_lost=1' -reg_conf $reg_file");
system("beekeeper.pl -url '$hive_url;reconnect_when_lost=1' -reg_conf $reg_file -loop");

print "# hive job URL: $hive_url\n\n";

print "# If you have trouble you might want to check/remove the data at -P folder\n";
