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

# $diff->set(%params)
# $diff のパラメータを設定する。
sub set {
	my ($diff, %params) = @_;
	foreach my $key (keys %params) {
		$diff->{$key} = $params{$key} if defined $params{$key};
	}
}

#
# diff ルーチン
#

# $diff->diff_chunks($old, $new, $put_chunk)
# diff を生成する。
sub diff_chunks {
	my ($diff, $old, $new, $put_chunk) = @_;
	my ($eq, $del, $add) = ([], [], []);
	my $flush_eq = sub {
		if (@$eq) {
			$put_chunk->('=', $eq);
			$eq = [];
		}
	};
	my $flush_ch = sub {
		if (@$del || @$add) {
			$put_chunk->('!', $del, $add);
			$del = [];
			$add = [];
		}
	};
	my @diffs = Algorithm::Diff::traverse_sequences($old, $new, {
		MATCH     => sub { $flush_ch->(); push @$eq,  $new->[$_[1]]; },
		DISCARD_A => sub { $flush_eq->(); push @$del, $old->[$_[0]]; },
		DISCARD_B => sub { $flush_eq->(); push @$add, $new->[$_[1]]; }
	});
	$flush_eq->();
	$flush_ch->();
}

# $diff->diff_chars($del, $add) : \@del, \@add
# 文字単位の diff を生成する。
sub diff_chars {
	my ($diff, $del, $add) = @_;
	my @old = split //, decode('UTF-8', join("\n", @$del));
	my @new = split //, decode('UTF-8', join("\n", @$add));
	my @chunks;
	$diff->diff_chunks(\@old, \@new, sub { push @chunks, [@_]; });
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
	if (! @chars && $diff->{show_spaces}) {
		$add_char->(1, '(空行)', 0);
	}
	foreach my $c (@chars) {
		$c = encode('UTF-8', $c);
		if ($c eq "\t") {
			if ($diff->{show_spaces}) {
				$add_char->(1, substr('--->', $pos % 4 - 4));
			} else {
				$add_char->(0, substr('    ', $pos % 4 - 4));
			}
		} elsif ($c eq '　' && $diff->{show_spaces}) {
			$add_char->(1, '全', 2);
		} elsif ($c eq ' ' && $diff->{show_spaces}) {
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

# $diff->print_chunk($ch, $del, $add)
# chunk を $html->println で表示する。
sub print_chunk {
	my ($diff, $ch, $del, $add) = @_;
	my $html = $diff->{html};
	my $conv_line = sub {
		return $diff->conv_line(split(//, decode('UTF-8', $_[0])));
	};
	if ($ch eq '=') {
		if (! $diff->{add_only} && ! $diff->{diff_only}) {
			$html->println(map { '  ' . $conv_line->($_) } @$del);
		}
	} else {
		if ($diff->{add_only} ? @$add : $diff->{diff_only}) {
			$html->println('') if defined $diff->{need_separator};
			$diff->{need_separator} = 1;
		}
		if (@$del && @$add && ! $diff->{add_only} && $diff->{diff_chars}) {
			($del, $add) = $diff->diff_chars($del, $add);
		} else {
			@$del = map { $html->span('old_char', $conv_line->($_)) } @$del;
			@$add = map { $html->span('new_char', $conv_line->($_)) } @$add;
		}
		if (! $diff->{add_only}) {
			$html->println(map { $html->span('del_mark', '-') .
					' ' . $html->span('old_line', $_) } @$del);
		}
		$html->println(map { $html->span('add_mark', '+') .
				' ' . $html->span('new_line', $_) } @$add);
	}
}

# $diff->print_diff($old, $new)
# diff を $html->println で表示する。
sub print_diff {
	my ($diff, $old, $new) = @_;
	$diff->diff_chunks($old, $new, sub { $diff->print_chunk(@_); });
}

1;
