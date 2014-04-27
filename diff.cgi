#!/usr/bin/perl

use strict;
use warnings;

use File::Basename;
use saiten::diff_app;

my $title = 'Diff Test';
my $cgi_file = basename($0);

my $app = saiten::diff_app->new($title, $cgi_file);
$app->set(old_file => 'test-1.txt', new_file => 'test-2.txt');
$app->main;
