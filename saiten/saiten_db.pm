package saiten::saiten_db;

use base 'saiten::db';

use strict;
use warnings;

#
# 確認ルーチン
#

# $db->check_class($class) : $num_fresh
# クラス番号 $class に新人が存在するか確認し、そのクラスの新人の人数を返す。
sub check_class {
	my ($db, $class) = @_;
	my ($num_fresh) = $db->query_one('新人の人数の取得', $db->sql(
			'select count(*) from fresh',
			$class ? (where => [class => $class]) : ()));
	if (! $num_fresh) {
		$db->error('そのクラスには誰もいません。');
	}
	return $num_fresh;
}

# $db->check_fresh($fresh) : $fresh_name, $fresh_class
# 新人 $fresh が DB に登録されていることを確認し、氏名と所属クラスを返す。
sub check_fresh {
	my ($db, $fresh) = @_;
	if (! defined $fresh || $fresh !~ /^[a-z0-9\-]+$/) {
		$db->error('新人のログイン名が不適切です。');
	}
	return $db->query_one("新人 $fresh の情報の取得",
			'select k_name, class from fresh where name = ?', $fresh);
}

# $db->check_staff($staff) : $staff_name, $staff_class
# スタッフ $staff が DB に登録されていることを確認し、氏名と所属クラスを返す。
sub check_staff {
	my ($db, $staff) = @_;
	if (! defined $staff || $staff !~ /^[a-z0-9\-]+$/) {
		$db->error('スタッフのログイン名が不適切です。');
	}
	return $db->query_one("スタッフ $staff の情報の取得",
			'select k_name, class from staff where name = ?', $staff);
}

# $db->check_exercise($exercise) : $level
# 問題 $exercise が DB に登録されていることを確認し、その問題のレベルを返す。
sub check_exercise {
	my ($db, $exercise) = @_;
	if (! defined $exercise || $exercise !~ /^[a-z0-9\-]+$/) {
		$db->error('問題番号が不適切です。');
	}
	return $db->query_one("問題 $exercise の情報の取得",
			'select level from exercise where id = ?', $exercise);
}

# $db->check_serial($fresh, $exercise, $serial) : $status, $saiten_staff
# 新人 $fresh の問題 $exercise の答案が $serial 回目であることを確認する。
sub check_serial {
	my ($db, $fresh, $exercise, $serial) = @_;
	my @row = $db->query_one('提出回数の取得', $db->sql(
			'select serial, status, staff_name from answer_unique',
			where => [fresh_name => $fresh, exercise_id => $exercise]));
	if (shift @row != $serial) {
		$db->error("新人 $fresh の問題 $exercise の提出回数が違います。");
	}
	return @row;
}

#
# 一覧ルーチン
#

# $db->fresh_list($class) : @rows of [$fresh, $name]
# 全体または $class 組の新人のリストを返す。
sub fresh_list {
	my ($db, $class) = @_;
	return $db->query_all('新人リストの取得', $db->sql(
			'select name, k_name from fresh',
			$class ? (where => [class => $class]) : (), order => 'no'));
}

# $db->staff_list : @rows of [$staff, $name, $class]
# スタッフのリストを返す。
sub staff_list {
	my $db = shift;
	return $db->query_all('スタッフリストの取得',
			'select name, k_name, class from staff order by no');
}

# $db->exercise_list($order, [$cond, $param [, ...]]) : \@exercises, \%levels
# すべての問題を格納した配列と、各問題のレベルを格納したハッシュを返す。
sub exercise_list {
	my ($db, $order) = (shift, shift);
	my @rows = $db->query_all('問題リストの取得', $db->sql(
			'select id, level from exercise', @_,
			order => ($order ? $order . ', ' : '') . 'part, chapter, number'));
	my (@exercises, %levels);
	foreach my $row (@rows) {
		my ($id, $level) = @$row;
		push @exercises, $id;
		$levels{$id} = $level;
	}
	return \@exercises, \%levels;
}

#
# status ページ
#

# $db->status($fresh) : @rows of [$id, $status, $staff, $date]
# 新人 $fresh の進捗状況を返す。
sub status {
	my ($db, $fresh) = @_;
	return $db->query_all("新人 $fresh の進捗状況の取得", $db->sql(
			'select exercise_id, status, staff_name, answer_date from answer',
			where => [fresh_name => $fresh], order => 'exercise_id, serial'));
}

#
# queue ページ
#

# $db->queue_count : %count
# 問題ごとの状況を格納したハッシュを返す。
# なお、$count{$id, $status} は配列をキーとするハッシュの値。
# http://blog.livedoor.jp/dankogai/archives/50936712.html
sub queue_count {
	my $db = shift;
	my @rows = $db->query_all('問題ごとの状況の取得', $db->sql(
			'select exercise_id, status, count(*) from answer_unique',
			group => 'exercise_id, status'));
	my %count;
	foreach my $row (@rows) {
		my ($id, $status, $cnt) = @$row;
		$count{$id} += $cnt;
		$count{$id, $status} = $cnt;
	}
	return %count;
}

# $db->queue_avg : %avg
# 問題ごとの平均提出回数を格納したハッシュを返す。
sub queue_avg {
	my $db = shift;
	my @rows = $db->query_all('問題ごとの平均提出回数の取得',
			'select id, avg from exercise inner join ' .
					'(select exercise_id, avg(serial) from answer_unique ' .
							'group by exercise_id) as u on exercise_id = id');
	my %avg;
	foreach my $row (@rows) {
		$avg{$row->[0]} = $row->[1];
	}
	return %avg;
}

#
# table ページ
#

# $db->table : @rows of [$fresh, $exercise_id, $status]
# 新人ごとに、各問題に対する答案の状況を返す。
sub table {
	my $db = shift;
	return $db->query_all('各問題の答案状況',
			'select fresh_name, exercise_id, status from answer_unique');
}

# $db->table_today($today) : @rows of [$fresh, $status, $count]
# 新人ごとに、今日の答案の状況を返す。
sub table_today {
	my ($db, $today) = @_;
	return $db->query_all('今日の答案状況', $db->sql(
			'select fresh_name, status, count(*) from answer_unique',
			where => ['cast(answer_date as text) like ?' => $today . ' %'],
			group => 'fresh_name, status'));
}

# $db->table_count : @rows of [$fresh, $status, $count]
# 新人ごとに、答案の状況ごとの個数を返す。
sub table_count {
	my $db = shift;
	return $db->query_all('答案状況ごとの個数', $db->sql(
			'select fresh_name, status, count(*) from answer',
			where => 'status between 3 and 4', group => 'fresh_name, status'));
}

# $db->table_avg : @rows of [$fresh, $avg]
# 新人ごとに、提出した回数の平均を返す。
sub table_avg {
	my $db = shift;
	return $db->query_all('提出回数の平均', $db->sql(
			'select fresh_name, avg(serial) from answer_unique',
			group => 'fresh_name'));
}

1;
