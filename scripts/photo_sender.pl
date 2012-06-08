#!/usr/bin/perl

use strict;
use MIME::Base64;
use Net::FTP;
use DBI;

use Data::Dumper;
use URI::Escape;

use constant IMAGES_PER_MAIL      => 10;
use constant IMAGES_PER_MAIL_NEWS => 10;

use constant NEW_IMAGES_ALBUM_NAME => 'This pictures or comments was changed on.*';

use constant WEEKLY   => 1;
use constant WHATSNEW => 2;

use constant WHATSNEW_THEME => 'Новые фотографии! :)';

use constant BODY_TEMPLATE_MAP => {
	&WEEKLY   => 'mail_body.tmpl',
	&WHATSNEW => 'mail_body_news.tmpl',
};

use constant GALLERY_URI           => 'http://akosarev.info/';

use constant PICTURE_INFO_TEMPLATE => 'mail_picture_info.tmpl';
use constant CONTAINER_TEMPLATE    => 'mail_container.tmpl';
use constant ATTACHMENTS_TEMPLATE  => 'mail_attachment.tmpl';
use constant DATA_PATH             => '/home/alex/Scripts/gf_mail/data/';
use constant MAIN_PATH             => '/home/alex/Scripts/gf_mail/';

#use constant WEB_PATH          => 'akosarev.info';
#use constant WEB_LOGIN         => 'akosarev';
#use constant WEB_PASSWORD      => 'Godaddy215473';

use constant WEB_PATH          => 'media.homyaki.info';
use constant WEB_LOGIN         => 'alex';
use constant WEB_PASSWORD      => '458973';

use constant WEB_DATA_PATH     => '/';
use constant WEB_IMAGES_PATH   => '/images/big/';
use constant DOWNLOAD_ATTEMPTS => 10;

use constant SUBSCR_FILE  => 'resume.txt';
use constant GALLERY_FILE => 'gallery.xml';

use constant DBI_USER     => 'root';
use constant DBI_PASSWORD => '458973';


my $download_attempts = 0;

sub load_template {
	my %h = @_;

	my $template_name = $h{template_name};
	my $parameters    = $h{parameters};

	my $template;

	if (open TEMPLATE, '<' . &MAIN_PATH . $template_name) {
		while (my $line = <TEMPLATE>) {
			$template .= $line;
		}
		close TEMPLATE;		
	}

	if (ref($parameters) eq 'HASH') {
		foreach my $name (keys %{$parameters}) {
			my $value = $parameters->{$name};
			$template =~ s/%$name%/$value/gs;
		}		
	}

	return $template;
}

sub load_picture_info{
	my %h = @_;

	my $comment    = $h{comment};
	my $file_name  = $h{file_name};
	my $album_name = $h{album_name};
	my $link       = $h{link};

	my $album_name_uri = $album_name;
	$album_name_uri =~ s/\s/_/g;
	$album_name_uri = &GALLERY_URI .  'albums/' . uri_escape($album_name_uri) . '.html';

	my $picture_info = load_template(
		template_name => &PICTURE_INFO_TEMPLATE,
		parameters    => {
			ALBUM_NAME => $album_name ? ($album_name . '<a href="' . $album_name_uri . '">&nbsp;Look &gt;&gt;</a>') : '',
			COMMENT    => $comment,
			NAME       => $file_name,
			LINK       => $link ? (&GALLERY_URI . $link) : ''
		}
	);

	return $picture_info;
}

sub load_body {
	my %h = @_;

	my $receiver_name = $h{receiver_name};
	my $gallery       = $h{gallery};
	my $header        = $h{header};
	my $type          = $h{type};

	my $pictures_info;

	my $album_name = '';
	my $album_tagged = 0;

	foreach my $picture_data (@{$gallery}){
		if ($album_name ne $picture_data->{album_name}){
			$album_name = $picture_data->{album_name};
			$album_tagged = 0;
		}

		$pictures_info .= load_picture_info(
			album_name => ($album_tagged ? '' : $album_name),
			comment    => $picture_data->{comment},
			file_name  => $picture_data->{file_name},
			link       => $picture_data->{link}
		);
		$album_tagged = 1;

	}	

	my $body = load_template(
		template_name => &BODY_TEMPLATE_MAP->{$type},
		parameters    => {
			HEADER        => $header,
			RECEIVER_NAME => $receiver_name,
			PICTURES_INFO => $pictures_info,
		}
	);

	return $body;
}

