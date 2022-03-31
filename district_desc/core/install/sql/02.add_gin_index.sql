begin;
	-- для триграммов надо установить расшитрение 

	-- # CREATE EXTENSION pg_trgm;
	-- # CREATE EXTENSION btree_gist;

	-- Так как в описание нужно будет добавлять html код, размер нужно увеличить:
	ALTER TABLE text_locations ALTER COLUMN description TYPE text;

	-- для поиска по описанию создаём индекс для текстового поиска:

	CREATE INDEX text_locations_desc_trgm_idx ON text_locations USING gist (description gist_trgm_ops);
	CREATE INDEX text_locations_tag_trgm_idx ON text_locations USING gist (tag gist_trgm_ops);

	-- для определения обновлений создаём индексы по времени модификации:
	CREATE INDEX text_locations_cdate_idx ON text_locations (cdate);
	CREATE INDEX text_locations_mdate_idx ON text_locations (mdate);

	-- Example:
	-- 
    SELECT tag, description, similarity(tag, 'стаматалогия') AS sml FROM text_locations  WHERE tag % 'стаматалогия' ORDER BY sml DESC;

commit;
