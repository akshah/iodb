select count(distinct PeerIPID) from bgpdata.Message;
SELECT * FROM test_outage.DataSet where FromFile like "rib%";
SELECT count(distinct Prefix) FROM sandy_outage.LookupTable where PeerIP="202.232.0.3" and RIB_Time="2012-10-25";
select count(*) from test_outage.PingOutage where OutageStart <= '2012-10-31 23:59:59' ; 
select IPBlock,unix_timestamp(OutageStart) from bgpdata.PingOutage;
select * from sandy_outage.IPTable where id="2";
select * from sandy_outage.Message,sandy_outage.IPTable where Message	.PeerIPID = IPTable.ID;
SELECT DISTINCT Prefix FROM test_outage.LookupTable WHERE PeerIP = '196.223.21.66' and RIB_Time = '2012-10-25';
select * from test_outage.GeoInfo where IPBlock='196.223.21.65';
SELECT * FROM sandy_outage.DataSet where FromFile like 'rib%' and FromFile like '%20121031%';
SELECT * FROM test_outage.OutageInfo where OutageID=3;
select * from test_outage.LookupTable;
select * from test_outage.IPTable where ip='154.11.11.113';
select * from test_outage.Message where PeerIPID ='11';
select * from test_outage.GeoInfo where IPBlock='154.11.11.113';

select PeerIPID from test_outage.Message where DataSetID = '2652';
select * from test_outage.IPTable where id= '830528';
select * from test_outage.GeoInfo where IPBlock='196.223.21.66';



select count(*) from test_outage.DataSet where FromFile like 'updates.linx%';
use bgpdata; show tables;
select * from test_outage.GeoInfo where Region like 'CO';
select count(distinct PeerIP) from test_outage.OutageInfo;
select max(OutageID) from test_outage.OutageInfo;
select * from test_outage.CollectedFrom;
select count(*) from test_outage.Message;
SELECT count(Prefix) FROM test_outage.LookupTable WHERE PeerIP = '154.11.11.113' and RIB_Time = '2012-10-25';

select * from test_outage.OutageInfo;


