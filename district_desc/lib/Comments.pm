package Comments;
# класс для работы с Комментариями

sub new {
	my $class = shift;
	my $this = {
		obj_id=>undef,
		db=>undef,
		@_
	};
	bless $this,$class;
	return $this;
}

# сохранение коментария 
sub save_comment {
	$class = shift;
	my $obj_id = $class->{obj_id};
	my $ex_id = shift;
	my %O = (prev_id=>undef,@_);

	# выбираем данные по предыдущему узлу:
	my $pd = $class->db->getList('select id, id_obj, id_expl, nleft, nright, level, count from comment where id_obj = ? and  id_expl = ?',$class->obj_id(),$O{prev_id});

	# подсчёт нового узла:
	my $C = {};
	$C->{nleft} = $pd->[0]{nright};
	$C->{nright} = $pd->[0]{nright}+1;
	$C->{level} = $pd->[0]{level}+1;
	$C->{count} = ($pd->[0]{nright} - $pd->[0]{nleft} + 1)/2 + $pd->[0]{count};

	# блокируем дерево на время редактирования:
	$class->db->do("SELECT id FROM comment WHERE id_expl = ? AND id_obj = ? FOR UPDATE",undef,$ex_id ,$obj_id);

	my $nid = $class->db->nextval('comment_id_sec');	
	$class->db->do('INSERT INTO comment (id,id_obj,id_expl,level,count,nleft,nright) VALUES (?,?,?,?,?,?,?)',undef,$nid, $obj_id,$ex_id,$C->{level}, $C->{count},$C->{nleft},$C->{nright});

	# обновление соседних ветвей
	$class->db->do("UPDATE comment SET nright = nright+2,nleft = nleft+2,count = count+1 WHERE nleft > ? AND nright >= ? AND id_obj = ?",undef,$pd->[0]{nright},$pd->[0]{nright}, $obj_id);

	# обновление своей ветви	
	$class->db->do("UPDATE comment SET nright = nright+2 WHERE nleft < ? AND  nright >= ? AND id_obj = ? ",undef,$pd->[0]{nright}, $pd->[0]{nright}, $obj_id);

	return $nid;
}

# удаление комантария
sub del_comment {
	my $class = shift;
	my $id = shift;
	my $obj_id = $class->{obj_id};

	# получаем данные по узлу:
	my $cn = $class->db->getList('select id, id_obj, id_expl, nleft, nright, level, count from comment where id = ?',$id);

	# обновляем ключи:
	$class->db->do("update comment set nleft = nleft-1, nright = nright -1, level = level- 1 where nleft > ? and nright  < ? and id_obj = ?",undef,$cn->[0]{nleft},$cn->[0]{nright},$obj_id);

	# обновляем всё что выше по дереву
	$class->db->do("update comment set nleft = case when nleft > ? then nleft - 2 ELSE nleft END, nright = case when nright > ? then nright - 2 ELSE nright END where id_obj = ?",undef,$cn->[0]{nleft},$cn->[0]{nright},$obj_id);

	$class->db->do("delete from comment where id = ? ",undef,$id);
	return 1;
}

# перенос узла коментария
sub chg_comment {
	my $class = shift;
	return 1;
}

sub db {
	my $class = shift;
	return $class->{db};
}

sub obj_id {
	my $class = shift;
	return $class->{obj_id};
}

1;
