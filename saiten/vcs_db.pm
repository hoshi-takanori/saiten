package saiten::vcs_db;

use base 'saiten::db';

use strict;
use warnings;

#
# コンストラクタ
#

# saiten::vcs_db->new($error, $repo, $fresh, $base, $path)
# コンストラクタ。引数はリポジトリのパスなど。
sub new {
	my ($class, $error, $repo, $fresh, $base, $path) = @_;
	my $vcs = $class->SUPER::new($error, $repo);
	$vcs->{fresh} = $fresh;
	$vcs->{base} = $base;
	$vcs->{path} = (defined $base ? $base . '/' : '') . $path;
	return $vcs;
}

#
# vcs ルーチン
#

# $vcs->revs : @revs
# リビジョン番号のリストを返す。
sub revs {
	my $vcs = shift;
	if (! defined $vcs->{revs}) {
		my @rows = $vcs->query_all('リビジョン番号の取得', $vcs->sql(
				'select rev from vcs',
				where => [fresh => $vcs->{fresh}, path => $vcs->{path}],
				order => 'date desc'));
		$vcs->{revs} = [];
		foreach my $row (@rows) {
			my ($rev) = @$row;
			push @{$vcs->{revs}}, $rev;
		}
	}
	return @{$vcs->{revs}};
}

# $vcs->info($rev) : $author, $date, $log
# 各リビジョンの情報を取得する。
sub info {
	my ($vcs, $rev) = @_;
	if (! defined $rev || $rev !~ /^[0-9.]+$/) {
		$vcs->error('リビジョン番号が不適切です。');
	}
	if (! defined $vcs->{info}->{$rev}) {
		my ($author, $date, $log) = $vcs->query_one('情報の取得', $vcs->sql(
				'select author, date, log from vcs',
				where => [fresh => $vcs->{fresh}, path => $vcs->{path},
						rev => $rev]));
		$date =~ s/^(\d+-\d+-\d+ \d+:\d+:\d+) .*$/$1/;
		$vcs->{info}->{$rev} = [ $author, $date, $log ];
	}
	return @{$vcs->{info}->{$rev}};
}

# $vcs->cat($rev) : @cat
# 指定されたリビジョンのソースを取得する。
sub cat {
	my ($vcs, $rev) = @_;
	if (! defined $rev || $rev !~ /^[0-9.]+$/) {
		$vcs->error('リビジョン番号が不適切です。');
	}
	if (! defined $vcs->{cats}->{$rev}) {
		my ($cat) = $vcs->query_one('ソースの取得', $vcs->sql(
				'select cat from vcs',
				where => [fresh => $vcs->{fresh}, path => $vcs->{path},
						rev => $rev]));
		my @cat = split "\n", $cat;
		$vcs->{cats}->{$rev} = \@cat;
	}
	return @{$vcs->{cats}->{$rev}};
}

# $vcs->ls_files($dirname) : @files
# 指定されたディレクトリにあるファイルのリストを返す。
sub ls_files {
	my ($vcs, $dirname) = @_;
	$dirname = $vcs->{base} . '/' . $dirname if defined $vcs->{base};
	my @rows = $vcs->query_all('ファイルのリストの取得', $vcs->sql(
			'select distinct path from vcs',
			where => [fresh => $vcs->{fresh},
					'path like ?' => $dirname . '/%',
					'path not like ?' => '%/Attic/%']));
	my @files;
	foreach my $row (@rows) {
		my ($path) = @$row;
		push @files, substr($path, length($dirname) + 1);
	}
	return @files;
}

1;
