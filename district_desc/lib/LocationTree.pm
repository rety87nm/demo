package LocationTree;

=nd
Class: Класс для работы с локациями шахматки
Локация - описание фрагмента местности отмеченный единственным тегом.
Нода - Системная часть локации описывающая отношения одной локации по отношению другой в виде дерева.

=cut

use strict;
use vars qw(@ISA );
use Comments;
use Error;

@ISA = qw(Comments);

=nd
Конструктор класса.
Example: my $LT = new LocationTree(db=>$DB);

=cut 

sub new {
	my $class = shift;
	my $this = $class->SUPER::new(db=>undef,@_,obj_id=>1);
	return $this;
}

=nd
 Сохранить локацию
	$LT->save($tag, $text, $parrent);
	$tag - тэг, по которому осуществляется переход на данный узел
	$text - текст описания
	$parent - узел дерева, идентификатор обьекта а не узла 
=cut

sub save {
	my $class = shift;
	my $tag = shift;
	my $text = shift;
	my $parrent_location_id = shift || undef;
	
	unless ($parrent_location_id){
		# Родительской ноды нет, выбираем её
		 $parrent_location_id = $class->get_topic_id();
	}

	# сохраняем для начала само описание обьекта:
	my $lt_id =  $class->db->nextval('text_locations_id_sec');
	
	# TODO проверка аргументов на типы

	$class->db->do('INSERT INTO text_locations  (id, description, tag) VALUES (?,?,?)',undef,$lt_id,$text,$tag);

	# встраиваем этот экземпляр в дерево:
	if ($class->SUPER::save_comment($lt_id, prev_id=>$parrent_location_id)){
		return  $lt_id;
	}else{
		return undef;
	}
}

# в случае если не задан узел дерева - выгружаем верхнюю ноду:
sub get_topic_id {
	my $class = shift;
	my $topic = $class->db->getList('select id_expl from comment where nleft  = 1 and level = 0 and id_obj = ?',$class->obj_id());
	return $topic->[0]{id_expl}; 
}

=nd
Выгрузить список локация для редактирования
date_from - дата изменения с 
date_to - дата изменения по
=cut

sub list {
	my $class = shift;
	my %I = (date_from=>undef,date_to=>undef,between=>{l=>undef,r=>undef},@_);
	my %QC = (
		F=>['tl.*', 'c.nleft', 'c.nright', 'c.level'],
		T=>['comment as c,', 'text_locations as tl' ],
		W=>['tl.id = c.id_expl','c.id_obj = 1'],
		O=>'order by c.nleft'
	);
	my @P = ();
	if (defined $I{date_from}){
		push @{$QC{W}},'(tl.mdate > ? OR (tl.mdate is null and  tl.cdate > ?))';
		push @P,$I{date_from};
		push @P,$I{date_from};
	}

	if (defined $I{between}{l} && defined $I{between}{r}){
		push @{$QC{W}}, 'c.nleft >= ?';
		push @{$QC{W}}, 'c.nright <= ?';
		push @P,$I{between}{l};
		push @P,$I{between}{r};
	}
	my $Q = 'select '.(join ",",@{$QC{F}}).' FROM '.(join " ", @{$QC{T}}).' WHERE '.(join " and ",@{$QC{W}}).' '.$QC{O};
	debug $Q;

	return $class->db->getList($Q,@P);
}

=nd
	Выгрузить одну локацию для просмотра
	$id - идентификатор локации
=cut

sub record {
	my $class = shift;
	my $id = shift;
	my $data = $class->db->getRecord('select tl.id as id_text, tl.description, tl.tag, COALESCE(tl.mdate,tl.cdate) as date, c.id  as node_id, c.nleft, c.nright, c.level from text_locations as tl, comment as c where tl.id = c.id_expl and c.id_obj = 1 and tl.id = ?',$id);
	return $data;
}

=nd
	Удаление узла комментария:
=cut

sub deleteNode {
	my $class = shift;
	my $id = shift;

	# выбираем идентификатор коментария по идентификатору обьекта:
	my $loc_data = $class->record($id);
		
	# удаляется комментарий, дочерние перемещаются на уровень выше.
	$class->SUPER::del_comment($loc_data->{node_id});

	# Удаляем локацию
	$class->db->do('delete from text_locations where id = ?',undef,$id);
	return 1;
}

=nd
	получить данные для построения хлебных крошек
=cut

sub getBreadCrumbs{
	my $class= shift;
	my $id = shift;
	my %I = (nleft=>undef,nright=>undef,@_);
	my $data = [];
	$data = $class->db->getList('select tl.id, tl.tag, c.nleft, c.nright, c.level from comment as c, text_locations as tl where tl.id = c.id_expl and c.id_obj = 1 and c.nleft <= ?  and c.nright >= ? order by c.nleft',$I{nleft},$I{nright});
	return $data;
}

=nd
	Выгрузить дочерние теги и локации 
	nleft - левый ключ ноды
	nright - правый, из интервала.
	level - уровень, на котором выгружать тэги
=cut

sub loadTags {
	my $class = shift;
	my %I = (nleft=>undef,nright=>undef,level=>undef,hl_ids=>[],@_);
	my $tags = [];
	if (@{$I{hl_ids}}){
		# переданы новые ids, отмечаем все родительские ноды:
		$tags = $class->db->getList('select tl.id, tl.tag, c.nleft, c.nright, c.level, T.hl from comment as c, text_locations as tl LEFT JOIN ( select count(*) as hl, tl.id, tl.tag, c.nleft, c.nright, c.level from comment as c, text_locations as tl, comment as c1 where c1.id_expl IN ('.(join ",",@{$I{hl_ids}}).') and tl.id = c.id_expl and c.id_obj = 1 and c.nleft <= c1.nleft  and c.nright >= c1.nright group by tl.id, tl.tag, c.nleft, c.nright, c.level) as T ON T.id = tl.id where tl.id = c.id_expl and c.id_obj = 1 and c.nleft > ?  and c.nright < ? and c.level = ? order by c.nleft' ,$I{nleft},$I{nright},$I{level}+1);
	}else{
		$tags = $class->db->getList('select tl.id, tl.tag, c.nleft, c.nright, c.level from comment as c, text_locations as tl where tl.id = c.id_expl and c.id_obj = 1 and c.nleft > ?  and c.nright < ? and level = ? order by c.nleft',$I{nleft},$I{nright},$I{level}+1);
	}

	debug $tags;
	return $tags;
}

1;
