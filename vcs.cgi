#!/usr/bin/perl

use strict;
use warnings;

use File::Basename;
use saiten::vcs_app;

$ENV{LANG} = 'ja_JP.UTF-8';

my $title = 'ソース閲覧システム';
my $cgi_file = basename($0);

my $dbname = 'dbi:Pg:dbname=java_db;host=localhost';
my $dbuser = 'username';
my $dbpass = 'password';

my @exercises = (
	'basic-1-1', 'basic-1-2',
	'basic-2-1', 'basic-2-2', 'basic-2-3', 'basic-2-4',
	'basic-3-1', 'basic-3-2', 'basic-3-3',

	'comp-1', 'comp-2',

	'basic-4-1', 'basic-4-2', 'basic-4-3',
	'basic-5-1', 'basic-5-2',
);

my @notice = (
	'5/9 ソース閲覧システム、はじめました。',
);

my $app = saiten::vcs_app->new($title, $cgi_file, $dbname, $dbuser, $dbpass);
$app->set(exercises => \@exercises, notice => \@notice);
$app->main;
