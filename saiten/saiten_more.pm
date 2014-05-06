package saiten::saiten;

use strict;
use warnings;

#
# status ページ
#

# $app->print_status($fresh, $exercises, $levels, $rows)
# 問題ごとの進捗状況を表示する。
sub print_status {
	my ($app, $fresh, $exercises, $levels, $rows) = @_;
	my $html = $app->{html};

	my (%status_line, %final_status, %final_staff);
	foreach my $row (@$rows) {
		my ($id, $status, $staff, $date) = @$row;
		my $str = $app->colored_status($status);
		$status_line{$id} = join ' ', $status_line{$id} || (), $str;
		$final_status{$id} = $status;
		$final_staff{$id} = $staff;
	}

	$html->print_open('p');
	foreach my $id (@$exercises) {
		if (defined $final_status{$id}) {
			my $str = $app->vcs_link($app->color_by_status($final_status{$id},
					$html->paren($id, $levels->{$id} > 1), 1), $fresh, $id);
			my $staff = '';
			if (defined $final_staff{$id}) {
				if ($app->{user_key} eq 'staff') {
					$staff = ' ' . $html->colored_string(
							$final_staff{$id} eq ($app->{user} || '') ?
									'darkgreen' : 'dimgray',
							$html->paren($final_staff{$id}));
				} elsif ($final_status{$id} == 2) {
					$staff = ' ' . $html->paren($final_staff{$id});
				}
			}
			$html->println($html->tagged_string('b', $str) . ': ' .
					$status_line{$id} . $staff . $html->open_tag('br'));
		}
	}
	$html->print_close('p');
}

# $app->print_status_table($fresh, $exercises, $levels, $rows)
# 講ごとの進捗状況テーブルを表示する。
sub print_status_table {
	my ($app, $fresh, $exercises, $levels, $rows) = @_;
	my $html = $app->{html};

	my %final_status;
	foreach my $row (@$rows) {
		my ($id, $status, $staff, $date) = @$row;
		$final_status{$id} = $status;
	}

	my (%group_status, %group_dates, %all_dates);
	foreach my $row (@$rows) {
		my ($id, $status, $staff, $date) = @$row;
		my ($group, $no) = $app->split_exercise($id);
		if (! defined $group_status{$group} || $final_status{$id} == 3 ||
				($final_status{$id} == 4 && $group_status{$group} != 3)) {
			$group_status{$group} = $final_status{$id};
		}
		$group_dates{$group} = {} unless $group_dates{$group};
		if ($date =~ /^\d+-(\d+-\d+) .*$/) {
			$group_dates{$group}->{$1} = 1;
			$all_dates{$1} = 1;
		}
	}

	my (@groups, %answered, %not_answered);
	foreach my $id (@$exercises) {
		my ($group, $no) = $app->split_exercise($id);
		push @groups, $group unless grep { $_ eq $group } @groups;
		if ($final_status{$id}) {
			my $str = $app->vcs_link($app->color_by_status($final_status{$id},
					$html->paren($no, $levels->{$id} > 1), 1), $fresh, $id);
			$answered{$group} = join ' ', $answered{$group} || (), $str;
		} elsif ($levels->{$id} == 1) {
			$not_answered{$group} = join ' ', $not_answered{$group} || (), $no;
		}
	}

	$html->print_open('table', border => 1);

	$html->print_open('tr');
	$html->print_th('問題', rowspan => 2);
	my ($prev, $cnt) = '', 0;
	foreach my $date (sort keys %all_dates) {
		if ($date =~ /^0*(\d+)-\d+$/ && $1 ne $prev) {
			$html->print_th($prev, colspan => $cnt) if $prev ne '';
			($prev, $cnt) = ($1, 0);
		}
		$cnt++;
	}
	$html->print_th($prev, colspan => $cnt) if $prev ne '';
	$html->print_th('提出済み', rowspan => 2);
	$html->print_th('未提出', rowspan => 2);
	$html->print_close('tr');

	$html->print_open('tr');
	foreach my $date (sort keys %all_dates) {
		$html->print_th($1) if $date =~ /^\d+-0*(\d+)$/;
	}
	$html->print_close('tr');

	foreach my $group (@groups) {
		$html->print_open('tr');
		$html->print_td($group);
		foreach my $date (sort keys %all_dates) {
			$html->print_td_center($group_dates{$group}->{$date} ?
					$app->color_by_status($group_status{$group}, '→') : undef);
		}
		$html->print_td($answered{$group});
		$html->print_td($not_answered{$group});
		$html->print_close('tr');
	}

	$html->print_close('table');
}

