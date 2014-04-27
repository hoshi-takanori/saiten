#!/usr/bin/perl

use strict;
use warnings;

use File::Basename;
use saiten::app;

my $title = 'Saiten Test';
my $cgi_file = basename($0);

my $app = saiten::app->new($title, $cgi_file);
$app->main;
