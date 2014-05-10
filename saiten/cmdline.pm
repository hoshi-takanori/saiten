package saiten::cmdline;

use strict;
use warnings;

use saiten::staff_db;

#
# コンストラクタ
#

# saiten::cmdline->new($dbname [, $dbuser [, $dbpass]])
# コンストラクタ。引数は DB 名など。
sub new {
	my $class = shift;
	my $cmd = bless {}, $class;
	$cmd->{db} = saiten::staff_db->new(sub { $cmd->error(@_) }, @_);
	return $cmd;
}

# $cmd->db : $db
# DB 接続を返す。
sub db {
	my $cmd = shift;
	return $cmd->{db};
}

# $cmd->error(@message)
# エラーメッセージを表示して、終了する。
sub error {
	my $cmd = shift;
	foreach my $msg (@_) {
		print $msg, "\n";
	}
	exit 1;
}

#
# コマンドライン版
#

# $cmd->list($exercise, $recursive)
# saiten list [all|exercise] を実行。
sub list {
	my ($cmd, $exercise, $recursive) = @_;
	if (defined $exercise && $exercise ne 'all') {
		my ($level) = $cmd->db->check_exercise($exercise);
		my @cnt = (0, 0, 0, 0, 0, 0);
		foreach my $row ($cmd->db->fresh_status(undef, $exercise)) {
			my ($fresh, $fresh_name, $serial, $status, $date, $staff) = @$row;
			if ($status) {
				print "$fresh ($serial)\n" if $status == 1;
				$cnt[$status]++;
				$cnt[5]++;
			} else {
				$cnt[0]++;
			}
		}
		if (! $recursive) {
			printf "採点待ち %d, 採点中 %d, NG %d, OK %d, total %d (rest %d)\n",
					$cnt[1], $cnt[2], $cnt[3], $cnt[4], $cnt[5], $cnt[0];
		}
	} else {
		my ($exercises, $levels, $count) = $cmd->db->exercises;
		my $cnt = 0;
		foreach my $id (@$exercises) {
			if ($count->{$id}) {
				print $levels->{$id} > 1 ? '(' . $id . ')' : $id,
						' ... ', $count->{$id}, "\n";
				if (defined $exercise) {
					$cmd->list($id, 1);
				}
				$cnt++;
			}
		}
		print "採点待ちの答案はありません。\n" if $cnt == 0;
	}
}

# $cmd->queue($date)
# saiten queue [date|today] を実行。
sub queue {
	my ($cmd, $date) = @_;
	if (defined $date) {
		my @time = localtime;
		my ($year, $month, $day) = ($time[5] + 1900, $time[4] + 1, $time[3]);
		if ($date =~ /^(\d+)[-\/](\d+)[-\/](\d+)$/) {
			($year, $month, $day) = ($1, $2, $3);
		} elsif ($date =~ /^(\d+)[-\/](\d+)$/) {
			($month, $day) = ($1, $2);
		} elsif ($date ne 'today') {
			$cmd->error('日付の形式が不適切です。');
		}
		$date = sprintf("%04d-%02d-%02d", $year, $month, $day);
	}
	my ($exercises, $levels) = $cmd->db->exercise_list;
	my %count = $cmd->db->queue_count($date);
	foreach my $id (@$exercises) {
		if ($count{$id}) {
			printf '%-16s', $levels->{$id} > 1 ? '(' . $id . ')' : $id;
			foreach my $status (1 .. 4) {
				my $cnt = $count{$id, $status};
				if ($cnt) {
					printf '%4d', $cnt;
				} else {
					print '   -';
				}
			}
			printf "%6d\n", $count{$id};
		}
	}
}

# $cmd->fresh($fresh)
# saiten fresh fresh_account を実行。
sub fresh {
	my ($cmd, $fresh) = @_;
	$cmd->db->check_fresh($fresh);

	my (%status_line, %final_status, %final_staff);
	my @status_str = ('未提出', '採点待ち', '採点中', 'NG', 'OK');
	foreach my $row ($cmd->db->status($fresh)) {
		my ($id, $status, $staff, $date) = @$row;
		$status_line{$id} =
				join ' ', $status_line{$id} || (), $status_str[$status];
		$final_status{$id} = $status;
		$final_staff{$id} = $staff;
	}

	my ($exercises, $levels) = $cmd->db->exercise_list;
	foreach my $id (@$exercises) {
		if (defined $status_line{$id}) {
			printf '%-16s', $levels->{$id} > 1 ? '(' . $id . ')' : $id;
			print $status_line{$id};
			print ' (', $final_staff{$id}, ')'
					if $final_status{$id} == 3 || $final_status{$id} == 4;
			print "\n";
		}
	}
}

# $cmd->status
# saiten status を実行。
sub status {
	my $cmd = shift;
	my @rows = $cmd->db->pendings($cmd->{user});
	if (! @rows) {
		print "採点中の答案はありません。\n";
	}
	foreach my $row (@rows) {
		my ($fresh, $exercise, $serial) = @$row;
		print "$exercise $fresh ($serial)\n";
	}
}