# $app->fresh_status
# 新人用 status ページを表示する。
sub fresh_status {
	my $app = shift;
	$app->require_user;
	my $html = $app->start_html('進捗');
	$html->print_p($app->user_name . ' さんの進捗状況：');
	if ($app->{vcs_mode}) {
		$html->print_p(
				'※ 問題番号をクリックすると、スタッフのコメントを読めます。');
	}

	my ($exercises, $levels) = $app->db->exercise_list;
	my @rows = $app->db->status($app->{user});
	$app->print_status(undef, $exercises, $levels, \@rows);
	$app->print_status_table(undef, $exercises, $levels, \@rows);

	my $wait_count = 0;
	foreach my $row (@rows) {
		my ($id, $status, $staff, $date) = @$row;
		$wait_count++ if $status == 1;
	}
	if ($wait_count) {
		$html->print_open('p');
		$html->print_open_form('post', undef, '本当に取り消しますか？');
		$html->println('問題の報告を取り消す：' . $html->open_tag('br'));
		$html->print_hidden(mode => 'cancel', $app->kv_user);
		$html->print_open('select', name => 'exercise');
		foreach my $row (@rows) {
			my ($id, $status, $staff, $date) = @$row;
			$html->print_option($id, $id) if $status == 1;
		}
		$html->print_close('select');
		$html->print_input('submit', undef, '取り消す');
		$html->print_close('form');
		$html->print_close('p');
	}

	$app->print_cgi_link('戻る');
	$html->print_tail;
}

# $app->staff_status($fresh)
# スタッフ用 status ページを表示する。
sub staff_status {
	my ($app, $fresh) = @_;
	my ($fresh_name, $fresh_class) = $app->db->check_fresh($fresh);
	my ($exercises, $levels) = $app->db->exercise_list;
	my @rows = $app->db->status($fresh);

	my $html = $app->start_html($fresh_name . 'の進捗');
	$html->print_p($fresh_name . ' ' . $html->paren($fresh) .
			' さんの進捗状況：');
	$app->print_status_table($fresh, $exercises, $levels, \@rows);
	$app->print_status($fresh, $exercises, $levels, \@rows);
	if (defined $app->{user}) {
		$app->print_button(undef, 'この新人の採点履歴を見る', undef,
				'history', fresh => $fresh);
	}
	$app->print_cgi_link('戻る');
	$html->print_tail;
}

#
# queue ページ
#

my $queue_style = <<'__END__';
span.clickable {
	color: darkblue;
	cursor: pointer;
}
__END__

my $queue_script = <<'__END__';
function toggle_group(group, open) {
	var show = document.getElementById('show-' + group);
	var hide = document.getElementById('hide-' + group);
	show.style.display = open ? '' : 'none';
	hide.style.display = open ? 'none' : '';
}
__END__

