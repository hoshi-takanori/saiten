package saiten::saiten;

use strict;
use warnings;

use saiten::vcs;
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
	if (! defined $path || $path !~ /^[A-Za-z0-9\/]+\.[a-z]+$/) {
		$app->error('パス名が不適切です。');
	}
}

# $app->vcs_path($exercise) : $path
# vcs 用のパス名を返す。
sub vcs_path {
	my ($app, $exercise) = @_;
	$app->db->check_exercise($exercise);
	my ($dir, $class);
	if ($exercise =~ /^([^-])([^-]*)-(\d+)-(\d+)$/) {
		my ($a, $aa, $b, $c, $d) = ($1, $1, $2, $3, $4);
		$aa =~ tr/a-z/A-Z/;
		$dir = "$a$b/$c";
		$class = sprintf('%s%s%02d%02d', $aa, $b, $c, $d);
	} elsif ($exercise =~ /^([^-]+)-(\d+)$/ && $app->{advanced_class}->{$1}) {
		$dir = $app->{advanced_dir}->{$1} || $1;
		$class = sprintf('%s%02d', $app->{advanced_class}->{$1}, $2);
	} else {
		$app->error('その問題には対応していません。');
	}
	return sprintf('%s/%s/%s.%s',
			$app->{base_dir}, $dir, $class, $app->{file_ext});
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

# $app->print_vcs($fresh, $path)
# vcs テーブルを表示する。
sub print_vcs {
	my ($app, $fresh, $path) = @_;
	my $html = $app->{html};

	my $vcs = saiten::vcs->new(
			sub { $app->error(@_) }, $app->{vcs_repo} . '/' . $fresh, $path);
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

	$html->print_open('table', border => 1);

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
			$html->print_open('pre');
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
	my $path = $app->vcs_path($exercise);

	$app->add_style_script($app->{user}, $path);
	my $html = $app->start_html('スタッフコメント');
	$html->print_p("問題 $exercise に対するスタッフのコメントです。",
			'※ svn update しないと svn commit に失敗するよ！');

	$app->print_vcs($app->{user}, $path);

	$app->print_cgi_link('戻る');
	$app->print_cgi_link('いままでの結果を確認する', 'status');
	$html->print_tail;
}

# $app->staff_vcs($fresh, $exercise)
# スタッフ用 vcs ページを表示する。
sub staff_vcs {
	my ($app, $fresh, $exercise) = @_;
	my ($fresh_name, $fresh_class) = $app->check_vcs_user($fresh);
	my $path = $app->vcs_path($exercise);

	$app->add_style_script($fresh, $path);
	my $html = $app->start_html('ソース閲覧');
	$html->print_p('新人、' . $fresh_name . ' ' . $html->paren($fresh) .
			" の問題 $exercise に対するソースです。");

	$html->print_open('p');
	$html->print_open_form('get');
	$html->println('新人選択：');
	$html->print_hidden(mode => 'vcs', $app->kv_user);
	$html->print_open('select', name => 'fresh');
	foreach my $row ($app->db->fresh_exercise($exercise)) {
		my ($target, $target_name, $serial) = @$row;
		$html->print_option($target,
				$html->paren($target_name, ! $serial), $target eq $fresh);
	}
	if (defined $app->{vcs_user}) {
		foreach my $target (keys %{$app->{vcs_user}}) {
			my $target_name = $app->{vcs_user}->{$target};
			$html->print_option($target, $target_name, $target eq $fresh);
		}
	}
	$html->print_close('select');
	$html->print_hidden(exercise => $exercise);
	$html->print_input('submit', undef, 'Go');
	$html->print_close('form');
	$html->print_close('p');

	if (defined $fresh_class) {
		$html->print_open('p');
		$html->print_open_form('get');
		$html->println('問題選択：');
		$html->print_hidden(mode => 'vcs', $app->kv_user, fresh => $fresh);
		$html->print_open('select', name => 'exercise');
		foreach my $row ($app->db->exercise_fresh($fresh)) {
			my ($id, $level, $serial) = @$row;
			$html->print_option($id,
					$html->paren($id, ! $serial), $id eq $exercise);
		}
		$html->print_close('select');
		$html->print_input('submit', undef, 'Go');
		$html->print_close('form');
		$html->print_close('p');
	}

	$app->print_vcs($fresh, $path);

	$app->print_cgi_link('戻る');
	$html->print_tail;
}

# $app->vcs_diff($fresh, $path, $old_rev, $new_rev)
# vcs diff を表示する。
sub vcs_diff {
	my ($app, $fresh, $path, $old_rev, $new_rev) = @_;
	$app->check_vcs_user($fresh);
	$app->check_vcs_path($path);

	my $vcs = saiten::vcs->new(
			sub { $app->error(@_) }, $app->{vcs_repo} . '/' . $fresh, $path);

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
