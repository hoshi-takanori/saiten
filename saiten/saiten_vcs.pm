package saiten::saiten;

use strict;
use warnings;

use saiten::diff;

#
# CSS および JavaScript
#

my $vcs1_style = <<'__END__';
td.nowrap { white-space: nowrap; }
pre span.add_mark, pre span.new_line { color: blue; }
__END__

my $vcs2_style = <<'__END__';
td.nowrap { white-space: nowrap; }
tr.hidden { display: none; }
span.clickable { color: blue; cursor: pointer; }
pre { color: #1f1f1f; }
pre span.space { color: lightgray; }
pre span.del_mark, pre span.old_line { color: red; }
pre span.add_mark, pre span.new_line { color: blue; }
pre span.old_line span.space { color: pink; }
pre span.new_line span.space { color: lightblue; }
__END__

my $vcs3_style = <<'__END__';
td.nowrap { white-space: nowrap; }
tr.hidden { display: none; }
span.clickable { color: blue; cursor: pointer; }
pre { color: #1f1f1f; }
pre span.space { color: lightgray; }
pre span.del_mark { color: red; }
pre span.add_mark { color: blue; }
pre span.old_line { color: darkred; }
pre span.new_line { color: darkblue; }
pre span.old_line span.space { color: pink; }
pre span.new_line span.space { color: lightblue; }
pre span.old_char { background: lavenderblush; color: red; }
pre span.new_char { background: lightcyan; color: blue; }
__END__

my $vcs_script = <<'__END__';
var request = null;
function toggle_diff(rev, old) {
	var tr = document.getElementById('tr-' + rev);
	if (tr.className != 'hidden') {
		tr.className = 'hidden';
	} else if (document.getElementById('pre-' + rev)) {
		tr.className = '';
	} else if (request == null) {
		request = new XMLHttpRequest();
		var pre = document.createElement('pre');
		pre.id = 'pre-' + rev;
		pre.innerHTML = 'ロード中...';
		document.getElementById('td-' + rev).appendChild(pre);
		tr.className = '';
		request.onreadystatechange = function () {
			if (request != null && request.readyState == 4) {
				if (request.status == 200) {
					pre.innerHTML = request.responseText;
				} else {
					pre.innerHTML = 'ロード失敗: ' + request.statusText;
				}
				request = null;
			}
		};
		request.open('GET', diff_path + '&old=' + old + '&new=' + rev, true);
		request.send('');
	}
}
__END__

#
# vcs ページ
#

# $app->vcs($fresh, $path) : $vcs
# vcs オブジェクトを生成する。
sub vcs {
	my ($app, $fresh, $path) = @_;
	if (! defined $app->{vcs}) {
		eval "require $app->{vcs_class}";
		$app->{vcs} = $app->{vcs_class}->new(sub { $app->error(@_) },
				$app->{vcs_repo}, $fresh, $app->{base_dir}, $path);
	}
	return $app->{vcs};
}

# $app->check_vcs_user($fresh) : $fresh_name
# vcs ユーザー名 $fresh をチェックする。
sub check_vcs_user {
	my ($app, $fresh) = @_;
	if (defined $app->{vcs_user} && defined $app->{vcs_user}->{$fresh}) {
		return $app->{vcs_user}->{$fresh};
	}
	return $app->db->check_fresh($fresh);
}

# $app->check_vcs_path($path)
# vcs パス名 $path をチェックする。
sub check_vcs_path {
	my ($app, $path) = @_;
	if (! defined $path || $path !~ /^[-A-Za-z0-9\/]+\.[a-z]+$/) {
		$app->error('パス名が不適切です。');
	}
}

# $app->vcs_path($exercise, $filename) : $path, $dirname, $basename
# vcs 用のパス名を返す。
sub vcs_path {
	my ($app, $exercise, $filename) = @_;
	$app->db->check_exercise($exercise);
	$filename =~ s/%2f/\//gi if defined $filename;
	$app->check_vcs_path($filename) if defined $filename;
	my ($dir, $class);
	if ($exercise =~ /^([^-])([^-]*)-(\d+)-(\d+)$/) {
		my ($a, $aa, $b, $c, $d) = ($1, $1, $2, $3, $4);
		$aa =~ tr/a-z/A-Z/;
		if (defined $app->{basic_dir_func}) {
			($dir, $class) = $app->{basic_dir_func}->("$a$b", $c, $d);
		} else {
			$dir = "$a$b/$c";
		}
		if (! defined $class) {
			$class = sprintf('%s%s%02d%02d', $aa, $b, $c, $d);
		}
	} elsif ($exercise =~ /^([^-]+)-(\d+)$/) {
		$dir = $app->{advanced_dir}->{$1} || $1;
		if (defined $app->{advanced_dir_func}) {
			($dir, $class) = $app->{advanced_dir_func}->($1, $2);
		} elsif (! defined $app->{advanced_base}) {
			$class = sprintf('%s%02d', $app->{advanced_class}->{$1}, $2);
		} else {
			$dir = $app->{advanced_base} . '/' . $1;
			$class = $app->{advanced_class}->{$1};
		}
	}
	if (! defined $dir || ! defined $class) {
		$app->error('その問題には対応していません。');
	}
	$filename = $class . '.' . $app->{file_ext} if ! defined $filename;
	return $dir . '/' . $filename, $dir, $filename;
}

# $app->add_style_script($fresh, $path)
# $app->{html} に style と script を追加する。
sub add_style_script {
	my ($app, $fresh, $path) = @_;
	my $html = $app->{html};
	if ($app->{vcs_mode} == 1) {
		$html->add_style($vcs1_style);
	} else {
		$html->add_style($app->{vcs_mode} == 2 ? $vcs2_style : $vcs3_style);
		$html->add_script("var diff_path = '" .
				$html->{cgi_file} . "?mode=diff&fresh=$fresh&path=$path';");
		$html->add_script($vcs_script);
	}
}

# $app->print_select_form($mode, $fresh, $fresh_class, $exercise)
# 新人と問題を選択するフォームを表示する。
sub print_select_form {
	my ($app, $mode, $fresh, $fresh_class, $exercise) = @_;
	my $html = $app->{html};

	my (@fresh_rows, @exercise_rows);
	if (defined $mode) {
		@fresh_rows = $app->db->fresh_exercise($exercise);
		@exercise_rows = $app->db->exercise_fresh($fresh);
	} else {
		@fresh_rows = $app->db->fresh_list;
		@exercise_rows = map { [$_] } @{$app->{exercises}};
	}

	$html->print_open_form('get');
	$html->print_hidden($html->kv(mode => $mode), $app->kv_user);
	$html->println('新人：');
	$html->print_open('select', name => 'fresh');
	foreach my $row (@fresh_rows) {
		my ($target, $target_name, $serial) = @$row;
		my $flag = defined $mode && ! $serial;
		$html->print_option($target,
				$html->paren($target_name, $flag), $target eq $fresh);
	}
	if (defined $app->{vcs_user}) {
		foreach my $target (keys %{$app->{vcs_user}}) {
			my $target_name = $app->{vcs_user}->{$target};
			$html->print_option($target, $target_name, $target eq $fresh);
		}
	}
	$html->print_close('select');
	$html->println('　問題：');
	$html->print_open('select', name => 'exercise');
	foreach my $row (@exercise_rows) {
		my ($id, $level, $serial) = @$row;
		my $flag = defined $mode &&
				(defined $fresh_class ? ! $serial : $level > 1);
		$html->print_option($id, $html->paren($id, $flag), $id eq $exercise);
	}
	$html->print_close('select');
	$html->print_input('submit', undef, 'Go');
	$html->print_close('form');
}

# $app->print_select_forms($mode, $fresh, $fresh_class, $exercise, @files)
# 新人と問題を選択するフォームを表示する。
sub print_select_forms {
	my ($app, $mode, $fresh, $fresh_class, $exercise, $basename, @files) = @_;
	my $html = $app->{html};

	$html->print_open('div', style => 'overflow: hidden;');

	$html->print_open('div', style => 'float: left;');
	$app->print_select_form($mode, $fresh, $fresh_class, $exercise);
	$html->print_close('div');

	if (@files) {
		$html->print_tag('div', '　　', style => 'float: left;');

		$html->print_open('div', style => 'float: left; margin-right: -50%;');
		$html->print_open_form('get');
		$html->print_hidden($html->kv(mode => $mode), $app->kv_user,
				fresh => $fresh, exercise => $exercise);
		$html->println('他のファイル：');
		$html->print_open('select', name => 'filename');
		foreach my $file (@files) {
			$html->print_option($file, $file, $file eq $basename);
		}
		$html->print_close('select');
		$html->print_input('submit', undef, 'Go');
		$html->print_close('form');
		$html->print_close('div');
	}

	$html->print_close('div');
	$html->print_p('');
}

# $app->print_vcs($fresh, $path)
# vcs テーブルを表示する。
sub print_vcs {
	my ($app, $fresh, $path) = @_;
	my $html = $app->{html};

	my $vcs = $app->vcs($fresh, $path);
	my @revs = $vcs->revs;
	if (! @revs) {
		$html->print_p('※ この問題のソースはコミットされてないようです。');
		return;
	}

	my $diff = saiten::diff->new($html);
	if ($app->{vcs_mode} == 1) {
		$diff->{add_only} = 1;
	} elsif ($app->{vcs_mode} == 3) {
		$diff->{diff_chars} = 1;
		$diff->{show_spaces} = 1;
	}

	$html->print_open('table', class => 'bordered', border => 1);

	$html->print_open('tr');
	$html->print_th('rev');
	$html->print_th('author');
	$html->print_th('date');
	$html->print_th('log');
	$html->print_close('tr');

	for (my $i = 0; $i <= $#revs; $i++) {
		my ($rev, $old) = ($revs[$i], $revs[$i + 1] || $revs[$i]);
		my ($author, $date, $log) = $vcs->info($rev);

		$html->print_open('tr');
		$html->print_td_center($app->{vcs_mode} == 1 ? ($rev) :
				($html->span('clickable', $rev),
						onclick => "toggle_diff('$rev', '$old');"));
		$html->print_td($html->paren($author, $author ne $fresh));
		$html->print_td($date, class => 'nowrap');
		$html->print_td($log);
		$html->print_close('tr');

		$html->print_open('tr', $app->{vcs_mode} == 1 ? () :
				(id => "tr-$rev", $i > 0 ? (class => 'hidden') : ()));
		$html->print_open('td',
				$app->{vcs_mode} == 1 ? () : (id => "td-$rev"), colspan => 4);
		if ($app->{vcs_mode} == 1 && $author eq $fresh) {
			$html->println($html->paren($vcs->cat($rev) . ' lines'));
		} elsif ($app->{vcs_mode} == 1 || $i == 0) {
			$html->print_open('pre',
					$app->{vcs_mode} == 1 ? () : (id => "pre-$rev"));
			$diff->print_diff([$vcs->cat($old)], [$vcs->cat($rev)]);
			$html->print_close('pre');
		}
		$html->print_close('td');
		$html->print_close('tr');
	}

	$html->print_close('table');
}

# $app->fresh_vcs($exercise)
# 新人用 vcs ページを表示する。
sub fresh_vcs {
	my ($app, $exercise) = @_;
	$app->require_user;
	if (! $app->{vcs_mode}) {
		$app->error('スタッフコメントは svn update して見てください。');
	}
	my ($path) = $app->vcs_path($exercise);

	$app->add_style_script($app->{user}, $path);
	my $html = $app->start_html('スタッフコメント');
	$html->print_p("問題 $exercise に対するスタッフのコメントです。",
			$html->colored_string('red',
					'※ svn update しないと svn commit に失敗するよ！'));

	$app->print_vcs($app->{user}, $path);

	$app->print_cgi_link('戻る');
	$app->print_cgi_link('いままでの結果を確認する', 'status');
	$html->print_tail;
}

# $app->staff_vcs($fresh, $exercise, $filename)
# スタッフ用 vcs ページを表示する。
sub staff_vcs {
	my ($app, $fresh, $exercise, $filename) = @_;
	my ($fresh_name, $fresh_class) = $app->check_vcs_user($fresh);
	my ($path, $dirname, $basename) = $app->vcs_path($exercise, $filename);

	$app->add_style_script($fresh, $path);
	my $html = $app->start_html('ソース閲覧');
	$html->print_p('新人、' . $fresh_name . ' ' . $html->paren($fresh) .
			(defined $filename ? " のファイル $basename です。" :
					" の問題 $exercise に対するソースです。"));

	$app->print_select_forms('vcs', $fresh, $fresh_class, $exercise,
			$basename, sort $app->vcs($fresh, $path)->ls_files($dirname));

	$app->print_vcs($fresh, $path);

	$app->print_cgi_link('戻る');
	$html->print_tail;
}

# $app->vcs_diff($fresh, $path, $old_rev, $new_rev)
# vcs diff データを送信する。
sub vcs_diff {
	my ($app, $fresh, $path, $old_rev, $new_rev) = @_;
	$app->check_vcs_user($fresh);
	$app->check_vcs_path($path);

	my $vcs = $app->vcs($fresh, $path);

	my $html = $app->{html};
	my $diff = saiten::diff->new($html);
	if ($app->{vcs_mode} == 3) {
		$diff->{diff_chars} = 1;
		$diff->{show_spaces} = 1;
	}

	$html->print("Content-Type: text/plain; charset=UTF-8\r\n");
	$html->print("\r\n");
	$diff->print_diff([$vcs->cat($old_rev)], [$vcs->cat($new_rev)]);
	$html->flush;
}

1;