# $app->queue($class)
# queue ページを表示する。
sub queue {
	my ($app, $class) = @_;

	my $num_fresh = $app->db->check_class($class);
	my ($exercises, $levels) = $app->db->exercise_list;
	my %count = $app->db->queue_count;
	my %avg = $app->db->queue_avg;
	my (@groups, %num_group, %exercise_no);
	foreach my $id (@$exercises) {
		if ($count{$id}) {
			my ($group, $no) = $app->split_exercise($id);
			push @groups, $group unless grep { $_ eq $group } @groups;
			my $option = $levels->{$id} == 1 ? 0 : 1;
			$exercise_no{$group, $option, $num_group{$group, $option}++} = $no;
		}
	}

	$app->{html}->add_style($queue_style);
	$app->{html}->add_script($queue_script);
	my $html = $app->start_html('全体の状況');
	$html->print_open('table', border => 1);

	$html->print_open('tr');
	$html->print_th('必須問題',
			colspan => $app->{user_key} eq 'staff' ? 9 : 7);
	$html->print_th('オプション問題',
			colspan => $app->{user_key} eq 'staff' ? 8 : 7);
	$html->print_close('tr');

	$html->print_open('tr');
	foreach my $option (0, 1) {
		$html->print_th('問題番号', colspan => 2);
		$html->print_th('採点待ち');
		$html->print_th('採点中') if $app->{user_key} eq 'staff';
		$html->print_th($app->colored_status(3));
		$html->print_th($app->colored_status(4));
		$html->print_th('合計');
		$html->print_th('未提出')
				if $app->{user_key} eq 'staff' && $option == 0;
		$html->print_th('平均回数');
	}
	$html->print_close('tr');

	foreach my $group (@groups) {
		my ($min_rows, $num_rows) = sort { $a <=> $b }
				$num_group{$group, 0} || 0, $num_group{$group, 1} || 0;

		$html->print_open('tbody', id => 'hide-' . $group,
				style => 'display: none;');
		$html->print_open('tr');
		foreach my $option (0, 1) {
			$html->print_td($html->span('clickable', $group . '-'),
					onclick => "toggle_group('$group', true);");
			$html->print_td(undef,
					colspan => $app->{user_key} eq 'staff' ? 8 - $option : 6);
		}
		$html->print_close('tr');
		$html->print_close('tbody');

		$html->print_open('tbody', id => 'show-' . $group);
		for (my $i = 0; $i < $num_rows; $i++) {
			$html->print_open('tr');
			foreach my $option (0, 1) {
				if ($i == 0) {
					$html->print_td($html->span('clickable', $group . '-'),
							rowspan => $num_rows,
							onclick => "toggle_group('$group', false);");
				}
				if ($i < ($num_group{$group, $option} || 0)) {
					my $no = $exercise_no{$group, $option, $i};
					my $id = $group . '-' . $no;
					my $str = $html->paren($no, $option);
					if ($app->{user_key} eq 'staff') {
						$str = $app->cgi_link($str, 'queue',
								$app->kv_class($class), exercise => $id);
					}
					$html->print_td_center($str);
					foreach my $status (1, 2, 3, 4) {
						my $cnt = $count{$id, $status};
						if ($app->{user_key} ne 'staff') {
							$cnt += $count{$id, 2} || 0 if $status == 1;
							next if $status == 2;
						}
						$html->print_td_right($cnt ?
								$app->color_by_status($status, $cnt) : undef);
					}
					$html->print_td_right($count{$id});
					if ($app->{user_key} eq 'staff' && $option == 0) {
						my $rest = $num_fresh - $count{$id};
						$html->print_td_right($rest ? $rest : undef);
					}
					$html->print_td_format('%.3g', $avg{$id});
				} elsif ($i == $min_rows) {
					$html->print_td(undef, colspan =>
							$app->{user_key} eq 'staff' ? 8 - $option : 6,
							rowspan => $num_rows - $min_rows);
				}
			}
			$html->print_close('tr');
		}
		$html->print_close('tbody');
	}

	$html->print_close('table');
	$app->print_cgi_link('戻る');
	$html->print_tail;
}

#
# table ページ
#

