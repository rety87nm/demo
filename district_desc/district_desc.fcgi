#!/usr/bin/perl -w

use strict;
use lib qw|./lib |;
use utf8;
use Script;
use DateTime;
use LocationTree;
use Util;
use Error;
use Step;

# получаем новый экземпляр Script
my $S = GETSCRIPT(name=>'district_desc');

# добавляем шаг скрипта показывающий полную карту редактирования 
$S->addStep(new Step('EDIT',
		# ветка с иструкциями что идёт последующим этапом после выполнения DO
		# если DO возвращает step - следующим этапом осуществляется переход на шаг REMINDER_OK
		# ecли DO возвращает page - следует выдача контента страницы welcome
		NEXT=>{'page'=>'district_desc.edit','step'=>'REMINDER_OK'},
		# опции вывода контента, передаются аргументом в функцию CGI->header
		OUT_OPTIONS=>{-type=>'text/html'},
		DO=>sub{
			my $F = GETVARS();
			my $C = $S->C;
			my $LT = new LocationTree(db=>GETDB());

			my $top = {};
			if (exists $C->{in}{_cur_id} && $C->{in}{_cur_id} =~ /^\d+$/){
				# редактирование начинаем с последней локации, если она есть в cookie:
				$top = $LT->record($C->{in}{_cur_id});
			}

			$F->{LIST_ITEMS} = $LT->list((%$top ? (between=>{l=>$top->{nleft},r=>$top->{nright}}) : () ));
			
			# переменная для компенсации сдвига.
			$F->{start_level} = $F->{LIST_ITEMS}[0]{level};
			debug "start_level";

			debug "DATA::",$F->{LIST_ITEMS};
			return 'step' if (exists $F->{email} && $F->{email} eq 'kurbatov@ani-project.org');
			return 'page';
		}
	)
);


$S->addStep(new Step('NEW',
		NEXT=>{'page'=>'district_desc.edit',step=>'EDIT'},
		OUT_OPTIONS=>{-type=>'text/html'},
		DO=>sub{
			my $F = GETVARS();
			my $LT = new LocationTree(db=>GETDB());

			unless (exists $F->{in}{tag} && $F->{in}{tag} ne '' ){
				$F->{error} = {
					text=>"Тег пуст. Нужно точно указывать тег для привязки описания."
				};
				return 'step';
			}

			unless (exists $F->{in}{description} && $F->{in}{description} ne '' ){
				$F->{error} = {
					text=>'Заполните описание.'
				};
				return 'step';
			}

			my $id =  $LT->save($F->{in}{tag}, $F->{in}{description}, $F->{in}{pid});
			debug "New node id:",$id;
			$S->redirect('/?add_ok='.$id.'&c=edit#form_'.$id);
			return 'stop';
		}
	)
);

$S->addStep(new Step('UPDATE',
		NEXT=>{'page'=>'district_desc.edit',step=>'EDIT'},
		OUT_OPTIONS=>{-type=>'text/html'},
		DO=>sub{
			my $F = GETVARS();
			if ($F->{in}{description} eq '' ){
				$F->{error} = {
					id=>$F->{in}{id},
					text=>"Пустое описание не информативно."
				};
				return 'step';
			}

			if ($F->{in}{tag} eq ''){
				$F->{error} = {
					id=>$F->{in}{id},
					text=>"нельзя удалить тег у существующего описания."

				};
				return 'step';
			}

			GETDB()->do('update text_locations set description = ?, tag = ?, mdate = now() where id = ?',undef, $F->{in}{description}, $F->{in}{tag}, $F->{in}{id});	
		
			debug "Changed node id:",$F->{in}{id};
			$S->redirect('/?edit_ok='.$F->{in}{id}.'&c=edit#form_'.$F->{in}{id});
			return 'stop';
		}
	)
);

