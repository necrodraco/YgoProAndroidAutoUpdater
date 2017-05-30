#!/usr/bin/env perl
use strict;
use warnings; 

package Library{
	use Moo; 
	use File::Find; 
	use File::Copy;
	use DBI; 
	
	no warnings 'experimental::smartmatch';

	has filename => (is => 'rw', required => 1);
	has resources => ( is => 'rw');

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
			$self->doCommand("cd ".$self->resources()->{pathToYgopro}.$argument.
				" && git pull");
		}
	}
	sub doUpload(){	
		my $self = shift(); 
		$self->doCommand("cd ".$self->resources()->{nameOfOutput}." && git add * ");
		$self->doCommand("cd ~/Downloads/test && git status");
		#my $versionNumber = $self->version();

		#$self->doCommand("cd ~/Downloads/test && git commit -m 'Automatic Upload:'".$versionNumber);
		#$self->doCommand("cd ~/Downloads/test && git push origin master");

		print "Upload finished\n";
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
}
1; 
