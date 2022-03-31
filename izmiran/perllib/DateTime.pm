package DateTime;

=nd
Class: DateTime

Различные утилиты для работы со временем.

Это не класс, просто набор функций
=cut

use strict;
use Exporter;
use vars qw/@ISA @EXPORT $VERSION/;
use Time::Local;
use Date::Calc qw/ Gmtime Day_of_Week_to_Text Month_to_Text Localtime Mktime Date_to_Time Day_of_Week Timezone /;
use HTTP::Date qw/ time2str str2time/;
use POSIX;
use locale;
use Error;

@ISA = qw/Exporter/;
@EXPORT = qw/CURRENT_EPOCH decodeDate encodeDate leapYear daysInMonth CURRENT_DATE
			encodeFormDate decodeFormDate NOW extractFromEpoch humanDate Pg_to_MSD nowMSD iso8601ToHttp/;
$VERSION = 1.0;

=nd
Func: CURRENT_EPOCH
Текущая дата (epoch)
=cut
sub CURRENT_EPOCH(){
	return timelocal(0,0,0,((localtime)[3..5]));
}

=nd
Func: CURRENT_DATE
Текущая дата (yyyy-mm-dd)
=cut
sub CURRENT_DATE {
	my $d = (shift || 0);
	my @d = (localtime(time + $d*86400))[3..5];
	$d[2]+=1900;$d[1]++;
	$d[1] = '0'.$d[1] if length $d[1] == 1;
	$d[0] = '0'.$d[0] if length $d[0] == 1;
	return "$d[2]-$d[1]-$d[0]";
}

=nd
Func: NOW
Текущая дата и время в формате yyyy-mm-dd hh:mm:ss
=cut
sub NOW(){
	my @d = (localtime)[0..5];
	$d[5]+=1900;$d[4]++;
	map {$_ = '0'.$_ if length $_ < 2 } @d;
	return "$d[5]-$d[4]-$d[3] $d[2]:$d[1]:$d[0]";
}

=nd
Func: decodeDate
Раборать дату на день,месяц и год.

Считается, что дата имеет вид yyyy-mm-dd (постгрес по умолчанию).
NB: работает только для годов из 4 цифр
Parameters:
	$date - Дата
Returns:
	Массив с данными
=cut
sub decodeDate {
	my $date = shift;
	if ($date=~/^(\d\d\d\d)-(\d+)-(\d+).*$/){
		$date = "$1-$2-$3";
		return map {int} reverse split /-/ , $date;
	}
	return ('','','');
}

=nd
Func: leapYear
Parameters:
	$year - год (по умолчанию текущий)
Returns:
	1 если год високосный, 0 иначе.
=cut
sub leapYear {
	my $year = shift;
	$year = ((localtime)[5]) + 1900 unless $year;
	return 0 if $year % 4;
    return 1 if $year % 100;
	return 0 if $year % 400;
	return 1;
}

=nd
Func: daysInMonth
Количество дней в месеце.

Parameters:
	$month - месяц, по умолчанию текущий
	$year - год (по умолчанию текущий)
=cut
sub daysInMonth {
	my ($month,$year) = @_;
	$year = ((localtime)[5]) + 1900 unless $year;
	$month = ((localtime)[4]) + 1 unless $month;
	my @days = (31,28,31,30,31,30,31,31,30,31,30,31);
	return 0 unless ($month > 0 && $month < 13);
	my $d = $days[$month-1];
	$d+=1 if leapYear($year) && $month == 2;
	return $d;
}

=nd
Func: encodeDate
Собрать дату из месяца, года и дня

Parameters:
	$day - день
	$month - месяц
	$year - год

Returns:

	дату в формате yyyy-mm-dd или undef.
=cut

sub encodeDate {
	my ($d,$m,$y) = map {int} @_;
	return undef if $y < 1;
	return undef unless ($m > 0 && $m < 13);
	return undef unless $d > 0 && $d <= daysInMonth($m,$y);
	$m = '0'.$m if length $m == 1;
	$d = '0'.$d if length $d == 1;
	return "$y-$m-$d";
}

