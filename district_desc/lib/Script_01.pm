package Script_01;

=nd
Class: Script_01

=cut

use vars qw(@ISA @EXPORT $VERSION %ENV $IN_PROCESS $KILL_SCRIPT);
use Template;
use Cfg;
use Error;
use Exporter;
use FCGI;
use FCGI::ProcManager::MaxRequests;
use Step;
use DB;
use Data::Dumper;
use URI::Escape;
use POSIX qw|SIGTERM|;
use JSON;
use locale;

$VERSION = 1.4;

@ISA = qw/Exporter/;
@EXPORT = qw/GETVARS GETSCRIPT GETCFG GETDB/;
POSIX::sigaction(SIGTERM,POSIX::SigAction->new(\&stopScript));
$SIG{PIPE} = 'IGNORE';
$KILL_SCRIPT = 0;
$IN_PROCESS = 0;
my $_SCRIPT = undef;

=nd
Method: new

Parameters:
	DB - 
	TMPL - 
=cut

sub new {
	my $class = shift;
	my $this =
	{	param=>{
			name=>undef,
			connect_db=>['main'],
			connect_memd=>0,
			init_tmpl=>1,
			auth=>0,
			no_cache=>0,
			tmpl=>1,
			@_
		},
		__VARS__=>{},
		__GDATA__=>{},
		__PDATA__=>undef,
		__ENV__=>{},
		__STABLE__=>{},
		__UFILES__=>{},
		__COOKIE__ => [],
		__STEPS__=>{}
	};

	# ©©©©©©©©© ©©©©©©©©©©©©©©©© ©©©©©
	conf_load($this->{param}{name});

	if (@{$this->{param}{connect_db}}){
		foreach my $base (@{$this->{param}{connect_db}}){
			debug $base;
			$this->{__DB__}{$base} = new DB('main');
		}
	}

	if ($this->{param}{tmpl}){
		$this->{__TMPL__} = _initTmpl();
	}
	
	$this->{__STEPS__}{FORB} = new Step('FORB',{NEXT=>{'page'=>'inc.forb'},do=>sub{return 'page'}});

	bless $this,$class;
	return $this;
}

=nd
Method: stopScript

=cut

sub stopScript{
	my $s = shift;
	warn "SYS| process $$ TERM signell",$s;
	$KILL_SCRIPT = 1;
	exit 0 unless $IN_PROCESS;
}

sub _initTmpl {
	my $T = new Template({
					INCLUDE_PATH=>cfg('server.root').'/s/tmpl/',
					ABSOLUTE=>1,
					RELATIVE=>1,
					COMPILE_EXT=>'_c',
					COMPILE_DIR=>cfg('tmpl.cache'),
					FILTERS=>{
						JSON=>\&_ttfilterJSON,
						UESC=>\&_ttfilterUESC,
						strip_tags=>\&_ttfilterSTRIP_TAGS,
					},
					PLUGIN_BASE => 'TT'
			}
	);

	$Template::Stash::SCALAR_OPS->{decline} = sub {
		my ($val,$s,$p1,$p2) = @_;
		if ($val > 10 && $val <21){
			return $p2;
		}
		$val %= 10;
		if ($val == 1){
			return $s;
		}elsif($val < 5 && $val > 1){
			return $p1;
		}
		return $p2;
	};

	$Template::Stash::SCALAR_OPS->{ rest } = sub {
        my ($val,$base) = @_;
        return ($base ? $val % $base : 0);
    };
	
	return $T;
}

sub _ttfilterUESC {
	my $text = shift;
	my $res =  Encode::decode( 'koi8-r', $text );
	$res =~ s/([^\x00-\x7F])/ '\\u' . sprintf '%04x', ord $1 /eg;
	return $res;
}

sub _ttfilterSTRIP_TAGS {
    my $text = shift;

    $text =~ s/</&lt;/g;
    $text =~ s/>/&gt;/g;

    return $text;
}

