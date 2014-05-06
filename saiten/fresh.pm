package saiten::fresh;

use base 'saiten::saiten';

use strict;
use warnings;

use saiten::fresh_db;

#
# コンストラクタ
#

# saiten::fresh->new($title, $cgi_file, $dbname [, $dbuser [, $dbpass]])
# コンストラクタ。引数はタイトルと CGI ファイル名と DB 名など。
sub new {
	my $app = shift->SUPER::new(@_);
	$app->{dbclass} = 'saiten::fresh_db';
	$app->{user_key} = 'name';
	$app->{user_title} = '新人';
	return $app;
}

# $app->param_names : @param_names
# $app の有効なパラメータ名のリストを返す。
sub param_names {
	return (shift->SUPER::param_names);
}

#
# 共通ルーチン
#

# $app->check_user($user) : $user_name, $user_class
# ユーザー $user が DB に登録されていることを確認し、氏名と所属クラスを返す。
sub check_user {
	my ($app, $user) = @_;
	return $app->db->check_fresh($user);
}

#
# top ページ
#

# $app->print_links
# top および home ページのリンク集を表示する。
sub print_links {
	my $app = shift;
	my $html = $app->{html};
	if ($app->{user}) {
		$app->print_cgi_link('いままでの結果を確認する', 'status');
	}
	$app->print_cgi_link('全体の状況を見る', 'queue');
	$app->print_cgi_link('新人の進捗を見る', 'table', sort_by => 'total_desc');
}

#
# home ページ
#

# $app->home_content
# home ページの内容を表示する。
sub home_content {
	my $app = shift;
	my $html = $app->{html};
	$html->print_open_form('post');
	$html->println('問題の完了を報告する：' . $html->open_tag('br'));
	$html->print_hidden(mode => 'report', $app->kv_user);
	$html->print_open('select', name => 'exercise', size => 10);
	my @rows = $app->db->exercise_for($app->{user});
	foreach my $row (@rows) {
		my ($id, $level) = @$row;
		$html->print_option($id, $html->paren($id, $level > 1));
	}
	$html->print_close('select');
	$html->print_open('br');
	$html->print_input('submit', undef, '報告');
	$html->print_close('form');
}

#
# report ページ
#

# $app->report($exercise)
# report ページを表示する。
sub report {
	my ($app, $exercise) = @_;
	$app->require_user;
	$app->db->check_exercise($exercise);
	my ($serial, $status) = $app->db->last_serial($app->{user}, $exercise);
	if ($serial > 0 && $status != 3) {
		my $reason = $status == 1 ? 'すでに報告済みです。' :
			$status == 2 ? 'すでに報告済みで、現在スタッフが採点中です。' :
			$status == 4 ? 'すでに OK をもらっています。' :
				"不明です。(status = $status)";
		$app->error("問題 $exercise の報告は受け付けられません。",
				'理由：' . $reason);
	}
	$app->db->insert_answer($app->{user}, $exercise, $serial + 1);

	my $html = $app->start_html('報告');
	$html->print_p($app->user_name . " さんの報告：問題 $exercise を完了。");
	$html->print_p($serial + 1 . ' 回目の報告を受け付けました。',
			'スタッフがチェックしますので、次の問題をどうぞ。');
	$app->print_button(undef, 'この報告を取り消す', '本当に取り消しますか？',
			'cancel', exercise => $exercise);
	$app->print_cgi_link('戻る');
	$app->print_cgi_link('いままでの結果を確認する', 'status');
	$html->print_tail;
}

#
# cancel ページ
#

# $app->cancel($exercise)
# cancel ページを表示する。
sub cancel {
	my ($app, $exercise) = @_;
	$app->require_user;
	$app->db->check_exercise($exercise);
	my ($serial, $status) = $app->db->last_serial($app->{user}, $exercise);
	if ($serial == 0 || $status != 1) {
		my $reason = $serial == 0 ?
						'まだ報告されてないか、すでに取り消されています。' :
				$status == 2 ? '現在スタッフが採点中です。' :
				$status == 3 ? '採点が完了し、すでに NG をもらっています。' :
				$status == 4 ? '採点が完了し、すでに OK をもらっています。' :
						"不明です。(status = $status)";
		$app->error("問題 $exercise の報告は取り消せません。",
				'理由：' . $reason);
	}
	$app->db->delete_answer($app->{user}, $exercise, $serial);
	$app->db->insert_cancel($app->{user}, $exercise, $serial);

	my $html = $app->start_html('取り消し');
	$html->print_p($app->user_name . " さんの問題 $exercise の報告を取り消し。");
	$html->print_p('報告を取り消しました。');
	$app->print_cgi_link('戻る');
	$app->print_cgi_link('いままでの結果を確認する', 'status');
	$html->print_tail;
}

#
# メインルーチン
#

# $app->route($mode, %param)
# ルーティングルーチン（オーバーライド用）。
sub route {
	my ($app, $mode, %param) = @_;
	if ($mode eq 'report') {
		$app->report($param{exercise});
	} elsif ($mode eq 'cancel') {
		$app->cancel($param{exercise});
	} elsif ($mode eq 'status') {
		require saiten::saiten_more;
		$app->fresh_status;
	} elsif ($mode eq 'vcs') {
		require saiten::saiten_vcs;
		$app->fresh_vcs($param{exercise});
	} elsif ($mode eq 'diff') {
		require saiten::saiten_vcs;
		$app->vcs_diff($param{fresh}, $param{path}, $param{old}, $param{new});
	} else {
		$app->SUPER::route($mode, %param);
	}
}

1;
