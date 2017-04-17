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
