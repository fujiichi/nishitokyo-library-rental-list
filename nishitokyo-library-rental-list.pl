#!/usr/bin/perl
# 西東京市図書館の貸出リストを取得して、CSV出力する
# 作成者：藤井 一郎（ichirou.fujii@gmail.com)
# バージョン：1.0
# 作成日：2014/06/08
# 使用方法：listup_rental_list(名前、利用者ID、パスワード)

use strict;
use warnings;
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
      		$isbn = $1;
    	}
  	}
  	return $isbn;
}

sub listup_rental_list {
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
	my $url = 'https://www.library.city.nishitokyo.lg.jp/rentallist';

	$mech->get($url);

	my $content = $mech->content;

	# HTML::TreeBuilderで解析する
	my $tree = HTML::TreeBuilder->new;
	$tree->parse($content);

	# DOM操作してトピックの部分だけ抜き出す。
	# <div id='topicsfb'><ul><li>....の部分を抽出する

	my $honbun = $tree->look_down('_tag', 'div', 'id', 'honbun')->as_HTML;
	my $honbuntree = HTML::TreeBuilder->new;
	$honbuntree->parse($honbun);

	my @infotables =  $honbuntree->look_down('_tag','div', 'class','infotable');
	foreach my $infotable (@infotables){
  		my $h3 =  $infotable->look_down('_tag','h3');
		my $h3a =  $infotable->look_down('_tag','a');
  		my $rentalid = $h3a->attr('href');
  		$rentalid =~ /\.\/rentaldetail\?conum=(.*)/;

  		$rentalid = $1;
  		my $itemno =  $h3->look_down('_tag','span');
  		my $title =  $h3->look_down('_tag','a');
  		my $rentinfo =  $infotable->look_down('_tag','table','class','tleft02');
  		my @rentinfoitems =  $rentinfo->look_down('_tag','td');

  		my $isbn = get_isbn($mech,$rentalid);

		print $username.",".$itemno->as_text.",".$rentalid.",\"".$title->as_text."\","."$isbn".",".$rentinfoitems[0]->as_text.",".$rentinfoitems[1]->as_text.",".$rentinfoitems[2]->as_text."\n";
	}

}
