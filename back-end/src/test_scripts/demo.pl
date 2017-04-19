#!/usr/bin/perl

open FILES, "ls |";
while(<FILES>){
	chomp($_);
	$_ =~ s/\s+/\\ /g; #escape space for the shell
	`bzip2 -d $_`; #extract file to be processed

	#store filename with and without .gz extension
	my $originalFilename = $_;
	my $newFilename = $originalFilename;
	$newFilename =~ s/\.bz2$//;

open BGP_DATA_FILE, "/usr/local/bin/bgpdump -m $newFilename|" or die "cannot pipe from bgpdump: $!";
while(<BGP_DATA_FILE>){
	print $_;
}
}
