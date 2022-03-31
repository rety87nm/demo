#!/usr/bin/gnuplot -persist
# Файл для отображения столбиков k индексов
current_date=system("psql -h localhost -d izmiran -U izmiran -A -t -F \" \" -c \"select CURRENT_DATE\"")
human_date=system("./human_date.pl \"".current_date."\"")
set terminal pngcairo size 1024,768 enhanced font 'Verdana,10'
set output '../img/k_index_'.current_date.'.png'
set ylabel "K-index" 
set grid ytics
set yrange [0:9]
set xrange [-1:8]
set xtics ("<03" 0, "03-06" 1, "06-09" 2, "09-12" 3, "12-15" 4,"15-18" 5, "18-21" 6, ">21" 7)
set style data boxes 
set boxwidth 0.9 absolute
set style fill solid 1
set palette model RGB defined (0 "green", 1 "green", 2 "green", 3 "yellow", 4 "orange", 5 "red", 6 "red", 7 "red", 8 "red", 9 "red")
set cbrange [0:9] 
set title "Индекс магнитного возмущения ".human_date." "  font ",14"
plot "<psql -h localhost -d izmiran -U izmiran -x -A -t -F \" \" -c \"select date_utc, var2kidx(t0_3) as k0_3, var2kidx(t3_6) as k3_6, var2kidx(t6_9) as k6_9, var2kidx(t9_12) as k9_12, var2kidx(t12_15) as k12_15, var2kidx(t15_18) as k15_18, var2kidx(t18_21) as k18_15, var2kidx(t21_0) as k21_0 from variations_by_day where date_utc='".current_date."'\" | tail -n +2" using 0:2:2 with boxes palette title "" 
