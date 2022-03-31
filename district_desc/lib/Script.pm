package Script;

=nd
Class: Script

=cut

use vars qw(@ISA @EXPORT $VERSION %ENV $IN_PROCESS $KILL_SCRIPT);
use Template;
use Encode;
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
use DateTime;

$VERSION = 1.4;

@ISA = qw/Exporter/;
@EXPORT = qw/GETVARS GETSCRIPT GETCFG GETDB/;
POSIX::sigaction(SIGTERM,POSIX::SigAction->new(\&stopScript));
$SIG{PIPE} = 'IGNORE';
$KILL_SCRIPT = 0;
$IN_PROCESS = 0;
my $_SCRIPT = undef;

=nd
BEGIN {
	use Template::Provider;
	use bytes; 
	no warnings 'redefine';
	my $bom = "\x{feff}"; 
	my $len = length($bom);
	*Template::Provider::_decode_unicode = sub {
		die "decode unicode!!!";
		my ($self,$s) = @_;
		$s = substr($s, $len) if substr($s, 0, $len) eq $bom;
		utf8::decode($s);
		return $s;
	}
}
=cut

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
		__COOKIE__ => {in=>{},out=>{}},
		__STEPS__=>{}
	};

	conf_load($this->{param}{name});

	if (@{$this->{param}{connect_db}}){
		foreach my $base (@{$this->{param}{connect_db}}){
			$this->{__DB__}{$base} = new DB('main');
		}
	}

	if ($this->{param}{tmpl}){
		$this->{__TMPL__} = _initTmpl();
	}
	
	$this->{__STEPS__}{FORB} = new Step('FORB',NEXT=>{'page'=>'inc.forb'},do=>sub{return 'page'});

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
					ENCODING=>'utf8',
					RELATIVE=>1,
					COMPILE_EXT=>'_c',
					COMPILE_DIR=>cfg('server.root').cfg('tmpl.cache'),
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

	$Template::Stash::SCALAR_OPS->{ human_date } = sub {
		my $val = shift;
		my $p = shift;
		debug  "PPPPPP",$p;
		return decode_utf8(humanDate(date=>$val,%$p));
	};

	return $T;
}

sub _ttfilterUESC {
	my $text = shift;
	my $res =  Encode::decode( 'UTF8', $text );
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
	¿¿¿¿¿¿¿¿¿¿¿¿ ¿¿¿ ¿¿¿¿¿¿¿
	
Parameters:
	$Step - ¿¿¿¿¿¿ ¿¿¿¿¿¿ Step

=cut

sub addStep{
	my Script $this = shift;
	my $Step = shift;
	$this->STEPS()->{$Step->name} = $Step;
	return 0;
}

sub GETDB {
	return GETSCRIPT()->D(shift);
}

=nd
Method: STEPS 
	¿¿¿¿¿¿¿¿¿¿ ¿¿¿¿¿¿ ¿¿ ¿¿¿ ¿ ¿¿¿¿¿¿ ¿¿¿¿¿¿¿

Parameters:

=cut

sub STEPS {
	my Script $this = shift;
	return $this->{__STEPS__};
}

=nd
Method: 
	rule ¿¿¿¿¿¿¿¿ ¿¿¿¿¿¿¿ ¿¿¿¿¿¿¿¿¿¿ ¿¿¿¿¿¿ ¿¿¿¿¿¿¿¿

=cut

sub rule{
	my Script $this = shift;
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
	my Script $this = shift;
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
	my Script $this = shift;
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
	my Script $this = shift;
	my $pid_file = cfg('app.'.$this->{param}{name}.'.pidfile');
	return 0 if -e $pid_file;
	return 1;
}

=nd
Method: execute

=cut

sub execute {
	my Script $this = shift;
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

		$this->read_cookie();

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
	my Script $this = shift;
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
				my ($k,$v) = map {Encode::decode('utf8',uri_unescape($_))} split /=/ , $i;
				_saveParameters($F->{in},$v,(split /\./ , $k));
			}
	}

	debug "Params:",$this->F;
	return 1;
}

