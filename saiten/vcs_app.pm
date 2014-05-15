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
	$app->{vcs_pattern} = {
		'basic-7-1' => 'Emp.*\.java',
		'basic-7-2' => '(Comp|Emp).*\.java',
		'basic-8-1' => 'animal\/.*\.java',
		'basic-8-2' => 'animal\/.*\.java',
		'basic-8-3' => 'flyable\/.*\.java',
		'mine-1' => 'MineBoard\.java',
		'mine-2' => 'MineBoard\.java',
		'mine-3' => 'MineBoard\.java',
	};
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
	$app->print_select_forms(undef, '', undef, '');
	if (defined $app->{notice}) {
		$html->print_open('hr');
		$html->print_p('お知らせ', @{$app->{notice}});
	}
	$html->print_tail;
}

#
# vcs ページ
#

# $app->cat($fresh, $exercise, $path) : @cat
# ファイルの中身を取得する。
sub cat {
	my ($app, $fresh, $exercise, $path) = @_;
	if (! grep { $_ eq $exercise } @{$app->{exercises}}) {
		$app->error('この問題はまだ閲覧の対象ではありません。');
	}

	my $vcs = $app->vcs($fresh, $path);
	my @revs = $vcs->revs;
	if (! @revs) {
		return;
	}
	my @cat = $vcs->cat($revs[0]);

	my @result;
	my $mode = 0;
	foreach my $line (@cat) {
		$mode = 1 if $mode == 0 && $line =~ /\/\* スタッフコメント欄/;
		$mode = 3 if $mode == 2 && $line ne '';
		if ($mode == 0 || $mode == 3) {
			push @result, $line;
		}
		$mode = 2 if $mode == 1 && $line =~ /\*\//;
	}
	return @result;
}

# $app->print_cat(@cat)
# ファイルの中身を表示する。
sub print_cat {
	my ($app, @cat) = @_;
	my $html = $app->{html};
	my $diff = saiten::diff->new($html);

	if (! @cat) {
		$html->print_p('※ この問題のソースはコミットされてないようです。');
		return;
	}

	$html->print_open('table', class => 'bordered', border => 1);
	$html->print_open('tr');
	$html->print_open('td');
	$html->print_open('pre');
	for (my $i = 0; $i <= $#cat; $i++) {
		$html->println(sprintf('%3d', $i + 1) . ' ' .
				$diff->conv_line(split(//, decode('UTF-8', $cat[$i]))));
	}
	$html->print_close('pre');
	$html->print_close('td');
	$html->print_close('tr');
	$html->print_close('table');
}

# $app->vcs_page($fresh, $exercise, $filename)
# vcs ページを表示する。
sub vcs_page {
	my ($app, $fresh, $exercise, $filename) = @_;
	my ($fresh_name, $fresh_class) = $app->check_vcs_user($fresh);
	my ($path, $dirname, $basename) = $app->vcs_path($exercise, $filename);
	my @cat = $app->cat($fresh, $exercise, $path);

	my $html = $app->start_html($fresh . ' ' . $exercise);
	$html->print_p($fresh_name . ' ' . $html->paren($fresh) . ' さんの ' .
			$exercise . ' の答案です。');

	my @filenames;
	if (defined $app->{vcs_pattern}->{$exercise}) {
		my ($p, $d, $b) = $app->vcs_path($exercise);
		my $pattern = $app->{vcs_pattern}->{$exercise};
		@filenames = grep { $_ eq $b || $_ =~ /^$pattern$/ }
				$app->vcs($fresh)->ls_files($dirname);
	}
	$app->print_select_forms(undef, $fresh, undef, $exercise,
			$basename, sort @filenames);

	$app->print_cat(@cat);

	if (@cat) {
		$app->print_cgi_link('ダウンロード', 'download',
				fresh => $fresh, exercise => $exercise,
				$html->kv(filename => $filename));
	}
	$app->print_cgi_link('戻る');
	$html->print_tail;
}

#
# download ページ
#

# $app->download($fresh, $exercise, $filename)
# download ページを表示する。
sub download {
	my ($app, $fresh, $exercise, $filename) = @_;
	$app->check_vcs_user($fresh);
	my ($path) = $app->vcs_path($exercise, $filename);
	my @cat = $app->cat($fresh, $exercise, $path);
	if (! @cat) {
		$app->error('この問題のソースはコミットされていません。');
	}

	my $html = $app->{html};
	$html->print("Content-Type: text/plain; charset=UTF-8\r\n");
	$html->print("\r\n");
	foreach my $line (@cat) {
		$html->println($line);
	}
	$html->flush;
}

#
# メインルーチン
#

# $app->main
# メインルーチン。
sub main {
	my $app = shift;
	my %param = $app->get_params;
	my $mode = $param{mode};
	my $fresh = $param{fresh};
	my $exercise = $param{exercise};
	my $filename = $param{filename};
	if (! defined $fresh || ! defined $exercise) {
		$app->top;
	} elsif (! defined $param{mode}) {
		$app->vcs_page($fresh, $exercise, $filename);
	} elsif ($param{mode} eq 'download') {
		$app->download($fresh, $exercise, $filename);
	} else {
		$app->error('不正な mode です。');
	}
}

1;
