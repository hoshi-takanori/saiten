#!/usr/bin/perl

use strict;
use warnings;

use File::Basename;
use saiten::fresh;

$ENV{LANG} = 'ja_JP.UTF-8';

my $title = 'Java 研修支援システム';
my $cgi_file = basename($0);

my $dbname = 'dbi:Pg:dbname=java_db;host=localhost';
my $dbuser = 'username';
my $dbpass = 'password';

my $app = saiten::fresh->new($title, $cgi_file, $dbname, $dbuser, $dbpass);
$app->set(message_file => 'message-fresh.txt', vcs_mode => 1);
$app->main;
