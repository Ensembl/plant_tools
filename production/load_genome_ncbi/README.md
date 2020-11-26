
This pipeline code, contributed by @leannehaggerty, configures a hive pipeline to create a bare bones core db from a public assembly at the NCBI. This is useful in case where https://github.com/Ensembl/ensembl-genomeloader cannot be used.

## To run the pipeline 

You will need bioperl and the following repos in your PERL5LIB:
ensembl-analysis (dev/hive_master)
ensembl 
ensembl-hive (version/2.5)
ensembl-killlist 
ensembl-io 
ensembl-variation 
ensembl-taxonomy
ensembl-production

Something like this would do:
export ENSCODE=

PERL5LIB=${ENSCODE}/ensembl/modules:${ENSCODE}/ensembl-analysis/modules:${ENSCODE}/ensembl-hive/modules:${ENSCODE}/ensembl-killlist/modules:${ENSCODE}/ensembl-production/modules:${ENSCODE}/ensembl-analysis/scripts:${ENSCODE}/ensembl-io/modules:${ENSCODE}/ensembl-analysis/scripts/buildchecks/:${ENSCODE}/ensembl-variation/modules:${ENSCODE}/ensembl-taxonomy/modules:$BIOPERL_LIB

