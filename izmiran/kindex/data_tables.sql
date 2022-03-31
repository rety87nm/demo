begin;
	-- Данные геомагнитных обсерваторий
	CREATE table mag_variations_SPG (
		-- универсальное время
		date_utc timestamp PRIMARY KEY NOT NULL,
		-- X компонента
		X numeric NOT NULL,
		-- Y компонента
		Y numeric NOT NULL,
		-- Z компонента
		Z numeric,
		-- H горизонтальная компонента sqrt(X^2+Y^2)
		H numeric NOT NULL,
		-- D = H - SR (Текущее измерение с вычетом регулярного солнечного возмущения) 
		D numeric NOT NULL
	);

	CREATE INDEX mag_variations_spg_date_utc_date_idx ON public.mag_variations_spg ( (date_utc::date) );
	CREATE INDEX mag_variations_spg_date_utc_date_time_idx ON public.mag_variations_spg ( (date_utc::date), (date_utc::time) );

	-- Функция обновляет значение горизонтальной компоненты при изменении 
	-- или добавления значения X или Y в таблицу.
	create or replace function calculate_h ()
	returns trigger language plpgsql as $$
	begin
		IF ( TG_OP = 'INSERT' ) THEN
			NEW.h := sqrt( NEW.x^2 + NEW.y^2 )::numeric(10,4);
		ELSE 
			IF NEW.x <> OLD.x OR NEW.y <> OLD.y THEN
				NEW.h := sqrt( NEW.x^2 * NEW.y^2 )::numeric(10,4);
			END IF;
		END IF;
		return NEW;
	end $$;

	CREATE TABLE temp_start_table (
		date_utc timestamp PRIMARY KEY NOT NULL,
		X numeric NOT NULL,
		Y numeric NOT NULL,
		H numeric NOT NULL
	);

	-- триггер на подсчет H стартовой таблицы
	create trigger trg_insert_start_table before insert or update
		on public.temp_start_table for each row execute procedure calculate_h();

	-- Усредненные солнечные вариации. усредненное значение H по 5 геомагнитно спокойным
    -- из 27 предыдущих суток.
	CREATE TABLE sr_variations (
		-- универсальное время
		time time PRIMARY KEY NOT NULL,
		-- Усредненное значение солнечной регулярной компоненты за 5 спокойных дней
		SR numeric not null
	);

	CREATE INDEX sr_variations_time_idx ON sr_variations USING hash (time);
	
	-- Статистика магнитного возмущения по дням. 
	-- Возмущение: max(mag_var.D) - min(mag_var.D) 
	CREATE TABLE variations_by_day (
		-- День 
		date_utc date PRIMARY KEY NOT NULL,
		-- D - максимальное магнитное возмущение за день по данной обсерватории
		D numeric NOT NULL default 0,
		-- t0_3 максимальное магнитное возмущение за период с 0 до 03:00
		t0_3 numeric NOT NULL default 0,
		t3_6 numeric NOT NULL default 0,
		t6_9 numeric NOT NULL default 0,
		t9_12 numeric NOT NULL default 0,
		t12_15 numeric NOT NULL default 0,
		t15_18 numeric NOT NULL default 0,
		t18_21 numeric NOT NULL default 0,
		t21_0  numeric NOT NULL default 0
	);

	CREATE INDEX variations_by_day_d_idx ON variations_by_day USING btree (d); 
	
	-- Удаляем temp table за ненадобностью
	-- DROP TABLE temp_start_table

	-- Функция для вычисления горизонтальной составляющей H 
	-- Магнитной вариации D непосредственно в момент измерения
	-- И дневных солнечных вариаций

	create or replace function calculate_sr_h_d ()
	returns trigger language plpgsql as $$
	begin
		-- Если пошли новые сутки - пересчитываем данные таблицы sr_variations
		perform * from mag_variations_SPG where date_utc::date = NEW.date_utc::date limit 1;

		IF NOT found THEN
			update sr_variations set sr = T.sr from (select mv.date_utc::time, (sum(mv.h)/count(mv.h))::numeric(10,4) as sr from (select vd.date_utc from variations_by_day as vd where vd.date_utc >= (NEW.date_utc::date - interval '27 days') order by vd.d limit 5) as calmer_day, mag_variations_spg as mv where mv.date_utc::date = calmer_day.date_utc group by mv.date_utc::time order by mv.date_utc::time) as T where T.date_utc = time;
		END IF;

		-- Вычисляем горизонтальную компоненту H
		IF ( TG_OP = 'INSERT' ) THEN
			NEW.h := sqrt( NEW.x^2 + NEW.y^2 )::numeric(10,4);
		ELSE 
			IF NEW.x <> OLD.x OR NEW.y <> OLD.y THEN
				NEW.h := sqrt( NEW.x^2 * NEW.y^2 )::numeric(10,4);
			END IF;
		END IF;
		
		-- Вычисляется D как вычитание солнечной регулярной вариации
		-- из величины текущей горизонтальной составляющей
		select NEW.h - sv.sr INTO NEW.D from sr_variations as sv where sv.time = NEW.date_utc::time;

		return NEW;
	end $$;

	create trigger trg_insert_mag_variations_SPG before insert or update
		on public.mag_variations_SPG for each row execute procedure calculate_sr_h_d();

	-- Функция обновления данных по статистике вариаций за день:
	create or replace function update_day_variations ()
	returns trigger language plpgsql as $$
	declare
		-- величина вариаций за день
		d_var numeric(10,4);
		-- величина вариация за трехчасовые интервалы:
		d_var_0_3 numeric(10,4);
		d_var_3_6 numeric(10,4);
		d_var_6_9 numeric(10,4);
		d_var_9_12 numeric(10,4);
		d_var_12_15 numeric(10,4);
		d_var_15_18 numeric(10,4);
		d_var_18_21 numeric(10,4);
		d_var_21_0 numeric(10,4);
		var_by_day_row variations_by_day%ROWTYPE;
	begin
		select (max(d) - min(d)) into d_var from mag_variations_spg where date_utc::date = NEW.date_utc::date group by date_utc::date;

		select (max(d)-min(d)) into d_var_0_3 from mag_variations_spg where date_utc::date = NEW.date_utc::date and  date_utc::time < '03:00';

		select (max(d)-min(d)) into d_var_3_6 from mag_variations_spg where date_utc::date = NEW.date_utc::date and date_utc::time >= '03:00' and date_utc::time < '06:00';

		select (max(d)-min(d)) into d_var_6_9 from mag_variations_spg where date_utc::date = NEW.date_utc::date and date_utc::time >= '06:00' and date_utc::time < '09:00';

		select (max(d)-min(d)) into d_var_9_12 from mag_variations_spg where date_utc::date = NEW.date_utc::date and date_utc::time >= '09:00' and date_utc::time < '12:00';

		select (max(d)-min(d)) into d_var_12_15 from mag_variations_spg where date_utc::date = NEW.date_utc::date and date_utc::time >= '12:00' and date_utc::time < '15:00';

		select (max(d)-min(d)) into d_var_15_18 from mag_variations_spg where date_utc::date = NEW.date_utc::date and date_utc::time >= '15:00' and date_utc::time < '18:00';

		select (max(d)-min(d)) into d_var_18_21 from mag_variations_spg where date_utc::date = NEW.date_utc::date and date_utc::time >= '18:00' and date_utc::time < '21:00';

		select (max(d)-min(d)) into d_var_21_0 from mag_variations_spg where date_utc::date = NEW.date_utc::date and date_utc::time >= '21:00';

		select * into var_by_day_row from variations_by_day where date_utc = NEW.date_utc::date;

		IF NOT found THEN
			insert into variations_by_day (date_utc, d, t0_3, t3_6, t6_9, t9_12, t12_15, t15_18, t18_21, t21_0) VALUES (NEW.date_utc::date, d_var, coalesce(d_var_0_3,0), coalesce(d_var_3_6,0), coalesce(d_var_6_9,0), coalesce(d_var_9_12,0), coalesce(d_var_12_15,0), coalesce(d_var_15_18,0), coalesce(d_var_18_21,0), coalesce(d_var_21_0,0));
		ELSE
			-- обновляем максимальное возмущение за день 
			-- если предыдущее значение было меньше
			IF var_by_day_row.d < d_var THEN
				update variations_by_day set d = d_var where date_utc = NEW.date_utc::date;
			END IF;

			IF var_by_day_row.t0_3 < d_var_0_3 THEN 
				update variations_by_day set t0_3 = d_var_0_3 where date_utc = NEW.date_utc::date;
			END IF;

			IF var_by_day_row.t3_6 < d_var_3_6 THEN 
				update variations_by_day set t3_6 = d_var_3_6 where date_utc = NEW.date_utc::date;
			END IF;

			IF var_by_day_row.t6_9 < d_var_6_9 THEN 
				update variations_by_day set t6_9 = d_var_6_9 where date_utc = NEW.date_utc::date;
			END IF;

			IF var_by_day_row.t9_12 < d_var_9_12 THEN 
				update variations_by_day set t9_12 = d_var_9_12 where date_utc = NEW.date_utc::date;
			END IF;

			IF var_by_day_row.t12_15 < d_var_12_15 THEN 
				update variations_by_day set t12_15 = d_var_12_15 where date_utc = NEW.date_utc::date;
			END IF;

			IF var_by_day_row.t15_18 < d_var_15_18 THEN 
				update variations_by_day set t15_18 = d_var_15_18 where date_utc = NEW.date_utc::date;
			END IF;

			IF var_by_day_row.t18_21 < d_var_18_21 THEN 
				update variations_by_day set t18_21 = d_var_18_21 where date_utc = NEW.date_utc::date;
			END IF;

			IF var_by_day_row.t21_0 < d_var_21_0 THEN 
				update variations_by_day set t21_0 = d_var_21_0 where date_utc = NEW.date_utc::date;
			END IF;

		END IF;

		return NEW;
	end $$;
	
	create trigger trg_after_insert_mag_variations_SPG after insert or update
		on public.mag_variations_SPG for each row execute procedure update_day_variations();

	-- Функция преобразует отклонение в индекс для SPB
	create or replace function var2kidx(var numeric) returns integer AS $$
	begin
		return	CASE 
				 WHEN var < 8 THEN 0
				 WHEN var >= 8 and var < 15 THEN 1
				 WHEN var >= 15 and var < 30 THEN 2
				 WHEN var >= 30 and var < 60 THEN 3
				 WHEN var >= 60 and var < 105 THEN 4
				 WHEN var >= 105 and var < 180 THEN 5
				 WHEN var >= 180 and var < 300 THEN 6
				 WHEN var >= 300 and var < 500 THEN 7
				 WHEN var >= 500 and var < 750 THEN 8
				 WHEN var >= 750 THEN 9
				END;
	end;
	$$ LANGUAGE plpgsql;

commit;

begin 
	-- Вспомогательные запросы которые необходимы в дальнейшем для алгоритма:

	-- Заполняем в ручную таблицы is_calm_day и temp_start_table
	-- psql -h localhost -d izmiran -U izmiran -c "COPY temp_start_table (date_utc, x, y) from STDIN DELIMITER ';'" < start_data.cvs
	--  insert into variations_by_day (date_utc) values ('2019-07-28'); 5 записей.

	-- Заполняем sr_variations стартовым днем:
	-- insert into sr_variations (select st.date_utc::time, (sum(st.h)/count(st.h))::numeric(10,4) as sr from temp_start_table as st, variations_by_day as id where id.date_utc >= (NOW() - interval '27 days')::date and id.date_utc = st.date_utc::date group by st.date_utc::time order by st.date_utc::time);
--запрос для отображения K индексов
--select date_utc, var2kidx(t0_3) as k0_3, var2kidx(t3_6) as k3_6, var2kidx(t6_9) as k6_9, var2kidx(t9_12) as k9_12, var2kidx(t12_15) as k12_15, var2kidx(t15_18) as k15_18, var2kidx(t18_21) as k18_15, var2kidx(t21_0) as k21_0 from variations_by_day where date_utc='2019-08-20'

rollback;