=nd
Method: addStep
	©©©©©©©©©©©© ©©© ©©©©©©©
	
Parameters:
	$Step - ©©©©©© ©©©©©© Step

=cut

sub addStep{
	my Script_01 $this = shift;
	my $Step = shift;
	$this->STEPS()->{$Step->name} = $Step;
	return 0;
}

sub GETDB {
	return GETSCRIPT()->D(shift);
}

=nd
Method: STEPS 
	©©©©©©©©©© ©©©©©© ©© ©©© © ©©©©©© ©©©©©©©

Parameters:

=cut

sub STEPS {
	my Script_01 $this = shift;
	return $this->{__STEPS__};
}

=nd
Method: 
	rule ©©©©©©©© ©©©©©©© ©©©©©©©©©© ©©©©©© ©©©©©©©©

=cut

sub rule{
	my Script_01 $this = shift;
	if (@_){
		$this->{__RULE__} = shift;
	}
	return $this->{__RULE__};
}

=nd
Method: reopen_std
=cut

sub reopen_std {
	#open (*STDIN,'+<',"/dev/null");
	#open (*STDOUT,'+<',"/dev/null");
	#open (*STDERR,'>',"/dev/null");
	open (*STDIN,'+<',"/tmp/log");
	open (*STDOUT,'+<',"/tmp/log");
	open (*STDERR,'>',"/tmp/log");

	return 1;
}

=nd
Method: daemonize
=cut

sub daemonize {
	my Script_01 $this = shift;
	my $path = cfg('app.'.$this->{param}{name}.'.pidfile');
	$this->check_pid_file($path) or die " Application Alredi running.".$!;

	my $pid = fork();
	unless (defined $pid){
	 	warn "SYS | can't fork!!!" && die;
	}
	if ($pid){
		print STDERR $path."....... PID = ".$pid."\n" if $pid;
		exit( 0 ) if $pid;
	}

	$this->create_pid_file($path);

	chdir '/' or warn "SYS | Can't change dir" && die;

	POSIX::setsid() or warn "SYS | Can't start new_session" && die;

	return 1;
}

sub create_pid_file{
	my Script_01 $this = shift;
	my $pid_file= cfg('app.'.$this->{param}{name}.'.pidfile');
	open( PID, '>' . $pid_file) or die "Couldn't open pid file \"$pid_file\" [$!].\n";
	print PID "$$\n";
	close PID;
	die "Pid_file \"$pid_file\" not created.\n" unless -e $pid_file;
	return 1;
}

=cut
=nd
Method: check_pid_file
Parameters:

Returns:
=cut

sub check_pid_file {
	my Script_01 $this = shift;
	my $pid_file = cfg('app.'.$this->{param}{name}.'.pidfile');
	return 1 unless -e $pid_file;

	### get the currently listed pid
	open( _PID, $pid_file ) or warn  "SYS | Couldn't open existant pid_file \"$pid_file\"";
	my $current_pid = <_PID>;
	chomp $current_pid;
	close _PID;
	my $running_cmd = (`ps h -o command -p $current_pid`)[-1] || '';
	if( $running_cmd =~ /$pid_file/ )
	{
		if( $current_pid == $$ )
		{
			warn "Pid_file created by this same process. Doing nothing.\n";
		    return 1;
		}
		die "$pid_file: Pid_file already exists for running process ($current_pid)... aborting\n";
	}
	warn "Pid_file \"$pid_file\" already exists.  Overwriting!\n";
	unlink $pid_file;
	return 1;
}

=nd
Method: execute

=cut

