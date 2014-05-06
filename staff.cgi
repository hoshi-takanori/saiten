#!/usr/bin/perl

use strict;
use warnings;

use File::Basename;
use saiten::staff;

$ENV{LANG} = 'ja_JP.UTF-8';

my $title = 'Java 研修支援システム (スタッフ用)';
my $cgi_file = basename($0);

my $dbname = 'dbi:Pg:dbname=java_db;host=localhost';
my $dbuser = 'username';
my $dbpass = 'password';

my $app = saiten::staff->new($title, $cgi_file, $dbname, $dbuser, $dbpass);
$app->set(message_file => 'message-staff.txt');
$app->main;
