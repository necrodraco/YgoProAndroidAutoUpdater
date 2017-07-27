#!/usr/bin/env perl
use strict;
use warnings; 

##Contains all the Methods for manipulating the Images and OBB-Archives
package ImageWorker{
	use Moo; 
	use Image::Magick; 
	
	use Archive::Zip;
	use Archive::Zip qw(:ERROR_CODES); 
	no warnings 'experimental::smartmatch';
	use File::Find; 
	use Data::Dumper; 

	has library => (is => 'rw', required => 1);
	
	my @imageList = (); 
	my @mainImageList = ();
	my $image; 

	sub doPic($){
		my ($self, $ref) = @_; 
		my $imageS = @imageList; 
		print "Menge Imagelist".(Dumper $imageS)."\n";
		foreach my $file (@imageList){
			my @items = split(/pics/, $file);
			my $src = $items[0]."pics".$items[1]; 
			my $dest = $self->library->resources()->{imageFolder};
			$image = new Image::Magick; 
			$image->Read($src);
			$image->Set(quality=>'90');
			$image->Strip();
			$image->Write($dest.$items[1]);
		}
	}

	sub saveInArchive($){
		my ($self, $ref) = @_; 
		my @reference = @{$ref};
		my $archiveName = shift @reference; 
		my $items = shift @reference; 
		my $split = shift @reference || 0;#The Archive should be splitted if 1
		
		my $archive = Archive::Zip->new();
		foreach my $key(keys %$items){
			if($key =~ /folder/){
				$archive->addTree($items->{$key}."/", $items->{$key});
			}else{
				$archive->addFile($items->{$key}) or die "Error during Add File";
			}
		}
		$archive->writeToFileNamed($archiveName) == AZ_OK or die "Error during writing to Archive ";
		if($split == 1){
			$self->library->doCommand('split -b 50m "'.$archiveName.'" "'.$archiveName.'.part-"');
		}
	}

	sub doImages(){
		my $self = shift(); 
		print "Start Image Doings\n";
		##Create the pic-items
		find({ wanted => \&returnAllJumpedImages, no_chdir=>1}, $self->library->resources()->{pathToExceptPics});
		find({ wanted => \&returnAllImages, no_chdir=>1}, $self->library->resources()->{pathToYgopro}.$self->library->resources()->{liveImages});
		
		print "All listed Images are found\n";
		if($self->library->resources()->{testing} eq "1"){
			#print "All Images to add to patch.obb: ".(Dumper )."\n";
			#print "All Jumped Images: ".(Dumper @mainImageList)."\n";
		}
		$self->doPic();

		print "Finished prepare and storing Pics\n";

		##Do Archiving Part 1
		my %pathImage = ("folder1"=>"pics");
		my @args = (
			$self->library->resources()->{nameOfPatchOBB}, 
			\%pathImage
			);
		$self->saveInArchive(\@args);
		
		print "Archiving Pics to patch.obb finished\n";

		##DO Archiving Part 2
		my %pathArchiveFolderOnly = (
			"folder1" => "ai", 
			"file1" => $self->library->resources()->{nameOfPatchOBB},
			#"file2" => $self->library->resources()->{nameOfMainOBB}
			);
		@args = (
			$self->library->resources()->{nameOfZipFile}, 
			\%pathArchiveFolderOnly, 
			1
			);
		$self->saveInArchive(\@args);

		print "Archiving All Files to ".$self->library->resources()->{nameOfZipFile}." finished\n";
	}

	sub returnAllJumpedImages(){
	my $F = $File::Find::name; 
		if(/\.jpg$/){
			my $filename = (split(/\//, $F))[-1];
			push(@mainImageList, "$filename");
		}
	}

	sub returnAllImages(){
		my $F = $File::Find::name; 
		if($F =~ /\.jpg$/){
			my $filename = (split(/\//, $F))[-1];
			if(!($filename ~~ @mainImageList)){
				push(@imageList, "$F");
			}
		}
	}
}

1; 