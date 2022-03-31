package Error;

=nd
Package: Error
Базовые функции для работы с ошибками и дебага.


Все ошибки складываются в хэш, в котором можно проверить их наличие. 
Есть возможность забиндить их в шаблом в ветку ERROR.

Дополнительно есть функция debug. Значение ключа debug берется из конфига 'server/debug'.
Однако вы можете явно переопределить это поведение, установив переменную $Error::DEBUG.

Используемый конфиг: server.cfg
=cut

use strict;
use vars qw(@ISA @EXPORT $VERSION $DEBUG);
use Exporter;
use Cfg;
use Time::HiRes qw/time/;
use utf8;
use open qw/:utf8 :std/;
use Data::Dumper;


$VERSION = 1.0;
@ISA = qw(Exporter);

@EXPORT = qw/warn debug isErr die tic toc tictoc/;


my %_ERR = ();
my %_TICTOC = ();
$DEBUG = 0;


=nd
Function: init 
Не экспортируемая функция. Очищает статическую переменную, в которой хранится 
информация об ошибках.

При правильном подходе нет нужды использовать ее явно, она будет вызвана при
инициализации модуля окружения 

=cut
sub init {
	%_ERR = (STACK=>{},debug=>cfg('server.debug',0));
	my %O = (logfile=>undef,@_);
	%_TICTOC = ();
	if (defined $O{logfile}){
		open (STDERR,'>>',$O{logfile}) or die "Can't open log file:", $O{logfile};
	}
	return 1;
}

sub __parceMsg($){
	my $msg = shift;
	my @arr = split /\|/ , $msg;
	my $code = (shift(@arr)|| 'UNKNOWN_ERROR');
	my $text = ((join '|', @arr) || 'NO MESSAGE');
	my $level = 0;
	my ($package,$file,$line) = caller($level);
	my @stack  = (); 
	while ($package){
		push @stack , " $package:$line ";
		$level++;
		($package,$file,$line) = caller($level);
	}
	$text.=" at ".(join " ==>\n " , reverse @stack)."\n";
	return ($code,$text);
}

=nd
Function: warn
Печатает и запоминает ошибку для последующей передачи в шаблон.

Parameters:
	$msg  - Строка с ошибкой

Returns:
	код последней ошибки в списке
=cut
sub warn {
	my $ret = undef;
	while (my $msg = shift){
		my ($c,$t) = __parceMsg($msg);
		$_ERR{STACK}->{$c} = $t;
		print STDERR $c.' | '.$t."\n";
		$ret = $c;
	}
	return $ret;
}

=nd
Function: bindErrors

Не импортируется. Формирует хэш ошибок.

Parameters:
	$hash - Ссылка на хэш, куда надо сложить параметры. В значение ERROR 
	будет положен хэш с ошибами.

Returns:
	1
=cut
sub bindErrors($){
	my $hash  = shift;
	$hash->{ERROR} = {};
	foreach my $i (keys %{$_ERR{STACK}}){
		$hash->{ERROR}{$i} = 1;
		$hash->{ERROR}{$i.'_msg'} = $_ERR{STACK}->{$i};
	}
	return 1;
}

=nd
Function: debug
Просто печатаем сообщение в лог, если определен дебаг.
=cut
sub debug {
	return unless $_ERR{debug} || $DEBUG; 
	my ($package,$file,$line) = caller(0);
	foreach my $i (@_){
		print STDERR "$package:$line:DBG: ",(ref $i ? Dumper $i : $i) , "\n";
	}
}

sub debug_db {
	return unless $_ERR{debug} || $DEBUG; 
	my ($package,$file,$line) = caller(0);
	foreach my $i (@_){
		print STDERR "$package:$line:DB: ",(ref $i ? Dumper $i : $i) , "\n";
	}
}

=nd
Function: isErr
Проверяет, случилась ли ошибка.

Parameters:
	$code - Код ошибки 

Returns:
	true/false
=cut
sub isErr($){
	my $code = shift;
	return 1 if exists $_ERR{STACK}->{$code};
	return 0;
}

=nd
Function: die
Печатаем сообщение и умираем. NB: будте осторожны, умрет сервер целиком
=cut
sub die {
	while (my $msg = shift){
		my ($c,$t) = __parceMsg($msg);
		print STDERR $c.' | '.$t;
	}
	exit;
}

=nd
Function: tic

Начать замер времени.

Parameters:
	$key - Ключ, с которым будет ассоциироваться замер
=cut
sub tic {
	my $key = shift;
	$_TICTOC{$key} = {SUM=>0} unless exists $_TICTOC{$key};
	$_TICTOC{$key}->{start} = time;
}

=nd
Function: toc

Закончить замер времени.

Parameters:
	$key - Ключ, с которым ассоциировался замер
=cut
sub toc {
	my $key = shift;
	$_TICTOC{$key}->{SUM} += time - $_TICTOC{$key}->{start};
	$_TICTOC{$key}->{start} = 0;
}

=nd
Function: tictoc

Вернуть суммарное значение замеров для заданного ключа

Parameters:
	$key - Ключ, с которым ассоциировался замер
=cut
sub tictoc {
	my $key = shift;
	return (exists $_TICTOC{$key} ? $_TICTOC{$key}->{SUM} : 0);
}
1;

# vim:enc=utf-8
