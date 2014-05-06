package saiten::diff_app;

use base 'saiten::app';

use strict;
use warnings;

use saiten::diff;

#
# CSS および JavaScript
#

my $style = <<'__END__';
body { background: white; margin: 1em; }'
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

#
# コンストラクタ
#

# saiten::diff_app->new($title, $cgi_file)
# コンストラクタ。引数はタイトルと CGI ファイル名。
sub new {
	my $app = shift->SUPER::new(@_);
	$app->{html}->add_style($style);
	return $app;
}

# $app->param_names : @param_names
# $app の有効なパラメータ名のリストを返す。
sub param_names {
	return ('old_file', 'new_file');
}

#
# 共通ルーチン
#

# $app->read_file($file) : @lines
# $file の中身をリストで返す。
sub read_file {
	my ($app, $file) = @_;
	open my $fh, '<', $file
			or $app->error('ファイルのオープンに失敗しました。');
	my @lines = <$fh>;
	close $fh;
	chomp @lines;
	return @lines;
}

#
# メインルーチン
#

# $app->main
# メインルーチン。
sub main {
	my $app = shift;
	my ($old, $new) = ($app->{old_file}, $app->{new_file});
	my @old = $app->read_file($old);
	my @new = $app->read_file($new);
	my $html = $app->start_html($old . ' vs ' . $new);
	my $diff = saiten::diff->new($html);
	$html->print_open('pre');
	$diff->print_diff(\@old, \@new);
	$html->print_close('pre');
	$html->print_tail;
}

1;
