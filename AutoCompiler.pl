#! /usr/bin/perl

use strict; 
use warnings; 
use File::Find; 
use File::Copy;
use DBI; 
use Archive::Zip;
use Archive::Zip qw(:ERROR_CODES); 
use Data::Dumper; 

no warnings 'experimental::smartmatch';

##DON'T Change anything following
#Parameters without change: 
my $command; 
my @pathsWithCDB = (); 
our @imageList = (); 
our @mainImageList = ();
my $filename = "settings.properties";
our ($ref, $image); 
our $library; 

##Imported Methods
use Library; 
use ImageWorker; 

##Methods: 
sub doGitPull($){
	my $refarg = shift; 
	my @arg = @{$refarg};
	foreach my $argument(@arg){
		$library->doCommand("cd ".$library->resources()->{pathToYgopro}.$argument.
			" && git pull");
	}
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

###############################################
##Deprecated Methods
sub returnAllDatabases(){
	my $F = $File::Find::name; 

	if($F =~ /\.cdb$/){
		push(@pathsWithCDB, "$F");
	}
}
sub prepareParams($){
	my $pathsRef = shift;
	my @paths = @{$pathsRef};
	my @lPath = (); 
	do{
		my $path = shift @paths;
		if(1 || 1 > -M $path){
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
		}
	}while(@paths);
	return \@lPath;
}
sub doSqlLiteMerge($){
	$ref = shift; 
	my @list = @{$ref};
	my $dest = $library->resources()->{pathToApkFolder}."/assets/cards.cdb";
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

	#Change all Anime Cards to Non-Anime
	doSqlQuery(
			$dbh, 
			"update texts set name = name || '(Anime)' where id IN(select d.id FROM datas d JOIN texts t WHERE t.name NOT LIKE '%(%)' AND d.ot = 4)"
			#UPDATE closure SET checked = 0 WHERE item_id IN (SELECT id FROM item WHERE ancestor_id = 1);
		);
	doSqlQuery($dbh, "update datas set ot = 3 where ot = 4");

	$dbh->disconnect();
}
sub doSqlQuery($){
	my $dbh = shift; 
	my $statement = shift; 
	$dbh->do($statement)or die "$DBI::errstr\n"; 
}
sub doSymlink(){
	##Remove all Symlinks for the Script Files
	$library->doCommand("cd ".$library->resources()->{pathToApkScriptFolder}.
		" && rm *.lua");

	##Create all the Symlinks for the Script-Files
	$library->doCommand("java -jar Symlinker.jar "
			.$library->resources()->{pathToApkScriptFolder}." "
			.$library->resources()->{manualFolder}." "
			.$library->resources()->{oldScriptFolder}." "
			.$library->resources()->{live2017ScriptFolder}." "
			.$library->resources()->{liveAnimeScriptFolder}." "
			.$library->resources()->{ygoproScriptFolder}
		);
}
sub doApk($){
	$ref = shift; 
	my %ai = %{$ref};
	foreach my $key(keys %ai){
		
		$library->doCommand("rm ".$library->resources()->{pathToApkFolder}."/assets/ai/full.lua");
		
		$library->doCommand("ln -s ".$library->resources()->{pathOfAIs}."/".$ai{$key}." ".
			$library->resources()->{pathToApkFolder}."/assets/ai/full.lua");

		##create the new APK
		$library->doCommand("apktool b -o ".$library->resources()->{pathToApkFolder}.$key.".apk ".
			$library->resources()->{pathToApkFolder});

		##sign it
		$library->doCommand("apksign ".$library->resources()->{pathToApkFolder}.$key.".apk"); 

		##rename
		$library->doCommand("rm ".$library->resources()->{pathToApkFolder}.$key.".apk && mv ".
			$library->resources()->{pathToApkFolder}.$key.".s.apk ".
			$library->resources()->{pathToApkFolder}.$key.".apk"
			); 
	}
}
sub doRest(){
	##Do all the Script Files
	doSymlink();

	##Do all the Sqlite-Shit
	find({ wanted => \&returnAllDatabases, no_chdir=>1}, $library->resources()->{pathToYgopro});
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

#Read all the Properties from settings.properties and save them in $library->resources()
$library = Library->new(filename => $filename);

$library->readElementsResources(); 

print "Read settings.properties Finished\n";

if($library->resources()->{testing} eq "1" && 0){
	print "Values contains: \n";
	print Dumper $library->resources();
}

##Do all Git Pulls
my @list = ($library->resources()->{liveImages},$library->resources()->{live2017},$library->resources()->{liveanime});
if($library->resources()->{testing} eq "1" && 0){
	print "Git will Pull from these Paths: \n";
	print Dumper \@list;
}
doGitPull(\@list);

print "Updated Local Instance of YgoPro Client completely\n";

##Do All the Image-Things and Archiving Things
doImages();

print "Updated the Images completely\n";

#Deprecated Actions
if($library->resources()->{testing} eq "1"){
	doRest();
}

print "finished Script\n";