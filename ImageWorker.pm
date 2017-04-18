#!/usr/bin/env perl
use strict;
use warnings; 
use Image::Magick; 
our ($values, $image);

##Contains all the Methods for manipulating the Images and OBB-Archives
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

sub saveInArchive($){
	$ref = shift; 
	my @reference = @{$ref};
	my $archiveName = shift @reference; 
	my $items = shift @reference; 
	my $archive = Archive::Zip->new();
	foreach my $key(keys %$items){
		if($key =~ /folder/){
			$archive->addTree($items->{$key}."/", $items->{$key});#$pathToAddingFolder, $folderItems{$key});
		}else{
			$archive->addFile($items->{$key}) or die "Error during Add File";
		}
	}
	$archive->writeToFileNamed($archiveName) == AZ_OK or die "Error during writing to Archive ";
}

sub doImages(){
	##Create the pic-items
	find({ wanted => \&returnAllImages, no_chdir=>1}, $values->{pathToYgopro}.$values->{liveImages});#."/pics");
	doPic(\@imageList);

	##Do Archiving Part 1
	my %pathImage = ("folder1"=>"pics");
	my @args = (
		"main.4.co.ygopro.ygoproandroid.obb", 
		\%pathImage
		);
	saveInArchive(\@args);

	##DO Archiving Part 2
	my %pathArchiveFolderOnly = (
		"folder1" => "ai", 
		"file1" => "patch.48.co.ygopro.ygoproandroid.obb",
		"file2" => "main.4.co.ygopro.ygoproandroid.obb"
		);
	@args = (
		"pics_normal.zip", 
		\%pathArchiveFolderOnly
		);
	saveInArchive(\@args);
}


1; 