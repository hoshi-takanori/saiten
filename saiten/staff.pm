package saiten::staff;

use base 'saiten::saiten';

use strict;
use warnings;

use saiten::staff_db;

#
# コンストラクタ
#

# saiten::staff->new($title, $cgi_file, $dbname [, $dbuser [, $dbpass]])
# コンストラクタ。引数はタイトルと CGI ファイル名と DB 名など。
sub new {
	my $app = shift->SUPER::new(@_);
	$app->{dbclass} = 'saiten::staff_db';
	$app->{user_key} = 'staff';
	$app->{user_title} = 'スタッフ';
	$app->{num_class} = 0;
	$app->{history_limit} = 20;
	$app->{show_ratio} = 1;
	$app->{vcs_mode} = 3;
	return $app;
}

# $app->param_names : @param_names
# $app の有効なパラメータ名のリストを返す。
sub param_names {
	return (shift->SUPER::param_names, 'num_class', 'history_limit');
}

#
# 共通ルーチン
#

# $app->check_user($user) : $user_name, $user_class
# ユーザー $user が DB に登録されていることを確認し、氏名と所属クラスを返す。
sub check_user {
	my ($app, $user) = @_;
	return $app->db->check_staff($user);
}

#
# top ページ
#

# $app->print_links
# top および home ページのリンク集を表示する。
sub print_links {
	my $app = shift;
	my $html = $app->{html};

	my ($exercises, $levels) = $app->db->exercise_list('level');

	if (defined $app->{user}) {
		$html->print_open('p');
		$html->print_open_form('get');
		$html->println('採点履歴を見る：');
		$html->println($app->cgi_link('全部', 'history') . '、');
		$html->println('問題：');
		$html->print_hidden(mode => 'history', $app->kv_user);
		$html->print_open('select', name => 'exercise');
		foreach my $id (@$exercises) {
			$html->print_option($id, $html->paren($id, $levels->{$id} > 1));
		}
		$html->print_close('select');
		$html->print_input('submit', undef, 'Go');
		$html->print_close('form');
		$html->print_close('p');
	}

	$html->print_open('p');
	$html->print_open_form('get');
	$html->println('問題ごとの進捗：');
	foreach my $class (1 .. $app->{num_class}, 0) {
		$html->println($app->cgi_link($app->class_name($class), 'queue',
				$app->kv_class($class)) . '、');
	}
	$html->println('問題：');
	$html->print_hidden(mode => 'queue', $app->kv_user);
	$html->print_open('select', name => 'exercise');
	foreach my $id (@$exercises) {
		$html->print_option($id, $html->paren($id, $levels->{$id} > 1));
	}
	$html->print_close('select');
	$html->print_input('submit', undef, 'Go');
	$html->print_close('form');
	$html->print_close('p');

	$html->print_open('p');
	$html->print_open_form('get');
	$html->println('新人ごとの進捗：');
	foreach my $class (1 .. $app->{num_class}, 0) {
		$html->println($app->cgi_link($app->class_name($class), 'table',
				$app->kv_class($class)) . '、');
	}
	$html->println('新人：');
	$html->print_hidden(mode => 'status', $app->kv_user);
	$html->print_open('select', name => 'fresh');
	foreach my $row ($app->db->fresh_list) {
		my ($fresh, $fresh_name) = @$row;
		$html->print_option($fresh, $fresh_name);
	}
	$html->print_close('select');
	$html->print_input('submit', undef, 'Go');
	$html->print_close('form');
	$html->print_close('p');

	$html->print_open('p');
	$html->println('スタッフの採点：');
	$html->println($app->cgi_link('全体', 'table_staff') . '、');
	$html->println($app->cgi_link('日付ごと', 'table_daily',
			$html->kv(target_staff => $app->{user})));
	$html->print_close('p');
}

#
# home ページ
#

# $app->home_content
# home ページの内容を表示する。
sub home_content {
	my $app = shift;
	my $html = $app->{html};

	my ($staff_name, $staff_class) = $app->db->check_staff($app->{user});
	my ($exercises, $levels, $count) =
			$app->db->exercises($app->{user}, $staff_class);

	my @pendings = $app->db->pendings($app->{user});
	if (@pendings) {
		$html->print_p('※ 採点中の答案があります。');
		$html->print_open('ul');
		foreach my $pending (@pendings) {
			my ($fresh, $exercise, $serial) = @$pending;
			my $fresh_link = $app->cgi_link($fresh, 'status', fresh => $fresh);
			my $exercise_link = $app->cgi_link($exercise, 'queue',
					$app->kv_class($staff_class), exercise => $exercise);
			my $serial_link = $app->vcs_link("$serial 回め", $fresh, $exercise);
			$html->print_open('li');
			$app->print_button(
					"$fresh_link さんの $exercise_link ($serial_link)：",
					'採点', undef, 'get_one',
					fresh => $fresh, exercise => $exercise, serial => $serial);
			$html->print_close('li');
		}
		$html->print_close('ul');
	}

	$html->print_open_form('post');
	$html->print_open('p');
	$html->println('答案を山から取り出す：' . $html->open_tag('br'));
	$html->print_hidden(mode => 'get_one', $app->kv_user);
	if ($app->{num_class}) {
		$html->print_open('select', name => 'class');
		foreach my $class (1 .. $app->{num_class}, 0) {
			$html->print_option($class,
					$app->class_name($class), ($staff_class == $class));
		}
		$html->print_close('select');
		$html->print_open('br');
	}
	$html->print_open('select', name => 'exercise', size => 10);
	foreach my $id (@$exercises) {
		my $str = $html->paren($id, ($levels->{$id} || 0) > 1);
		if ($count->{$id}) {
			$str .= ' (' . ($staff_class ?
							$app->class_name($staff_class) . 'の' : '') .
					'採点待ち ' . $count->{$id} . ' 個)';
		}
		$html->print_option($id, $str);
	}
	$html->print_close('select');
	$html->print_open('br');
	$html->print_input('submit', undef, '取り出す');
	$html->print_close('p');
	$html->print_close('form');

	if ($app->{multi_exercises}) {
		$app->print_cgi_link('まとめて取り出す', 'get_multi',
				$app->kv_class($staff_class));
	}
	$app->print_button(undef, '問題リストの表示の設定', undef, 'exercise');
}

