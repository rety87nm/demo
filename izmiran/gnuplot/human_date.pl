#!/usr/bin/perl -w
use lib qw(../perllib/);
use DateTime qw(humanDate);
print humanDate(date=>$ARGV[0],what=>'date',case=>'gen',elegant=>0,tz=>0,form=>'full');

