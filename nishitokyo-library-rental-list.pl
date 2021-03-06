#!/usr/bin/perl
# 西東京市図書館の貸出リストを取得して、CSV出力する
# 作成者：藤井 一郎（ichirou.fujii@gmail.com)
# 
# バージョン：2.1　2014/08/09　貸出件数が0件の場合異常終了するバグを修正
# バージョン：2.0　2014/08/02　リスト表示がデフォルトになったことに対応
#                              20冊以上リスト取得できていなかった問題を解消
# バージョン：1.0　2014/06/08　新規作成

use strict;
use warnings;
use LWP::UserAgent;
use HTML::TreeBuilder;
use WWW::Mechanize;
use utf8;
binmode STDIN, ':encoding(cp932)';
binmode STDOUT, ':encoding(cp932)';
binmode STDERR, ':encoding(cp932)';

sub get_isbn {
# 貸出詳細からISBNを取得する。
	my ($mech,$rentalid) = @_;
	my $url = 'https://www.library.city.nishitokyo.lg.jp/rentaldetail?conum='.$rentalid;
	$mech->get($url);
	my $content = $mech->content;

	my $tree = HTML::TreeBuilder->new;
	$tree->parse($content);
	my $isbn="";

	my $bookinfo = $tree->look_down('_tag', 'table', 'class', 'tleft02');
	my @bookinfoitems =  $bookinfo->look_down('_tag','tr');
	foreach my $bookinfoitem (@bookinfoitems){
    	my $bookinfoitem_attr = $bookinfoitem->look_down('_tag','th');
    	my $bookinfoitem_value = $bookinfoitem->look_down('_tag','td');
    	if ($bookinfoitem_attr->as_text =~ /ＩＳＢＮ/){
			$isbn = $bookinfoitem_value->as_HTML;
			$isbn =~ /<span> *([-0-9]*) *[<&]/;
      		if($1){
      			$isbn = $1;
      		} else {
      			$isbn ='';
	      	}
    	}
  	}
  	return $isbn;
}

sub listup_rental {
	#引数受け取り
	my ($username,$userid, $passwd) = @_;

	#newする
	my $mech = WWW::Mechanize->new();

	#ログインページを取得
	$mech->get('https://www.library.city.nishitokyo.lg.jp/login');

	#print $mech->content;
	#アカウント名とパスワードを書き込んで送信
	$mech->submit_form(
     	form_id => 'inputForm49',
     	fields => {
        	textUserId => $userid,
        	textPassword => $passwd,
     	},
     	button => 'buttonLogin'
	);

	# urlを指定する
	my $url = 'https://www.library.city.nishitokyo.lg.jp/rentallist?1&mv=30&pcnt=1&sort=1';

	$mech->get($url);

	my $content = $mech->content;

	# HTML::TreeBuilderで解析する
	my $tree = HTML::TreeBuilder->new;
	$tree->parse($content);

	# DOM操作してトピックの部分だけ抜き出す。
	# <div id='topicsfb'><ul><li>....の部分を抽出する
	
	
	my $rental_table = $tree->look_down('_tag', 'table');
    if($rental_table){
		$rental_table = $rental_table->as_HTML;
		my $rental_table_tree = HTML::TreeBuilder->new;
		$rental_table_tree->parse($rental_table);

		my @infotables =  $rental_table_tree->look_down('_tag','tr');
		foreach my $infotable (@infotables){
  			my @rentinfoitems =  $infotable->look_down('_tag','td');
			if (@rentinfoitems){
				my $itemno  = $rentinfoitems[0]->as_text;
				my $title  = $rentinfoitems[1]->as_text;
				my $rentalid = $rentinfoitems[1]->look_down('_tag','a')->attr('href');
  				$rentalid =~ /\.\/rentaldetail\?conum=(.*)/;
  				$rentalid = $1;
				my $library  = $rentinfoitems[2]->as_text;
				my $rentaldate  = $rentinfoitems[3]->as_text;
				my $returndate  = $rentinfoitems[4]->as_text;
				my $isbn = get_isbn($mech,$rentalid);

				print $username.",".$itemno.",".$rentalid.",\"".$title."\","."$isbn".",".$library.",".$rentaldate.",".$returndate."\n";
			}
		}
	}
}