#
# get_one ページ
#

# $app->get_one($class, $fresh, $exercise, $serial)
# get_one ページを表示する。
sub get_one {
	my ($app, $class, $fresh, $exercise, $serial) = @_;

	$app->require_user;
	$app->db->check_class($class) if $class;
	$app->db->check_exercise($exercise);
	my ($fresh_name, $fresh_class);
	if (! defined $fresh) {
		($fresh, $fresh_name, $serial) =
				$app->db->get_answer($app->{user}, $class, $exercise);
	} else {
		($fresh_name, $fresh_class) = $app->db->check_fresh($fresh);
		my ($status, $saiten_staff) =
				$app->db->check_serial($fresh, $exercise, $serial);
		if ($status == 1) {
			$app->db->reserve_answer($app->{user}, $fresh, $exercise, $serial);
		} elsif ($status != 2) {
			$app->error(
					"新人 $fresh の問題 $exercise は採点中ではありません。");
		} elsif ($saiten_staff ne $app->{user}) {
			$app->error("新人 $fresh の問題 $exercise は" .
					"他のスタッフ ($saiten_staff) が採点中です。");
		}
	}

	my $html = $app->start_html('採点');

	$html->print_p('以下の答案を取り出しました。');
	$html->print_open('table', class => 'bordered', border => 1);
	$html->print_open('tr');
	$html->print_th('名前');
	$html->print_td($app->cgi_link($fresh_name, 'status', fresh => $fresh));
	$html->print_close('tr');
	$html->print_open('tr');
	$html->print_th('ログイン名');
	$html->print_td($fresh);
	$html->print_close('tr');
	$html->print_open('tr');
	$html->print_th('問題');
	$html->print_td($app->cgi_link($exercise, 'queue',
			$app->kv_class($class), exercise => $exercise));
	$html->print_close('tr');
	$html->print_open('tr');
	$html->print_th('提出回数');
	$html->print_td("$serial 回");
	$html->print_close('tr');
	$html->print_close('table');

	$html->print_p('次のようにすればソースを取得・コンパイル・実行できます。');
	$html->print_open('pre');
	if ($exercise =~ /^([^-])([^-]*)-(\d+)-(\d+)$/) {
		my ($a, $aa, $b, $c, $d) = ($1, $1, $2, $3, $4);
		$aa =~ tr/a-z/A-Z/;
		my $dir = $app->{base_dir} . "/$fresh/$a$b/$c";
		my $cls = sprintf('%s%s%02d%02d', $aa, $b, $c, $d);
		$html->println('    cd ~/' . $dir);
		$html->println('    svn update');
		$html->println('    javac ' . $cls . '.java');
		$html->println('    java ' . $cls);
	} elsif ($exercise =~ /^([^-]+)-\d+$/) {
		my $dir = $app->{base_dir} . "/$fresh/$1";
		$html->println('    cd ~/' . $dir);
		$html->println('    svn update');
	}
	if ($app->{vcs_mode}) {
		$html->println('', '    ※ または、' .
				$app->vcs_link('こちら', $fresh, $exercise) . 'を...');
	}
	$html->print_close('pre');

	$html->print_p('それでは、採点よろしくお願いします。');
	$html->print_open('table');
	$html->print_open('tr');
	$html->print_open('td', width => 12);
	$html->print_close('td');
	$html->print_open('td');
	$app->print_button(undef, 'NG', undef, 'mark', $app->kv_class($class),
			fresh => $fresh, exercise => $exercise, serial => $serial,
			old_status => 2, status => 3);
	$html->print_close('td');
	$html->print_open('td', width => 32);
	$html->print_close('td');
	$html->print_open('td');
	$app->print_button(undef, 'OK', undef, 'mark', $app->kv_class($class),
			fresh => $fresh, exercise => $exercise, serial => $serial,
			old_status => 2, status => 4);
	$html->print_close('td');
	$html->print_close('tr');
	$html->print_close('table');

	$html->print_open('p');
	$app->print_button('もしも、採点待ちに戻したい場合には：',
			'採点待ちに戻す', '本当に採点待ちに戻しますか？',
			'mark', $app->kv_class($class),
			fresh => $fresh, exercise => $exercise, serial => $serial,
			old_status => 2, status => 1);
	$html->print_close('p');

	$html->print_tail;
}

