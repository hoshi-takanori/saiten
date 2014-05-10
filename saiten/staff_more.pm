package saiten::staff;

use strict;
use warnings;

#
# exercise ページ
#

# $app->print_hide_show($hide, $exercises, $levels, $selected)
# 表示しない、または、優先して表示する問題を選択するためのリストを表示する。
sub print_hide_show {
	my ($app, $hide, $exercises, $levels, $selected) = @_;
	my $html = $app->{html};

	$html->print_open_form('post');
	$html->print_hidden(mode => 'exercise', $app->kv_user);
	$html->print_open('select',
			name => ($hide ? 'hide' : 'show'), size => 10, 'multiple');
	foreach my $id (@$exercises) {
		$html->print_option($id, $html->paren($id, $levels->{$id} > 1),
				$selected->{$id} ? ('selected') : ());
	}
	$html->print_close('select');
	$html->print_open('br');
	$html->print_input('reset', undef, 'リセット');
	$html->print_input('submit', undef, $hide ? '隠す' : '優先する');
	$html->print_close('form');

	$app->print_button(undef, $hide ? 'すべて表示する' : 'どれも優先しない',
			undef, 'exercise', ($hide ? 'hide' : 'show') => 'none');
}

# $app->exercise($hide, $show)
# exercise ページを表示する。
sub exercise {
	my ($app, $hide, $show) = @_;
	$app->require_user;

	if (defined $hide) {
		$app->db->hide_show_exercises($app->{user}, 1,
				$hide eq 'none' ? () : split(/&/, $hide));
	}
	if (defined $show) {
		$app->db->hide_show_exercises($app->{user}, 0,
				$show eq 'none' ? () : split(/&/, $show));
	}

	my ($exercises, $levels) = $app->db->exercise_list('level');
	my $hide_exercises = $app->db->get_hide_show($app->{user}, 1);
	my $show_exercises = $app->db->get_hide_show($app->{user}, 0);

	my $html = $app->start_html('問題選択');
	$html->print_p($app->user_name(1) . ' さんの問題選択のページです。');

	if (defined $hide) {
		$html->print_p('※ リストに表示しない問題を更新しました。');
	}
	if (defined $show) {
		$html->print_p('※ 優先して表示する問題を更新しました。');
	}

	$html->print_open('table');
	$html->print_open('tr');
	$html->print_td('リストに表示しない問題：');
	$html->print_td('', width => 24);
	$html->print_td('優先して表示する問題：');
	$html->print_close('tr');
	$html->print_open('tr');
	$html->print_open('td');
	$app->print_hide_show(1, $exercises, $levels, $hide_exercises);
	$html->print_close('td');
	$html->print_td('', width => 24);
	$html->print_open('td');
	$app->print_hide_show(0, $exercises, $levels, $show_exercises);
	$html->print_close('td');
	$html->print_close('tr');
	$html->print_close('table');

	$html->print_p(
			'※ 複数選択はシフト + クリックやコントロール + クリックです。');

	$app->print_cgi_link('戻る');
	$html->print_tail;
}

#
# history ページ
#

