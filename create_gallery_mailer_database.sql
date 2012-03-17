CREATE TABLE `images` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(128) DEFAULT NULL,
  `resume` blob,
  `album_name` varchar(128) DEFAULT NULL,
  `new_image` tinyint(1) DEFAULT '0',
  `link` text,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=MyISAM AUTO_INCREMENT=2963 DEFAULT CHARSET=latin1;

CREATE TABLE `users` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(128) DEFAULT NULL,
  `name_call` varchar(128) DEFAULT NULL,
  `email` varchar(128) DEFAULT NULL,
  `subject` longtext,
  `active` tinyint(1) DEFAULT '0',
  `news_receiver` tinyint(1) DEFAULT '0',
  PRIMARY KEY (`id`)
) ENGINE=MyISAM AUTO_INCREMENT=33 DEFAULT CHARSET=utf8;

CREATE TABLE `users_images` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `image_id` int(11) DEFAULT NULL,
  `user_id` int(11) DEFAULT NULL,
  `sent` tinyint(1) DEFAULT '1',
  `updated` tinyint(1) DEFAULT '0',
  `sent_date` datetime DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM AUTO_INCREMENT=13885 DEFAULT CHARSET=latin1;
