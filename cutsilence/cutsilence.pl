#!/usr/bin/perl -w

# Принцип работы программы удаления пауз речи из видео:
#
# 1. Выполняется поиск тихих интервалов времени на видео командой ffmpeg.
#    На этом этапе настраивается уровень шума который можно считать тишиной.
#
# 2 Вырезается из оригинального видео все набранные на первом шаге интервалы, и корректируется задержка

my @pts;

# необходимо добавить задержку чтобы видео не обрезалось прям после слова, а хотя бы некоторое время висело (сек)
my $delay = 0.5;

# Уровень шума ниже которого считается тишина (dB)
my $noise_level = -25;

# Исходный видеофайл
unless ($ARGV[0] && $ARGV[0] ne ''){
    die "Please enter filename.\nExample: ./cutsilence.pl myfile.mp4 ";
}

my $filename = $ARGV[0];

# Конечный видеофайл
my $out_filename = $filename.'_wos';

# команда ffmpeg которая находит тишину:
my $get_sl = 'yes | ffmpeg -i '.$filename.' -af silencedetect=n='.($noise_level).'dB:d=1 '.$out_filename.'.mp3 2>&1';

for (`$get_sl`){
    chomp $_;
    
    if ($_ =~ /silence_start:\s([\d\.]+)/){
        # начало паузы
        push @pts, $1;
    }

    if ($_ =~ /silence_end:\s([\d\.]+)/){
        # конец паузы
        push @pts, $1;
    }

    #    if ($_ =~ /Duration:\s(\d\d):(\d\d):(\d\d)/){
    #    $d = $3+$2*60+$1*3600;
    #}
}

# первый интервал видео со звуком с 0.. до первого интервала тишины
#unshift @pts,0;

# последний интервал видео со звуком начинается с конца интервала тишины до конца видео:
#push @pts,$d if ($d > $pts[$#$pts]);

# прост удалим последний
pop @pts;

# Начальный интервал начнем с 0
unshift @pts,0;

my @btw = ();
foreach (1..(($#pts+1)/2)){
    push @btw,"between(t,".(shift(@pts)-$delay).",".(shift(@pts)+$delay).")";
}

my $command = 'ffmpeg -i '.$filename.' -vf "select=\''.(join "+", @btw).'\', setpts=N/FRAME_RATE/TB" -af "aselect=\''.(join "+", @btw).'\', asetpts=N/SR/TB" '.$out_filename.'.mp4';

print `$command`;

exit;
