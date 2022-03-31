#!/bin/bash

while true ;
	do nc -q 1 -l -p 8081 -e /home/alexx/myself/mycode/remote_touch/remote_touch_cgi.pl || continue;
done