# $app->calc_table : \@groups, \%count
# table ページを計算する。
sub calc_table {
	my $app = shift;

	my ($exercises, $levels) = $app->db->exercise_list;
	my @table = $app->db->table;
	my @today = $app->db->table_today($app->today);
	my @count = $app->db->table_count;
	my @avg = $app->db->table_avg;

	my (@groups, %group_of, @fresh_list, %count);

	foreach my $id (@$exercises) {
		my ($group, $no) = $app->split_exercise($id);
		push @groups, $group unless grep { $_ eq $group } @groups;
		$group_of{$id} = $group;
	}

	foreach my $row (@table) {
		my ($fresh, $id, $status) = @$row;
		push @fresh_list, $fresh unless grep { $_ eq $fresh } @fresh_list;
		$status = 1 if $status == 2;
		$status = 5 if $levels->{$id} > 1 && $status == 4;
		$count{$fresh, $group_of{$id}, $status}++;
	}

	foreach my $fresh (@fresh_list) {
		my ($ok, $ng, $wait);
		foreach my $group (@groups) {
			foreach my $status (1, 3, 4, 5) {
				$count{$fresh, 'total', $status} +=
						$count{$fresh, $group, $status} || 0;
			}
			$count{$fresh, $group, 4} += $count{$fresh, $group, 5} || 0;
			undef $count{$fresh, $group, 5};
		}
	}

	foreach my $row (@today) {
		my ($fresh, $status, $count) = @$row;
		$status = 1 if $status == 2;
		$count{$fresh, 'today', $status} += $count;
	}

	foreach my $row (@count) {
		my ($fresh, $status, $count) = @$row;
		$count{$fresh, $status} = $count;
	}

	foreach my $row (@avg) {
		my ($fresh, $avg) = @$row;
		$count{$fresh, 'avg'} = $avg if $avg;
	}

	return \@groups, \%count;
}

# $app->sort_table($sort_by, $count) : \@fresh_list, \%fresh_name
# table ページをソートする。
sub sort_table {
	my ($app, $sort_by, $count) = @_;

	my (@fresh_list, %fresh_name);
	my @rows = $app->db->fresh_list;
	foreach my $row (@rows) {
		my ($fresh, $name) = @$row;
		push @fresh_list, $fresh;
		$fresh_name{$fresh} = $name;
	}

	if (defined $sort_by) {
		my %order;
		for (my $i = 0; $i <= $#fresh_list; $i++) {
			$order{$fresh_list[$i]} = $i;
		}
		if ($sort_by =~ /^today(_desc)?$/) {
			@fresh_list = sort {
				$count->{$a, 'today', 4} <=> $count->{$b, 'today', 4} ||
				($count->{$a, 'today', 3} + $count->{$a, 'today', 1}) <=>
				($count->{$b, 'today', 3} + $count->{$b, 'today', 1}) ||
				$order{$a} <=> $order{$b}
			} @fresh_list;
		} elsif ($sort_by =~ /^total(_desc)?$/) {
			@fresh_list = sort {
				$count->{$a, 'total', 4} <=> $count->{$b, 'total', 4} ||
				$count->{$a, 'total', 5} <=> $count->{$b, 'total', 5} ||
				($count->{$a, 'total', 3} + $count->{$a, 'total', 1}) <=>
				($count->{$b, 'total', 3} + $count->{$b, 'total', 1}) ||
				$order{$a} <=> $order{$b}
			} @fresh_list;
		} elsif ($sort_by =~ /^avg(_desc)?$/) {
			@fresh_list = sort {
				$count->{$a, 'avg'} <=> $count->{$b, 'avg'} ||
				$order{$a} <=> $order{$b}
			} @fresh_list;
		} elsif ($sort_by =~ /^ratio(_desc)?$/) {
			@fresh_list = sort {
				my $aa = $app->calc_ratio($count->{$a, 3}, $count->{$a, 4});
				my $bb = $app->calc_ratio($count->{$b, 3}, $count->{$b, 4});
				$aa <=> $bb || $order{$a} <=> $order{$b}
			} @fresh_list;
		}
		if ($sort_by =~ /_desc$/) {
			@fresh_list = reverse @fresh_list;
		}
	}

	return \@fresh_list, \%fresh_name;
}

