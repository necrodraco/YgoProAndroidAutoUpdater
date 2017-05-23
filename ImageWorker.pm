#!/usr/bin/env perl
use strict;
use warnings; 
use Image::Magick; 
our ($library, $image, $ref, @imageList, @mainImageList);

##Contains all the Methods for manipulating the Images and OBB-Archives


sub doPic($){
	$ref = shift; 
	my @list = @{$ref};
	foreach my $file (@list){
		my @items = split(/pics/, $file);
		my $src = $items[0]."pics".$items[1]; 
		my $dest = $library->resources()->{imageFolder};

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
			$archive->addTree($items->{$key}."/", $items->{$key});
		}else{
			$archive->addFile($items->{$key}) or die "Error during Add File";
		}
	}
	$archive->writeToFileNamed($archiveName) == AZ_OK or die "Error during writing to Archive ";
	$library->doCommand('split -b 64m "'.$archiveName.'" "'.$archiveName.'.part-"');
}

sub doImages(){
	print "Start Image Doings\n";
	##Create the pic-items
	find({ wanted => \&returnAllJumpedImages, no_chdir=>1}, $library->resources()->{pathToExceptPics});#.$library->resources()->{liveImages});
	find({ wanted => \&returnAllImages, no_chdir=>1}, $library->resources()->{pathToYgopro}.$library->resources()->{liveImages});
	
	print "All listed Images are founded\n";
	if($library->resources()->{testing} eq "1"){
		#print "All Images to add to patch.obb: ".(Dumper )."\n";
		#print "All Jumped Images: ".(Dumper @mainImageList)."\n";
	}
	doPic(\@imageList);

	print "Finished prepare and storing Pics\n";

	##Do Archiving Part 1
	my %pathImage = ("folder1"=>"pics");
	my @args = (
		$library->resources()->{nameOfPatchOBB}, 
		\%pathImage
		);
	saveInArchive(\@args);
	
	print "Archiving Pics to patch.obb finished\n";

	##DO Archiving Part 2
	my %pathArchiveFolderOnly = (
		"folder1" => "ai", 
		"file1" => $library->resources()->{nameOfPatchOBB},
		#"file2" => $library->resources()->{nameOfMainOBB}
		);
	@args = (
		$library->resources()->{nameOfZipFile}, 
		\%pathArchiveFolderOnly
		);
	saveInArchive(\@args);

	print "Archiving All Files to ".$library->resources()->{nameOfZipFile}." finished\n";
}


1; 