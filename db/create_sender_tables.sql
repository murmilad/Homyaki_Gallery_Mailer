DROP TABLE users;

CREATE TABLE IF NOT EXISTS users (
		id        int(11) auto_increment,
		name      varchar(128),
		name_call varchar(128),
		email     varchar(128),
		subject   varchar(256),
		active    bit default 0,
		PRIMARY KEY (id)
) type=Innobase;

INSERT INTO users (name, name_call, email, subject, active)
	VALUES 
	('Нина', 'Нин', 'pna79@mail.ru', 'Накопились тут фоты :) Шлю спам :)', 1),
	('Лёша', 'Лёху', 'netalexinfo@hotbox.ru', 'У! Лёху, тут новые фоты!', 1),
	('Лёша', 'Лёху Второй', 'root@homyaki.info', 'У! Лёху Второй, тут новые фоты!', 0);

DROP TABLE images;

CREATE TABLE IF NOT EXISTS images (
		id        int(11) auto_increment,
		name      varchar(128) UNIQUE,
		resume    blob,
		PRIMARY KEY (id)
) type=Innobase;

DROP TABLE users_images;

CREATE TABLE IF NOT EXISTS users_images (
		id        int(11) auto_increment,
		image_id  int(11),
		user_id   int(11),
		sent      bit default 1,
		updated   bit default 0,
		sent_date datetime,
		PRIMARY KEY (id)
) type=Innobase;