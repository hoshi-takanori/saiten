package saiten::saiten;

use base 'saiten::app';

use strict;
use warnings;

#
# コンストラクタ
#

# saiten::fresh->new($title, $cgi_file, $dbname [, $dbuser [, $dbpass]])
# コンストラクタ。引数はタイトルと CGI ファイル名と DB 名など。
sub new {
	my $app = shift->SUPER::new(@_);
	$app->{html}->add_style(
			'body { background: white; margin: 1em; }',
			'table { border-collapse: collapse; }',
			'th, td { padding: 3px 4px; }');
	$app->{vcs_mode} = 0;
	$app->{vcs_repo} = '/home/SVN/java';
	$app->{base_dir} = 'java';
	$app->{file_ext} = 'java';
	$app->{advanced_dir} = { comp => 'compound' };
	$app->{advanced_class} =
			{ comp => 'Compound', dice => 'DiceGame', mine => 'MineGame' };
	return $app;
}

# $app->param_names : @param_names
# $app の有効なパラメータ名のリストを返す。
sub param_names {
	return ('message_file', 'vcs_mode', 'vcs_repo', 'base_dir', 'file_ext',
			'advanced_dir', 'advanced_class');
}

#
# ユーザー管理ルーチン
#

# $app->check_user($user) : $user_name, $user_class
# ユーザー $user が DB に登録されていることを確認し、氏名と所属クラスを返す。
sub check_user {
	return 'unknown';
}

# $app->set_user($user)
# $user が DB に登録されていることを確認し、$app->{user} を設定する。
sub set_user {
	my ($app, $user) = @_;
	if (defined $user) {
		my ($user_name, $user_class) = $app->check_user($user);
		$app->{user_name} = $user_name;
		$app->{user_class} = $user_class;
	}
	$app->{user} = $user;
}

# $app->require_user
# ログイン済みでなければエラーとする。
sub require_user {
	my $app = shift;
	if (! defined $app->{user}) {
		$app->error('この機能はログインしないと使えません。');
	}
}

# $app->user_name($with_title)
# 文字列 "$user_name ($user)" を返す。
sub user_name {
	my ($app, $with_title) = @_;
	my $str = $app->{user_name} . ' (' . $app->{user} . ')';
	if ($with_title) {
		$str = $app->{user_title} . '、' . $str if $app->{user_title};
		$str = $app->{user_class} . ' 組の' . $str if $app->{user_class};
	}
	return $str;
}

# $app->kv_user
# リスト ($user_key => $user) を返す。
sub kv_user {
	my $app = shift;
	return $app->{html}->kv($app->{user_key} => $app->{user});
}

#
# 共通ルーチン
#

# $app->cgi_link($str [, $mode [, $key => $value, ...]])
# CGI リンク <a href="$cgi_file?mode=$mode...">$str</a> を返す。
sub cgi_link {
	my ($app, $str, $mode, @args) = @_;
	my $html = $app->{html};
	return $html->link_tag($str, undef,
			$html->kv(mode => $mode), $app->kv_user, @args);
}

# $app->print_cgi_link($str [, $mode [, $key => $value, ...]])
# CGI リンク <p><a href="$cgi_file?mode=$mode...">$str</a></p> を表示、改行。
sub print_cgi_link {
	my $app = shift;
	my $html = $app->{html};
	$html->print_p($app->cgi_link(@_));
}

# $app->print_button($prefix, $button, $confirm, $mode [, $key => $value, ...])
# いくつかの hidden 属性とひとつのボタンからなる、単純なフォームを表示。
sub print_button {
	my ($app, $prefix, $button, $confirm, $mode, @args) = @_;
	my $html = $app->{html};
	$html->print_open_form('post', undef, $confirm);
	$html->println($prefix) if defined $prefix;
	$html->print_hidden($html->kv(mode => $mode), $app->kv_user, @args);
	$html->print_input('submit', undef, $button);
	$html->print_close('form');
}

# $app->class_name($class) : $class_name
# クラス番号 $class に対する名前（全体、1 組、2 組、など）を返す。
sub class_name {
	my ($app, $class) = @_;
	return $class ? "$class 組" : '全体';
}

# $app->kv_class($class)
# リスト (class => $class) を返す。
sub kv_class {
	my ($app, $class) = @_;
	return $class ? (class => $class) : ();
}

