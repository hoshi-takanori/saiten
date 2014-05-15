package saiten::staff_db;

use base 'saiten::saiten_db';

use strict;
use warnings;

#
# home ページ
#

# $db->pendings($staff) : @rows of [$fresh, $exercise, $serial]
# スタッフ $staff が採点中の答案のリストを返す。
sub pendings {
	my ($db, $staff) = @_;
	return $db->query_all('採点中の答案の取得', $db->sql(
			'select fresh_name, exercise_id, serial from answer',
			where => [status => 2, staff_name => $staff],
			order => 'reserve_date'));
}

# $db->exercises($staff, $class) : \@exercises, \%levels, \%count
# スタッフ $staff が採点できる答案のリストを返す。
sub exercises {
	my ($db, $staff, $class) = @_;

	my (@exercises, %count);
	my ($all_exercises, $levels) = $db->exercise_list;

	my %pref = %$levels;
	foreach my $i (-1, 0) {
		my @rows = $db->query_all(undef, $db->sql(
				'select exercise_id from ' .
						($i < 0 ? 'hide_exercise' : 'staff_exercise'),
				where => [staff_name => $staff]));
		foreach my $row (@rows) {
			$pref{$row->[0]} = $i;
		}
	}

	foreach my $i (0, 1, 2) {
		foreach my $exercise (@$all_exercises) {
			push @exercises, $exercise if $pref{$exercise} == $i;
		}
		push @exercises, '---' if $i < 2 && @exercises;
	}

	my @rows = $db->query_all(undef, $db->sql(
			'select exercise_id, count(*) from ' .
					'answer inner join fresh on fresh_name = name',
			where => [status => 1, (defined $class ? (class => $class) : ())],
			group => 'exercise_id'));
	foreach my $row (@rows) {
		my ($exercise, $count) = @$row;
		$count{$exercise} = $count;
	}

	return \@exercises, $levels, \%count;
}

#
# get_one ページ
#

# $db->get_answer($staff, $class, $exercise) : $fresh, $fresh_name, $serial
# $class 組の問題 $exercise の答案の山からひとつ取り出す。
sub get_answer {
	my ($db, $staff, $class, $exercise) = @_;
	my @rows = $db->query_all('問題 $exercise の答案の取得', $db->sql(
			'select fresh_name, serial from answer' .
					($class ? ' inner join fresh on fresh_name = name' : ''),
			where => [exercise_id => $exercise, status => 1,
					$class ? (class => $class) : ()],
			order => 'answer_date'));
	if ($#rows < 0) {
		$db->error(($class ? get_class_name($class) . 'の' : '') .
				"問題 $exercise には、採点対象の答案はありません。");
	}
	my ($fresh, $serial) = @{$rows[0]};
	my ($fresh_name) = $db->check_fresh($fresh);
	$db->reserve_answer($staff, $fresh, $exercise, $serial);
	return $fresh, $fresh_name, $serial;
}

# $db->reserve_answer($staff, $fresh, $exercise, $serial)
# 新人 $fresh の問題 $exercise の答案を取り出す。
sub reserve_answer {
	my ($db, $staff, $fresh, $exercise, $serial) = @_;
	my $sth = $db->query('採点中の答案の取得', $db->sql('update answer',
			set => [status => 2, staff_name => $staff, reserve_date => 'now'],
			where => [fresh_name => $fresh, exercise_id => $exercise,
					serial => $serial, status => 1]));
	if ($sth->rows != 1) {
		$db->error('データベースを更新できませんでした。',
				'競合が発生したようです。再度取り出してみてください。');
	}
}

# $db->answer_status($fresh, $exercise) : ($status, $serial)
# 新人 $fresh の問題 $exercise の状態を取得する。
sub answer_status {
	my ($db, $fresh, $exercise) = @_;
	return $db->query_one('答案の状態の取得', $db->sql(
			'select status, serial from answer_unique',
			where => [fresh_name => $fresh, exercise_id => $exercise]));
}

#
# mark ページ
#