# $app->history($fresh, $exercise, $offset)
# history ページを表示する。
sub history {
	my ($app, $fresh, $exercise, $offset) = @_;
	$app->require_user;
	$app->db->check_fresh($fresh) if defined $fresh;
	$app->db->check_exercise($exercise) if defined $exercise;
	if (defined $offset && $offset !~ /^\d+$/) {
		$app->error('オフセット値が不適切です。');
	}
	my $limit = $app->{history_limit};
	$offset = int(($offset || 0) / $limit) * $limit;

	my ($count, @rows) = $app->db->history(
			$app->{user}, $fresh, $exercise, $limit, $offset);

	my $html = $app->start_html('採点履歴');
	$html->print_p($app->user_name(1) . ' さんの' .
			(defined $fresh ? "新人 $fresh に対する" : '') .
			(defined $exercise ? "問題 $exercise に対する" : '') .
			'採点履歴です。');

	if ($count >= $limit) {
		$html->print_open('p');
		my @params = $html->kv(fresh => $fresh, exercise => $exercise);
		my $print = sub {
			my ($str, $off, $link) = @_;
			$str = sprintf('%s (%d 〜 %d)', $str, $off + 1, $off + $limit);
			$html->println('| ' . ($link ? $app->cgi_link($str, 'history',
					@params, $off ? (offset => $off) : ()) : $str));
		};
		$html->println($app->cgi_link('先頭', 'history', @params));
		$print->('まえ', $offset - $limit, 1) if $offset > $limit;
		$print->('現在', $offset);
		$print->('あと', $offset + $limit, 1) if $offset + $limit * 2 <= $count;
		$html->println('| ' . $app->cgi_link("末尾 (〜 $count)", 'history',
				@params, offset => int(($count - 1) / $limit) * $limit));
		$html->print_close('p');
	}

	$html->print_open('table', class => 'bordered', border => 1);

	$html->print_open('tr');
	$html->print_th('番号');
	$html->print_th('新人');
	$html->print_th('ログイン名');
	$html->print_th('問題');
	$html->print_th('回数');
	$html->print_th('結果');
	$html->print_th('採点日付');
	$html->print_th('採点・訂正');
	$html->print_close('tr');

	for (my $i = 0; $i <= $#rows; $i++) {
		my ($fresh, $fresh_name, $exercise,
				$serial, $status, $mark_date, $final_serial) = @{$rows[$i]};

		$html->print_open('tr');
		$html->print_td_center($offset + $i + 1);
		$html->print_td($app->cgi_link($fresh_name, 'status', fresh => $fresh));
		$html->print_td($fresh);
		$html->print_td(
				$app->cgi_link($exercise, 'queue', exercise => $exercise));
		$html->print_td_center(
				$app->vcs_link($html->paren($serial, $serial < $final_serial),
						$fresh, $exercise));
		$html->print_td_center($app->colored_status($status));
		$html->print_td($app->trim_date($mark_date));
		$html->print_open('td', align => 'center');
		if ($status == 2 && $serial == $final_serial) {
			$app->print_button(undef, '採点', undef, 'get_one',
					fresh => $fresh, exercise => $exercise, serial => $serial);
		} elsif (($status == 3 || $status == 4) && $serial == $final_serial) {
			$app->print_button(undef, ($status == 3 ? 'OK' : 'NG') . ' に訂正',
					'本当に採点結果を訂正しますか？', 'mark',
					fresh => $fresh, exercise => $exercise, serial => $serial,
					old_status => $status, status => $status == 3 ? 4 : 3);
		} else {
			$html->print('&nbsp;');
		}
		$html->print_close('td');
		$html->print_close('tr');
	}

	$html->print_close('table');

	$app->print_cgi_link('戻る');
	$html->print_tail;
}

#
# queue_exercise ページ
#

# $app->queue_exercise($class, $exercise)
# queue_exercise ページを表示する。
sub queue_exercise {
	my ($app, $class, $exercise) = @_;
	$app->db->check_class($class) if $class;
	my $level = $app->db->check_exercise($exercise);
	my @rows = $app->db->fresh_status($class, $exercise);

	my $html = $app->start_html("$exercise の答案の山");
	$html->print_p($app->class_name($class) .
			"の問題 $exercise に対する答案の山です。");

	if (defined $app->{user}) {
		$app->print_button(undef, 'この問題の答案を山から取り出す', undef,
				'get_one', $app->kv_class($class), exercise => $exercise);
		$app->print_button(undef, 'この問題の採点履歴を見る', undef,
				'history', exercise => $exercise);
	}

	foreach my $cur_status (4, 3, 2, 1, $level == 1 ? (0) : ()) {
		my $count = 0;
		foreach my $row (@rows) {
			my ($fresh, $fresh_name, $serial, $status, $date, $staff) = @$row;
			$count++ if ($status || 0) == $cur_status;
		}
		next if $count == 0;

		$html->print_tag('h2',
				$app->status_string($cur_status) . " ($count 人)");
		$html->print_open('table', class => 'bordered', border => 1);

		$html->print_open('tr');
		$html->print_th('新人');
		$html->print_th('ログイン名');
		$html->print_th('回数') if $cur_status >= 1;
		$html->print_th('提出日付') if $cur_status >= 1;
		$html->print_th('採点') if $cur_status == 1 && defined $app->{user};
		$html->print_th('採点者') if $cur_status >= 2;
		$html->print_close('tr');

		foreach my $row (@rows) {
			my ($fresh, $fresh_name, $serial, $status, $date, $staff) = @$row;
			$status = 0 if ! defined $status;
			next if $status != $cur_status;

			$html->print_open('tr');
			$html->print_td(
					$app->cgi_link($fresh_name, 'status', fresh => $fresh));
			$html->print_td($fresh);
			if ($status >= 1) {
				$html->print_td_center(
						$app->vcs_link($serial, $fresh, $exercise));
				$html->print_td($app->trim_date($date));
			}
			if (defined $app->{user} && ($status == 1 ||
					$status == 2 && $staff eq $app->{user})) {
				$html->print_open('td');
				$app->print_button(undef, '採点', undef, 'get_one', fresh =>
						$fresh, exercise => $exercise, serial => $serial);
				$html->print_close('td');
			} elsif ($status >= 2) {
				$html->print_td($staff);
			}
			$html->print_close('tr');
		}

		$html->print_close('table');
	}

	$app->print_cgi_link('戻る');
	$html->print_tail;
}