# $app->table($sort_by)
# table ページを表示する。
sub table {
	my ($app, $sort_by) = @_;
	if (defined $sort_by ? $sort_by !~ /^(today|total|avg|ratio)(_desc)?$/ :
			$app->{user_key} ne 'staff') {
		$app->error('sort_by が不適切です。');
	}

	my ($groups, $count) = $app->calc_table;
	my ($fresh_list, $fresh_name) = $app->sort_table($sort_by, $count);

	my $html = $app->start_html('新人ごとの進捗');

	if (defined $sort_by) {
		my $key = $sort_by =~ /^today(_desc)?$/ ? '今日提出分の採点結果' :
				$sort_by =~ /^total(_desc)?$/ ? '採点結果の合計' :
				$sort_by =~ /^avg(_desc)?$/ ? '平均提出回数' :
				$sort_by =~ /^ratio(_desc)?$/ ? 'OK 率 (%) ' : '？';
		my $order = $sort_by !~ /_desc$/ ? '昇順' : '降順';
		$html->print_p('新人ごとの進捗状況を、' .
				$key . 'の' . $order . 'でソートしたもの：');
	} else {
		$html->print_p('新人ごとの進捗状況：');
	}

	$html->print_open('table', border => 1);

	$html->print_open('tr');
	$html->print_th($app->{user_key} eq 'staff' ?
			$app->cgi_link('新人', 'table') : '新人', rowspan => 2);
	$html->print_th('ログイン名', rowspan => 2) if $app->{user_key} eq 'staff';
	my ($prev_section, $section, $cnt);
	foreach my $group (@$groups) {
		$section = $group =~ /^(.*)-\d+$/ ? $1 : 'adv.';
		if (defined $prev_section && $prev_section ne $section) {
			$html->print_th($prev_section, colspan => $cnt);
			$cnt = 0;
		}
		$prev_section = $section;
		$cnt++;
	}
	$html->print_th($section, colspan => $cnt) if defined $section;
	foreach my $i (0 .. 3) {
		my $key = ('today', 'total', 'avg', 'ratio')[$i];
		my $str = ('今日', '合計', '回数', 'OK 率')[$i];
		$html->print_th($str . $html->open_tag('br') .
				$app->cgi_link('△', 'table', sort_by => $key) . ' ' .
				$app->cgi_link('▽', 'table', sort_by => $key . '_desc'),
				rowspan => 2);
	}
	$html->print_close('tr');

	$html->print_open('tr');
	foreach my $group (@$groups) {
		$html->print_th($group =~ /^.*-(\d+)$/ ? $1 : $group);
	}
	$html->print_close('tr');

	foreach my $fresh (@$fresh_list) {
		$html->print_open('tr');
		if ($app->{user_key} eq 'staff') {
			$html->print_td($app->cgi_link($fresh_name->{$fresh},
					'status', fresh => $fresh));
			$html->print_td($fresh);
		} else {
			$html->print_td($fresh eq ($app->{user} || '') ?
					$app->{user_name} : '＊＊＊');
		}
		foreach my $group (@$groups, 'today', 'total') {
			my @array;
			foreach my $status (4, 5, 3, 1) {
				my $cnt = $count->{$fresh, $group, $status};
				next unless $cnt;
				my $color = ('gray', undef, 'red', 'blue', 'blue')[$status - 1];
					push(@array, $html->colored_string($color,
							$html->paren($cnt, $status == 5)));
			}
			$html->print_td(@array ? join(' ', @array) : undef);
		}
		$html->print_td_format('%.3g', $count->{$fresh, 'avg'});
		$html->print_td_format('%5.1f',
				$app->calc_ratio($$count{$fresh, 3}, $$count{$fresh, 4}));
		$html->print_close('tr');
	}

	$html->print_close('table');

	$html->print_p('凡例：' .
			$app->color_by_status(4, '青：OK') . '、' .
			$app->color_by_status(3, '赤：NG') . '、' .
			$html->colored_string('gray', '灰色：採点待ち'));

	$app->print_cgi_link('戻る');
	$html->print_tail;
}

1;
