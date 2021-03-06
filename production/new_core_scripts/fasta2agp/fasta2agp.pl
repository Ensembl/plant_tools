#!/usr/bin/env perl
## Gets as input a fasta file with chunks and parses it into a virtual AGP file
## The fasta file is expected to have headers in this format: <chrom_num>_<chunk_num>

use 5.14.0;
use strict;
use warnings;

{
    my ($file) = @ARGV;
    if (@ARGV < 1){
        usage();
    }
    open IN, "<", $file or die "can't open $file\n";

    ##This is the starting chrom header, everytime it changes total_length becomes 0
    my $current_chr_header = 1;
    
    my ($chr_header,$chunk_header,$count,$chunk_length,$chunk_count,$total_length);
    while (my $line = <IN>){
        chomp($line);
        #if ($line =~ />(\d+\w)_(\d+)/){
        if ($line =~ />(\w+)_(\d+)/){
            if ($chunk_length){
                
                ##Get the coordinates for the start and end of the ASM part
                my $asm_start = $total_length+1;
                my $asm_end   = $total_length+$chunk_length;
                
                ##Print the output for the AGP file
                print "$chr_header\t$asm_start\t$asm_end\t$chunk_count\tW\t";
                say "$chunk_header\t1\t$chunk_length\t+";
                $total_length = $total_length + $chunk_length;
            }
            $chunk_length = 0;
            $chr_header   = $1;
            $chunk_count  = $2;
            
            ##If the chrom header changes, reset the total length
            if ($chr_header ne $current_chr_header){
                $total_length = 0;
                $current_chr_header = $chr_header;
            }

            ##The new chunk header for the new chunk
            $chunk_header = $chr_header."_".$chunk_count;
            next;
        }
        $chunk_length += length($line);
    } 
    
    ##Printout for the last chunk
    ##Get the coordinates for the start and end of the ASM part
    my $asm_start = $total_length+1;
    my $asm_end   = $total_length+$chunk_length;
    
    ##Print the output for the AGP file
    print "$chr_header\t$asm_start\t$asm_end\t$chunk_count\tW\t";
    say "$chunk_header\t1\t$chunk_length\t+";
    $total_length = $total_length + $chunk_length;

}


sub usage {
    say "Usage perl fasta2agp.pl [a] [b]";
    exit 0;
}
 