sub execute {
	my Script_01 $this = shift;
	my ($procname, $sock_path, $children, $max_req);
	$procname = $this->{param}{name};
	$sock_path  = cfg('app.'.$procname.'.socket');
	$children = cfg('app.'.$procname.'.childs') || 1;
	$max_req = cfg('app.'.$procname.'.max_req') || 10 ;
	$this->daemonize($procname);
	my $sock = FCGI::OpenSocket($sock_path, 10) or die "Can't open socket $sock_path: $!\n";
	my $req  = FCGI::Request( \*STDIN, \*STDOUT, \*STDERR, \%ENV, $sock, FCGI::FAIL_ACCEPT_ON_INTR);

	reopen_std();
	my $count = 0;

	debug "DATA:::==================================";
	my $pm = FCGI::ProcManager::MaxRequests->new({
		n_processes =>	($children || 2),
		max_requests=>	$max_req || 50,
		start_delay =>	0,
	    	pm_title    =>	"perl-fcgi manager (daemon ; $procname)",
	}) or die 'FCGI::ProcManager::MaxRequests->new failed';

	$pm->pm_manage();
	
	$pm->pm_change_process_name("perl-fcgi (child; $procname)");

	while($req->Accept() >= 0){
		$pm->pm_pre_dispatch();
		$this->D->reconnect();
		$IN_PROCESS = 1;
		$this->{__ENV__} = $req->GetEnvironment();
		%ENV = %{$this->{__ENV__}};

		$this->{__REQ__} = $req;
		
		Error::init();
		debug "ENVIRONMENT:",$this->{__ENV__}; 
		$this->_readParameters();	

		my $step = $this->rule->();
		debug "Execute first step :".$step;
		
		my $loop = 1;

		while ($loop){
			my $c = $this->execStep($step);
			debug "Result execute step \"$step\":",$c;
			if ($c =~ /^step\.*/i){
			 	$step = $this->getNextStep($step,$c);
				next;
			}elsif($c =~ /^page\.*/i){
				$this->showPage($step,$c);
			}
			$loop = 0;
		}
		$this->_clearRequestData();

		$pm->pm_post_dispatch();
	}
}

sub _readParameters{
	my Script_01 $this = shift;
	my $R = $this->R;
	my $F = $this->F;
	$F->{in} = {};

	if ($ENV{REQUEST_METHOD} eq 'POST'){
		if ($ENV{CONTENT_LENGTH} && $ENV{CONTENT_LENGTH} =~ /^\d+$/ ){
			my $max_mbyte  = 5; 
			my $max_length = $max_mbyte * 1024 * 1024;
			read(STDIN, $this->{__PDATA__}, ( ($ENV{CONTENT_LENGTH} > $max_length) ? $max_length : $ENV{CONTENT_LENGTH} ), 0);
			
			debug "read data:",$this->{__PDATA__};
			if ($ENV{CONTENT_TYPE} eq 'application/x-www-form-urlencoded'){
				$this->{__PDATA__} =~ s/\+/%20/g;
				$ENV{QUERY_STRING} .= ( ($ENV{QUERY_STRING} eq '' || $ENV{QUERY_STRING} =~ /&$/) ? $this->{__PDATA__} : '&'.$this->{__PDATA__}  );
			}

			# form/multipart data
			if ($ENV{CONTENT_TYPE} =~ /multipart\/form-data/ ){
				$this->readMultipart();
			}
		}
	}

	if ($ENV{QUERY_STRING}){
			my @pairs = split /&/ ,$ENV{QUERY_STRING};
			foreach my $i (@pairs){
				my ($k,$v) = map {uri_unescape($_)} split /=/ , $i;
				_saveParameters($F->{in},$v,(split /\./ , $k));
			}
	}

	debug "Params:",$this->F;
	return 1;
}

sub R {
	my Script_01 $this = shift;
	return $this->{__REQ__};
}

