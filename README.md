# YgoProAndroidAutoUpdater
Script which allows automatically Update YgoProAndroid. In Developing

#Tested Only on Linux / Ubuntu

#On Windows you could get problems with e.g. the Symlinker

#Need to be installed: 
perl #test with perl --version
java #test with java -version
perl sqlite3 Module # install on Ubuntu by sudo apt-get install libdbd-sqlite3-perl
ImageMagic #install on Ubuntu by sudo apt-get install imagemagick imagemagick-doc
perl MooX Module
Git LTS #Look for documentation #Only needed when Fill out the Upload-Options
Apktool #Can be found here: https://ibotpeaches.github.io/Apktool/
Apksign #Can be found here: https://github.com/appium/sign
YGOPRO Liveimages #Can be found here:  run "git clone https://github.com/Ygoproco/Live-images.git" in /ygopro of your desktopClient

#How To use: 
1. Rename/copy the "template.properties" to "settings.properties"
2. Fill in all the Lines
3. Run perl AutoCompiler.pl