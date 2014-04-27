package saiten::html;

use strict;
use warnings;

#
# コンストラクタ
#

# saiten::html->new($title, $cgi_file)
# コンストラクタ。引数はタイトルと CGI ファイル名。
sub new {
	my ($class, $title, $cgi_file) = @_;
	my $html = {
		title => $title,
		cgi_file => $cgi_file,
		style => [],
		script => [],
		buffer => []
	};
	return bless $html, $class;
}

# $html->clear
# 表示用バッファの内容をクリアする。
sub clear {
	my $html = shift;
	$html->{buffer} = [];
}

#
# HTML タグ文字列ルーチン
#

# $html->key_value($key => $value)
# $value が undef でなければ $key => $value を、undef なら () を返す。
sub key_value {
	my ($html, $key, $value) = @_;
	return defined $value ? ($key => $value) : ();
}

# $html->paren($str [, $flag [, $open [, $close]]])
# フラグ $flag が undef または真なら、括弧でくくった文字列 ($str) を返す。
sub paren {
	my ($html, $str, $flag, $open, $close) = @_;
	if (defined $flag && ! $flag) {
		return $str;
	} elsif (! defined $open) {
		return '(' . $str . ')';
	} else {
		return $open . $str . (defined $close ? $close : $open);
	}
}

# $html->open_tag($tag [, $key => $value, ...])
# 開きタグ <$tag> または <$tag $key="$value" ...> を返す。
sub open_tag {
	my ($html, $tag) = (shift, shift);
	while (@_) {
		my ($key, $value) = (shift, shift);
		$tag .= ' ' . $key;
		if (defined $value) {
			$tag .= '=' . $html->paren($value, $value !~ /^\d+$/, '"');
		}
	}
	return $html->paren($tag, undef, '<', '>');
}

# $html->close_tag($tag)
# 閉じタグ </$tag> を返す。
sub close_tag {
	my ($html, $tag) = @_;
	return $html->paren($tag, undef, '</', '>');
}

# $html->tagged_string($tag, $str [, $key => $value, ...])
# タグで囲まれた文字列 <$tag $key="$value" ...>$str</$tag> を返す。
sub tagged_string {
	my ($html, $tag, $str, @args) = @_;
	return $html->open_tag($tag, @args) . $str . $html->close_tag($tag);
}

# $html->span_tag($class)
# 開き span タグ <span class="$class"> を返す。
sub span_tag {
	my ($html, $class) = @_;
	return $html->open_tag('span', class => $class);
}

# $html->span($class, $str)
# span タグで囲まれた文字列 <span class="$class">$str</span> を返す。
sub span {
	my ($html, $class, $str) = @_;
	return defined $class ?
			$html->tagged_string('span', $str, class => $class) : $str;
}

# $html->colored_string($color, $str)
# 色つき文字列 <font color="$color">$str</font> を返す。
sub colored_string {
	my ($html, $color, $str) = @_;
	return defined $color ?
			$html->tagged_string('font', $str, color => $color) : $str;
}

# $html->link_tag($str [, $url [, $key => $value, ...]])
# リンクタグで囲まれた文字列 <a href="$url?$key=$value...">$str</a> を返す。
sub link_tag {
	my ($html, $str, $url, $sep) = (shift, shift, shift, '?');
	$url = $html->{cgi_file} unless defined $url;
	while (@_) {
		my ($key, $value) = (shift, shift);
		$url .= $sep . $key . '=' . $value;
		$sep = '&';
	}
	return $html->tagged_string('a', $str, href => $url);
}

#
# HTML タグ表示ルーチン
#

# $html->print($str [, $str, ...])
# 引数 $str, ... をすべて表示用バッファに追加する。
sub print {
	my $html = shift;
	push @{$html->{buffer}}, @_;
}