sub _out {
	my Script_01 $this = shift;
	my Step $action = shift;
	my $res = (shift || 'ok');
	tic('TIMEOUT');
	return warn "SYS| Can't print file without intialization template subsystem"
	unless $this->{__TMPL__};
	my $r = undef;
	my $a = undef;
	# add cookie
	my ( $domain ) = ( cfg ('servername') =~ /([^.]+\.[^.]+)$/o );
	map { print 'Set-Cookie: '.$_.'; domain=.'.$domain."; path=/\n" } @{$this->C};
	# add nocache
	if ($this->{param}{no_cache}) {
		print "Cache-Control:no-cache,no-store,max-age=0,must-revalidate\n";
		print "Pragma: no-cache\n";
		print "Expires: Mon, 26 Jul 1997 05:00:00 GMT\n";
	}
	# add header
	$r = $action->header();
	return 0 unless $r;
	# get filename
	my $filename = cfg ($action->{'content_'.$res});
	if (my $result = $this->out($filename)){
		return $result;
	}
	toc('TIMEOUT');
	debug "TIME OUT TEMPLATE",tictoc('TIMEOUT');
	return 0;
}

sub out {
	my Script_01 $this = shift;
	my $file = shift;
	my $out = '';
	unless ($this->{__TMPL__}->process($file,$this->F(),\$out)){
		warn "SYS | TMPL_ERR ".$this->{__TMPL__}->error();
	}
	return $out;
}


sub _saveParameters {
	my ($ref,$val,@key) = @_;
	my $last = pop @key;
	foreach my $i (@key){
		$ref->{$i} = {} unless exists $ref->{$i} && ref $ref->{$i} eq 'HASH';
		$ref = $ref->{$i};
	}
	$ref->{$last} = $val;
}

sub F {
	my Script_01 $this = shift;
	return $this->{__VARS__};
}

=nd
Method: PD
Возвращает пришедшие пост данные
=cut

sub PD {
	my Script_01 $this = shift;
	return $this->{__PDATA__};
}

=nd
Method: GD
Возвращает пришедшие гет данные, те же самые данные дублированны в
=cut

sub GD {
	my Script_01 $this = shift;
	return $this->{__GDATA__};
}

=nd
Method: getENV
Везвращает переменные окружениz
=cut

sub E {
	my Script_01 $this = shift;
	return $this->{__ENV__};
}

=nd
Method: FL
	Files list - возвращает список загруженных джанных 
=cut

sub FL {
	my Script_01 $this = shift;
	return $this->{__UFILES__}
}

=nd
Method: D
Возвращает ссылку на класс DB;
Надо помнить что коннект происходит в каждом потоке свой.
=cut

sub D {
	my Script_01 $this = shift;
	my $base = shift || 'main';
	return $this->{__DB__}{$base};
}

=nd
Method: P
возвращает обьект класса Perm

Parameters:
Returns:
=cut

sub P {
	my Script_01 $this = shift;
	return $this->{__PERM__};
}

=nd
Method: C
возвращает обьект класса Cookie

Parameters:
Returns:
=cut

sub C {
	my Script_01 $this = shift;
	return $this->{__COOKIE__};
}

=nd
Method: T
вернуть обьект Template::Toolkit

=cut

sub T {
	my Script_01 $this = shift;
	return $this->{__TMPL__};
}

=nd
Method: Memd
вернуть обьект Memcached

=cut

sub Memd {
	my Script_01 $this = shift;
	return $this->{__MEMD__};
}

=nd
Method: stable
сохранить в параметре который не изменяется от итераций скрипта

Parameters:

Returns:

=cut

sub __param {
	my Script_01 $this = shift;
	my $type = shift;
	unless (@_){
		return %{$this->{$type}};
	}
	if ($#_ == 0){
		my $p = shift;
		return (exists $this->{$type}{$p} ? $this->{$type}{$p} : undef);
	}
	my %v =@_;
	foreach my $i (keys %v){
		$this->{$type}{$i} = $v{$i};
	}
	return 1;

}

sub stable{
	my Script_01 $this = shift;
	return $this->__param('__STABLE__',@_);
}