# $app->split_exercise($exercise_id) : $exercise_group, $exercise_no
# 問題番号をグループと番号に分割して返す。
sub split_exercise {
	my ($app, $id) = @_;
	if ($id =~ /^(.+)-(\d+)$/) {
		return $1, $2;
	} else {
		return $id, 0;
	}
}

# $db->check_status($status)
# 答案の状態 $status が適切であることを確認する。
sub check_status {
	my ($app, $status) = @_;
	if (! defined $status || $status !~ /^[1-4]$/) {
		$app->error('答案の状態が不適切です。');
	}
}

# $app->status_string($status)
# $status に応じた文字列 '採点待ち', '採点中', 'NG', 'OK' などを返す。
sub status_string {
	my ($app, $status) = @_;
	return	$status == 0 ? '未提出' :
			$status == 1 ? '採点待ち' :
			$status == 2 ? '採点中' :
			$status == 3 ? 'NG' :
			$status == 4 ? 'OK' : "不明 (status = $status)";
}

# $app->color_by_status($status, $str [, $black])
# $status に応じて $str に色を付けたものを返す。
sub color_by_status {
	my ($app, $status, $str, $black) = @_;
	my $html = $app->{html};
	return	$status == 3 ? $html->colored_string('red', $str) :
			$status == 4 ? $html->colored_string('blue', $str) :
			$black ? $html->colored_string('black', $str) :$str;
}

# $app->colored_status($status)
# 文字列 '採点待ち', '採点中', 'NG', 'OK' に色をつけたものを返す。
sub colored_status {
	my ($app, $status) = @_;
	return $app->color_by_status($status, $app->status_string($status));
}

# $app->calc_ratio($ng_count, $ok_count) : $ok_ratio
# $ng_count と $ok_count から OK 率を計算。
sub calc_ratio {
	my ($app, $ng_count, $ok_count) = (shift, shift || 0, shift || 0);
	if ($ng_count || $ok_count) {
		return $ok_count / ($ng_count + $ok_count) * 100;
	} else {
		return undef;
	}
}

# $app->vcs_link($str, $fresh, $exercise)
# vcs ページへのリンクを返す。
sub vcs_link {
	my ($app, $str, $fresh, $exercise) = @_;
	return $app->{vcs_mode} ? $app->cgi_link($str, 'vcs',
			$app->{html}->kv(fresh => $fresh), exercise => $exercise) : $str;
}

#
# top ページ
#

# $app->print_links
# top および home ページのリンク集を表示する。
sub print_links {
}

# $app->top
# top ページを表示する。
sub top {
	my $app = shift;
	my $html = $app->start_html;
	$html->print_p('ログインしてください。');
	$html->print_open_form('get');
	$html->println('ログイン名：');
	$html->print_input('text', $app->{user_key});
	$html->print_input('submit', undef, 'Go');
	$html->print_close('form');
	$app->print_links;
	$html->print_file($app->{message_file});
	$html->print_tail;
}

#
# home ページ
#

# $app->home_content
# home ページの内容を表示する。
sub home_content {
}

# $app->home
# home ページを表示する。
sub home {
	my $app = shift;
	my $html = $app->start_html($app->{user_name});
	$html->print_p($app->user_name(1) . ' さんのページです。');
	$app->home_content;
	$app->print_links;
	$html->print_file($app->{message_file});
	$html->print_tail;
}

#
# メインルーチン
#

# $app->route($mode, %param)
# ルーティングルーチン（オーバーライド用）。
sub route {
	my ($app, $mode, %param) = @_;
	if ($mode eq 'queue') {
		require saiten::saiten_more;
		$app->queue;
	} elsif ($mode eq 'table') {
		require saiten::saiten_more;
		$app->table($param{sort_by});
	} else {
		$app->error('不正な mode です。');
	}
}

# $app->main
# メインルーチン。
sub main {
	my $app = shift;
	my %param = $app->get_params;
	my $mode = $param{mode};
	my $user = $param{$app->{user_key}};
	$app->set_user($user);
	if (! defined $mode && ! defined $user) {
		$app->top;
	} elsif (! defined $mode) {
		$app->home;
	} else {
		$app->route($mode, %param);
	}
}

1;
