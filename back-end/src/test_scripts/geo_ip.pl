use Geo::IP;
my $gi = Geo::IP->open("/usr/local/share/GeoIP/GeoIPCity.dat", GEOIP_STANDARD);
my $record = $gi->record_by_addr('24.24.24.24');
print "Country: ",$record->country_code,"\n",
"Region: ",$record->region,"\n",
"City: ",$record->city,"\n",
"Lattitude: ",$record->latitude,"\n",
"Longitude: ",$record->longitude,"\n";

