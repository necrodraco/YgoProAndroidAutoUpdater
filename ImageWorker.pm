#!/usr/bin/env perl
use strict;
use warnings; 
use Image::Magick; 
#require "AutoCompiler.pl";
our ($values, $image);
sub doPic($){
	my $ref = shift; 
	my @list = @{$ref};
	foreach my $file (@list){
		my @items = split(/pics/, $file);
		my $src = $items[0]."/pics".$items[1]; 
		my $dest = $values->{imageFolder};

		$image = new Image::Magick; 
		$image->Read($src);
		$image->Set(quality=>'90');
		$image->Strip();
		$image->Write($dest.$items[1]);
	}
}


1; 