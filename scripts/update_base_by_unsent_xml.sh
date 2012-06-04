
echo > tmp.sql;

for i in `grep -oP 'acoll_\d{7}[^"]*' $1 | uniq`; do echo  " update images set new_image = 1 where name = '$i';" >> tmp.sql; done;

mysql --defaults-file=/etc/mysqldump.cnf sender < tmp.sql;

