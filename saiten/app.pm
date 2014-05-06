package saiten::app;

use strict;
use warnings;

use saiten::html;

#
# コンストラクタ
#

# saiten::app->new($title, $cgi_file [, @args])
# コンストラクタ。引数はタイトルと CGI ファイル名など。
sub new {
	my ($class, $title, $cgi_file, @args) = @_;
	my $app = {
		html => saiten::html->new($title, $cgi_file),
		args => \@args,
		dbclass => undef,
		user_key => 'user'
	};
	return bless $app, $class;
}

# $app->param_names : @param_names
# $app の有効なパラメータ名のリストを返す。
sub param_names {
	return ();
}

# $app->set(%params)
# $app のパラメータを設定する。
sub set {
	my ($app, %params) = @_;
	foreach my $key (keys %params) {
		die "bad key '$key'" unless grep { $_ eq $key } $app->param_names;
		$app->{$key} = $params{$key};
	}
}

# $app->db
# 未接続なら DB に接続して $app->{db} を初期化し、それを返す。
sub db {
	my $app = shift;
	if (! defined $app->{db}) {
		$app->{db} = $app->{dbclass}->new(
				sub { $app->error(@_) }, @{$app->{args}});
	}
	return $app->{db};
}

#
# エラー処理ルーチン
#

# $app->error(@message)
# エラーページを表示して、終了する。$html->flush を呼ぶ前に呼ぶこと。
sub error {
	my $app = shift;
	my $html = $app->{html};
	$html->clear;
	$html->print_head('エラー');
	$html->print_p(@_);
	$html->print_link('戻る');
	$html->print_tail;
	exit;
}

# $app->debug(@args)
# デバッグページを表示して、終了する。$html->flush を呼ぶ前に呼ぶこと。
sub debug {
	require Data::Dumper;
	my $app = shift;
	print "Content-Type: text/plain; charset=UTF-8\r\n\r\n";
	print Data::Dumper::Dumper(@_);
	exit;
}

#
# 共通ルーチン
#

# $app->start_html([$str])
# HTML の始まりを表示し、$app->{html} を返す。
sub start_html {
	my ($app, $str) = @_;
	my $html = $app->{html};
	$html->print_head($str, $app->{user});
	return $html;
}

# $app->today : $today
# 今日の日付を "yyyy-mm-dd" 形式の文字列で返す。
sub today {
	my @time = localtime;
	return sprintf("%04d-%02d-%02d", $time[5] + 1900, $time[4] + 1, $time[3]);
}

# $app->trim_date($date) : $date
# 日付文字列 "yyyy-mm-dd hh:mm:ss.xxx" のミリ秒部分を取り除いたものを返す。
sub trim_date {
	my ($app, $date) = @_;
	$date =~ s/\..*$// if defined $date;
	return $date;
}

#
# top ページ
#

# $app->top
# top ページを表示する。
sub top {
	my $app = shift;
	my $html = $app->start_html;
	$html->print_p('Hello, World!');
	$html->print_tail;
}

#
# メインルーチン
#

# $app->get_params : %param
# CGI のパラメータを取得し、ハッシュに格納して返す。
sub get_params {
	my $method = $ENV{REQUEST_METHOD};
	my $query = $ENV{QUERY_STRING};
	my %param;
	if (! defined $method) {
		$query = join '&', @ARGV;
	} elsif ($method eq 'POST') {
		$query = '';
		my $length = $ENV{CONTENT_LENGTH};
		read(STDIN, $query, $length) if $length > 0;
	}
	foreach (split /&/, $query) {
		$param{$1} = join '&', $param{$1} || (), $2 if /^([^=]+)=(.*)$/;
	}
	return %param;
}

# $app->main
# メインルーチン。
sub main {
	my $app = shift;
	my %param = $app->get_params;
	if (%param) {
		$app->debug(\%param);
	} else {
		$app->top;
	}
}

1;
