package saiten::fresh_db;

use base 'saiten::saiten_db';

use strict;
use warnings;

#
# home ページ
#

# $db->exercise_for($fresh) : @rows of [$id, $level]
# 新人 $fresh が報告できる問題のリストを、必須問題、オプション問題の順に返す。
sub exercise_for {
	my ($db, $fresh) = @_;
	my $sql = 'select id, level from exercise where id not in (select ' .
			'exercise_id from answer where fresh_name = ? and status = 4) ' .
			'order by level, part, chapter, number';
	return $db->query_all("新人 $fresh の問題リストの取得", $sql, $fresh);
}

#
# report ページ
#

# $db->last_serial($fresh, $exercise) : $serial, $status
# 新人 $fresh の問題 $exercise の最新の報告が何回目になるかを返す。
sub last_serial {
	my ($db, $fresh, $exercise) = @_;
	my ($serial, $status) = $db->query_one(undef, $db->sql(
			'select serial, status from answer',
			where => [fresh_name => $fresh, exercise_id => $exercise],
			order => 'serial desc'));
	return $serial || 0, $status;
}

# $db->insert_answer($fresh, $exercise, $serial)
# answer テーブルに ($fresh, $exercise, $serial) の報告済みデータを追加する。
sub insert_answer {
	my ($db, $fresh, $exercise, $serial) = @_;
	my $sql = 'insert into answer values (?, ?, ?)';
	$db->query("問題 $exercise の報告", $sql, $fresh, $exercise, $serial);
}

#
# cancel ページ
#

# $db->delete_answer($fresh, $exercise, $serial)
# answer テーブルから ($fresh, $exercise, $serial) の報告済みデータを削除する。
sub delete_answer {
	my ($db, $fresh, $exercise, $serial) = @_;
	$db->query("問題 $exercise の報告の削除", $db->sql(
			'delete from answer', where => [fresh_name => $fresh,
					exercise_id => $exercise, serial => $serial]));
}

# $db->insert_cancel($fresh, $exercise, $serial)
# cancel テーブルに ($fresh, $exercise, $serial) の取り消しログを追加する。
sub insert_cancel {
	my ($db, $fresh, $exercise, $serial) = @_;
	my $sql = 'insert into cancel values (?, ?, ?)';
	$db->query(undef, $sql, $fresh, $exercise, $serial);
}

1;
