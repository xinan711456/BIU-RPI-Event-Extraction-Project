#! /usr/bin/perl -w

# pairs.t version 2.05
# ($Id: pairs.t,v 1.12 2008/05/30 23:12:40 sidz1979 Exp $)

# Copyright (C) 2004

# Jason Michelizzi, University of Minnesota Duluth
# mich0212 at d.umn.edu

# Ted Pedersen, University of Minnesota Duluth
# tpederse at d.umn.edu

# Before 'make install' is performed this script should be runnable with
# 'make test'.  After 'make install' it should work as 'perl t/pairs.t'

# A script to run queries on a large file of words and compare the results
# with a set of relatedness values stored in "keys."  The list of pairs
# of words was generated by the randomPairs.pl program that can be obtained
# from http://www.d.umn.edu/~tpederse/wordnet.html

# This script supports two options:
# 1) the --key option can be used to generate a key, in which case no actual
#    tests are run.
# 2) the --keydir option can be used to specify where the key is or should be
#    stored.  The default value is t/keys.

use strict;
use warnings;

use Getopt::Long;

our ($opt_key, $opt_keydir);

GetOptions ("key", "keydir=s");

my @measures;
my $num_tests;

BEGIN {
  @measures = qw/hso jcn lch lesk lin path res wup/;
  $num_tests = 21 + (5 + 109) * scalar @measures;
}

use Test::More tests => $num_tests;

BEGIN {use_ok 'WordNet::QueryData'}
BEGIN {use_ok 'WordNet::Tools'}
BEGIN {use_ok 'WordNet::Similarity::hso'}
BEGIN {use_ok 'WordNet::Similarity::jcn'}
BEGIN {use_ok 'WordNet::Similarity::lch'}
BEGIN {use_ok 'WordNet::Similarity::lesk'}
BEGIN {use_ok 'WordNet::Similarity::lin'}
BEGIN {use_ok 'WordNet::Similarity::path'}
# There's really no point in testing random like this
#BEGIN {use_ok 'WordNet::Similarity::random'}
BEGIN {use_ok 'WordNet::Similarity::res'}
#BEGIN {use_ok 'WordNet::Similarity::vector'}
BEGIN {use_ok 'WordNet::Similarity::wup'}
BEGIN {use_ok 'File::Spec'}

# number of decimal places;
my $precision = 4;

my $wn = WordNet::QueryData->new;
ok ($wn);

my $wntools = WordNet::Tools->new($wn);
ok ($wntools);
my $wnHash = $wntools->hashCode();
ok ($wnHash);

my $infile = File::Spec->catfile ('t', 'pairs.txt');

ok (-e $infile);
ok (-r $infile);

ok (open FH, $infile) or diag "Could not open $infile: $!";
my @lines = <FH>;

ok (close FH);

my @pairs = map {my ($w1, $w2) = split; [$w1, $w2]} @lines;

my $wnverfile;
if ($opt_keydir) {
  $wnverfile = File::Spec->catfile ($opt_keydir, "wnver.key");
}
else {
  $wnverfile = File::Spec->catfile ('t', 'keys', "wnver.key");
}

ok (open KEY, $wnverfile) or diag "Could not open $wnverfile: $!";
my $wnver = <KEY>;
ok (defined $wnver);
$wnver = "" if(!defined($wnver));
$wnver =~ s/[\r\f\n]+//g;
$wnver =~ s/^\s+//;
$wnver =~ s/\s+$//;
ok (close KEY);

# if the key option is given, we want to generate a "key" for the tests.
# A key is essentially just a list of relatedness values.  If the key
# option is not given, then we use the key to test if the relatedness
# values we are generating correspond to the key's values.
unless ($opt_key) {
  # not generating a key--actually running tests

  foreach my $measure (@measures) {
    SKIP: {
      skip "Hash-code of key file(s) does not match installed WordNet", 114 if($wnver ne $wnHash);

      my $keyfile;
      if ($opt_keydir) {
        $keyfile = File::Spec->catfile ($opt_keydir, "${measure}pairs.key");
      }
      else {
        $keyfile = File::Spec->catfile ('t', 'keys', "${measure}pairs.key");
      }

      ok (open KEY, $keyfile) or diag "Could not open $keyfile: $!";

      my @keys = map {chomp; $_} <KEY>;

      is (scalar @keys, scalar @pairs);

      ok (close KEY);

      my $module = "WordNet::Similarity::$measure"->new ($wn);
      ok ($module);
      $module->{trace} = 1;
      my ($err, $errstr) = $module->getError ();
      is ($err, 0) or diag $errstr;

      for (0..$#pairs) {
        my ($word1, $word2) = ($pairs[$_]->[0], $pairs[$_]->[1]);
        my $score = $module->getRelatedness ($word1, $word2);

        my ($err, $estr) = $module->getError ();

        # format $score so that we can compare it to value from file
        $score = defined $score ? sprintf ("%.*f", $precision, $score) : 'undef';

        is ($score, $keys[$_])
	  or diag "Wrong relatedness using $measure for $word1 $word2";
      }
    }
  }
}
else {
  # generating keys
  my $wfile;
  if($opt_keydir) {
    $wfile = File::Spec->catfile($opt_keydir, "wnver.key");
  }
  else {
    $wfile = File::Spec->catfile('t', 'keys', "wnver.key");
  }

  ok (open KEY, ">$wfile") or diag "Could not open $wfile: $!";
  print KEY "$wnHash\n";
  ok (close KEY);

  foreach my $measure (@measures) {
    my $keyfile;
    if ($opt_keydir) {
      $keyfile = File::Spec->catfile ($opt_keydir, "${measure}pairs.key");
    }
    else {
      $keyfile = File::Spec->catfile ('t', 'keys', "${measure}pairs.key");
    }

    ok (open KEY, ">$keyfile") or diag "Could not open $keyfile: $!";

    my $module = "WordNet::Similarity::$measure"->new ($wn);
    ok ($module);
    my ($err, $errstr) = $module->getError ();
    is ($err, 0) or diag "$errstr\n";

    for (0..$#pairs) {
      my $score = $module->getRelatedness ($pairs[$_]->[0], $pairs[$_]->[1]);
      if (defined $score) {
	printf KEY "%.*f\n", $precision, $score;
      }
      else {
	print KEY "undef\n";
      }
      $module->getError();
    }
    ok (close KEY);
  }

  # hack to prevent annoying warning: when we generate keys, we skip a lot
  # of tests.  This magic avoids an irritating warning that says something
  # to the effect of "looks like you planned X tests but only ran Y."
 SKIP: {
    my $num_skipped = $num_tests - 23 - 4 * scalar (@measures);
    skip ("Generating key, no need to run test", $num_skipped);
  }
}

__END__