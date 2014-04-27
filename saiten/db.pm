package saiten::db;

use strict;
use warnings;

use DBI;

#
# コンストラクタ
#

# saiten::db->new($error, $dbname [, $dbuser [, $dbpass]])
# コンストラクタ。引数はエラールーチンと DB 名とユーザー名とパスワード。
sub new {
	my ($class, $error, $dbname, $dbuser, $dbpass) = @_;
	my $db = bless { error => $error }, $class;
	$db->connect($dbname, $dbuser, $dbpass);
	return $db;
}

#
# 基本ルーチン
#

# $db->error($message [, $message, ...])
# エラーメッセージを表示して終了。 エラールーチンがあれば、そっちが呼ばれる。
sub error {
	my ($db, @messages) = @_;
	if (defined $db->{error}) {
		$db->{error}->(@messages);
	}
	print STDERR "ERROR!\n";
	foreach (@messages) {
		print STDERR $_, /\n$/ ? '' : "\n";
	}
	exit 1;
}

# $db->connect($dbname, $dbuser, $dbpass)
# DB に接続する。失敗したらエラーメッセージを表示して終了。
sub connect {
	my ($db, $dbname, $dbuser, $dbpass) = @_;
	$db->{dbh} = DBI->connect($dbname, $dbuser, $dbpass, { PrintError => 0 })
		or $db->error("データベース $dbname への接続に失敗しました。",
				'エラーメッセージ：' . $DBI::errstr);
}

# $db->query($what, $sql [, @params]) : $sth
# クエリーを実行して $sth を返す。失敗したらエラーページを表示して終了。
# ただし、$what が undef ならば、クエリー実行時のエラーを無視する。
sub query {
	my ($db, $what, $sql, @params) = @_;
	my $sth = $db->{dbh}->prepare($sql)
		or $db->error('prepare 失敗：' . $sql,
				'エラーメッセージ：' . $db->{dbh}->errstr);
	my $rv = $sth->execute(@params);
	if (! $rv && defined $what) {
		$db->error(($what || 'クエリーの実行') . 'に失敗しました。',
				'エラーメッセージ：' . $sth->errstr);
	}
	return $rv ? $sth : undef;
}

# $db->query_all($what, $sql [, @params]) : @rows
# クエリーを実行して結果をすべて返す。失敗したらエラーページを表示して終了。
# ただし、$what が undef ならば、クエリー実行時のエラーを無視する。
sub query_all {
	my ($db, $what, $sql, @params) = @_;
	my $sth = $db->query($what, $sql, @params) or return ();
	my $rows = $sth->fetchall_arrayref;
	if ($sth->err && defined $what) {
		$db->error(($what || 'クエリーの実行') . 'に失敗しました。',
				'エラーメッセージ：' . $sth->errstr);
	}
	return @$rows;
}

# $db->query_one($what, $sql [, @params]) : @row
# 結果が 1 行になる筈のクエリーを実行する。結果が 1 行でなければエラー。
# ただし、$what が undef ならばエラーを無視して、最初の行を返す。
sub query_one {
	my ($db, $what, $sql, @params) = @_;
	my @rows = $db->query_all($what, $sql, @params);
	my $cnt = $#rows + 1;
	if ($cnt != 1 && defined $what) {
		$db->error(($what || 'クエリーの実行') . ($cnt > 0 ?
				"の結果が $cnt 行ありました。" : 'ができませんでした。'));
	}
	return $cnt > 0 ? @{$rows[0]} : ();
}

# $db->sql_where($sql, $order [, $cond, $param [, ...]]) : $sql, @params
# $param が真ならば where 付きのクエリーとパラメータを返す。
sub sql_where {
	my ($db, $sql, $order, $where) = (shift, shift, shift, ' where ');
	my @params;
	while (@_) {
		my ($cond, $param) = (shift, shift);
		if (defined $param) {
			$sql .= $where . $cond;
			push @params, $param;
			$where = ' and ';
		}
	}
	if ($order) {
		$sql .= ' order by ' . $order;
	}
	return $sql, @params;
}

1;