#
# table_staff ページ
#

# $app->print_count($count)
# 採点中、NG、OK、合計のカウントと、OK 率を表示する。
sub print_count {
	my ($app, $count) = @_;
	my $html = $app->{html};
	my $total = 0;
	foreach my $status (2, 3, 4) {
		$html->print_td_right($count->{$status} ?
				$app->color_by_status($status, $count->{$status}) : undef);
		$total += $count->{$status};
	}
	$html->print_td_right($total ? $total : undef);
	$html->print_td_format('%5.1f', $app->calc_ratio($count->{3}, $count->{4}));
}

# $app->table_staff
# table_staff ページを表示する。
sub table_staff {
	my $app = shift;

	my (%staff_count, $rest);
	my $init_count = sub {
		foreach my $part ('whole', 'today', 'before') {
			$staff_count{$part, $_[0]} = { 2 => 0, 3 => 0, 4 => 0 };
		}
	};

	my (@classes, %staff_list, %staff_name, %staff_class);
	foreach my $row ($app->db->staff_list) {
		my ($staff, $name, $class) = @$row;
		push @classes, $class unless grep { $_ eq $class } @classes;
		$staff_list{$class} = [] unless defined $staff_list{$class};
		push @{$staff_list{$class}}, $staff;
		$staff_name{$staff} = $name;
		$staff_class{$staff} = $class;
		$init_count->($staff);
	}

	foreach my $row ($app->db->table_staff) {
		my ($staff, $status, $count) = @$row;
		if (defined $staff) {
			$staff_count{'whole', $staff}->{$status} = $count;
		} else {
			$rest = $count;
		}
	}

	foreach my $row ($app->db->table_staff_today($app->today)) {
		my ($staff, $status, $count) = @$row;
		$staff_count{'today', $staff}->{$status} = $count;
	}

	$init_count->('total');
	foreach my $class (@classes) {
		$init_count->('class-' . $class);
		foreach my $staff (@{$staff_list{$class}}) {
			foreach my $status (2, 3, 4) {
				foreach my $part ('whole', 'today', 'before') {
					$staff_count{'before', $staff}->{$status} =
							$staff_count{'whole', $staff}->{$status} -
							$staff_count{'today', $staff}->{$status};
					$staff_count{$part, 'class-' . $class}->{$status} +=
							$staff_count{$part, $staff}->{$status};
					$staff_count{$part, 'total'}->{$status} +=
							$staff_count{$part, $staff}->{$status};
				}
			}
		}
	}

	my $html = $app->start_html('採点状況');
	$html->print_p('スタッフごとの採点状況：');

	$html->print_open('table', class => 'bordered', border => 1);

	$html->print_open('tr');
	$html->print_th('クラス', rowspan => 2) if $#classes > 0;
	$html->print_th('スタッフ', rowspan => 2);
	$html->print_th('ログイン名', rowspan => 2);
	$html->print_th('昨日まで', colspan => 5);
	$html->print_th('今日', colspan => 5);
	$html->print_th('総計', colspan => 5);
	$html->print_close('tr');

	$html->print_open('tr');
	foreach (0 .. 2) {
		foreach my $status (2, 3, 4) {
			$html->print_th($app->colored_status($status));
		}
		$html->print_th('合計');
		$html->print_th('OK 率');
	}
	$html->print_close('tr');

	foreach my $class (@classes) {
		my @staffs = @{$staff_list{$class}};
		for (my $i = 0; $i <= $#staffs + 1; $i++) {
			my $staff = $i <= $#staffs ? $staffs[$i] : 'class-' . $class;
			$html->print_open('tr');
			$html->print_td_center($class, rowspan => $#staffs + 2)
					if $#classes > 0 && $i == 0;
			if ($i <= $#staffs) {
				$html->print_td($app->cgi_link($staff_name{$staff},
						'table_daily', target_staff => $staff));
				$html->print_td($staff);
			} else {
				$html->print_td($#classes > 0 ? '小計' : '合計', colspan => 2);
			}
			foreach my $part ('before', 'today', 'whole') {
				$app->print_count($staff_count{$part, $staff})
			}
			$html->print_close('tr');
		}
	}

	if ($#classes > 0) {
		$html->print_open('tr');
		$html->print_td('合計', colspan => 3);
		foreach my $part ('before', 'today', 'whole') {
			$app->print_count($staff_count{$part, 'total'})
		}
		$html->print_close('tr');
	}

	$html->print_close('table');

	$html->print_p('採点待ち：' . $rest) if defined $rest;

	$app->print_cgi_link('戻る');
	$app->print_cgi_link('日付ごとの採点状況', 'table_daily',
			$html->kv(target_staff => $app->{user}));
	$html->print_tail;
}

#
# table_daily ページ
#

# $app->print_daily_table($staff_name, \@dates, \%date_count, $is_daily)
# 日付または時刻ごとのテーブルを表示する。
sub print_daily_table {
	my ($app, $staff_name, $dates, $date_count, $is_daily) = @_;
	my $html = $app->{html};

	$html->print_open('table', class => 'bordered', border => 1);

	$html->print_open('tr');
	$html->print_th($is_daily ? '日付' : '時刻', rowspan => 2);
	$html->print_th($staff_name . ' さん', colspan => 5) if defined $staff_name;
	$html->print_th('全体', colspan => 5);
	$html->print_close('tr');

	$html->print_open('tr');
	foreach (defined $staff_name ? ('staff') : (), 'all') {
		foreach my $status (2, 3, 4) {
			$html->print_th($app->colored_status($status));
		}
		$html->print_th('合計');
		$html->print_th('OK 率');
	}
	$html->print_close('tr');

	foreach my $date (@$dates) {
		$html->print_open('tr');
		$html->print_td($is_daily ? $date : "$date:00 〜 $date:59");
		foreach my $part (defined $staff_name ? ('staff') : (), 'all') {
			$app->print_count($date_count->{$part, $date});
		}
		$html->print_close('tr');
	}

	$html->print_open('tr');
	$html->print_td('合計');
	foreach my $part (defined $staff_name ? ('staff') : (), 'all') {
		$app->print_count($date_count->{$part, 'total'});
	}
	$html->print_close('tr');

	$html->print_close('table');
}

# $app->table_daily($staff)
# table_daily ページを表示する。
sub table_daily {
	my ($app, $staff) = @_;
	my ($staff_name) = $app->db->check_staff($staff) if defined $staff;

	my (@dates, %date_count, @hours, %hour_count);
	$date_count{'all', 'total'} = { 2 => 0, 3 => 0, 4 => 0 };
	$date_count{'staff', 'total'} = { 2 => 0, 3 => 0, 4 => 0 };
	$hour_count{'all', 'total'} = { 2 => 0, 3 => 0, 4 => 0 };
	$hour_count{'staff', 'total'} = { 2 => 0, 3 => 0, 4 => 0 };

	foreach my $row ($app->db->table_daily) {
		my ($date, $status, $count) = @$row;
		$date =~ s/ .*$//;
		if (! defined $date_count{'all', $date}) {
			push @dates, $date;
			$date_count{'all', $date} = { 2 => 0, 3 => 0, 4 => 0 };
			$date_count{'staff', $date} = { 2 => 0, 3 => 0, 4 => 0 };
		}
		$date_count{'all', $date}->{$status} = $count;
		$date_count{'all', 'total'}->{$status} += $count;
	}

	foreach my $row ($app->db->table_hourly($app->today)) {
		my ($hour, $status, $count) = @$row;
		if (! defined $hour_count{'all', $hour}) {
			push @hours, $hour;
			$hour_count{'all', $hour} = { 2 => 0, 3 => 0, 4 => 0 };
			$hour_count{'staff', $hour} = { 2 => 0, 3 => 0, 4 => 0 };
		}
		$hour_count{'all', $hour}->{$status} = $count;
		$hour_count{'all', 'total'}->{$status} += $count;
	}

	if (defined $staff) {
		foreach my $row ($app->db->table_daily($staff)) {
			my ($date, $status, $count) = @$row;
			$date =~ s/ .*$//;
			$date_count{'staff', $date}->{$status} = $count;
			$date_count{'staff', 'total'}->{$status} += $count;
		}

		foreach my $row ($app->db->table_hourly($app->today, $staff)) {
			my ($hour, $status, $count) = @$row;
			$hour_count{'staff', $hour}->{$status} = $count;
			$hour_count{'staff', 'total'}->{$status} += $count;
		}
	}

	my $html = $app->start_html('採点状況');

	$html->print_open('p');
	$html->print_open_form('get');
	$html->println('スタッフ選択：');
	$html->print_hidden(mode => 'table_daily', $app->kv_user);
	$html->print_open('select', name => 'target_staff');
	foreach my $row ($app->db->staff_list) {
		my ($target, $target_name) = @$row;
		$html->print_option($target, $target_name,
				defined $staff && $target eq $staff);
	}
	$html->print_close('select');
	$html->print_input('submit', undef, 'Go');
	$html->print_close('form');
	$html->print_close('p');

	$html->print_p('日付ごとの採点状況：');
	$app->print_daily_table($staff_name, \@dates, \%date_count, 1);

	$html->print_p('今日の、時刻ごとの採点状況：');
	$app->print_daily_table($staff_name, \@hours, \%hour_count, 0);

	$app->print_cgi_link('戻る');
	$app->print_cgi_link('スタッフごとの採点状況', 'table_staff');
	$html->print_tail;
}

1;
