package saiten::diff;

use strict;
use warnings;

use Encode;
use Algorithm::Diff;

#
# コンストラクタ
#

# saiten::diff->new($html)
# コンストラクタ。
sub new {
	my ($class, $html) = @_;
	return bless { html => $html }, $class;
}

#
# diff ルーチン
#

# $diff->diff_chunks($old, $new, $conv_line, $recursive) : @chunks
# diff を生成する。
sub diff_chunks {
	my ($diff, $old, $new, $conv_line, $recursive) = @_;
	my @diffs = Algorithm::Diff::diff($old, $new);
	my @chunks;
	my ($i, $j) = (0, 0);
	my $make_chunk = sub {
		my ($l, $k) = @_;
		my @lines;
		for ( ; $$l < $k; $i++, $j++) {
			push @lines, $conv_line->($new->[$j]);
		}
		push @chunks, ['=', \@lines] if @lines;
	};
	foreach my $hunk (@diffs) {
		my (@del, @add);
		foreach my $each (@$hunk) {
			my ($ch, $k, $line) = @$each;
			$make_chunk->($ch eq '-' ? \$i : \$j, $k);
			push @{$ch eq '-' ? \@del : \@add}, $line;
			$ch eq '-' ? $i++ : $j++;
		}
		if ($recursive && @del && @add) {
			push @chunks, ['!', $diff->diff_chars(\@del, \@add)];
		} else {
			@del = map { $conv_line->($_) } @del;
			@add = map { $conv_line->($_) } @add;
			push @chunks, ['!', \@del, \@add];
		}
	}
	$make_chunk->(\$j, $#$new + 1);
	return @chunks;
}

# $diff->diff_chars($del, $add) : \@del, \@add
# 文字単位の diff を生成する。
sub diff_chars {
	my ($diff, $del, $add) = @_;
	my @old = split //, decode('UTF-8', join("\n", @$del));
	my @new = split //, decode('UTF-8', join("\n", @$add));
	my @chunks = $diff->diff_chunks(\@old, \@new, sub { return $_[0]; });
	my @del = $diff->make_lines('-', @chunks);
	my @add = $diff->make_lines('+', @chunks);
	return \@del, \@add;
}

# $diff->make_lines($which, @chunks) : @lines
# 文字単位の diff から行を再構成する。
sub make_lines {
	my ($diff, $which, @chunks) = @_;
	my $html = $diff->{html};
	my (@lines, @line);
	my $add_line = sub {
		push @lines, $diff->conv_line(@line);
		@line = ();
	};
	my $add_chars = sub {
		my $class = shift;
		push @line, $html->span_tag($class) if defined $class;
		foreach my $c (@_) {
			if ($c eq "\n") {
				push @line, $html->close_tag('span') if defined $class;
				$add_line->();
				push @line, $html->span_tag($class) if defined $class;
			} else {
				push @line, $c;
			}
		}
		push @line, $html->close_tag('span') if defined $class;
	};
	foreach my $chunk (@chunks) {
		my ($ch, $old, $new) = @$chunk;
		if ($ch eq '=') {
			$add_chars->(undef, @$old);
		} elsif ($which eq '-') {
			$add_chars->('old_char', @$old);
		} else {
			$add_chars->('new_char', @$new);
		}
	}
	$add_line->();
	return @lines;
}

#
# ソース表示ルーチン
#

# $diff->conv_line(@chars) : $line
# 一行分の文字の配列を表示用文字列に変換する。
sub conv_line {
	my ($diff, @chars) = @_;
	my $html = $diff->{html};
	my ($line, $pos, $space) = ('', 0, 0);
	my $add_char = sub {
		my ($sp, $c, $cnt) = @_;
		if (defined $sp && $space != $sp) {
			$line .= ($space = $sp) ?
					$html->span_tag('space') : $html->close_tag('span');
		}
		if (defined $c) {
			$line .= $c;
			$pos += defined $cnt ? $cnt : length($c);
		}
	};
	if (! @chars) {
		$add_char->(1, '(空行)', 0);
	}
	foreach my $c (@chars) {
		$c = encode('UTF-8', $c);
		if ($c eq "\t") {
			$add_char->(1, substr('--->', $pos % 4 - 4));
		} elsif ($c eq '　') {
			$add_char->(1, '全', 2);
		} elsif ($c eq ' ') {
			$add_char->(1, '_', 1);
		} elsif ($c eq '&') {
			$add_char->(0, '&amp;', 1);
		} elsif ($c eq '<') {
			$add_char->(0, '&lt;', 1);
		} elsif ($c eq '>') {
			$add_char->(0, '&gt;', 1);
		} elsif ($c =~ /^<.*>$/) {
			$add_char->(0, $c, 0);
		} else {
			$add_char->(0, $c, length($c) == 1 ? 1 : 2);
		}
	}
	$add_char->(0);
	return $line;
}

# $diff->conv_diff($old, $new) : $string
# diff を表示用文字列に変換する。
sub conv_diff {
	my ($diff, $old, $new) = @_;
	my $html = $diff->{html};
	my @chunks = $diff->diff_chunks($old, $new, sub { return
			$diff->conv_line(split(//, decode('UTF-8', $_[0]))); }, 1);
	my @lines;
	foreach my $chunk (@chunks) {
		my ($ch, $del, $add) = @$chunk;
		if ($ch eq '=') {
			push @lines, map { '  ' . $_ } @$del;
		} else {
			if (! @$del || ! @$add) {
				@$del = map { $html->span('old_char', $_) } @$del;
				@$add = map { $html->span('new_char', $_) } @$add;
			}
			push @lines, map { $html->span('del_mark', '-') .
					' ' . $html->span('old_line', $_) } @$del;
			push @lines, map { $html->span('add_mark', '+') .
					' ' . $html->span('new_line', $_) } @$add;
		}
	}
	return join("\n", @lines);
}

1;
