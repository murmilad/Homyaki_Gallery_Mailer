for i in `ls /home/alex/Scripts/gf_mail/data/ | grep -P '132278\d{4}.eml'`; do cat /home/alex/Scripts/gf_mail/data/$i | /usr/sbin/sendmail -f alex\@homyaki.info -t; done