# $html->println($str [, $str, ...])
# 引数 $str, ... をそれぞれ改行つきで表示用バッファに追加する。
sub println {
	my $html = shift;
	foreach my $str (@_) {
		$html->print($str . "\n");
	}
}

# $html->flush
# 表示用バッファの内容をすべて表示する。
sub flush {
	my $html = shift;
	print @{$html->{buffer}};
}

# $html->print_open_tag([undef,] $tag [, $key => $value, ...])
# 開きタグを <$tag> や <$tag $key="$value" ...> のように表示。
# 最初の引数が undef ならば改行しない。そうでなければ改行する。
sub print_open_tag {
	my ($html, $tag, $cr) = (shift, shift, "\n");
	if (! defined $tag) {
		($tag, $cr) = (shift, '');
	}
	$html->print($html->open_tag($tag, @_) . $cr);
}

# $html->print_close_tag($tag)
# 閉じタグ </$tag> を表示し、改行する。
sub print_close_tag {
	my ($html, $tag) = @_;
	$html->println($html->close_tag($tag));
}

# $html->print_tag($tag, $str [, $key => $value, ...])
# タグで囲まれた文字列 <$tag $key="$value" ...>$str</$tag> を表示、改行。
sub print_tag {
	my $html = shift;
	$html->println($html->tagged_string(@_));
}

# $html->print_p($str [, $str, ...])
# p タグで囲まれた文字列 <p>$str</p> を表示、改行。
# 文字列が複数あれば、間に改行タグ <br> をはさむ。
sub print_p {
	my $html = shift;
	$html->print_tag('p', join $html->open_tag('br') . "\n", @_);
}

# $html->print_link($str [, $url [, $key => $value, ...]])
# リンク文字列 <p><a href="$url?$key=$value...">$str</a></p> を表示、改行。
sub print_link {
	my $html = shift;
	$html->print_tag('p', $html->link_tag(@_));
}

# $html->print_open_form($method [, $action [, $confirm]])
# 開き form タグ <form method="$method" action="$action"> を表示、改行。
sub print_open_form {
	my ($html, $method, $action, $confirm) = @_;
	my @args = (method => $method, action => $action || $html->{cgi_file});
	if ($confirm) {
		push @args, onsubmit => "return window.confirm('$confirm');";
	}
	$html->print_open_tag('form', @args);
}

# $html->print_input($type, $name [, $value])
# input タグ <input type="$type" name="$name" value="$value"> を表示、改行。
# $name および $value は省略可。$name を省略する場合は undef を指定する。
sub print_input {
	my ($html, $type, $name, $value) = @_;
	my @args = (type => $type);
	if (defined $name) {
		push @args, name => $name;
	}
	if (defined $value) {
		push @args, value => $value;
	}
	$html->print_open_tag('input', @args);
}

# $html->print_hidden($key => $value [, ...])
# いくつかの hidden 属性を表示。
sub print_hidden {
	my $html = shift;
	while (@_) {
		my ($key, $value) = (shift, shift);
		$html->print_input('hidden', $key, $value);
	}
}

# $html->print_option($value, $str [, $selected])
# option タグ <option value="$value" [selected]>$str</option> を表示、改行。
sub print_option {
	my ($html, $value, $str, $selected) = @_;
	if ($selected) {
		$html->print_tag('option', $str, value => $value, 'selected');
	} else {
		$html->print_tag('option', $str, value => $value);
	}
}

# $html->print_button_form($button, $confirm [, $key => $value, ...])
# いくつかの hidden 属性とひとつのボタンからなる、単純なフォームを表示。
sub print_button_form {
	my ($html, $button, $confirm, @args) = @_;
	$html->print_open_form('post', undef, $confirm);
	$html->print_hidden(@args);
	$html->print_input('submit', undef, $button);
	$html->print_close_tag('form');
}

# $html->print_th($str [, $key => $value, ...])
# th タグで囲まれた文字列 <th $key="$value" ...>$str</th> を表示、改行。
sub print_th {
	my ($html, $str) = (shift, shift);
	$html->print_tag('th', $str, @_);
}