# Показ единственной локации
$S->addStep(new Step('SHOW',
		NEXT=>{'page'=>'district_desc.play'},
		OUT_OPTIONS=>{-type=>'text/html'},
		DO=>sub {
			my $F = GETVARS();
			my $C = $S->C;
			my $LT = new LocationTree(db=>GETDB(),obj_id=>1);

			# При каждом просмотре обновляем ему метку времени
			$C->{out} = {};
			$C->{out}{_last_date} = NOW();
			debug "Last view Date:", $C->{out}{_last_date};

			# если в cookie есть последнее положение - перемещаемся туда:
			unless ($F->{in}{id} && $F->{in}{id} =~ /^\d+$/){
				unless ($C->{in}{_cur_id} && $C->{in}{_cur_id} =~ /^\d+$/){
					# нет в куках информации куда перемещаться - переходим в корень
					$F->{in}{id} = $LT->get_topic_id();
				}else{
					# переходим на сохраненный.
					$F->{in}{id} = $C->{in}{_cur_id};
				}
			}

			my $data = $LT->record($F->{in}{id});

			unless (%$data){
				# данных по этому id нет. отправляем на топик с сообщением, что последняя посещенная вами запист удалена:.	
				# Пересобираем список новых ids из cookie, чтобы исключить удаленный.
				$C->{in}{_new_ids} =~ s/$F->{in}{id}\|?//;
				$C->{in}{_new_ids} =~ s/\|$//;

				$F->{in}{id} = $LT->get_topic_id();
				$F->{alert} = 'Последняя просмотренная Вами запись, была кем-то удалена.';
				$data = $LT->record($F->{in}{id});
			}
			
			# Сохраняем в cookie текущее положение, если не сказано не сохранять:
			unless ($F->{in}{norem}){
				$C->{out}{_cur_id} = $F->{in}{id};
			}


			my %ids = ();
			debug "READ Cookie:", $C->{in};
			if (%{$C->{in}} && exists $C->{in}{_last_date} && $C->{in}{_last_date} =~ /^\d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2}$/ ){
				$F->{list_new_ids} = $LT->list(date_from=>$C->{in}{_last_date});

				# пользователь уже имеет cookie на последний просмотр, значит уже был. даём ему данные о новинках, если нет:
				if (exists $C->{in}{_new_ids} && $C->{in}{_new_ids} ne ''){
					my @cids = ();
					map { push @cids, $_ if $_ != $F->{in}{id} } (split /\|/, $C->{in}{_new_ids});
					map {$ids{$_} = 1} ( (map {$_->{id}} @{$F->{list_new_ids}}),@cids );
					if (%ids){
						$C->{out}{_new_ids} =  join "|", (keys %ids);
					}else{
						$C->{out}{_new_ids} = '';
					}
				}else{
					# куков на список новых id нет - формируем.
					if (@{$F->{list_new_ids}}){
						map {$ids{$_->{id}} = 1} @{$F->{list_new_ids}};
						$C->{out}{_new_ids} = join "|", (keys %ids);
					}else{
						$C->{out}{_new_ids} = '';
					}
				}
			}

			if (%ids){
				$F->{highlight_ids} = \%ids;
			}

			# собираем дату сгорания cookie 60 дней
			my $exp_d = (join "-",map {length $_ < 2 ? "0".$_ : $_} extractFromEpoch(time+(60*24*60*60),"year","month","day"))." ".(join ":", map {length $_ < 2 ? "0".$_ : $_} extractFromEpoch(time+(60*24*60*60),"hour","minute","second"));

			$S->printCookie(_last_date=>{ttl=>Pg_to_MSD($exp_d).';'},_cur_id=>{ttl=>Pg_to_MSD($exp_d).';'});
			debug "HIGHLIGHT ids",$F->{highlight_ids};

			$F->{date} = NOW();
			# выгружаем дочерние ноды для получения тегов:
			my $tags = $LT->loadTags(nleft=>$data->{nleft}, nright=>$data->{nright},level=>$data->{level},hl_ids=>[keys %ids]);
			$F->{tags} = $tags;

			# обрабатываем текст добавляя ссылки:
			foreach (@$tags){
				my $st = '';
				if (defined $_->{hl}){
					$st = ($_->{hl} > 1 ? '<sup> '.$_->{hl}.'*</sup>' : ' *' );
				}

				$data->{description} =~ s/(\W)($_->{tag})(\W)/$1<a style="color:#3A7DB9;" href="?id=$_->{id}">$_->{tag}$st<\/a>$3/gi;

			}

			$F->{data} = $data;

			$F->{breadcrumbs} = $LT->getBreadCrumbs($data->{id_text}, nleft=>$data->{nleft}, nright=>$data->{nright});
			debug "bR:",$F->{breadcrumbs};
			# собираем хлебные крошки: 
			return 'page';
		}
	)
);


$S->addStep(new Step('DELETE',
		NEXT=>{'page'=>'district_desc.edit'},
		OUT_OPTIONS=>{-type=>'text/html'},
		DO=>sub{
			my $F = GETVARS();
			
			# Удаляем дерево узла.
			my $LT = new LocationTree(db=>GETDB(),obj_id=>1);

			# Удаляем локации которые более не структурированы
			$LT->deleteNode($F->{in}{id});

			debug "Delete node id:",$F->{in}{id};
			$S->redirect('/?del_ok='.$F->{in}{id}.'&c=edit');
			return 'stop';
		}
	)
);


$S->rule(sub {
		if(exists $S->F()->{in}{c} && $S->F()->{in}{c} eq 'edit' ){
			if (exists $S->F()->{in}{id} && $S->F()->{in}{id} =~ /^\d+$/){
				if (exists $S->F()->{in}{update}){
					# обновить имеющееся 
					return 'UPDATE';
				}elsif(exists $S->F()->{in}{'delete'}){
					# Удалить ноду
					return 'DELETE';
				}
			}elsif(exists $S->F()->{in}{pid} && $S->F()->{in}{pid} =~ /^\d+$/){
				# добавить дочернюю ноду, так как есть parent_id
				return 'NEW';
			}			
			# полная страница редактирования
			return 'EDIT';
		}
		return 'SHOW';
	}
);

$S->execute();
