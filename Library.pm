#!/usr/bin/env perl
use strict;
use warnings; 

package Library{
	use Moo; 

	has filename => (is => 'rw', required => 1);
	has resources => ( is => 'rw');

	sub readElementsResources($){
		my $self = shift();
		open(my $file, "<", $self->filename()) or die "can't open ".$self->filename();
		my $values = ();
		while (my $row = <$file>) {
				if(!($row =~ "#")){
					my @items = split(/=/,$row);
					$items[1] =~ s/\n//g;
					$values->{$items[0]} = $items[1]; 
				}
			}
		close($file);
		$self->resources($values);
	}

	sub doCommand($){
		my ($self, $command) = @_;
		if(defined($command) && $command ne ""){
			system "$command"; 
		}else{
			print "One Command was not set. \n";
		}
	}
}
1; 
