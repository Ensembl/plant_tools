use strict;
use warnings;
use Test::More tests => 2;

#ok( eval{ `perl exampleREST.pl` } =~ /zea_mays/ , 'exampleREST.pl' );

ok( eval{ `bash exampleFTP.sh --spider 2>&1` } !~ /No such file/ , 'exampleFTP.sh --spider ' );

ok( eval{ `bash exampleMySQL.sh` } =~ /COUNT/ , 'exampleMySQL.sh' );