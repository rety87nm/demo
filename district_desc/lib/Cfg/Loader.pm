package Cfg::Loader;

use strict;
use utf8;
use vars qw(@ISA $VERSION);
use File::Find;
use Data::Dumper;

$VERSION = 0.1;

my %CFG = ();

sub readCfgFiles {
	my $p = shift || './';
	return find(\&parseCfg,$p);	
}

sub parseCfg {
	my $n = $File::Find::name;
	return 1 unless $n =~ /^.*\/conf(.*)\/(\w+)\.cfg$/;
	my @keys = split (/\//,$1);
	my $t = \%CFG;
	for (@keys){
		$t->{$_} = {} unless exists $t->{$_};
		$t = $t->{$_};
	}
	$t->{$2}=do($n);
}

sub load {
	my $p = shift;
	readCfgFiles($p);
	return \%CFG;
}

1;
