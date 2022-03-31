#!/usr/bin/perl -w
use warnings; use strict;
use IO::Handle;
use File::Temp "tempfile";

open (MDFH, "<", 'SPG_min_2019_min.csv') or die "Can't open data file:$!";

=cm
set xdata time
set timefmt "%Y-%m-%dT%H:%M:%S"
set format x "%Y-%m-%dT%H:%M:%S" 
set xtics rotate
set yrange [14460.0:14510.0] 
set multiplot 
plot "08-13.cvs" using 1:2 with lines,
set yrange [2660.00:2740.00]
plot "08-13.cvs" using 1:3 with lines,
set yrange [50380.0:50410.0]
plot "08-13.cvs" using 1:4 with lines
=cut


print $X;
exit;

my @date_str = qw(
29/04/2010-00.00 29/04/2010-00.30 29/04/2010-01.00
29/04/2010-01.30 29/04/2010-02.00 29/04/2010-02.30
29/04/2010-03.00 29/04/2010-03.30 29/04/2010-04.00
29/04/2010-04.30 29/04/2010-05.00 29/04/2010-05.30
29/04/2010-06.00 29/04/2010-06.30 29/04/2010-07.00
29/04/2010-07.30 29/04/2010-08.00 29/04/2010-08.30
29/04/2010-09.00 29/04/2010-09.30 29/04/2010-10.00
29/04/2010-10.30 29/04/2010-11.00 29/04/2010-11.30
29/04/2010-12.00 29/04/2010-12.30 29/04/2010-13.00
29/04/2010-13.30 29/04/2010-14.00 29/04/2010-14.30
29/04/2010-15.00 29/04/2010-15.30 29/04/2010-16.00
29/04/2010-16.30 29/04/2010-17.00 29/04/2010-17.30
29/04/2010-18.00 29/04/2010-18.30 29/04/2010-19.00
29/04/2010-19.30 29/04/2010-20.00 29/04/2010-20.30
29/04/2010-21.00 29/04/2010-21.30 29/04/2010-22.00
29/04/2010-22.30 29/04/2010-23.00 29/04/2010-23.30
);

my @value = qw(
2 3 1 1 2 2 1 2 2 3 2 1 1 1 1 4 3 3 2 1 2 3 1 1 2 2 
1 2 2 3 2 1 1 1 1 4 3 3 2 1 2 3 1 1 2 2 1 2
);

my($T,$N) = tempfile("plot-XXXXXXXX", "UNLINK", 1);

for my $k (0 .. @value - 1) {
	say $T $date_str[$k], " ", $value[$k];
}

close $T;
open my $P, "|-", "gnuplot" or die;
printflush $P qq[
unset key
set title "Video Server Play Daily Hourly Report"
set xdata time
set timefmt "%d/%m/%Y-%H.%M"
set format x "%d/%m-%H.%M"
set xtics rotate
set yrange [0:] noreverse
set terminal png giant size 1000,500 
set output "plot.png"
plot "$N" using 1:2 with filledcurves y1=0
];
close $P;
__END__

