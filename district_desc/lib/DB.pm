package DB;

use lib qw|../conf/ |;
use Cfg;
use DBI;
use Error;
Error::init();

=nd
Method: new

Конструктор обьекта
=cut

sub new {
	my $class = shift;
	my $base = shift;
	my $dbh = undef;
	my @db_param = (cfg('db.'.$base.'.str').cfg('db.'.$base.'.basename').';host='.cfg('db.'.$base.'.dbhost'),
						cfg('db.'.$base.'.user'), 
						cfg('db.'.$base.'.pass'), 
						cfg('db.'.$base.'.options'));


	my $this= {
		dbh=>$dbh,
		basename=>$base,
		connect=>sub{return DBI->connect_cached(@db_param);},
	};

	bless ($this,$class);
	# при создании обьекта делаем реконнект
	$this->reconnect();
	return $this;
}

=nd
Method: reconnect
проверяет соединение с бд и переустанавливает в случае если коннекта нет
=cut

sub reconnect {
	my DB $this = shift;
	return 1 if (defined $this->dbh() && $this->dbh()->ping);
	$this->{dbh} = $this->{connect}->(); 
	unless (defined $this->dbh() && $this->dbh()->ping){
		warn "SYS | Connect database Failed";
		return 0;
	};
	return 1;
};

sub dbh {
	my $this = shift;
	return $this->{dbh};
}

=nd
Method: save
сохраняет или изменяет данные в таблици, метод работает только с таблицами обьектов (имеется id sequence)

Parameters: 
	$table - таблица в которую необходимо сделать изменения
	$H - хеш с данными для сохранения, если есть id - делаем update, если нет - делаем insert

Returns:
	$id - идентификатор вставленного или изменённого элемента
=cut

=nd
Method: getRecord
	выбор одной записи из таблици

Parameters: 
	$Q - запрос
	$P - список параметров ключ - значение

Returns:
	ссылку на хеш с данными
=cut

sub getRecord{
	my $this = shift;
	my $QUERY = shift;
	my @par = @_;
	my $sth = $this->dbh()->prepare($QUERY);
	debug "DBI|",[$QUERY,@par];
	$sth->execute(@par);
	my $h = $sth->fetchrow_hashref;
	return $h || {};
}
	
=nd
Method: getList
	выбор списка из таблици

Parameters:
	$Q - запрос
	$P - список параметров ключ - значение

Returns:
	ссылку на массив хешей с данными 

=cut

sub getList{
	my $this = shift;
	my $QUERY = shift;
	my @par = @_;
	my $res = [];
	my $sth = $this->dbh()->prepare($QUERY);
	debug "DBI|",[$QUERY,@par];
	$sth->execute(@par);
	while ( my $r = $sth->fetchrow_hashref){
		push @$res, $r;
	}
	return (@$res ? $res : []); 
}

=nd
Method: do
	выполнить запрос 

Parameters:
	$q - строку запроса 

Returns:
	$errstr
=cut

sub do{
	my $this = shift;
	debug (\@_);
	my $r = $this->dbh()->do(@_);
	unless ($r){
		debug_db $this->{dbh}->errstr;
		return undef;
	}
	return 	$r; 
}

sub commit {
	my DB $this = shift;
	my $res = $this->dbh()->commit();
	return ($res ? 0 : warn ("DB|".$this->dbh()->errsrt));
}

sub execFunc {
	my DB $this = shift;
	my $f = shift;
	my $q = $this->do("select $f as res"); 
	return (%$r ? $r->{res} : undef);
}

sub nextval {
	my $class = shift;
	my $key = shift;
	my $val = $class->getRecord('select nextval(\''.$key.'\') as val');
	return $val->{val};
}

1;