=nd
Func: encodeFormDate
Собрать дату из месяца, года и дня для данных формы.

Собирает дату из данных потока и удаляет (если надо) ненужные куски.
Parameters:
	$F - поток данных
	$name - имя (должны быть указаны данные $name.'_day',$name.'_month',$name.'_year')
	savedecoded - Оставить декодированные данные в потоке. По умолчанию 0.
Returns:
	Полученную дату или undef.
=cut
sub encodeFormDate {
	my ($H,$p) = (shift,shift);
	my %I = (savedecoded=>0,@_);
	$H->{$p} = encodeDate($H->{$p.'_day'},$H->{$p.'_month'},$H->{$p.'_year'});
	if ($H->{$p} && $I{savedecoded} == 0){
		delete $H->{$p.'_day'};
		delete $H->{$p.'_month'};
		delete $H->{$p.'_year'};
	}
	return $H->{$p};
}

=nd
Func: decodeFormDate
Обратная функция к <encodeFormData>

Parameters:
	$F - поток данных
	$name - имя. В $F окажутся параметры $name.'_day',$name.'_month',$name.'_year'
	$date
=cut
sub decodeFormDate {
	my ($H,$p,$d) = @_;
	($H->{$p.'_day'},$H->{$p.'_month'},$H->{$p.'_year'}) = decodeDate($d);
}

=nd
Method: extractFromEpoch
Достать нужные влеичины из timestamp.

Parameters:
	$time - Время
		Далее список полей, которые надо доставать: 'day','month','year','minute' ,'second','hour';

=cut
sub extractFromEpoch {
	my $time = shift;
	my @what = @_;
	my @res = ();
	my @tm = localtime($time);
	foreach my $i (@what){
		push @res , $tm[0] if $i eq 'second'; 
		push @res , $tm[1] if $i eq 'minute'; 
		push @res , $tm[2] if $i eq 'hour'; 
		push @res , $tm[3] if $i eq 'day'; 
		push @res , $tm[4]+1 if $i eq 'month'; 
		push @res , $tm[5]+1900 if $i eq 'year'; 
	}
	return @res;
}

=nd
Method: humanDate
возвраящет дату в нормальном человеческом формате.

Parameters:
	date  - Дата в формате PG
	what - что возвращать ('date','datetime','time','monthyear'),
	case - Падеж (gen,nom,prep)
	elegant - Использовать элегантый вывоз (сегодня, вчера, завтра и т.д)
	form - формат даты ('full' полное с месяцами прописью, 'short' с месяцами цифрмами)
	tz - timezone в секундах