# $html->print_td($str [, $key => $value, ...])
# td タグで囲まれた文字列 <td $key="$value" ...>$str</td> を表示、改行。
# $str が undef または '' ならば、代わりに &nbsp; を使用。
sub print_td {
	my ($html, $str) = (shift, shift);
	$str = '&nbsp;' unless defined $str && $str ne '';
	$html->print_tag('td', $str, @_);
}

# $html->print_td_center($str [, $key => $value, ...])
# 中央寄せされた td タグ <td align="center" key=...>$str</td> を表示、改行。
# $str が undef または '' ならば、代わりに &nbsp; を使用。
sub print_td_center {
	my ($html, $str) = (shift, shift);
	$html->print_td($str, align => 'center', @_);
}

# $html->print_td_right($str [, $key => $value, ...])
# 中央寄せされた td タグ <td align="right" key=...>$str</td> を表示、改行。
# $str が undef または '' ならば、代わりに &nbsp; を使用。
sub print_td_right {
	my ($html, $str) = (shift, shift);
	$html->print_td($str, align => 'right', @_);
}

# $html->print_td_format($format, $number)
# $number を $format でフォーマットして、td タグで右寄せして表示、改行。
# $number が undef ならば、代わりに &nbsp; を使用。
sub print_td_format {
	my ($html, $format, $number) = @_;
	$html->print_td_right(defined $number ? sprintf($format, $number) : undef);
}

#
# HTML 表示ルーチン
#

# $html->add_style(@styles)
# CSS style を追加。
sub add_style {
	my $html = shift;
	push $html->{style}, @_;
}

# $html->add_script(@scripts)
# JavaScript を追加。
sub add_script {
	my $html = shift;
	push $html->{script}, @_;
}

# $html->print_head([$str [, $user]])
# HTML の始まりを表示。$str や $user を指定すると title, h1 タグに追加される。
sub print_head {
	my ($html, $str, $user) = @_;
	my $title = $html->{title};
	$title .= ' - ' . $str if defined $str;
	$title .= ' ' . $html->paren($user) if defined $user;
	$html->print("Content-Type: text/html; charset=UTF-8\r\n");
	$html->print("\r\n");
	$html->print_open_tag('!DOCTYPE', 'html');
	$html->print_open_tag('html');
	$html->print_open_tag('head');
	$html->print_open_tag('meta', charset => 'UTF-8');
	$html->print_tag('title', $title);
	$html->print_lines($html->{style}, 'style', type => 'text/css');
	$html->print_lines($html->{script}, 'script', type => 'text/javascript');
	$html->print_close_tag('head');
	$html->print_open_tag('body');
	$html->print_tag('h1', $title);
}

# $html->print_lines($lines [, $tag [, $key => $value, ...]])
# 配列 @$lines が空でなければその中身を、$tag があればそれで囲んで表示する。
sub print_lines {
	my ($html, $lines, $tag, @args) = @_;
	if (@$lines) {
		$html->print_open_tag($tag, @args) if $tag;
		$html->println(@$lines);
		$html->print_close_tag($tag) if $tag;
	}
}

# $html->print_file($file [, $tag [, $key => $value, ...]])
# ファイル $file があればその中身を、$tag があればそれで囲んで表示する。
sub print_file {
	my ($html, $file, $tag, @args) = @_;
	if (defined $file && -f $file && open my $fh, $file) {
		$html->print_open_tag($tag, @args) if $tag;
		$html->print(<$fh>);
		close $fh;
		$html->print_close_tag($tag) if $tag;
	}
}

# $html->print_tail
# HTML の終わりを表示して、表示用バッファをフラッシュする。
sub print_tail {
	my $html = shift;
	$html->print_close_tag('body');
	$html->print_close_tag('html');
	$html->flush;
}

1;
