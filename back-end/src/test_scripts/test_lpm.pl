use Net::IP::LPM;
 
my $lpm = Net::IP::LPM->new();
 
$lpm->add('0.0.0.0/0', 'default');


$lpm->add('68.0.0.0/12', 'net1');
$lpm->add('68.0.128.0/18', 'net1');
$lpm->add('68.0.16.0/20', 'net1');
$lpm->add('68.0.192.0/18', 'net1');
$lpm->add('68.0.32.0/20', 'net1');
$lpm->add('68.0.48.0/20', 'net1');
$lpm->add('68.0.64.0/18', 'net1');
$lpm->add('68.1.128.0/19', 'net1');
$lpm->add('68.1.16.0/21', 'net1');
$lpm->add('68.1.160.0/19', 'net1');
$lpm->add('68.1.20.0/22', 'net1');


print $lpm->lookup('68.54.144.0'),"\n";