sub get_boundary {

	return '----_=_NextPart_001_01C9C1B0.11A4C87D';
}

sub get_picture_source {
	my %h = @_;

	my $file_path   = $h{file_path};
	my $base64_path = $file_path . '.base64';

	my $source;

	if(-f $base64_path) {
#		$source = `cat $base64_path`;
		open SOURCE, "<$base64_path";
		while (my $line = <SOURCE>) {
			$source .= $line;
		}
		close SOURCE;
	} else {
		$source = `uuencode -m $file_path $file_path | grep -v begin-base64`;
		open SOURCE, ">$base64_path";
		print SOURCE $source;
		close SOURCE;
	}

	
	return $source;
}

sub load_attachments {
	my %h = @_;

	my $boundary = $h{boundary};
	my $gallery  = $h{gallery};

	my $attachments;

	foreach my $picture_data (@{$gallery}) {

		my $name = $picture_data->{file_name};

		my $picture_source = get_picture_source (
			file_path => &DATA_PATH . $name
		);

		$attachments .= load_template(
			template_name => &ATTACHMENTS_TEMPLATE,
			parameters    => {
				BOUNDARY       => $boundary,
				NAME           => $name,
				PICTURE_SOURCE => $picture_source,
			}
		);
	}	

	return $attachments;
}

sub prepare_email {
	my %h = @_;

	my $from          = $h{from};
	my $to            = $h{to};
	my $theme         = $h{theme};
	my $header        = $h{header};
	my $receiver_name = $h{receiver_name};
	my $gallery       = $h{gallery};
	my $type          = $h{type};

	my $boundary      = get_boundary();

	my $body = load_body(
		receiver_name => $receiver_name,
		header        => $header,
		gallery       => $gallery,
		type          => $type,
	);

	my $attachments = load_attachments (
		boundary => $boundary,
		gallery  => $gallery
	);

	if ($type == &WHATSNEW){
		$theme = &WHATSNEW_THEME;
	}

	my $container = load_template(
		template_name => &CONTAINER_TEMPLATE,
		parameters    => {
			FROM        => $from,
			TO          => $to,
			THEME       => encode_mail_value_base64($theme),
			BOUNDARY    => $boundary,
			BODY        => encode_base64($body),
			ATTACHMENTS => $attachments,
		}
	);

	return $container;
}

sub encode_mail_value_base64 {
	my $text = shift;

	my $encoded_text = encode_base64($text);
	$encoded_text =~ s/\n//s;

	return "=?UTF-8?B?$encoded_text?=";
}

sub send_mail {
	my $mail = shift;

	my $data_path = &DATA_PATH;

	my $email_file_name = time();

	open TMP, ">${data_path}${email_file_name}.eml";
	print TMP $mail;
	close TMP;

	my $mail = `(cat ${data_path}${email_file_name}.eml) | /usr/sbin/sendmail -f alex\@homyaki.info -t`;
	sleep(3);
}

sub prepare_send_mail {
	my %h = @_;

	my $from          = $h{from};
	my $to            = $h{to};
	my $theme         = $h{theme};
	my $receiver_name = $h{receiver_name};
	my $header        = $h{header};
	my $gallery       = $h{gallery};
	my $type          = $h{type};
                                
	my $mail_message = prepare_email (
		from          => $from,
		to            => $to,
		theme         => $theme,
		receiver_name => $receiver_name,
		header        => $header,
		gallery       => $gallery,
		type          => $type,
	);

	send_mail($mail_message);
}


sub download_file {
	my $src_file_path = shift;

	$src_file_path =~ /\/([^\/]*)$/;
	my $dest_file_path = &DATA_PATH . ($1 ? $1 : $src_file_path);

	$src_file_path = &WEB_DATA_PATH . $src_file_path;

	my $ftp = Net::FTP->new(&WEB_PATH, Debug => 0)
		or die "Cannot connect to some.host.name: $@";

	$ftp->login(&WEB_LOGIN, &WEB_PASSWORD)
		or die "Cannot login ", $ftp->message;

	if ($src_file_path =~ /jpg$/i){
		$ftp->binary()
			or die "Cannot set binary mode ", $ftp->message;
	}

	if (!$ftp->get($src_file_path, $dest_file_path) && ($download_attempts++ < &DOWNLOAD_ATTEMPTS)){
		print "Cannot get $src_file_path, attempt $download_attempts :" . $ftp->message . "\n";
		$ftp->quit();
		download_file($src_file_path);
	} else {
		$download_attempts = 0;
		$ftp->quit();
	}

}

