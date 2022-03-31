#!/usr/bin/gnuplot -persist
variations_data="<psql -h localhost -d izmiran -U izmiran -A -t -F \" \" -c \"select overlay( date_utc::text placing 'T' from 11 for 1 ), x, y, z from mag_variations_spg where date_utc::date = CURRENT_DATE order by date_utc\""
current_date=system("psql -h localhost -d izmiran -U izmiran -A -t -F \" \" -c \"select CURRENT_DATE\"")
human_date=system("./human_date.pl \"".current_date."\"")
set xdata time
set timefmt "%Y-%m-%dT%H:%M:%S"
set format x "%H:%M:%S" 
set terminal pngcairo size 1024,768 enhanced font 'Verdana,10'
set output '../img/var_XYZ_'.current_date.'.png'
set multiplot layout 3, 1 title "Вариации магнитного поля земли за ".human_date." " font ",14"
set grid
set tmargin 3
set ylabel "nT" rotate by 0
set xrange [current_date.'Т00:00:00':current_date.'T23:59:59']
#
set title "SPG X"
set yrange [14478:14494]
unset key
plot variations_data using 1:2 with lines lt 4,
#
set title "SPG Y"
set yrange [2710:2724]
unset key
plot variations_data using 1:3 with lines lt 3,
#
set title "SPG Z"
unset key
set yrange [50400:50407]
plot variations_data using 1:4 with lines lt 2
unset multiplot
