#!/usr/bin/perl

use constant BASE_PATH       => '/media/BIGBASE/Photo/';
use constant RESUME_PATH     => ':/SDMMC/My Pictures/';
use constant RESUME_FILENAME => 'resume.txt';
use constant RESUME_PIC_PATH => '/home/alex/tmp/gfgallery/resume/';

my $exists_folders = {};

sub is_pda_enubled {

	my $status_message = `pstatus 2>&1`;

	if ($status_message =~ /^Platform:\s+3\s+\(Windows CE\)$/m) {
		return 1;
	} else {
		return 0;
	}
}

sub copy_resume_to_base {

	my $base_path = &BASE_PATH;
	$base_path =~ s/ /\\ /g;

	my $resume_file = &RESUME_FILENAME;
	$resume_file =~ s/ /\\ /g;

	my $resume_path = &RESUME_PATH . '/' . &RESUME_FILENAME;
	$resume_path =~ s/ /\\ /g;

	my $error = `cp -f $base_path/$resume_file $base_path/${resume_file}.bak 2>&1; cd $base_path 2>&1; pcp $resume_path 2>&1`;

	if ($error !~ /File copy of \d+ bytes took|File copy took less than one second!/) {
		print "Error: $error\n";
		return 0;
	} else {
		return 1;
	}
}

sub check_folders {
	my $path = shift;

	my @folders = split('/', $path);
	shift @folders;
	pop   @folders;

	my $folder;
	foreach (@folders) {
		$folder .= '/' . $_;

		unless ($exists_folders->{$folder}) {
			my $folders = `pls $folder 2>&1`;
			if ($folders =~ /No such file or directory/){
				my $error = `pmkdir $folder 2>&1`;
				if ($error) {
					print "Error: $error\n";
				}
			}
			$exists_folders->{$folder} = 1;
		}
	}
}

sub check_file {
	my $file = shift;

	$file =~ s/^://;

	check_folders($file);

	my $result = `pls $file 2>&1`;
	if ($result =~ /No such file or directory/) {
		return 0;
	} else {
		return 1;
	}
}

sub check_file_date {
	my $file = shift;

	my $data = `ls -l $file 2>&1`;

	if ($data =~ /(\d{4}-\d{2}-\d{2})/) {
		my $file_date = $1;

		my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time());

		$year = 1900 + $year;
		$sec  = sprintf('%02d',$sec);
		$min  = sprintf('%02d',$min);
		$hour = sprintf('%02d',$hour);
		$mday = sprintf('%02d',$mday);
		$mon++;
		$mon  = sprintf('%02d',$mon);

		my $current_date = "$year-$mon-$mday";

		return ($current_date eq $file_date);
	} else {
		print "Error: $data\n";
	}
	
}

sub copy_images_to_resume {

	my $resume_pic_path = &RESUME_PIC_PATH;
	$resume_pic_path =~ s/ /\\ /g;

	my $resume_path = &RESUME_PATH;
	$resume_path =~ s/ /\\ /g;

	my @files_list = `find $resume_pic_path -name *.jpg`;

	my $count   = scalar(@files_list);
	my $index   = 0;
	my $percent = 0;

	foreach my $file (@files_list){
		$index++;
		$file =~ s/ /\\ /g;
		$file =~ s/\n//g;
		my $source_file = $file;
		$file =~ s/$resume_pic_path/$resume_path/;

		if (check_file_date($source_file)) {
			unless (check_file($file)) {
				$file =~ s/\\//g;
				$file =~ s/\//\\\\/g;
				$file =~ s/ /\\ /g;
				print "pcp $source_file $file \n";
				my $error = `pcp $source_file $file 2>&1`;
				sleep 1;
				if ($error !~ /File copy of \d+ bytes took|File copy took less than one second!/) {
					print "Error: $error\n";
					return 0;
				}
			}
		}

		my $new_percent = sprintf("%d", $index * 100 / $count);
		if ($percent != $new_percent) {
			print "Export resume pictures $new_percent% done\n";
		}
		$percent = $new_percent;
		 
	}

	return 1;
}

copy_images_to_resume();