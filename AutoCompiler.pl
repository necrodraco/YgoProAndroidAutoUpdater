#! /usr/bin/perl

use strict; 
use warnings; 
use File::Find; 
use File::Copy;
use DBI; 
use Image::Magick; 
use Archive::Zip;
use Archive::Zip qw(:ERROR_CODES); 
use Data::Dumper; 
no warnings 'experimental::smartmatch';

##DON'T Change anything following
#Parameters without change: 
my $command; 
my $image;
my @pathsWithCDB = (); 
my @imageList = (); 
my $filename = "settings.properties";
my $values = ();
my $ref; 
##Methods: 
sub readMethods(){
	open(my $file, "<", $filename) or die "can't open ".$filename;
		while (my $row = <$file>) {
				if(!($row =~ "#")){
					my @items = split(/=/,$row);
					$items[1] =~ s/\n//g;
					$values->{$items[0]} = $items[1]; 
				}
			}
	close($file);
}

sub doCommand($){
	my $command = shift; 
	system "$command";
}
sub doGitPull($){
	my $refarg = shift; 
	my @arg = @{$refarg};
	foreach my $argument(@arg){
		$command = "cd ".$values->{pathToYgopro}.$argument." && git pull";
		system "$command";
	}
}

###############################################
##Deprecated Methods

sub returnAllDatabases(){
	my $F = $File::Find::name; 

	if($F =~ /\.cdb$/){
		push(@pathsWithCDB, "$F");#"\"$F\"");
	}
}
sub returnAllImages(){
	my $F = $File::Find::name; 
	if($F =~ /\.jpg$/){
		push(@imageList, "$F");
	}
}
sub prepareParams($){
	my $pathsRef = shift;
	my @paths = @{$pathsRef};
	my @lPath = (); 
	do{
		my $path = shift @paths;
		#if(1 > -M $path){
			if(!($path =~ m/\/language\//)){
				if($path =~ m/\/cards-tf.cdb/){
					unshift(@lPath, $path);
				}else{
					if($path =~ m/\/live2/){
						push(@lPath, $path);
					}else{
						if(@paths ~~ m/\/live2/){
							push(@paths, $path);
						}else{
							if($path =~ m/\/liveanime\//){
								push(@lPath, $path);
							}else{
								if(@paths ~~ m/\/liveanime\//){
									push(@paths, $path);
								}else{
									if($path =~ m/\/expansions\//){
										push(@lPath, $path);
									}else{
										if(@paths ~~ m/\/expansions\//){
											push(@paths, $path);
										}else{
											push(@lPath, $path);
										}
									}
								}
							}
						}
					}
				}
			}
		#}
	}while(@paths);
	return \@lPath;
}
sub doSqlLiteMerge($){
	$ref = shift; 
	my @list = @{$ref};
	my $dest = $values->{pathToApkFolder}."/assets/cards.cdb";
	my $src = shift @list; 
	copy($src, $dest) or die "Copy failed: $!";
	
	my $dbargs = {AutoCommit => 1, PrintError => 1};
	my $dbh = DBI->connect("dbi:SQLite:dbname=$dest", "", "", $dbargs);

	foreach my $cdbFile(@list){
		doSqlQuery($dbh, "attach '".$cdbFile."' as toMerge");
		doSqlQuery($dbh, "insert or ignore into datas select * from toMerge.datas");
		doSqlQuery($dbh, "insert or ignore into texts select * from toMerge.texts");
		doSqlQuery($dbh, "detach toMerge");
	}	
	$dbh->disconnect();
}
sub doSqlQuery($){
	my $dbh = shift; 
	my $statement = shift; 
	$dbh->do($statement)or die "$DBI::errstr\n"; 
}
sub doPic($){
	$ref = shift; 
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
sub doSymlink(){
	##Remove all Symlinks for the Script Files
	doCommand("cd ".$values->{pathToApkScriptFolder}." && rm *.lua");

	##Create all the Symlinks for the Script-Files
	doCommand("java -jar Symlinker.jar "
			.$values->{pathToApkScriptFolder}." "
			.$values->{manualFolder}." "
			.$values->{oldScriptFolder}." "
			.$values->{live2017ScriptFolder}." "
			.$values->{liveAnimeScriptFolder}." "
			.$values->{ygoproScriptFolder}
		);
}
sub doApk($){
	$ref = shift; 
	my %ai = %{$ref};
	foreach my $key(keys %ai){
		doCommand("cd ".$values->{pathToApkFolder}."/assets/ai && rm full.lua && ln -s ".$values->{pathToAIs}."".$ai{$key}." full.lua");

		##create the new APK
		doCommand("apktool b -o ".$values->{pathToApkFolder}.$key.".apk ".$values->{pathToApkFolder});

		##sign it
		doCommand("apksign ".$values->{pathToApkFolder}.$key.".apk"); 

		##rename
		doCommand("rm ".$values->{pathToApkFolder}.$key.".apk && mv ".$values->{pathToApkFolder}.$key.".s.apk ".$values->{pathToApkFolder}.$key.".apk"); 
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
sub doRest(){
	##Do all the Script Files
	doSymlink();

	##Do all the Sqlite-Shit
	find({ wanted => \&returnAllDatabases, no_chdir=>1}, $values->{pathToYgopro});
	doSqlLiteMerge(prepareParams(\@pathsWithCDB));

	##Do all to get the APK
	my %ais = (
			"_simple" => "full_simple.lua",
			"_experienced" => "full_experienced.lua"
		);
	doApk(\%ais);

	##upload
	##TODO
}

##############################################
##End of Deprecated Methods

##Actions
print "started Script\n";

#Read all the Properties from settings.properties and save them in $values
readMethods();
print "Read settings.properties Finished\n";

if($values->{testing} eq "1"){
	print "Values contains: \n";
	print Dumper $values;
}

##Do all Git Pulls
my @list = ($values->{liveImages},$values->{live2017},$values->{liveanime});
if($values->{testing} eq "1"){
	print "Git will Pull from these Paths: \n";
	print Dumper \@list;
}

doGitPull(\@list);

print "Updated Local Instance of YgoPro Client completely\n";

#Deprecated Actions
if($values->{testing} eq "1"){

	##Do All the Image-Things and Archiving Things
	#doImages();

	#doRest();
}

print "finished Script\n";