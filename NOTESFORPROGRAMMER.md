#NOTES FOR THE PROGRAMMER

#!/usr/bin/env perl
use strict;
use warnings;

use File::Find;
use Algorithm::Bucketizer;

my $bucketizer = Algorithm::Bucketizer->new( bucketsize => 4 * 1024 * 1024 * 1024 );

find( { wanted => sub { $bucketizer->add_item( $_, -s ) if (-f) }, no_chdir => 1 }, '.' );
$bucketizer->optimize( algorithm => 'random', maxtime => 10, maxrounds => 100 );

for my $b ( $bucketizer->buckets ) {
    print "\nBucket " . $b->serial . " (" . $b->level . "):\n";
    print "$_\n" for ( $b->items );
}