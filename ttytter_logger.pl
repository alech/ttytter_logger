use Date::Parse;
use JSON;
use Data::Dumper;
use File::Copy qw(move copy);

#use strict;
#use warnings;

sub create_empty_tweet_file {
	my $year = shift;
	my $month = shift;
	open(my $fh, '>', tweet_file($year, $month));
	print $fh "";
	close($fh);
	return 1;
}

sub create_empty_tweet_index_file {
	open(my $fh, '>', $extpref_logger_dest . "/data/js/tweet_index.js");
	print $fh "var tweet_index = []";
}

sub tweet_file {
	my $year = shift;
	my $month = shift;
	return $extpref_logger_dest . "/data/js/tweets/". $year . "_" . $month . ".js";
}

sub add_tweet_to_tweet_file {
	my $year = shift;
	my $month = shift;
	my $ref = shift;

	#print Dumper($ref);

	my $infilename = tweet_file($year, $month);
	my $outfilename   = tweet_file($year, $month) . '.tmp';
	open(my $in, '<', $infilename);
	open(my $out, '>', $outfilename);
	print $out "Grailbird.data.tweets_" . $year . "_" . $month . "= [\n";
	my $json = JSON->new();
	$json->utf8();
	print $out $json->encode($ref->{'__json_decoded'}) . "\n"; # new tweet at beginning

	<$in>; # skip first line
	LINES:
	while (my $line = <$in>) {
		last LINES if ($line eq "]"); # skip last closing array
		if ($line =~ /^,/) {
			print $out $line; # line already starts with ,
		}
		else {
			print $out ',' . $line # add , to beginning of ex-first line, now second line
		}
        }	
	close($in);
	print $out "]";
	close($out);

	move($outfilename, $infilename) or die "move failed: $!";
}

sub update_tweet_index {
	my $year = shift;
	my $month = shift;
	
	my $json = JSON->new();
	$json->utf8();

	if (! -e $extpref_logger_dest . "/data/js/tweet_index.js") {
		create_empty_tweet_index_file();
	}
	open(my $in, '<', $extpref_logger_dest . "/data/js/tweet_index.js");
	local $/ = undef;
	my $data = <$in>;
	close($in);
	$data =~ s/var tweet_index =//m; # remove var definition
	my @index = @{ $json->decode($data) };
	$curr_index = -1;
	for (my $i = 0; $i < scalar(@index); $i += 1) {
		if ($index[$i]->{'year'} == $year && $index[$i]->{'month'} == int($month)) {
			$curr_index = $i;
			$index[$i]->{'tweet_count'} += 1;
		}
	}
	if ($curr_index == -1) { # not found, new month
		push @index, {
			'file_name' => "data/js/tweets/" . $year . "_" . $month . ".js",
			'year' => $year,
			'month' => int($month),
			'var_name' => "tweets_" . $year . "_" . $month,
			'tweet_count' => 1,
		}
	}
	open(my $out, '>', $extpref_logger_dest . "/data/js/tweet_index.js");
	print $out "var tweet_index = " . $json->encode(\@index);
	close($out);
}

$handle = sub {
	my $ref = shift;
	($ss,$mm,$hh,$day,$month,$year,$zone) = strptime($ref->{'created_at'});
	$month += 1;
	$month = sprintf("%02d", $month);
	$year += 1900;
	#print ($month  . "\n");
	#print ($year  . "\n");
	if (! -e tweet_file($year, $month)) {
		create_empty_tweet_file($year, $month);
	}
	add_tweet_to_tweet_file($year, $month, $ref);
	update_tweet_index($year, $month);
	
	&defaulthandle($ref);
	return 1;
}