sub R {
	my Script $this = shift;
	return $this->{__REQ__};
}

sub _out {
	my Script $this = shift;
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
	my Script $this = shift;
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
	my Script $this = shift;
	return $this->{__VARS__};
}

=nd
Method: PD
÷ÏÚ×ÒÁÝÁÅÔ ÐÒÉÛÅÄÛÉÅ ÐÏÓÔ ÄÁÎÎÙÅ
=cut

sub PD {
	my Script $this = shift;
	return $this->{__PDATA__};
}

=nd
Method: GD
÷ÏÚ×ÒÁÝÁÅÔ ÐÒÉÛÅÄÛÉÅ ÇÅÔ ÄÁÎÎÙÅ, ÔÅ ÖÅ ÓÁÍÙÅ ÄÁÎÎÙÅ ÄÕÂÌÉÒÏ×ÁÎÎÙ ×
=cut

sub GD {
	my Script $this = shift;
	return $this->{__GDATA__};
}

=nd
Method: getENV
÷ÅÚ×ÒÁÝÁÅÔ ÐÅÒÅÍÅÎÎÙÅ ÏËÒÕÖÅÎÉz
=cut

sub E {
	my Script $this = shift;
	return $this->{__ENV__};
}

=nd
Method: FL
	Files list - ×ÏÚ×ÒÁÝÁÅÔ ÓÐÉÓÏË ÚÁÇÒÕÖÅÎÎÙÈ ÄÖÁÎÎÙÈ 
=cut

sub FL {
	my Script $this = shift;
	return $this->{__UFILES__}
}

=nd
Method: D
÷ÏÚ×ÒÁÝÁÅÔ ÓÓÙÌËÕ ÎÁ ËÌÁÓÓ DB;
îÁÄÏ ÐÏÍÎÉÔØ ÞÔÏ ËÏÎÎÅËÔ ÐÒÏÉÓÈÏÄÉÔ × ËÁÖÄÏÍ ÐÏÔÏËÅ Ó×ÏÊ.
=cut

sub D {
	my Script $this = shift;
	my $base = shift || 'main';
	return $this->{__DB__}{$base};
}

=nd
Method: P
×ÏÚ×ÒÁÝÁÅÔ ÏÂØÅËÔ ËÌÁÓÓÁ Perm

Parameters:
Returns:
=cut

sub P {
	my Script $this = shift;
	return $this->{__PERM__};
}

=nd
Method: C
×ÏÚ×ÒÁÝÁÅÔ ÏÂØÅËÔ ËÌÁÓÓÁ Cookie

Parameters:
Returns:
=cut

sub C {
	my Script $this = shift;
	return $this->{__COOKIE__};
}

=nd
Method: T
×ÅÒÎÕÔØ ÏÂØÅËÔ Template::Toolkit

=cut

sub T {
	my Script $this = shift;
	return $this->{__TMPL__};
}

=nd
Method: Memd
×ÅÒÎÕÔØ ÏÂØÅËÔ Memcached

=cut

sub Memd {
	my Script $this = shift;
	return $this->{__MEMD__};
}

=nd
Method: stable
ÓÏÈÒÁÎÉÔØ × ÐÁÒÁÍÅÔÒÅ ËÏÔÏÒÙÊ ÎÅ ÉÚÍÅÎÑÅÔÓÑ ÏÔ ÉÔÅÒÁÃÉÊ ÓËÒÉÐÔÁ

Parameters:

Returns:

=cut

sub __param {
	my Script $this = shift;
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
	my Script $this = shift;
	return $this->__param('__STABLE__',@_);
}