sub get_subscr_images_array {

	download_file(&SUBSCR_FILE);
	download_file(&GALLERY_FILE);

	my $albums     = {};
	my $new_images = {};
	my $links      = {};
	my $order      = {};

	open GALLERY, '<' . &DATA_PATH . &GALLERY_FILE;
	my $album;
	my $index = 0;
	while (my $line = <GALLERY>) {
	
		my $image;
		my $link;
		if ($line =~ /<album\s.+\stitle="([^"]*)"/){
			$album = $1;
		} elsif ($line =~ /<image\s.+\simage="([^"]*)"/){
			$image = $1;
			if ($line =~ /<image\s.+\slink="([^"]*)"/){
				$link = $1;
			}
			$index++;
		}
		$links->{$image} = $link;
		$order->{$image} = $index;
		$albums->{$image} = $album;
		my $new_images_regexp = &NEW_IMAGES_ALBUM_NAME;
		if ($album =~ /$new_images_regexp/){
			$new_images->{$image} = 1;
		}
	}
	close GALLERY;

	my @subscr_images;

	open SUBSCR, '<' . &DATA_PATH . &SUBSCR_FILE;
	while (my $line = <SUBSCR>) {
		$line =~ s/\s+$//;
		if ($line =~ m/(.*)\|(.+)/) {
			push(@subscr_images, {
				file_order => $order->{$1},
				file_name  => $1,
				comment    => $2,
				album_name => $albums->{$1},
				new_image  => $new_images->{$1} || 0,
				link       => $links->{$1},
			});
		}
	}
	close SUBSCR;

	@subscr_images = sort {$a->{file_order} <=> $b->{file_order}} @subscr_images;

	return \@subscr_images;
}

sub download_images {
	my $subscr_images = shift;

	foreach my $subscr_image (@{$subscr_images}) {
		my $path = &WEB_IMAGES_PATH . $subscr_image->{file_name};
		download_file($path)
			unless (-f (&DATA_PATH . $subscr_image->{file_name}));
	}
}

sub is_available_image {
	my $image_file_name = shift;

	return -f (&DATA_PATH . $image_file_name);
}

sub get_images_list {
	my $subscr_images = shift;

	my $subscr_images_result = [];

	my $index;
	foreach my $subscr_image (@{$subscr_images}) {
		if ($index < 10) {
			push(@{$subscr_images_result}, $subscr_image);
		}
		$index++;
	}

	return $subscr_images_result;
}

sub connect_to_db {	
	my $dbh = DBI->connect( 'dbi:mysql:sender;mysql_socket=/var/run/mysqld/mysqld.sock', &DBI_USER, &DBI_PASSWORD);

	$dbh->do("set character set utf8");

	return $dbh;
}

sub get_rows {
	my %h = @_;

	my $dbh    = $h{dbh};
	my $sql    = $h{sql};
	my $fields = $h{fields};
	my $sort   = $h{'sort'} || 'id';
#print Dumper(\%h);
	my $sth = $dbh->prepare($sql);
	$sth->execute();

	my @result;
#print $sql;
	my $columns = $sth->fetchall_hashref($sort);	

	my $convert_command = '@result = map +{'
		. join (',', map {"$_ => \$columns->{\$_}->{$_}"} split(',', $fields))
		. '}, keys %{$columns}';

	eval $convert_command;
	
	return \@result;
}

sub get_receivers_list {
	my %h = @_;

	my $dbh  = $h{dbh};
	my $type = $h{type};

	my $fields = 'id,name,name_call,email,subject,active,news_receiver';

	my $sql;

	if ($type eq &WEEKLY){
		$sql = qq{ 
			SELECT 
				 $fields
				FROM users 
			WHERE active = 1
		};
	} elsif ($type eq &WHATSNEW) {
		$sql = qq{ 
			SELECT 
				 $fields
				FROM users 
			WHERE news_receiver = 1
		};
	} elsif ($type eq '') {
                $sql = qq{
                        SELECT
                                 $fields
                                FROM users
                };
        }

	return get_rows(
		dbh    => $dbh,
		sql    => $sql,
		fields => $fields,
	);
}

