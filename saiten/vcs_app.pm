package saiten::vcs_app;

use base 'saiten::saiten';

use strict;
use warnings;

use Encode;

use saiten::saiten_db;
use saiten::saiten_vcs;

#
# コンストラクタ
#

# saiten::vcs_app->new($title, $cgi_file, $dbname [, $dbuser [, $dbpass]])
# コンストラクタ。引数はタイトルと CGI ファイル名と DB 名など。
sub new {
	my $app = shift->SUPER::new(@_);
	$app->{dbclass} = 'saiten::saiten_db';
	$app->{vcs_user} = { neko => 'ねこ' };
	return $app;
}

# $app->param_names : @param_names
# $app の有効なパラメータ名のリストを返す。
sub param_names {
	return (shift->SUPER::param_names, 'exercises', 'notice');
}

#
# top ページ
#

# $app->top
# top ページを表示する。
sub top {
	my $app = shift;
	my $html = $app->start_html;
	$html->print_p('新人と問題を選択してください。');
	$html->print_open('p');
	$app->print_select_form(undef, '', undef, '');
	$html->print_close('p');
	$html->print_tail;
}

#
# vcs ページ
#

# $app->print_cat($fresh, $path)
# ファイルの中身を表示する。
sub print_cat {
	my ($app, $fresh, $path) = @_;
	my $html = $app->{html};

	my $vcs = $app->vcs($fresh, $path);
	my @revs = $vcs->revs;
	if (! @revs) {
		$html->print_p('※ この問題のソースはコミットされてないようです。');
		return;
	}
	my @cat = $vcs->cat($revs[0]);

	my $diff = saiten::diff->new($html);

	$html->print_open('table', class => 'bordered', border => 1);
	$html->print_open('tr');
	$html->print_open('td');
	$html->print_open('pre');
	my ($no, $mode) = (1, 0);
	foreach my $line (@cat) {
		$mode = 1 if $mode == 0 && $line =~ /\/\* スタッフコメント欄/;
		$mode = 3 if $mode == 2 && $line ne '';
		if ($mode == 0 || $mode == 3) {
			$html->println(sprintf('%3d', $no) . ' ' .
					$diff->conv_line(split(//, decode('UTF-8', $line))));
			$no++;
		}
		$mode = 2 if $mode == 1 && $line =~ /\*\//;
	}
	$html->print_close('pre');
	$html->print_close('td');
	$html->print_close('tr');
	$html->print_close('table');
}

# $app->vcs_page($fresh, $exercise)
# vcs ページを表示する。
sub vcs_page {
	my ($app, $fresh, $exercise) = @_;
	my ($fresh_name, $fresh_class) = $app->check_vcs_user($fresh);
	my ($path) = $app->vcs_path($exercise);
	if (! grep { $_ eq $exercise } @{$app->{exercises}}) {
		$app->error('この問題はまだ閲覧の対象ではありません。');
	}

	my $html = $app->start_html($fresh . ' ' . $exercise);
	$html->print_p($fresh_name . ' ' . $html->paren($fresh) . ' さんの ' .
			$exercise . ' の答案です。');

	$html->print_open('p');
	$app->print_select_form(undef, $fresh, undef, $exercise);
	$html->print_close('p');

	$app->print_cat($fresh, $path);

	$app->print_cgi_link('戻る');
	$html->print_tail;
}

#
# メインルーチン
#

# $app->main
# メインルーチン。
sub main {
	my $app = shift;
	my %param = $app->get_params;
	my $fresh = $param{fresh};
	my $exercise = $param{exercise};
	if (! defined $fresh || ! defined $exercise) {
		$app->top;
	} else {
		$app->vcs_page($fresh, $exercise);
	}
}

1;
