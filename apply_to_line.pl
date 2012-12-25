#! /usr/bin/perl -w

# This script is useful for working on outputs that belong to several
# classes easily split-able by a regular expression. For example: An
# output where we have positive and negative numbers, we can call this
# script with: ./$0 "-" "1" "^[^-]+" "1".  1 corresponds to no action
# on the line. Otherwise, we can select the line with the first
# argument, and modify it with the second one.

use strict;

sub usage
{
  print "Invalid usage: $0 <match cmd>+\n";
  exit 1;
}

my @content;

{
  local $/ = undef;
  my $tmp = <STDIN>;
  @content = split /\n/, $tmp;
}

while (@ARGV)
{
  my $match = shift;
  my $cmd = shift;

  usage() if (not defined $match or not defined $cmd);


  my @res = map { eval $cmd && $_  } grep(/$match/, @content);

  print "$_\n" for @res;
}