=nd
Method: charprepare
Parameters:
	$data - ÄÁÎ×Å
	unescape - ÓÄÅÌÁÔØ uri_unescape ÄÁÎÎÙÈ
	from - ÉÚ ËÁËÏÊ  ËÏÄÉÒÏ×ËÉ ÐÏ ÕÍÏÌÞÁÎÉÀ ÉÚ utf
	to - × ËÁËÕÀ, ÐÏ ÕÍÏÌÞÁÎÉÀ × ËÏÄÉÒÏ×ËÕ ÓÅÒ×ÅÒÁ

Returns
	ÓÔÒÏËÕ Ó ÄÁÎÎÙÍÉ

=cut

sub charprepare {
	my Script $this = shift;
	my $data = shift;
	my %I = (to=>cfg('global.server_charset'),
			 from=>'UTF8',
			 unescape=>1,
	@_);
	
	debug "===== data ======",$data;
	# ÄÌÑ ÔÅÓÔÏ×ÙÈ ÚÁÐÒÏÓÏ× ÐÅÒÅÄÁ£Í ÐÁÒÁÍÅÔÒ chartest=ÔÅÓÔ × ÓÔÒÏËÕ ÚÁÐÒÏÓÁ, ÄÌÑ ÏÐÒÅÄÅÌÅÎÉÑ × ËÁËÏÊ Ö ËÏÄÉÒÏ×ËÅ ÒÕÓËÉÅ ÂÕË×Ï×ËÉ

	if (defined $I{unescape}){
		$data =~ s/\+/%20/g;
		$data = uri_unescape($data);
		#ÏÔÕÎÅÓËÅÊÐÉÌÏÓØ
		debug "=======unescape===========",$data;
	}

	debug "==========charset!!!!================",$I{from};

	return Convert::Cyrillic::cstocs($I{from},$I{to},$data) if ($I{from} && $I{from} ne cfg('global.server_charset'));
	return $data;
}

