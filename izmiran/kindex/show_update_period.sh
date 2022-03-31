#!/bin/bash

# Скрипт возвращает строку формата [date_from] [date_to] - период за который в базе нет данных

psql -h localhost -d izmiran -U izmiran -F " " -A -t -c "select overlay( (date_utc + interval '1 minute')::text placing 'T' from 11 for 1 ) as from_date, concat(LOCALTIMESTAMP(0)::date,'T',LOCALTIMESTAMP(0)::time) as to_date from mag_variations_spg order by date_utc desc limit 1;"

