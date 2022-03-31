#!/usr/bin/perl -w

use strict;
use lib qw|../../lib ../../conf|;
use utf8;
use DB;
use LocationTree;
use Error;
use Cfg;
Error::init();

conf_load('district_desc');

my $db = new DB('main');
$db->reconnect();

my $LT = new LocationTree(obj_id=>1,db=>$db);

# Начальный экземпляр и инициализация дерева коментариев:

# INSERT INTO text_locations (id,tag,description) VALUES (1,'Микрорайон "Лесной"','Справочник-путеводитель по микрорайону. Общий вид. ');
# INSERT INTO comment (id_obj,id_expl,nleft,nright,level,count) VALUES (1,1,1,2,0,0);

# сохраняем коментарий к обьекту 1 экземпляром 2 к 
my $id1 =  $LT->save('Описание','Тут живёт около 1 тыс. жителей. По структуре застроек принято разделять микрорайон на 2 части. Восточная часть. Западная часть. В районе имеются здания инфраструктуры.',undef);
my $id1_1 = $LT->save('Западная часть','Западная часть находится западнее от станции. В этой части 3 новых дома: 12, 16, 17. Старые дома, ожидающие расселения: 42 и 34. Вдоль 12 дома, ул Лесопарковая разветвляется: в одну сторону уходит в лесопарковую зону на бетонку, в другую - выезд на ул. "Магистральная".',$id1);
my $id1_2 = $LT->save('Восточная часть','Восточная часть находится ближе к станции. Эта чать района включает в себя улицы ул. "Лесной проезд (дома 1, 2, 3, 4, 6 и 7)", ул. "Лесная ()". В этой части находится торговый центр и стоматология.',$id1);
my $id1_2_1 = $LT->save('Стоматология','Небольшая стоматологическая клиника.',$id1_2);
my $id1_3 = $LT->save('Здания инфраструктуры','Небольшое количество зданий разной величины.',$id1);

$db->commit;
exit;

