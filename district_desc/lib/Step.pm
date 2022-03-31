package Step;

=nd
Class: Step
	Примитивное действие.

=cut

use strict;
use vars qw(@ISA @EXPORT $VERSION);
use Exporter;
use Data::Dumper;
use Cfg;
use CGI;
use vars qw/ %ENV /;
@ISA = qw(Exporter);
@EXPORT = qw/OK/; 

sub new {
	my $class = shift;
	my $n = shift;

	my $this = {
		'NEXT'=>{},
		'OUT_OPTIONS'=>{},
		'DO'=>sub {return 'PAGE'},
		@_
	};
	$this->{NAME} = $n;
	bless $this,$class;
	return $this;
}

sub header {
	my Step $this = shift;
	my $R = new CGI();
	print $R->header(-type=>cfg('step.default.contenttype','text/html'),
					 -charset=>cfg('step.default.charset','utf-8'),%{$this->getOptions()});
}

sub name {
	my Step $this = shift;
	return $this->{NAME};
}

sub do {
	my Step $this = shift;
	return $this->{DO}->();
}

sub getPage {
	my Step $this = shift;
	my $k = shift;
	my $i = $this->{NEXT};
	for (split /\./,$k){
		$i = $i->{$_};
	}
	return $i;
}

sub getOptions {
	my Step $this = shift;
	return $this->{OUT_OPTIONS};
}

=nd
Method: Получить наименование следующего шага, в случае когда исход текущего требует не страницы
=cut

sub nextStep{
	my Step $this = shift;
	my $k = shift;
	my $i = $this->{NEXT};
	for (split /\./,$k){
		$i = $i->{$_};
	}
	return $i;
}

1;