=cut
sub humanDate {
	my %I = (date=>'2000-01-01',what=>'date',case=>'gen',elegant=>1,tz=>0,form=>'full',@_);
	# так, теперь нам надо прибавить к дате смещение
	my $val = substr($I{date},0,16);
	my ($date,$time) = split / / , $val;
	$time='00:00' unless $time;
	my @dater = reverse split /-/ , $date;
	$dater[1]-=1;
	$dater[2]= ($dater[2] < 1900 || $dater[2] > 2036 ? 2008 : $dater[2]);
	$dater[2]= 2008 if $dater[2] < 0;
	my @timer = split /:/ , $time;
	my @realdate = gmtime(timegm(0,(reverse @timer),@dater) + $I{tz});
	$realdate[5]+=1900;$realdate[4]+=1;
	$realdate[1] = '0'.$realdate[1] if $realdate[1] < 10;
	my $ds = join '.' , map {int} reverse @realdate[3..5];
	my $res = '';
	my %times = ('-2'=>'позавчера','-1'=>'вчера','0'=>'сегодня','1'=>'завтра',
		 		  2=>'послезавтра');
	my %month=();
	%month = (
		gen=>{
			1=>'января',2=>'февраля',3=>'марта',4=>'апреля',5=>'мая',6=>'июня',
			7=>'июля',8=>'августа',9=>'сентября',10=>'октября',11=>'ноября',12=>'декабря'},
		nom=>{1=>'январь',2=>'февраль',3=>'март',4=>'апрель',5=>'май',6=>'июнь',
			7=>'июль',8=>'август',9=>'сентябрь',10=>'октябрь',11=>'ноябрь',12=>'декабрь'},
		prep=>{1=>'январе',2=>'феврале',3=>'марте',4=>'апреле',5=>'мае',6=>'июне',
			7=>'июле',8=>'августе',9=>'сентябре',10=>'октябре',11=>'ноябре',12=>'декабре'}
	);	
	if ($I{what} eq 'datetime' || $I{what} eq 'date'){
		if ($I{elegant}){
			foreach my $i (-2..2){
				my @t = localtime(time+$I{tz}+($i)*86400);
				$t[5]+=1900;$t[4]+=1;
				if ($t[3] == $realdate[3] && $t[4] == $realdate[4] && $t[5] == $realdate[5]){
					$res = $times{$i};
					last;
				}
			}
		} 
		unless ($res){
			if ($I{form} eq 'full'){
				$res = $realdate[3].' '.$month{$I{case}}->{$realdate[4]}.' '.$realdate[5];
			}else{
				$res = $realdate[3].'.'.(length $realdate[4] < 2 ? '0' : '').$realdate[4].'.'.$realdate[5];
			}
		}
	}
	if (length $val > 10){
		if ($I{what} eq 'datetime'){
			$res .=' в '.join ':' , reverse @realdate[1..2];
		}elsif($I{what} eq 'time'){
			$res .=join ':' , reverse @realdate[1..2];
		}
	}
	if ($I{what} eq 'monthyear'){
		if ($I{form} eq 'full'){
			$res = $month{$I{case}}->{$realdate[4]}.' '.$realdate[5];
		}else{
			$res = (length $realdate[4] < 2 ? '0' : '').$realdate[4].'.'.$realdate[5];
		}
	}	
	if ($I{what} eq 'daymonth'){
		if ($I{form} eq 'full'){
			$res = $realdate[3].' '.$month{$I{case}}->{$realdate[4]};
		}else{
			$res = $realdate[3].'.'.(length $realdate[4] < 2 ? '0' : '').$realdate[4];
		}
	}
	return $res;
}

=nd
Method: nowMSD
    current date in RFC822 format
=cut

sub nowMSD {
	(undef, undef, undef, my $deltaHour, undef, undef, undef) = Timezone;
	my ($year, $month, $day, $hour, $min, $sec, $doy, $dow, $dst) = Localtime();

	my $date = sprintf("%.3s, %02d %.3s %4d %02d:%02d:%02d +0${deltaHour}00",
		Day_of_Week_to_Text($dow), $day, Month_to_Text($month), $year, $hour, $min, $sec, $dst);
}

=nd
Method: Pg_to_MSD
    convert date from Postgres to RFC822 format
=cut

sub Pg_to_MSD {
	my $pg = shift;

	(undef, undef, undef, my $deltaHour, undef, undef, undef) = Timezone;

 	my ($year, $month, $day, $hour, $min, $sec) = $pg =~ /^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})\.?\d*$/;
	my $dow = Day_of_Week($year, $month, $day);
	$dow = 0 if $dow == 7;

 	my $time = asctime($sec, $min, $hour, $day, $month-1, $year-1900, $dow, 0, -1);
	chomp($time);
 	$time =~ s/^(\w{3}) (\w{3}) (\d{2}) (\d\d:\d\d:\d\d) (\d{4})$/$1, $3 $2 $5 $4 +0${deltaHour}00/;
	$time;
}

=nd
Method: iso8601ToHttp
	Перекодирует дату из формата iso8601 to HTTP format date
Parameters: 
	$date - дата в формате Postgres (iso8601);
Retruns:
	строку в формате HTTP
=cut

sub iso8601ToHttp {
	my $date = shift;
	return time2str(str2time($date));
}

1;
