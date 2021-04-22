##Example for lettuce - please change for relevant species
##Run: sh update_ncbi_loader_meta.sh
species=lactuca_sativa
display_name="Lactuca sativa"
prod_name=vigna_unguiculata_gca004118075v1
annotation_url=https://lgr.genomecenter.ucdavis.edu/Links.php
annotation_provider=LGSC
version=2021-04-UCD
date=2021-04

##Deletion
echo delete from meta where meta_key=\"genebuild.id\"\;
echo delete from meta where meta_key=\"species.stable_id_prefix\"\;
echo delete from meta where meta_key=\"species.strain_group\"\;
echo

##Updates
echo update meta set meta_value=\"$display_name\" \
where meta_key=\"species.display_name\"\;

echo update meta set meta_value=\"$date\" \
where meta_key=\"genebuild.initial_release_date\"\;

echo update meta set meta_value=\"$date\" \
where meta_key=\"genebuild.last_geneset_update\"\;

##After running GFF Loader
echo update meta set meta_value=\"$annotation_url\" \
where meta_key=\"annotation.provider_url\"\;

echo update meta set meta_value=\"external_annotation_import\" \
where meta_key=\"genebuild.method\"\;

echo

##Insertions
echo insert into meta \(meta_key, meta_value\) \
values \(\"annotation.provider_name\",\"$annotation_provider\"\)\; 

echo insert into meta \(meta_key, meta_value\) \
values \(\"genebuild.version\",\"$version\"\)\; 
