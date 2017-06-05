#!/usr/bin/env perl
use strict;
use warnings; 

package Library{
	use Moo; 
	use File::Find; 
	use File::Copy;
	use DBI; 
	use Git::Repository; 
	
	no warnings 'experimental::smartmatch';

	has filename => (is => 'rw', required => 1);
	has resources => ( is => 'rw');
	has changes => (is => 'rw', default => 0); 

	my @pathsWithCDB = (); 

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
	sub doGitPull($){
		my ($self, $refarg) = @_;
		my @arg = @{$refarg};
		foreach my $argument(@arg){
			my $repo = Git::Repository->new(git_dir => $self->resources()->{pathToYgopro}.$argument."/.git");
			my $status = $repo->run('pull');
			if($status ne 'Bereits aktuell.'){
				$self->changes(1); 
			}
		}
	}
	sub doUpload(){	
		my $self = shift(); 
		#print "Go in Drive Upload\n";
		#$self->placeFiles($self->resources()->{pathToDrive}, 0, "");
		$self->placeFiles($self->resources()->{nameOfOutput}, 1, ".*");
		print "Drive Upload finished\n";
		print "Upload finished\n";
	}
	sub placeFiles(){
		my ($self, $pathToPlace, $git, $part) = @_; 

		$self->doCommand("cp -t ".$pathToPlace." pics_normal.zip".$part." ygopro".$self->resources()->{nameOfExperiencedApk}.".apk");
		$self->doCommand("cp ygopro".$self->resources()->{nameOfSimpleApk}.".apk ".$pathToPlace."/".$self->resources()->{nameOfApk});
		if($git){
			$self->doCommand("cd ".$pathToPlace." && git add * ");
			$self->doCommand("cd ".$pathToPlace." && git status");
			my $versionNumber = $self->version();

			$self->doCommand("cd ".$pathToPlace." && git commit -m 'Automatic Upload: ".$versionNumber."'");
			$self->doCommand("cd ".$pathToPlace." && git push origin master");
		}
	}
	sub version(){
		my ($self, $versionNumber) = @_; 
		open(my $versionRead, "<", "version.md"); 
			$versionNumber = <$versionRead>;
		close($versionRead);
		
		my @versions = split("v", $versionNumber);
		$versions[1] = $versions[1] + 1;
		$versionNumber = join("v", @versions);
		
		open(my $versionWrite, ">", "version.md"); 
			print $versionWrite $versionNumber; 
		close($versionWrite); 
		return $versionNumber; 
	}
	sub doSymlink(){
		my $self = shift(); 
		##Remove all Symlinks for the Script Files
		$self->doCommand("cd ".$self->resources()->{pathToApkScriptFolder}.
			" && rm *.lua");

		##Create all the Symlinks for the Script-Files
		$self->doCommand("java -jar Symlinker.jar "
				.$self->resources()->{pathToApkScriptFolder}." "
				.$self->resources()->{manualFolder}." "
				.$self->resources()->{oldScriptFolder}." "
				.$self->resources()->{live2017ScriptFolder}." "
				.$self->resources()->{liveAnimeScriptFolder}." "
				.$self->resources()->{ygoproScriptFolder}
		);
	}
	sub doApk($){
		my ($self, $ref) = @_; 
		my %ai = %{$ref};
		foreach my $key(keys %ai){
			
			$self->doCommand("rm ".$self->resources()->{pathToApkFolder}."/assets/ai/full.lua");
			
			$self->doCommand("ln -s ".$self->resources()->{pathOfAIs}."/".$ai{$key}." ".
				$self->resources()->{pathToApkFolder}."/assets/ai/full.lua");

			##create the new APK
			$self->doCommand("apktool b -o ".$self->resources()->{pathToApkFolder}.$key.".apk ".
				$self->resources()->{pathToApkFolder});

			##sign it
			$self->doCommand("apksign ".$self->resources()->{pathToApkFolder}.$key.".apk"); 

			##rename
			$self->doCommand("rm ".$self->resources()->{pathToApkFolder}.$key.".apk && mv ".
				$self->resources()->{pathToApkFolder}.$key.".s.apk ".
				$self->resources()->{pathToApkFolder}.$key.".apk"
				); 
		}
	}
	sub returnAllDatabases(){
		my $F = $File::Find::name; 

		if($F =~ /\.cdb$/){
			push(@pathsWithCDB, "$F");
		}
	}
	sub doSqlLite($){
		my $self = shift(); 
		find({ wanted => \&returnAllDatabases, no_chdir=>1}, $self->resources()->{pathToYgopro});
		my $ref = prepareParams(\@pathsWithCDB); 
		my @list = @{$ref};
		my $dest = $self->resources()->{pathToApkFolder}."/assets/cards.cdb";
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
			);
		doSqlQuery($dbh, "update datas set ot = 3 where ot = 4");

		$dbh->disconnect();
	}
	sub doSqlQuery($){
		my $dbh = shift; 
		my $statement = shift; 
		$dbh->do($statement)or die "$DBI::errstr\n"; 
	}
	sub prepareParams($){
		my $pathsRef = shift;
		my @paths = @{$pathsRef};
		my @lPath = (); 
		do{
			my $path = shift @paths;
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
		}while(@paths);
		return \@lPath;
	}
}
1; 
