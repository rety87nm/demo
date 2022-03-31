package Cfg;

=nd
Class: Cfg

Модуль для работы с конфигурационными файлами
Работает следующим образом: ищет в заданной директории файлы типа *.cfg, 
исполняет их и записывает результат в общую переменную

=cut 

use strict;
use utf8;
use vars qw(@ISA $VERSION @EXPORT $CFG);
use Exporter;
$VERSION = 0.2;
@ISA=qw(Exporter);
@EXPORT = qw(cfg conf_load);

use Data::Dumper;

sub conf_load {
	my $appname = shift;
	use Cfg::Loader;
	open F,"</etc/$appname" or die "Can't open path_file, please check symlink in /etc/$appname/";
	my $p = <F>; chomp $p;
	$CFG = Cfg::Loader::load($p.'/conf/');
	# добавляем корневой путь к Хешу конфига:
	$CFG->{server}{root} = $p;
	use Cfg::Loader;
}

=nd
Method: cfg 

Parameters:
	$key - ключ по которому хотят получить данные

Returns:
	ссылку на структуру данных конфига

=cut

sub cfg {
	my $k = shift;
	my $val = @_;
	my $c = $CFG;

	for (split /\./,$k){
		return $val unless exists $c->{$_};
		$c = $c->{$_};
	}
	return $c;
}

sub keys {
	return [keys %{$CFG}];
}

1;
