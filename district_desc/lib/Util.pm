package Util;
use Exporter;
@ISA = qw/Exporter/;
@EXPORT = qw/randstr date/;

=nd
rand(10,[a-z]); -> собрать пароль длиной 10 символов, состоящий только из символов ряда a..z
=cut

sub randstr {
	my ($size,$chrs) = ((shift || 10),(shift || ['A'..'Z','a'..'z',0..9]));
	my $r = '';
	$r .= $chrs->[int(rand($#$chrs+1))] for (1..$size);
	return $r;
}

# возвращает текущую дату в хеше: {d=>,m=>,y=>,mm,ss}
sub date {
	my @d = localtime(time); 
	my $h = {}; 
	$h = {
		ss=>(($d[0] < 10) ? '0'.$d[0] : $d[0]), 
		mm=>(($d[1] < 10) ? '0'.$d[1] : $d[1]), 
		h=>(($d[2] < 10) ? '0'.$d[2] : $d[2] ), 
		d=>(($d[3] < 10) ? "0".$d[3] : $d[3]),
		m=>((++$d[4] < 10) ? "0".$d[4] : $d[4]),
		y=>(1900+$d[5])
	};
	return $h;
}


1;