# $db->update_answer($staff, $fresh, $exercise, $serial, $old_status, $status)
# 採点結果に基づいて answer テーブルを更新する。
sub update_answer {
	my ($db, $staff, $fresh, $exercise, $serial, $old_status, $status) = @_;
	my $sth = $db->query('採点結果の更新', $db->sql('update answer',
			set => $status > 1 ? [status => $status, mark_date => 'now'] :
					'status = 1, staff_name = null, reserve_date = null',
			where => [fresh_name => $fresh, exercise_id => $exercise,
					serial => $serial, status => $old_status]));
	if ($sth->rows != 1) {
		$db->error('データベースを更新できませんでした。',
				'競合が発生した可能性があります。');
	}
}

# $db->insert_teisei($staff, $fresh, $exercise, $serial, $old_status, $status)
# teisei テーブルに訂正ログを追加する。
sub insert_teisei {
	my ($db, $staff, $fresh, $exercise, $serial, $old_status, $status) = @_;
	my $sql = 'insert into teisei values (?, ?, ?, ?, ?, ?)';
	$db->query(undef, $sql,
			$fresh, $exercise, $serial, $old_status, $status, $staff);
}

# $db->count_answer($staff, $class, $exercise) : $answer_count
# $class 組の問題 $exercise の答案を数える。
sub count_answer {
	my ($db, $staff, $class, $exercise) = @_;
	my ($count) = $db->query_one('問題 $exercise の答案のカウント', $db->sql(
			'select count(*) from answer' .
					($class ? ' inner join fresh on fresh_name = name' : ''),
			where => [exercise_id => $exercise, status => 1,
					$class ? (class => $class) : ()]));
	return $count;
}

#
# exercise ページ
#

# $db->get_hide_show($staff, $hide) : \%hide_or_show
# スタッフ $staff の表示しない or 優先して表示する問題のハッシュを返す。
sub get_hide_show {
	my ($db, $staff, $hide) = @_;
	my $table = $hide ? 'hide_exercise' : 'staff_exercise';
	my @rows = $db->query_all('問題の設定の取得', $db->sql(
			'select exercise_id from ' . $table,
			where => [staff_name => $staff]));
	my %hide_or_show;
	foreach my $row (@rows) {
		$hide_or_show{$row->[0]} = 1;
	}
	return \%hide_or_show;
}

# $db->hide_show_exercises($staff, $hide, @exercises)
# hide_exercise または staff_exercise テーブルを更新する。
sub hide_show_exercises {
	my ($db, $staff, $hide, @exercises) = @_;

	foreach my $id (@exercises) {
		$db->check_exercise($id);
	}

	my $table = $hide ? 'hide_exercise' : 'staff_exercise';
	$db->query('問題の設定の更新', $db->sql(
			'delete from ' . $table, where => [staff_name => $staff]));

	my $sql = 'insert into ' . $table . ' values (?, ?)';
	foreach my $id (@exercises) {
		$db->query('問題の設定の更新', $sql, $staff, $id);
	}
}

#
# history ページ
#

# $db->history($staff, $fresh, $exercise, $limit, $offset) : $count, @rows
# スタッフ $staff の採点履歴を返す。
sub history {
	my ($db, $staff, $fresh, $exercise, $limit, $offset) = @_;
	my @where = ['answer.staff_name' => $staff,
			defined $fresh ? (fresh_name => $fresh) : (),
			defined $exercise ? (exercise_id => $exercise) : ()];
	my ($count) = $db->query_one('採点履歴のカウント', $db->sql(
			'select count(*) from answer', where => @where));
	my @rows = $db->query_all('採点履歴の取得', $db->sql(
			'select fresh_name, k_name, exercise_id, answer.serial, ' .
					'answer.status, answer.mark_date, answer_unique.serial ' .
					'from answer inner join fresh on fresh_name = name ' .
					'inner join answer_unique using (fresh_name, exercise_id)',
			where => @where,
			order => 'answer.mark_date desc, answer.reserve_date desc', 
			limit => $limit, offset => $offset));
	return $count, @rows;
}