=nd
Method: charprepare
Parameters:
	$data - данве
	unescape - сделать uri_unescape данных
	from - из какой  кодировки по умолчанию из utf
	to - в какую, по умолчанию в кодировку сервера

Returns
	строку с данными

=cut

sub charprepare {
	my Script_01 $this = shift;
	my $data = shift;
	my %I = (to=>cfg('global.server_charset'),
			 from=>'UTF8',
			 unescape=>1,
	@_);
	
	debug "===== data ======",$data;
	# для тестовых запросов передаём параметр chartest=тест в строку запроса, для определения в какой ж кодировке руские буквовки

	if (defined $I{unescape}){
		$data =~ s/\+/%20/g;
		$data = uri_unescape($data);
		#отунескейпилось
		debug "=======unescape===========",$data;
	}

	debug "==========charset!!!!================",$I{from};

	return Convert::Cyrillic::cstocs($I{from},$I{to},$data) if ($I{from} && $I{from} ne cfg('global.server_charset'));
	return $data;
}

sub define_charset{
	my Script_01 $this = shift;
	my $q = shift;
	debug "Method define_charset",$q;
	if( $q =~ /_charset_test_=%D4%C5%D3%D4/ ){
		debug "DEFINE CHARSET TEST KOI8";
		return 'koi8';
	}elsif( $q =~ /_charset_test_=%F2%E5%F1%F2/){
		debug "DEFINE CHARSET TEST WIN";
		return 'win';
	}
	return 'UTF8';
}

=nd
Method: append
Добавить поля к потоку, если таких не существует.

Parameters:
	Первым параметром должен идти префикс (undef, если его нет), т.е. вертка потока, в которую надо добавлять.

Returns:
	0 или код ошибки
=cut