sub define_charset{
	my Script $this = shift;
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
äÏÂÁ×ÉÔØ ÐÏÌÑ Ë ÐÏÔÏËÕ, ÅÓÌÉ ÔÁËÉÈ ÎÅ ÓÕÝÅÓÔ×ÕÅÔ.

Parameters:
	ðÅÒ×ÙÍ ÐÁÒÁÍÅÔÒÏÍ ÄÏÌÖÅÎ ÉÄÔÉ ÐÒÅÆÉËÓ (undef, ÅÓÌÉ ÅÇÏ ÎÅÔ), Ô.Å. ×ÅÒÔËÁ ÐÏÔÏËÁ, × ËÏÔÏÒÕÀ ÎÁÄÏ ÄÏÂÁ×ÌÑÔØ.

Returns:
	0 ÉÌÉ ËÏÄ ÏÛÉÂËÉ
=cut

sub append {
	my Script $this = shift;
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
ÓÄÅÌÁÔØ ÒÅÄÉÒÅËÔ

Parameters:
	$url - ÕÒÌ ÐÏ ËÏÔÏÒÏÍÕ ÒÅÄÉÒÅËÔÑÔ

Returns:
	ÚÁÇÏÌÏ×ÏË × stdout

=cut

sub redirect {
	my Script $this = shift;
	my $url = shift;
	print "Status: 302 Found\n";
	print "Location: ".$url."\n\n";
	return 0;
}

=nd
Method: redirect_html
ÓÄÅÌÁÔØ ÕÒÌ ÒÅÄÉÒÅËÔ ÞÅÒÅÚ html ÓÔÒÁÎÉÞËÕ Ó js ÒÅÄÉÒÅËÔÏÍ

Parameters:

Returns:

=cut

sub redirect_html {
	my Script $this = shift;
	print "Status: 200; OK\n";
	print "Content-Type: text/html; charset=".cfg('global.header_charset')."\n\n";
	$this->out(cfg('pages.sys.gwredirect'));
	return 0;
}

=nd
Method: readMultipart
	ÞÉÔÁÅÔ ÐÏÓÔ ÄÁÎÎÙÅ, ÐÒÉÛÅÄÛÉÅ Ó multipart/form-data

Parameters:
	$boundary - ÒÁÚÄÅÌÉÔÅÌØ ÍÅÖÄÕ ÞÁÓÔÑÍÉ ËÏÎÔÅÎÔÁ

Returns:
 ÓÓÙÌËÕ ÎÁ ÈÅÛ Ó ÄÁÎÎÙÍÉ
 	vars=>{}, - ÄÁÎÎÙÅ Ó ÆÏÒÍÙ ÂÅÚ Content-type
	files=>[], - ÄÁÎÎÙÅ Ó Conetnt-type

=cut

sub readMultipart{
	my Script $this = shift;
	
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
íÅÔÏÄ ÄÌÑ ÚÁÇÒÕÚËÉ ÆÁÊÌÏ× ÎÁ ÓÅÒ×ÅÒ
Parameters:
	$as - ÉÍÑ ÆÁÊÌÁ ÐÏÄ ËÏÔÏÒÙÍ ÎÁÄÏ ÅÇÏ ÓÏÈÒÁÎÉÔØ 
	$fn - ÉÍÑ ÐÁÒÁÍÅÔÒÁ × ËÏÔÏÒÏÍ ×ÒÉÛ£Ì ÆÁÊÌ
	$dir - ÄÉÒÅËÔÏÒÉÑ ËÕÄÁ ÎÁÄÏ ÓÏÈÒÁÎÉÔØ ÆÁÊÌ
	accept - ÓÐÉÓÏË ÒÁÚÒÅÛ£ÎÎÙÈ ÒÁÓÛÉÒÅÎÉÊ, 

Returns:
	0 - ÕÓÐÅÛÎÏ 
	×Ï ×ÓÑËÉÈ ÄÒÕÇÉÈ ÓÌÕÞÁÑÈ - ÎÅÔ 
=cut

sub upload {
	my Script $this = shift; 
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
		$_SCRIPT = new Script(@_);
	}
	return $_SCRIPT;
}

sub execStep {
	my Script $this = shift;
	my $name = shift;
	return $this->{__STEPS__}->{$name}->do();
}

sub GETVARS {
	return GETSCRIPT()->F();
}

sub _clearRequestData {
	my Script $this = shift;
	$this->{__VARS__} = {};
	GETDB()->commit;
	return 1;
}

sub printCookie {
	my $this = shift;
	my %I = @_;
	if (%{$this->C()->{out}}){
		debug "Cookie data:",\%{$this->C()->{out}};
		foreach my $k (keys %{$this->C->{out}}){
			debug "Cookie key:",$k.'='.$this->C->{out}{$k};
 			print 'Set-Cookie:'.$k.'='.$this->C->{out}{$k}.'; '.($I{$k}{ttl} ? 'expires='.$I{$k}{ttl} : '').' domain=.'.cfg('server.name').'; path=/'."\n";
		}
	}
}

sub showPage {
	my Script $this = shift;
	my ($name,$c) = (shift,shift);
	my $ST = $this->STEPS()->{$name};
	
	$ST->header();
	# put content-page
	debug "---------", cfg('pages.'.$ST->getPage($c));
	unless (my $file = cfg('pages.'.$ST->getPage($c))){
		warn "undefined file in pages.cfg for key: ".cfg('pages.'.$ST->getPage($c));
	}else{
		print $this->out($file);
	}
}

sub read_cookie {
	my $this = shift;
	my $str = $this->E()->{HTTP_COOKIE};
	foreach my $p (split /;\s/, $this->E()->{HTTP_COOKIE}){
		my ($k,$v) = (split /=/, $p);
		$this->C()->{in}{$k} = $v;
	}
}

sub getNextStep{
	my Script $this = shift;
	my $name = shift;
	my $k = shift;
	return $this->{__STEPS__}->{$name}->nextStep($k);
}


1;