sub get_pictures_list {
	my %h = @_;

	my $dbh         = $h{dbh};
	my $receiver_id = $h{receiver_id};
	my $type        = $h{type};

	my $fields = 'id,name,resume,album_name,new_image,link';

	my $sql;
	my $images_per_mail = 0;

	my $have_current_album = 0;
	if ($type eq &WEEKLY){
		$images_per_mail = &IMAGES_PER_MAIL;

		$sql = qq{ 
			SELECT
				images.album_name,
				count(images.id) AS count,
				sum(CASE WHEN users_images.sent IS NULL THEN 0 WHEN users_images.sent = 0 THEN 0 ELSE 1 END) AS sent_count,
				sum(CASE WHEN users_images.sent IS NULL THEN 1 WHEN users_images.sent = 0 THEN 1 ELSE 0 END) AS unsent_count
			FROM images
				LEFT OUTER JOIN users_images ON images.id = users_images.image_id
				AND users_images.user_id = $receiver_id 
			WHERE
				NOT (images.album_name IS NULL)
				AND images.album_name != ''
			GROUP BY images.album_name
			HAVING 
				sent_count > 0
				AND unsent_count > 0

		};

		my $unsent_albums = get_rows(
			dbh    => $dbh,
			sql    => $sql,
			fields => 'album_name,count,sent_count,unsent_count',
			'sort' => 'album_name'
		);

		my @unsent_albums;
		if (ref ($unsent_albums) eq 'ARRAY') {
			@unsent_albums = map +{
				unsent_count  => $_->{unsent_count},
				sent_count    => $_->{sent_count},
				album_name    => $_->{album_name},
				count         => $_->{count},
			}, @{$unsent_albums};
		}

		if (sprintf("%d", rand(2)) == 1) {
			@unsent_albums = sort {$b->{unsent_count} <=> $a->{unsent_count}} @unsent_albums
		} else {
			@unsent_albums = sort {$a->{unsent_count} <=> $b->{unsent_count}} @unsent_albums
		}
		my $current_album_sql;

		if (scalar(@unsent_albums) > 0){
			if (scalar(@unsent_albums) > 1) {
				my $albums_to_send = [];
				my $count_images_to_send = $images_per_mail;
				foreach my $unsent_album (@unsent_albums){
					if ($count_images_to_send > 0) {
						push(@{$albums_to_send}, $unsent_album->{album_name});
					}
					$count_images_to_send -= $unsent_album->{unsent_count};
				}
				$current_album_sql = ' AND images.album_name in ("' . join ('", "', @{$albums_to_send}) . '")';
				
			} else {
				$current_album_sql = ' AND images.album_name = "' 
					. $unsent_albums[0]->{album_name} . '";';				
			}
			$have_current_album = 1;
		} else {
			my $album_sql = qq{ 
				SELECT
					 images.album_name
				FROM images
					LEFT OUTER JOIN users_images ON
						images.id = users_images.image_id
						AND users_images.user_id = $receiver_id
				WHERE
					(users_images.sent IS NULL  
					OR users_images.sent != 1)
				GROUP BY images.album_name
			};
	
			my $new_albums = get_rows(
				dbh    => $dbh,
				sql    => $album_sql,
				fields => 'album_name',
				'sort' => 'album_name'
			);
			if (ref ($new_albums) eq 'ARRAY' && scalar(@{$new_albums}) > 0){
				$current_album_sql = ' AND images.album_name = "'
				. $new_albums->[int(rand(scalar(@$new_albums)-1))]->{album_name}
				. '" ';
			}
			
		}

		$sql = qq{ 
			SELECT
				 images.$fields
			FROM images
				LEFT OUTER JOIN users_images ON
					images.id = users_images.image_id
					AND users_images.user_id = $receiver_id
			WHERE
				(users_images.sent IS NULL  
				OR users_images.sent != 1)
				$current_album_sql
		};
	
	} elsif ($type eq &WHATSNEW) {
		$images_per_mail = &IMAGES_PER_MAIL_NEWS;

		my $album_sql = qq{ 
			SELECT
				 images.album_name
			FROM images
				LEFT OUTER JOIN users_images ON
					images.id = users_images.image_id
					AND users_images.user_id = $receiver_id
			WHERE
				(
					users_images.sent IS NULL  
					OR users_images.sent != 1
				)
				AND images.new_image = 1
			GROUP BY images.album_name
		};

		my $albums = get_rows(
			dbh    => $dbh,
			sql    => $album_sql,
			fields => 'album_name',
			'sort' => 'album_name'
		);

		if (ref ($albums) eq 'ARRAY' && scalar(@{$albums}) > 0){
			my $count_each_album = sprintf("%d", ($images_per_mail / scalar(@{$albums}))) + 1;

			$sql      = '';
			my $union = '';
			foreach my $album (@{$albums}){
				my $album_name = $album->{album_name};

				$sql .= qq{ 
					$union
					(SELECT
						 images.$fields
					FROM images
						LEFT OUTER JOIN users_images ON
							images.id = users_images.image_id
							AND users_images.user_id = $receiver_id
					WHERE
						(
							users_images.sent IS NULL  
							OR users_images.sent != 1
						)
						AND images.new_image  = 1
						AND images.album_name = "$album_name"
					LIMIT $count_each_album)
					 
				};
				$union = 'UNION';
			}
		}
	}

	my $pictures_list = get_rows(
		dbh    => $dbh,
		sql    => $sql,
		fields => $fields
	) if $sql;

	my @pictures_list = map +{
		file_name  => $_->{name},
		comment    => $_->{resume},
		album_name => $_->{album_name},
		new_image  => $_->{new_image},
		link       => $_->{link},
	}, @{$pictures_list};
	
	if ($type eq &WEEKLY){
		@pictures_list = sort {$a->{album_name} cmp $b->{album_name} || $a->{file_name} cmp $b->{file_name}} @pictures_list;
	}  elsif ($type eq &WHATSNEW) {
		@pictures_list = sort {$b->{album_name} cmp $a->{album_name} || $a->{file_name} cmp $b->{file_name}} @pictures_list;
	}

	my $length = scalar(@pictures_list);

	my $result = [];
	if ($length > $images_per_mail) {
		my $first = 0;
	
		for (my $index = $first; $index < $first + $images_per_mail; $index++){
			push(@{$result}, $pictures_list[$index]);
		}
	} else {
		$result = \@pictures_list;
	}

	my $header;

	return {
		header         => $header,
		images_to_send => $result
	};		
}


