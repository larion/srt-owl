#! /usr/bin/env perl

# Build the database for srt-owl
#
# Author: Larion Garaczi
# Date: 2014

use 5.018;
use warnings;
use DBI;

use constant F_NAME  => "freqlists/nl.txt";
use constant DB_NAME => "srt-owl.db";

#my $freqlist_fname = "freqlists/$options{'lang'}.txt";
open my $freq_list_fh, '<', F_NAME or
  die "Can't open language file: $!";

##### process freq_list #####
# TODO more extensive word properties!!

say "Building Frequency list";

my $freqlist = {};
build_freqlist($freqlist, $freq_list_fh);

##### connect to the database #####

say "Connecting to Database";

my $dbh = DBI->connect(
	sprintf("dbi:SQLite:%s", DB_NAME),
	"", # no username
	"", # no password
	{PrintError => 0, RaiseError => 1, AutoCommit => 0}
) or die "Can't connect to database: $DBI::errstr\n";
$dbh->do("PRAGMA synchronous = OFF; PRAGMA journal_mode = WAL;"); # speed-up!

##### create the words table #####

say "Creating tables";
create_words_table($dbh, "nl"); # TODO

##### populate the words table #####

say "Populating words table with the frequency list";
freqlist2db($dbh, $freqlist);

##### create the index #####

say "Creating index";

my $sql_select = "CREATE UNIQUE INDEX word_ind ON words (word)";
$dbh->do($sql_select);
$dbh->commit;

##### disconnect from DB #####

$dbh->disconnect;

##############################

sub build_freqlist { # map words to their place in the frequency lists
	my($freqlist, $freqlist_fh) = @_;
	my($i, $total_occurences);
	for(<$freqlist_fh>){
		chomp;
		$i++; # position in frequency list
		my($word, $occurences) = split;
		my $total_occurences+=$occurences;
		$freqlist->{$word} = $i;
	}
}

sub create_words_table { #TODO
	my($dbh, $lang) = @_;
	my $sql_create_table =<<"SQL";
CREATE TABLE IF NOT EXISTS words (
	id  INTEGER PRIMARY KEY,
	word  VARCHAR(255) NOT NULL);
SQL
	$dbh->do($sql_create_table);
}

sub freqlist2db {
	my($dbh, $freqlist) = @_;
	my $sql_insert = "INSERT INTO words (id, word) VALUES (?, ?);";
	my $sth = $dbh->prepare($sql_insert);
	my($id, $word);
	$sth -> execute($id, $word) while( ($word,$id) = each(%$freqlist) );
	$dbh->commit;
}
