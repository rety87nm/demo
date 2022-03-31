#!/usr/bin/perl -w

#  Повернуть экран на 90 если он занял горизонтальную ориентацию
#  adb shell settings put system user_rotation 1

# Выключить переднее приложение:
# adb shell "dumpsys activity | grep top-activity"
# db shell am force-stop <PACKAGE> 

# Скрипт cgi обертка для скрипта удаленного управления remote_touch.pl
use strict;
use Time::HiRes qw(usleep nanosleep);

my $file_png = "/tmp/rt/screen.png";
$| = 1;

my $str = <STDIN>;

exit unless $str;

open(LOG,">>","log_cgi") or die "Can't open logfile";

my ($x,$y);
my $cmd;

if ( $str =~ /^GET\s\/\?(\d+),(\d+)\sHTTP.*$/ ){
    ($x,$y) = ($1, $2);
}elsif( $str =~ /^GET\s\/\?cmd=(\w+)\sHTTP.*$/ ){
    $cmd = $1;
}

my ($mpath, $lpath) = ("/sdcard/rt", "/tmp/rt");

print LOG "RECEIFED STRING: ".$str."\n";

if (defined $x && defined $y){
	print LOG "x:".$x."\ty:".$y;
	print LOG "\n";
}

if (defined $cmd){
	print LOG "command: ".$cmd;
	print LOG "\n";
}

if ( $x && $y ){
    # touch command
    print LOG "Push tap on width: $x and height: $y\n";

	`adb shell input tap $x $y`;
    usleep 500;

	# редирект на чистый урл:
    print_redirect_header("/remote_touch/");
	exit;
}

if ( defined $cmd && $cmd ne "" ){
    if ( $cmd eq 'close_top'){
        print LOG "They wannt execute command close_top\n";
        close_top();
    }elsif( $cmd eq 'swipe_right' ){
        print LOG "They wannt execute command swipe right\n";
        swipe_right();
		usleep (300);
	}elsif ( $cmd eq 'swipe_left' ){
	    print LOG "They wannt execute command swipe left\n";
        swipe_left();
		usleep (300);
	}

	print_redirect_header("/remote_touch/");
	exit;
}

make_shot();

print_page();

close LOG;
exit;

sub print_page {

    print "HTTP/1.1 200\r\n";
    print "Content-Type: text/html; charset=UTF-8\r\n";

    my $html = <<'HTML';

<!DOCTYPE html>
<html>
   <head>
      <title>Remote device screen</title>
   </head>
   <body>
      <a href = "/remote_touch" target="_self"> 
         <img ismap src="/remote_touch/screen.png" alt="Android screen" border="0"/> 
      </a>
	  <div>
		 <p style="font-size:3em;" ><a href="/remote_touch/?cmd=close_top">Закрыть верхнее приложение</a></p>
		 <p style="font-size:3em;" ><a href="/remote_touch/?cmd=swipe_left"><--</a> | <a href="/remote_touch/?cmd=swipe_right">--></a></p>
	  </div>
   </body>
</html>
HTML

    my $body_length = ( length($html)-1 );

    print "Content-length: ".$body_length."\r\n";
    print $html;
}

sub make_shot {
	# Делаем скриншот
	`adb shell input keyevent KEYCODE_WAKEUP`;
	`adb shell mkdir -p $mpath`;
	`adb shell screencap $mpath/screen.png`;

	# Забираем png со смартфона:
	`mkdir -p $lpath`;
	`adb pull $mpath/screen.png $lpath/screen.png`;
}

# Закрыть приложение которое находится сверху.
sub close_top {
	`adb shell input keyevent KEYCODE_WAKEUP`;
	
	# Может быть несколько активити верхнего уровня.
	my $str = `adb shell "dumpsys activity | grep top-activity"`;
	my @t_acts = split ("\n", $str);

	print LOG "TOP APPLICATIONS:\t".$str."\n";

	#	15444:com.google.android.googlequicksearchbox:search/u0a113

	#	perl -e 'my $cmd = `adb shell "dumpsys activity | grep top-activity"`; my @s =  (split "\n", $cmd); print $cmd; print $#s."\n";'
	foreach ( @t_acts ){
		my ($appid) = ($_ =~ /\d+\:([\w\.]+).*\/\w+\s/);
		if ($appid ne ""){
			print LOG "Top application found:|".$appid."| Kill him.\n";
			`adb shell am force-stop $appid`;
		}
	}
}

sub swipe_right {
	# свайп на правый экран
	my ($xs,$ys,$xe,$ye,$t) = (837, 1045, 312, 1045, 300);
	`adb shell input swipe $xs $ys $xe $ye $t`;
}

sub swipe_left {
	# свайп на левый экран
	my ($xs,$ys,$xe,$ye,$t) = (312, 1045, 837, 1045, 300);
	`adb shell input swipe $xs $ys $xe $ye $t`;
}

sub print_redirect_header {
    my $url = shift;
    # редирект на чистый урл:
	print "HTTP/1.1 302 Found\r\n";
	print "Location: $url\r\n";
	print "\r\n";
}
