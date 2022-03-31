#!/bin/bash

# Скрипт заливает временные стартовые данные для алгоритма расчета k-индекса
# ./load_start_data.sh  2019-07-05T00:00:00 2019-08-01T00:00:00

date_from=$1
date_to=$2

GET "http://geomag.gcras.ru/intermagnet-webapp/IntermagnetAscii?station=SPG&param=v1;v2;v3;&table=pre_min&timeFrom=$date_from&timeTo=$date_to" | tail -n +2 | cut -d';' -f1-3 | psql -h localhost -d izmiran -U izmiran -c "COPY temp_start_table (date_utc, x, y) from STDIN DELIMITER ';'"
