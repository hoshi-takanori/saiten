package saiten::vcs;

use strict;
use warnings;

#
# コンストラクタ
#

# saiten::vcs->new($error, $repo, $path)
# コンストラクタ。引数はタイトルと CGI ファイル名。
sub new {
	my ($class, $error, $repo, $path) = @_;
	my $vcs = {
		error => $error,
		repo => $repo,
		path => $path,
		info => {},
		cats => {}
	};
	return bless $vcs, $class;
}

#
# 基本ルーチン
#

# $vcs->error($message [, $message, ...])
# エラーメッセージを表示して終了。 エラールーチンがあれば、そっちが呼ばれる。
sub error {
	my ($vcs, @messages) = @_;
	if (defined $vcs->{error}) {
		$vcs->{error}->(@messages);
	}
	print STDERR "ERROR!\n";
	foreach (@messages) {
		print STDERR $_, /\n$/ ? '' : "\n";
	}
	exit 1;
}

#
# svnlook ルーチン
#

# $vcs->svnlook($cmd, @args)
# svnlook コマンドを実行し、結果を返す。
sub svnlook {
	my ($vcs, $cmd, @args) = @_;
	open my $fh, '-|', 'svnlook', $cmd, $vcs->{repo}, @args
			or $vcs->error("svnlook $cmd failed");
	if (wantarray) {
		my @lines = <$fh>;
		close $fh;
		chomp @lines;
		return @lines;
	} else {
		local $/ = undef;
		my $lines = <$fh>;
		close $fh;
		return $lines;
	}
}

# $vcs->revs : @revs
# リビジョン番号のリストを返す。
sub revs {
	my $vcs = shift;
	if (! defined $vcs->{revs}) {
		my @lines = $vcs->svnlook('history', $vcs->{path});
		$vcs->{revs} = [];
		foreach my $line (@lines) {
			push @{$vcs->{revs}}, $1 if $line =~ /^\s*(\d+)\s/;
		}
	}
	return @{$vcs->{revs}};
}

# $vcs->info($rev) : $author, $date, $log
# 各リビジョンの情報を取得する。
sub info {
	my ($vcs, $rev) = @_;
	if (! defined $rev || $rev !~ /^[0-9]+$/) {
		$vcs->error('リビジョン番号が不適切です。');
	}
	if (! defined $vcs->{info}->{$rev}) {
		my ($author, $date, $len, @log) =
				$vcs->svnlook('info', '-r', $rev, $vcs->{path});
		$date =~ s/^(\d+-\d+-\d+ \d+:\d+:\d+) .*$/$1/;
		$vcs->{info}->{$rev} = [ $author, $date, join("\n", @log) ];
	}
	return @{$vcs->{info}->{$rev}};
}

# $vcs->cat($rev) : @cat
# 指定されたリビジョンのソースを取得する。
sub cat {
	my ($vcs, $rev) = @_;
	if (! defined $rev || $rev !~ /^[0-9]+$/) {
		$vcs->error('リビジョン番号が不適切です。');
	}
	if (! defined $vcs->{cats}->{$rev}) {
		my @cat = $vcs->svnlook('cat', '-r', $rev, $vcs->{path});
		$vcs->{cats}->{$rev} = \@cat;
	}
	return @{$vcs->{cats}->{$rev}};
}

# $vcs->ls_files($dirname) : @files
# 指定されたディレクトリにあるファイルのリストを返す。
sub ls_files {
	my ($vcs, $dirname) = @_;
	my @files;
	foreach my $path ($vcs->svnlook('tree', '--full-paths', $dirname)) {
		if (length($path) > length($dirname) + 1 &&
				index($path, $dirname . '/') == 0 && $path !~ /\/$/) {
			push @files, substr($path, length($dirname) + 1);
		}
	}
	return @files;
}

1;
