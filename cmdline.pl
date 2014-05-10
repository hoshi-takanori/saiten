#!/usr/bin/perl

use strict;
use warnings;

use saiten::cmdline;

my $dbname = 'dbi:Pg:dbname=java_db;host=localhost';
my $dbuser = 'username';
my $dbpass = 'password';

my $cmd = saiten::cmdline->new($dbname, $dbuser, $dbpass);
$cmd->main(@ARGV);
