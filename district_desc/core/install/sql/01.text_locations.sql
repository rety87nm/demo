begin;
	CREATE sequence comment_id_sec START WITH 1 INCREMENT BY 1;
	create table comment(
		id bigint primary key default nextval('comment_id_sec'),
		-- идентификатор обьеккта
		id_obj bigint not null,
		-- идентификаатор экземпляра
		id_expl bigint not null,
		date timestamp default now(),
		update_date timestamp,
		nleft integer not null,
		nright integer not null,
		level integer not null,
		count integer default 0
	);

	-- так как у нас коментарии расширяемого формата - одному обьекту данного экземпляра соответствует только одна нода дерева.
	create unique index comment_id_tree_label_idx on comment(id_obj,id_expl);
	create index comment_nleft_nright_idx on comment(nleft,nright);
	

	-- таблица с описанием текстовой локации для шахматки дома
	CREATE sequence text_locations_id_sec START WITH 1 INCREMENT BY 1;
	CREATE TABLE text_locations (
		id bigint primary key default nextval('text_locations_id_sec'),
		description varchar(512) not null,
		-- Тег, по которому переходят к этой локации
		tag text not null,
		cdate timestamp default now(),
		mdate timestamp 
	);

	-- заводим узел дерева
	INSERT INTO text_locations (id,tag,description) VALUES (1,'Микрорайон "Лесной"','Справочник-путеводитель по микрорайону. Описание.');
	INSERT INTO comment (id_obj,id_expl,nleft,nright,level,count) VALUES (1,1,1,2,0,0);

	-- дабы не возникло ошибки при старте скрипта загрузки данных:
	select nxtval('text_locations_id_sec');
commit;
