import sys
import re

##Get the mrna id from the line
def get_id(line):
    r1 = re.findall(r"ID=(.*?);", line)
    id = r1[0]
    return id

#======================================== 
#Main
#========================================
filename1 = sys.argv[1]
filename2 = sys.argv[2]
dict = {}

f1 = open(filename1)
for line in f1:
    ##Get the mRNA id if exists
    line = line.rstrip('\n')
    if re.search(r'mRNA', line):
        mrna_id = get_id(line)
        continue
    
    ##Add the exons to the dict for the mRNA id
    if mrna_id not in dict.keys():
        dict[mrna_id] = []
    dict[mrna_id].append(line)

f2 = open(filename2)
for line in f2:
    ##mRNA line - print it and the exons associated
    line = line.rstrip('\n')
    if re.search(r'mRNA', line):
        mrna_id = get_id(line)
        print(line)

        ##Get the exons from dict using mrna_id
        exons = dict[mrna_id]
        for e in exons:
            print(e)
        continue
    
    ##Regular line just print
    print(line)

#=========================================== 
## This script takes two GFF3 files, one with mRNA and exons
## chr01   irgsp1_rep      mRNA    2983    10815   .       +       .       ID=Os01t0100100-01;Name=Os01t0100100-01;Locus_id=Os01g0100100;Note=RabGAP/TBC domain containing protein.;Transcript_evidence=AK242339 (DDBJ%2C antisense transcript);ORF_evidence=Q655M0 (UniProt);GO=Molecular Function: Rab GTPase activator activity (GO:0005097),Cellular Component: intracellular (GO:0005622),Biological Process: regulation of Rab GTPase activity (GO:0032313);InterPro=RabGAP/TBC (IPR000195)
##chr01   irgsp1_rep      exon    2983    3268    .       +       .       Parent=Os01t0100100-01
##chr01   irgsp1_rep      exon    3354    3616    .       +       .       Parent=Os01t0100100-01
##chr01   irgsp1_rep      exon    4357    4455    .       +       .       Parent=Os01t0100100-01

#
#
## and another with mRNAs and CDs
##chr01  irgsp1_rep      mRNA    2983    10815   .       +       .       ID=Os01t0100100-01;..Locus_id=Os01g0100100;...
##chr01  irgsp1_rep      five_prime_UTR  2983    3268    .       +       .       Parent=Os01t0100100-01
##chr01  irgsp1_rep      five_prime_UTR  3354    3448    .       +       .       Parent=Os01t0100100-01
##chr01  irgsp1_rep      CDS     3449    3616    .       +       0       Parent=Os01t0100100-01
#
## and merges them

