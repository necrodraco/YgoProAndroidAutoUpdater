#! /usr/bin/perl

use strict; 
use warnings; 
	
use Data::Dumper; 


##DON'T Change anything following
#Parameters without change: 
my $filename = "settings.properties";
my ($library, $imageWorker); 

##Imported Methods
use Library; 
use ImageWorker; 

##Actions
print "started Script\n";

$library = Library->new(filename => $filename);

#Read all the Properties from settings.properties and save them in $library->resources()
$library->readElementsResources(); 

print "Read settings.properties Finished\n";

if($library->resources()->{testing} eq "1"){
	print "Values contains: \n";
	print Dumper $library->resources();
}

##Do all Git Pulls
my @list = ($library->resources()->{liveImages},$library->resources()->{live2017},$library->resources()->{liveanime});
if($library->resources()->{testing} eq "1"){
	print "Git will Pull from these Paths: \n";
	print Dumper \@list;
}
$library->doGitPull(\@list);
print "pull finished\n";

#Only Upload Files if Something has changed
if($library->changes() == 1){
	print "Updated Local Instance of YgoPro Client completely\n";

	##Do All the Image-Things and Archiving Things
	$imageWorker = ImageWorker->new(library => $library); 
	$imageWorker->doImages();

	print "Updated the Images completely\n";

	##Do all the Script Files
	$library->doSymlink();

	##Do all the Sqlite-Doings
	$library->doSqlLite();

	##Do all to get the APK
	my %ais = (
			$library->resources()->{'nameOfSimpleApk'} => "full".$library->resources()->{'nameOfSimpleApk'}.".lua",
			$library->resources()->{'nameOfExperiencedApk'} => "full".$library->resources()->{'nameOfExperiencedApk'}.".lua"
	);
	$library->doApk(\%ais);

	##upload of the files to Github
	if($library->resources()->{'DoUpload'} == 1){
		$library->doUpload();
	}
}else{
	#print "upload only for test\n";
	#$library->doUpload();
	print "No changes, no Update\n";
}
print "finished Script\n";