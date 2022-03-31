#!/bin/bash

# Скрипт дополняет данные по магнитометрии с момента последнего обновления

# ./load_data_to_db.sh 2019-07-05T00:00:00 2019-08-01T00:00:00

# Может использоваться совместно с show_update_peiod.sh:
# ./load_data_to_db.sh `./show_update_period.sh`

date_from=$1
date_to=$2

echo "Download and load data from $date_from to $date_to period."

GET "http://geomag.gcras.ru/intermagnet-webapp/IntermagnetAscii?station=SPG&param=v1;v2;v3;&table=pre_min&timeFrom=$date_from&timeTo=$date_to" | tail -n +2 | cut -d';' -f1-4 | psql -h localhost -d izmiran -U izmiran -c "COPY mag_variations_spg (date_utc, x, y, z) from STDIN DELIMITER ';'"
