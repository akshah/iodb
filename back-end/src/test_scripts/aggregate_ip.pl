#!/usr/bin/perl


use NetAddr::IP;
use Net::IP::LPM;

my $lpm = Net::IP::LPM->new();
$lpm->add('0.0.0.0/0', 'default');

push @addresses, NetAddr::IP->new($_) for <DATA>;
my @compacted=NetAddr::IP::compact(@addresses);
foreach my $in (@compacted){
		
 $lpm->add($in,$in);
}
print $lpm->lookup('129.82.138.0'),"\n";
__DATA__
129.82.138.0/24
129.82.139.0/24
142.121.23.0/24