sub append {
	my Script_01 $this = shift;
	my $base = $this->{__VARS__};
	#   unless ($#_ % 2){
	my $prefix = shift;
	if (defined $prefix){
		my @path = split /\./ , $prefix;
		foreach my $i (@path){
			$base->{$i} = {} unless exists $base->{$i};
			$base = $base->{$i};
		}
	}
	#   }
	my $I = ($#_  == 0 ? shift : {@_});
	if (ref $base eq 'ARRAY'){
		foreach my $k (@$base){
			foreach my $j (keys %$I){
				$k->{$j} = $I->{$j} unless exists $k->{$j};
			}
		}
	}elsif(ref $base eq 'HASH'){
		foreach my $j (keys %$I){
			$base->{$j} = $I->{$j} unless exists $base->{$j};
		}
	}else{
		return warn "SYS|Chain has unexpexcted type";
	}
	return 0;
}

=nd
Method: redirect
сделать редирект

Parameters:
	$url - урл по которому редиректят

Returns:
	заголовок в stdout

=cut

sub redirect {
	my Script_01 $this = shift;
	my $url = shift;
	print "Status: 302 Found\n";
	print "Location: ".$url."\n\n";
	return 0;
}

=nd
Method: redirect_html
сделать урл редирект через html страничку с js редиректом

Parameters:

Returns:

=cut

sub redirect_html {
	my Script_01 $this = shift;
	print "Status: 200; OK\n";
	print "Content-Type: text/html; charset=".cfg('global.header_charset')."\n\n";
	$this->out(cfg('pages.sys.gwredirect'));
	return 0;
}

=nd
Method: readMultipart
	читает пост данные, пришедшие с multipart/form-data

Parameters:
	$boundary - разделитель между частями контента

Returns:
 ссылку на хеш с данными
 	vars=>{}, - данные с формы без Content-type
	files=>[], - данные с Conetnt-type

=cut

sub readMultipart{
	my Script_01 $this = shift;
	
	my ($boundary) = $ENV{CONTENT_TYPE} =~ /boundary=([^\r]+)/;
	my $nl = "\015\012";
	my $buffer = $this->{__PDATA__};
	my $bstart = '--'.$boundary;
	my @l = split /$bstart/,$buffer;
	my $c = 0;
	my $files = {};
	my $params = [];

	for ( @l ){
		next unless $_;
		debug "PARSE PART ".$c++." :".$_;
		my @mpart = split /\015\012\015\012/, $_, 2;
		my $c1 = 0;

		my $new_files = undef;
		my $new_params = 0;
		for (@mpart){
			if ($_ =~ /^$nl/){
				if ($_ =~ /Content-Type:\s*(.*)$/){
					my ($type,$name,$file) = ('','','');
					if ($_ =~ /Content-Disposition:\s(.*)/){
						if ($1 =~ /^form-data;\sname=\"(\w+)\";\sfilename=\"(.*)\"/){
							$files->{$1}{file} = $2;
							$new_files = $1;
						}
					}
				}else{
					if ($_ =~ /Content-Disposition:\sform-data;\sname=\"(\w+)\"/){
						push @{$params}, {name=>$1,value=>undef};
						$new_params = 1;
					}
				}
				next;
			}

			$_ =~ s/\r?\n$//;
			if ($new_files){
				$files->{$new_files}{data} = $_;

			}elsif($new_params){
				$params->[$#$params]->{value} = $_;
			}
			($new_files,$new_params) = (undef,0);
		}
	}

	$this->{__UFILES__} = $files;

	foreach my $i (@$params){
		$ENV{QUERY_STRING} .= ($ENV{QUERY_STRING} ne '' ? '&' : '').$i->{name}.'='.$i->{value};
		debug "=========================",$ENV{QUERY_STRING};
	}

	return 1;
}

=nd
Method: upload
Метод для загрузки файлов на сервер
Parameters:
	$as - имя файла под которым надо его сохранить 
	$fn - имя параметра в котором вришёл файл
	$dir - директория куда надо сохранить файл
	accept - список разрешённых расширений, 

Returns:
	0 - успешно 
	во всяких других случаях - нет 
=cut

sub upload {
	my Script_01 $this = shift; 
	my ($a,$f,$d) = (shift,shift,shift); 
	my %I = (accept=>[],@_);
	my $files = $this->FL; 
	my $name = $files->{$f}{file}; 
	warn 'UPLD', 'UPLD_'.$name unless $files->{$f}{data}; 
	
	my %ext = map {$_=>1} @{$I{accept}};
	my $exts = '';
	
	if (%ext){
		$name =~ m/\.(\w+?)$/;
		my $exts = $1;
		$exts = lc($exts) if $exts;
		unless (exists $ext{$exts}){
			return warn 'UPLD', 'UPLD_'.$name;
		}
	}

	open (ST,">>$d$a") || warn 'UPLD', 'UPLD_'.$a."|$!"; 
	binmode ST; 
	print ST $files->{$f}{data}; 
	close ST;
	return 0;
}

sub GETSCRIPT {
	unless ($_SCRIPT){
		$_SCRIPT = new Script_01(@_);
	}
	return $_SCRIPT;
}

sub execStep {
	my Script_01 $this = shift;
	my $name = shift;
	return $this->{__STEPS__}->{$name}->do();
}

sub GETVARS {
	return GETSCRIPT()->F();
}

sub _clearRequestData {
	my Script_01 $this = shift;
	$this->{__VARS__} = {};
	GETDB()->commit;
	return 1;
}

sub showPage {
	my Script_01 $this = shift;
	my ($name,$c) = (shift,shift);
	my $ST = $this->STEPS()->{$name};
	# print header step-content
	$ST->header();
	# put content-page
	debug "---------", cfg('pages.'.$ST->getPage($c));
	unless (my $file = cfg('pages.'.$ST->getPage($c))){
		warn "undefined file in pages.cfg for key: ".cfg('pages.'.$ST->getPage($c));
	}else{
		print $this->out($file);
	}
}

1;