#
# mark ページ
#

# $app->mark($class, $fresh, $exercise, $serial, $old_status, $status)
# mark ページを表示する。
sub mark {
	my ($app, $class, $fresh, $exercise, $serial, $old_status, $status) = @_;

	$app->require_user;
	$app->db->check_class($class) if $class;
	my ($fresh_name, $fresh_class) = $app->db->check_fresh($fresh);
	$app->db->check_exercise($exercise);
	my ($cur_status, $saiten_staff) =
			$app->db->check_serial($fresh, $exercise, $serial);
	$app->check_status($old_status);
	$app->check_status($status);

	if (! ($old_status == 2 && ($status == 1 || $status == 3 || $status == 4))
	 && ! ($old_status == 3 && $status == 4)
	 && ! ($old_status == 4 && $status == 3)) {
		$app->error('答案の状態の組み合わせが不適切です。');
	} elsif ($cur_status != $old_status) {
		$app->error(
				"新人 $fresh の問題 $exercise はすでに採点・変更済みです。");
	} elsif ($saiten_staff ne $app->{user}) {
		$app->error("新人 $fresh の問題 $exercise は" .
				"他のスタッフ ($saiten_staff) が採点中です。");
	}

	$app->db->update_answer(
			$app->{user}, $fresh, $exercise, $serial, $old_status, $status);
	if (! ($old_status == 2 && ($status == 3 || $status == 4))) {
		$app->db->insert_teisei(
				$app->{user}, $fresh, $exercise, $serial, $old_status, $status);
	}

	my $html = $app->start_html('採点');

	my $fresh_link = $app->cgi_link("$fresh_name ($fresh)", 'status',
			fresh => $fresh);
	my $exercise_link = $app->cgi_link($exercise, 'queue',
			$app->kv_class($class), exercise => $exercise);
	$html->print_p("$fresh_link さんの $exercise_link の $serial 回目の答案を" .
			($status == 1 ? '採点待ちに戻しました。' :
					' ' . $app->colored_status($status) . ' にしました。'));

	if ($old_status == 2 && ($status == 3 || $status == 4)) {
		my $new_status = $status == 3 ? 4 : 3;
		$app->print_button('もしも、採点を間違えた場合には：',
				'採点結果を ' . $app->status_string($new_status) .
						' に訂正する', '本当に採点結果を訂正しますか？',
				'mark', $app->kv_class($class),
				fresh => $fresh, exercise => $exercise, serial => $serial,
				old_status => $status, status => $new_status);
	}

	my $answer_count = $app->db->count_answer($app->{user}, $class, $exercise);
	if ($status != 1 && $answer_count > 0) {
		$html->print_open('p');
		$app->print_button("答案はあと $answer_count 個残っています。" .
				$html->open_tag('br'), '次の答案を取り出す', undef, 'get_one',
				$app->kv_class($class), exercise => $exercise);
		$html->print_close('p');
	}

	$app->print_cgi_link('戻る');
	$html->print_tail;
}

#
# メインルーチン
#

# $app->route($mode, %param)
# ルーティングルーチン（オーバーライド用）。
sub route {
	my ($app, $mode, %param) = @_;
	my $class = $param{class};
	my $fresh = $param{fresh};
	my $exercise = $param{exercise};
	my $serial = $param{serial};
	if ($mode eq 'get_one') {
		$app->get_one($class, $fresh, $exercise, $serial);
	} elsif ($mode eq 'mark') {
		$app->mark($class, $fresh, $exercise, $serial,
				$param{old_status}, $param{status});
	} elsif ($mode eq 'exercise') {
		require saiten::staff_more;
		$app->exercise($param{hide}, $param{show});
	} elsif ($mode eq 'history') {
		require saiten::staff_more;
		$app->history($fresh, $exercise, $param{offset});
	} elsif ($mode eq 'status') {
		require saiten::saiten_more;
		$app->staff_status($fresh);
	} elsif ($mode eq 'vcs') {
		require saiten::saiten_vcs;
		$app->staff_vcs($fresh, $exercise, $param{filename});
	} elsif ($mode eq 'diff') {
		require saiten::saiten_vcs;
		$app->vcs_diff($fresh, $param{path}, $param{old}, $param{new});
	} elsif ($mode eq 'queue' && ! defined $exercise) {
		require saiten::saiten_more;
		$app->queue;
	} elsif ($mode eq 'queue') {
		require saiten::staff_more;
		$app->queue_exercise($class, $exercise);
	} elsif ($mode eq 'table_staff') {
		require saiten::staff_more;
		$app->table_staff;
	} elsif ($mode eq 'table_daily') {
		require saiten::staff_more;
		$app->table_daily($param{target_staff});
	} else {
		$app->SUPER::route($mode, %param);
	}
}

1;
