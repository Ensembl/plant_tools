##To run: perl add_new_core --param_file=[PARAM_FILE]
##you can find param files in param_file_examples dir
use 5.14.0;
use warnings;
use Data::Dumper;
use production::Tools::FileReader qw(slurp slurp_hash_list read_file file2hash file2hash_tab line2hash);
use Getopt::Long;
use Pod::Usage;
use DBI;
my $core;
my $file2;
my $param_file;

{
    GetOptions ("param_file=s" => \$param_file,
                "file2=s" => \$file2)
    or die("Incorrect Usage");

    if (!$param_file){
        usage();
    }

    my $h   = file2hash_tab($param_file);
    my $dbh = get_dbh($h);

    ##creating db and adding tables
    #create_db($h);

    ##Adding controlled vocab
    #add_cv($h);

    ##Loading Fasta data
    load_fasta($h);

    ##Loading AGP data
    #load_agp($h);

    ##updating meta table (will also needs manual tweaking)
    #copy_meta($h, $dbh);

    ##Add seq region attribs
    #add_seq_region_attribs($h, $dbh);




}

#========================================
sub create_db {
#========================================
    my ($h) = @_;

    ##Creating the DB and adding tables
    warn "Creating and populating new core for $h->{core}\n";
    my $cmd = "mysqladmin -h $h->{host} -P $h->{port} -u$h->{user} -p$h->{pass} CREATE $h->{core}";
    system($cmd);

    ##Adding tables
    $cmd = "mysql -h$h->{host} -P$h->{port} -u$h->{user} -p$h->{pass} $h->{core} < $ENV{ENSEMBL_ROOT_DIR}/ensembl/sql/table.sql";
    system($cmd);
}


#========================================
sub add_cv {
#========================================
    my ($h) = @_;
    warn "Adding controlled vocabulary for $core\n";

    my $path = "$ENV{ENSEMBL_ROOT_DIR}/ensembl-production/scripts/production_database";
    system("mkdir /tmp/prod_db_tables");
    my $cmd = "perl $path/populate_production_db_tables.pl ".
              "--host $h->{host} --port $h->{port} --user $h->{user} --pass $h->{pass} ".
              '$(mysql-ens-meta-prod-1 details prefix_m) '.
              "--database $h->{core} ".
              "--dumppath /tmp/prod_db_tables --dropbaks";
    say $cmd;
    system($cmd);
}

#========================================
sub set_top_level {
#========================================
    my ($h) = @_;
    my $path = "$ENV{ENSEMBL_ROOT_DIR}/ensembl-pipeline/scripts";
    my $cmd = "perl $path/set_toplevel.pl ".
              "--host $h->{host} --port $h->{port} --user $h->{user} --pass $h->{pass} ".
              "--dbname $h->{core} ";
    say $cmd;
    system($cmd);
}

#========================================
sub load_fasta {
#========================================
    my ($h) = @_;
    my $path = "$ENV{ENSEMBL_ROOT_DIR}/ensembl-pipeline/scripts";
    my $cmd = "perl $path/load_seq_region.pl ".
              "--host $h->{host} --port $h->{port} --user $h->{user} --pass $h->{pass} ".
              "--dbname $h->{core} ".
              "--coord_system_name scaffold --coord_system_version $h->{version} ".
              "--rank 2 -default_version -sequence_level ".
              "--fasta_file $h->{fasta_file}";
    say $cmd,"\n";
    #system($cmd);
}

#========================================
sub load_agp {
#========================================
    my ($h) = @_;
    my $path = "$ENV{ENSEMBL_ROOT_DIR}/ensembl-pipeline/scripts";

    ##Load AGP part 1
    my $cmd = "perl $path/load_seq_region.pl ".
              "--host $h->{host} --port $h->{port} --user $h->{user} --pass $h->{pass} ".
              "--dbname $h->{core} ".
              "--coord_system_name chromosome --coord_system_version $h->{version} ".
              "--rank 1 --default_version ".
              "-agp_file $h->{agp_file}";
    say $cmd,"\n";
    system($cmd);

    ##Load AGP part 2
    $cmd = "perl $path/load_agp.pl ".
            "--host $h->{host} --port $h->{port} --user $h->{user} --pass $h->{pass} ".
            "--dbname $h->{core} ".
            "--assembled_name chromosome -assembled_version $h->{version} ".
            "--component_name scaffold ".
            "-agp_file $h->{agp_file}";
    say $cmd,"\n";
    system($cmd);

}

