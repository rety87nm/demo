#!/usr/bin/gnuplot -persist
current_date=system("psql -h localhost -d izmiran -U izmiran -A -t -F \" \" -c \"select CURRENT_DATE\"")
human_date=system("./human_date.pl \"".current_date."\"")
set xdata time
set timefmt "%H:%M:%S"
set format x "%H:%M:%S" 
set terminal pngcairo size 1024,768 enhanced font 'Verdana,10'
set output "../img/H_calmer_day.png"
set grid
set xrange ["00:00:00":"23:59:59"]
set yrange [14710:14760]
set ylabel "nT" rotate by 0
set title "Вариации по магнитоспокойным дням ".human_date." "  font ",14"
set multiplot
plot "<psql -h localhost -d izmiran -U izmiran -A -t -F \" \" -c \"select date_utc::time, h from mag_variations_spg where date_utc::date = CURRENT_DATE order by date_utc::time\"" using 1:2 with lines lt 7 ti "Значение H в данный момент", "<psql -h localhost -d izmiran -U izmiran -A -t -F \" \" -c \"select * from sr_variations order by time\"" using 1:2 with lines lt 6 ti "Значение H магнитоспокойных дней"
unset multiplot