sub update_pictures_db {
	my %h = @_;

	my $dbh     = $h{dbh};
	my $gallery = $h{gallery};
	foreach my $image (@{$gallery}){

		my $file_name  = $image->{file_name};
		my $comment    = $image->{comment};
		my $album_name = $image->{album_name};
		my $new_image  = $image->{new_image} || 0;
		my $link       = $image->{link};

		my $fields = "id,name,resume,album_name,new_image,link";

		my $sql = qq{ 
			SELECT $fields
				FROM images
			WHERE name = '$file_name'
		};

		my $image = get_rows(
			dbh    => $dbh,
			sql    => $sql,
			fields => $fields
		);

		if (scalar(@{$image}) == 0) {
			$comment =~ s/"/\\"/g;
			my $sql = qq{ 
				INSERT
					INTO images (name, resume, album_name, new_image, link)
					VALUES ("$file_name", "$comment", "$album_name", $new_image, "$link")
			};
		
			my $sth = $dbh->prepare($sql);
			$sth->execute();		
		} elsif (
			$image->[0]->{resume} ne $comment
			|| $image->[0]->{album_name} ne $album_name
			|| $image->[0]->{new_image} ne $new_image
			|| $image->[0]->{link} ne $link
		) {
			my $image_id = $image->[0]->{id};

			if ($image->[0]->{resume} ne $comment){
				$comment =~ s/"/\\"/g;
				$sql = qq{
					UPDATE images
						SET
							resume    = "$comment"
					WHERE id = $image_id
				};
				my $sth = $dbh->prepare($sql);
				$sth->execute();		

				$sql = qq{
					UPDATE users_images
						SET updated = 1
					WHERE image_id = $image_id
				};
				my $sth = $dbh->prepare($sql);
				$sth->execute();
			}
			if ($image->[0]->{album_name} ne $album_name){
				$sql = qq{
					UPDATE images
						SET album_name = "$album_name"
					WHERE id = $image_id
				};
				my $sth = $dbh->prepare($sql);
				$sth->execute();
			}
			if ($image->[0]->{new_image} ne $new_image){
				$sql = qq{
					UPDATE images
						SET new_image = $new_image
					WHERE id = $image_id
				};

				my $sth = $dbh->prepare($sql);
				$sth->execute();
			
			}
			if ($image->[0]->{link} ne $link){                    
		                                $sql = qq{                                              
		                            		UPDATE images                                   
		                                      		SET link = "$link"              
		                                    	WHERE id = $image_id                            
		                       		};
		                       		my $sth = $dbh->prepare($sql);
		                       		$sth->execute();
                        }
		}
	}
}

