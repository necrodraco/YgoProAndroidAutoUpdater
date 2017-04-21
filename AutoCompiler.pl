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
our $values = ();
our ($ref, $image); 

##Imported Methods
use ImageWorker; 

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

##Do All the Image-Things and Archiving Things
doImages();

print "Updated the Images completely\n";

#Deprecated Actions
if($values->{testing} eq "1"){

	
	#doRest();
}

print "finished Script\n";