#
# queue_exercise ページ
#

# $db->fresh_status($class, $exercise) : @rows
# $class 組における、問題 $exercise の各新人の状態を返す。
sub fresh_status {
	my ($db, $class, $exercise) = @_;
	return $db->query_all('問題 $exercise の答案の山の取得',
			'select name, k_name, serial, status, answer_date, staff_name ' .
					'from fresh left outer join (select * from answer_unique ' .
					'where exercise_id = ?) as u on name = fresh_name ' .
					($class ? 'where class = ? ' : '') .
					'order by answer_date, no',
			$exercise, $class ? ($class) : ());
}

#
# table_staff ページ
#

# $db->table_staff : @rows of [$staff, $status, $count]
# スタッフごとの採点数を返す。
sub table_staff {
	my $db = shift;
	return $db->query_all('スタッフごとの採点数の取得', $db->sql(
			'select staff_name, status, count(*) from answer',
			group => 'staff_name, status'));
}

# $db->table_staff_today($today) : @rows of [$staff, $status, $count]
# 今日の、スタッフごとの採点数を返す。
sub table_staff_today {
	my ($db, $today) = @_;
	return $db->query_all('今日の採点数の取得',
			'select staff_name, status, count(*) from answer ' .
					'where status = 2 and date(reserve_date) = ? ' .
					'or status in (3, 4) and date(mark_date) = ? ' .
					'group by staff_name, status', $today, $today);
}

#
# table_daily ページ
#

# $db->table_daily($staff) : @rows of [$date, $status, $count]
# $staff または全体の、日付ごとの採点数を返す。
sub table_daily {
	my ($db, $staff) = @_;
	return $db->query_all('日付ごとの採点数の取得',
			'select date, status, count(*) from (select case ' .
					"when status = 2 then date(reserve_date) " .
					"when status in (3, 4) then date(mark_date) " .
					'else null end as date, * from answer) as d ' .
					'where date is not null ' .
							(defined $staff ? 'and staff_name = ? ' : '') .
					'group by date, status order by date, status',
			(defined $staff ? ($staff) : ()));
}

# $db->table_hourly($today, $staff) : @rows of [$hour, $status, $count]
# $staff または全体の、時刻ごとの採点数を返す。
sub table_hourly {
	my ($db, $today, $staff) = @_;
	my $date_hour = "date_part('hour', date)";
	if ($db->{dbh}->{Driver}->{Name} eq 'SQLite') {
		$date_hour = "cast(strftime('%H', date) as int)";
	}
	return $db->query_all('時刻ごとの採点数の取得',
			'select ' . $date_hour . ' as hour, status, count(*) ' .
					'from (select case when status = 2 then reserve_date ' .
					'when status in (3, 4) then mark_date else null end ' .
					'as date, * from answer) as d ' .
					'where date(date) = ? ' .
							(defined $staff ? 'and staff_name = ? ' : '') .
					'group by hour, status order by hour, status',
			$today, (defined $staff ? ($staff) : ()));
}

#
# vcs ページ
#

# $db->fresh_exercise($exercise) : @rows of [$fresh, $k_name, $serial]
# 問題 $exercise を新人が何回提出したかのリストを返す。
sub fresh_exercise {
	my ($db, $exercise) = @_;
	return $db->query_all('新人と提出回数の取得',
			'select name, k_name, serial from fresh left outer join ' .
					'(select * from answer_unique where exercise_id = ?) ' .
					'as u on name = fresh_name order by no', $exercise);
}

# $db->exercise_fresh($fresh) : @rows of [$exercise, $level, $serial]
# 新人 $fresh が問題を何回提出したかのリストを返す。
sub exercise_fresh {
	my ($db, $fresh) = @_;
	return $db->query_all('問題と提出回数の取得',
			'select id, level, serial from exercise left outer join ' .
					'(select * from answer_unique where fresh_name = ?) ' .
					'as u on id = exercise_id ' .
					'order by level, part, chapter, number', $fresh);
}

1;