sub set_picture_as_sent {
	my %h = @_;

	my $dbh         = $h{dbh};
	my $receiver_id = $h{receiver_id};
	my $image_name  = $h{image_name};

	my $current_date_time = get_current_date_time();

	my $fields = "id";

	my $sql = qq{ 
		SELECT $fields
			FROM images
		WHERE name = '$image_name'
	};

	my $image_id = get_rows(
		dbh    => $dbh,
		sql    => $sql,
		fields => $fields
	);

	$image_id = $image_id->[0]->{id};

	$fields = "id,sent";

	my $sql = qq{ 
		SELECT $fields
			FROM users_images
		WHERE user_id = $receiver_id AND image_id = $image_id
	};

	my $users_images = get_rows(
		dbh    => $dbh,
		sql    => $sql,
		fields => $fields
	);

	if (scalar(@{$users_images}) == 0) {
		$sql = qq{
			INSERT
				INTO users_images (user_id, image_id, sent, sent_date)
			VALUES ($receiver_id, $image_id, 1, '$current_date_time')
		};
		my $sth = $dbh->prepare($sql);
		$sth->execute();
	} elsif ($users_images->[0]->{sent} == 0) {
		$sql = qq{
			UPDATE users_images
				SET
					sent      = 1,
					updated   = 0,
					sent_date = '$current_date_time'
			WHERE user_id = $receiver_id AND image_id = $image_id
		};
		my $sth = $dbh->prepare($sql);
		$sth->execute();
	}
}

sub get_current_date_time {
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time());

	$year = 1900 + $year;
	$sec  = sprintf('%02d',$sec);
	$min  = sprintf('%02d',$min);
	$hour = sprintf('%02d',$hour);
	$mday = sprintf('%02d',$mday);
	$mon++;
	$mon  = sprintf('%02d',$mon);

	#YYYY-MM-DD HH:MM:SS

	return "${year}-${mon}-${mday} ${hour}:${min}:${sec}";
}



my $command      = $ARGV[0];
my $sending_type = &WEEKLY;

if ($command eq 'weekly') {
	$sending_type = &WEEKLY;
} elsif ($command eq 'whatsnew') {
	$sending_type = &WHATSNEW;
} elsif ($command eq 'receivers') {
	$sending_type = '';
}


my $dbh       = connect_to_db();
my $receivers = get_receivers_list(dbh => $dbh, type => $sending_type);

if ($sending_type) {
	my $subscr_images = get_subscr_images_array();
	

	update_pictures_db(
		dbh     => $dbh,
		gallery => $subscr_images
	);

	foreach my $receiver (@{$receivers}) {

		my $images = get_pictures_list(
			dbh         => $dbh,
			receiver_id => $receiver->{id},
			type        => $sending_type,
		);

		download_images($images->{images_to_send});

		if (scalar(@{$images->{images_to_send}}) > 0) {
			prepare_send_mail (
				from          => 'alex@homyaki.info',
				to            => $receiver->{email},
				theme         => $receiver->{subject},
				receiver_name => $receiver->{name_call},
				header        => $images->{header},
				gallery       => $images->{images_to_send},
				type          => $sending_type,
			);

			prepare_send_mail (
				from          => 'alex@homyaki.info',
				to            => 'root@homyaki.info',
				theme         => $receiver->{subject},
				receiver_name => $receiver->{name_call},
				header        => $images->{header},
				gallery       => $images->{images_to_send},
				type          => $sending_type,
			);
	
			foreach my $sent_image (@{$images->{images_to_send}}) {
				set_picture_as_sent(
					dbh         => $dbh,
					receiver_id => $receiver->{id},
					image_name  => $sent_image->{file_name}
				)
			}
		}
	}
} elsif ($command eq 'receivers'){
	print Dumper($receivers);
#foreach my $reseiver (@$receivers) {
#	print "UPDATE users SET name = '" . $reseiver->{name} . "', name_call = '$reseiver->{name_call}',subject = '$reseiver->{subject}' WHERE id = $reseiver->{id};\n"
	
#		print "UPDATE users SET active = '$reseiver->{active}', news_receiver= '$reseiver->{news_receiver}' WHERE id = $reseiver->{id};\n"
#}
}