#========================================
sub copy_meta {
#========================================
    my ($h, $dbh) = @_;
    my ($sql, $sth);

    ##Deleting current meta
    $sql = "delete from $h->{'core'}.meta";
    $sth = $dbh->prepare($sql);
    $sth->execute();

    ##Copying meta from other source
    $sql = qq{
    insert into $h->{'core'}.meta
    (select * from $h->{'meta_source'}.meta)
    };
    $sth = $dbh->prepare($sql);
    $sth->execute();

    ##Add test regarding the version

    ##Cleaning up meta table (repeats and patches)
    $sql = "delete from $h->{'core'}.meta where meta_key rlike ";
    my @keys = qw/patch repeat/;
    for my $key (@keys){
        my $sql_to_run = $sql."'$key'";
        $sth = $dbh->prepare($sql_to_run);
        $sth->execute();
    }

}

#========================================
sub add_seq_region_attribs {
#========================================
    my ($h, $dbh) = @_;
    my ($sql, $sth);

    print Dumper $dbh;

    my $seq_region_file = $h->{seq_region_file};
    my $core = $h->{core};

    ##Get the seq_regions
    $sql = "select seq_region_id, name from $core.seq_region where coord_system_id=2 order by name asc;";
    $sth = $dbh->prepare($sql);
    $sth->execute();

    my $rank = 1;
    while (my $ref = $sth->fetchrow_hashref()) {
        my ($seq_region_id, $name) = ($ref->{seq_region_id},$ref->{name});

        my $comp;
        if ($name =~ /\d(\w)/){
            $comp = $1;
        }
        elsif ($name = 'Un'){
            $comp = 'U';
        }
        else{
            say "no $comp for $name";
        }

        ##Insert polyploid value
        my $sql = qq{
            insert into $core.seq_region_attrib
                (seq_region_id, attrib_type_id, value)
            values
                ($seq_region_id, 425, '$comp');
        };
        run_sql($dbh,$sql,$core);

        ##Insert top level
        $sql = qq{
            insert into $core.seq_region_attrib
                (seq_region_id, attrib_type_id, value)
            values
                ($seq_region_id, 6, '1');
        };
        run_sql($dbh,$sql,$core);


        ##Insert karyotype rank
        $sql = qq{
            insert into $core.seq_region_attrib
                (seq_region_id, attrib_type_id, value)
            values
                ($seq_region_id, 367, $rank);
        };
        run_sql($dbh,$sql,$core);
        $rank++;
    }

    $sth->finish();
}

#========================================
sub run_sql {
#========================================
    my ($dbh, $sql, $core) = @_;

    say "running:\n $sql";
    my $sth = $dbh->prepare($sql);
    $sth->execute();
    $sth->finish();
}


#========================================
sub get_params {
#========================================
    my ($file) = @_;
    my $h = file2hash_tab($param_file);

    my $user = $h->{user};
    my $pass = $h->{pass};
    my $host = $h->{host};
    my $port = $h->{port};
    my $core = $h->{core};
    return ($user,$pass,$host,$port,$core);

}

#========================================
sub get_dbh {
#========================================
    my ($h) = @_;
    my $dsn = "DBI:mysql:host=$h->{host};port=$h->{port}";
    my $dbh = DBI->connect($dsn, $h->{user}, $h->{pass});
    return $dbh;
}

#========================================
sub usage {
#========================================
    say "Usage perl add_new_core --param_file=[PARAM_FILE]";
    exit 0;
}

