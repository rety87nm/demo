package HttpClient;

# Класс - патч для работы LWP::UserAgent.
# Дополняем метод get таймаутом по alarm.
#
# Example:

=example

	my $browser = HttpClient->new( timeout => 2 );
	my $response = $browser->get("http://220v.ru/");

	if ($response->is_success) {
		print $response->decoded_content;
	} else {
		die $response->status_line;
	}

=cut

use strict;
use utf8;
use warnings;

use parent qw( LWP::UserAgent );

use Try::Tiny;
use HTTP::Response;

sub get {
	my ( $self, $url ) = (@_);

	my $response;

	return try {
		local $SIG{ALRM} = sub { die "TIMEOUT"; };

		alarm $self->timeout();
		$response = $self->SUPER::get($url);
		alarm 0;

		return $response;
	}

	catch {
		return $response ? $response : HTTP::Response( 500, $_ );
	};
}

1;