# $cmd->get($exercise, $fresh)
# saiten get [exercise [fresh]] を実行。
sub get {
	my ($cmd, $exercise, $fresh) = @_;
	my ($fresh_name, $status, $serial);
	if (defined $exercise) {
		$cmd->db->check_exercise($exercise);
	} else {
		my ($exercises, $levels, $count) =
				$cmd->db->exercises($cmd->{user}, $cmd->{user_class});
		foreach my $id (@$exercises) {
			if ($count->{$id}) {
				$exercise = $id;
				last;
			}
		}
		if (! defined $exercise) {
			$cmd->error('採点待ちの答案はありません。');
		}
	}
	if (defined $fresh) {
		($fresh_name) = $cmd->db->check_fresh($fresh);
		($status, $serial) = $cmd->db->answer_status($fresh, $exercise);
		if (! defined $status || $status != 1) {
			$cmd->error("新人 $fresh の $exercise の答案はありません。");
		}
		$cmd->db->reserve_answer($cmd->{user}, $fresh, $exercise, $serial);
	} else {
		($fresh, $fresh_name, $serial) = $cmd->db->get_answer(
				$cmd->{user}, $cmd->{user_class}, $exercise);
	}
	print "以下の答案を取り出しました。\n";
	print "新人: $fresh_name ($fresh), 問題: $exercise ($serial 回目)\n";
}

# $cmd->mark($status, $exercise, $fresh)
# saiten unget|ng|ok [exercise fresh] を実行。
sub mark {
	my ($cmd, $status, $exercise, $fresh) = @_;
	my ($serial);
	if (defined $exercise) {
		$cmd->db->check_exercise($exercise);
		$cmd->db->check_fresh($fresh);
	}
	my @rows = $cmd->db->pendings($cmd->{user});
	if (! @rows) {
		print "採点中の答案はありません。\n";
		return;
	}
	if (defined $exercise) {
		foreach my $row (@rows) {
			my ($f, $e, $s) = @$row;
			if ($f eq $fresh && $e eq $exercise) {
				$serial = $s;
				last;
			}
		}
		if (! defined $serial) {
			$cmd->error(
					"新人 $fresh の $exercise の答案は採点中ではありません。");
		}
	} elsif ($#rows == 0) {
		($fresh, $exercise, $serial) = @{$rows[0]};
	} else {
		print "採点中の答案は複数あります。\n";
		$cmd->status;
		return;
	}
	$cmd->db->update_answer(
			$cmd->{user}, $fresh, $exercise, $serial, 2, $status);
	if ($status == 1) {
		$cmd->db->insert_teisei(
				$cmd->{user}, $fresh, $exercise, $serial, 2, $status);
	}
	if ($status == 1) {
		print "新人 $fresh の $exercise の答案を採点待ちに戻しました。\n";
	} elsif ($status == 3) {
		print "新人 $fresh の $exercise の答案を NG にしました。\n";
	} elsif ($status == 4) {
		print "新人 $fresh の $exercise の答案を OK にしました。\n";
	} else {
		$cmd->error("不正な status ($status) です。");
	}
}

# $cmd->usage
# コマンドライン版の使用方法を表示して終了。
sub usage {
	print "usage: $0 list|queue|fresh|status|get|unget|ng|ok [args]\n";
	print "    list [all|exercise]    ... list answers in queue\n";
	print "    queue [date|today]     ... show exercise queue\n";
	print "    fresh fresh_account    ... show fresh's status\n";
	print "    status                 ... show answers you've got\n";
	print "    get [exercise [fresh]] ... get one answer\n";
	print "    unget [exercise fresh] ... unget the answer\n";
	print "    ng|ok [exercise fresh] ... mark the answer\n";
}

# $cmd->main(@ARGV)
# メインルーチン。
sub main {
	my $cmd = shift;
	if (defined $ENV{REQUEST_METHOD}) {
		print "Content-Type: text/plain\r\n\r\n";
		$cmd->usage
	}
	$cmd->{user} = $ENV{USER};
	my ($name, $class) = $cmd->db->check_staff($cmd->{user});
	$cmd->{user_class} = $class;
	my $op = shift;
	if (! defined $op) {
		$cmd->usage;
		exit 1;
	} elsif ($op eq 'list' || $op eq 'ls') {
		$cmd->list(@_);
	} elsif ($op eq 'queue') {
		$cmd->queue(@_);
	} elsif ($op eq 'fresh') {
		$cmd->fresh(@_);
	} elsif ($op eq 'status' || $op eq 'st') {
		$cmd->status(@_);
	} elsif ($op eq 'get') {
		$cmd->get(@_);
	} elsif ($op eq 'unget') {
		$cmd->mark(1, @_);
	} elsif ($op eq 'ng') {
		$cmd->mark(3, @_);
	} elsif ($op eq 'ok') {
		$cmd->mark(4, @_);
	} else {
		$cmd->usage;
		exit 1;
	}
}

1;
