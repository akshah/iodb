SELECT * FROM iodb.MsgPath;
SELECT * FROM iodb.ASPath;
SELECT FromFile from iodb.DataSet;
SELECT * from iodb.IPTable where IP = "187.16.216.24";
SELECT distinct CollectDate FROM iodb.DataSet where FromFile like 'updates.linx%';
SELECT * FROM iodb.OriginTable;
SELECT * FROM iodb.Message;
SELECT count(*) as Num,MsgType,PeerAS,NextHopID FROM iodb.Message where PeerIPID = 8 and PrefixID= 7 and PrefixMask = 24 group by MsgType;
SELECT * FROM iodb.AggrTable;
SELECT * FROM iodb.Community;
SELECT * FROM iodb.PrefixOriginASN;
SELECT PeerIP FROM iodb.LookupTable where RIB_Time like '%';
SELECT count(distinct OutageID) FROM iodb.PingOutage;
select distinct DATE_FORMAT(OutageStart,'%Y-%m-%d') as day from iodb.PingOutage order by day;
select DATE_FORMAT(OutageStart,'%Y-%m-%d') as day,count(OutageID) from iodb.PingOutage group by day;
SELECT OutageID,PeerIP,BGP_LPM FROM iodb.OutageInfo where BGP_LPM != 'default' order by OutageID;
select count(*) from OutageInfo o,(select OutageID from PingOutage where OutageStart like '2011-07-26%') p where PeerIP='137.164.26.26' and o.OutageID=p.OutageID;
SELECT count(OutageID) FROM iodb.OutageInfo where PeerIP='119.63.216.246';
SELECT * FROM iodb.GeoInfo;
SELECT * FROM iodb.PingOutage where OutageID = 15;
select count(*),IPBlock from PingOutage group by IPBlock order by count(*)  desc;
select unix_timestamp(OutageStart) from PingOutage where IPBlock= '59.176.176.0/24' and unix_timestamp(OutageStart) > 1311789651 limit 1 ;
select OutageID,unix_timestamp(OutageStart),unix_timestamp(OutageEnd) from PingOutage where IPBlock='59.176.176.0/24';
SELECT * FROM iodb.OutageInfo o,PingOutage p where o.PeerIP = '12.0.1.63' and o.OutageID=p.OutageID;
SELECT ID from IPTable where IP='12.0.1.63';
SELECT IP from IPTable where ID='328182';
SELECT ID from IPTable where IP='68.108.0.0';#PeerIPID='8085' and
SELECT * from Message where PeerIPID='25701'; 
SELECT PeerAS,NextHopID from Message where PeerIPID = '4' and PrefixID='' and Mask='23';
SELECT count(Prefix) FROM iodb.LookupTable where PeerIP='198.32.176.24' and RIB_Time = '2011-07-26';
SELECT p.IPBlock,o.PeerIP,o.BGP_LPM,p.OutageStart,p.OutageEnd FROM iodb.PingOutage p,iodb.OutageInfo o,iodb.IPTable ip where p.OutageID=o.OutageID and o.PeerIP=ip.IP and o.BGP_LPM != "default";
select * from MsgPath where MsgPathID = 4;
select PeerAS,NextHopID from iodb.Message where PeerIPID='4';


SELECT * FROM scratchdb.MsgPath;
SELECT * FROM scratchdb.ASPath;
SELECT * FROM scratchdb.DataSet;
SELECT * FROM scratchdb.OriginTable;
SELECT * FROM scratchdb.Message;
SELECT * FROM scratchdb.AggrTable;
SELECT * FROM scratchdb.Community;
SELECT * FROM scratchdb.PrefixOriginASN;
SELECT * FROM scratchdb.LookupTable;
SELECT * FROM scratchdb.PingOutage;
SELECT count(*) FROM scratchdb.OutageInfo;
SELECT * FROM scratchdb.GeoInfo;
SELECT count(Prefix) FROM scratchdb.LookupTable;



SELECT * FROM test_outage.CollectedFrom;
SELECT * FROM test_outage.DataSet;
SELECT * FROM test_outage.BGPVersion;
SELECT * FROM test_outage.Message;
SELECT * FROM test_outage.LookupTable;
SELECT * FROM test_outage.GeoInfo;
SELECT * FROM test_outage.PingOutage;
SELECT * FROM test_outage.OutageInfo;
SELECT * FROM test_outage.IPTable;
SELECT DATE_FORMAT(OutageStart,'%Y:%m:%d:%H') from (SELECT distinct OutageStart FROM iodb.PingOutage) O;

SELECT DATE_FORMAT('2009-10-04 22:23:00', '%W %M %Y');

SELECT max(OutageEnd) FROM iodb.PingOutage;


SELECT DISTINCT MsgTime,MsgPath.MsgPathID,MsgPath.ASN,MsgPath.PathOrder from Message, MsgPath 
where MsgTime >= '2012-10-26 00:27:44' and MsgTime < '2012-10-27 00:27:44'  and 
Message.MsgPathID = MsgPath.MsgPathID and MsgPath.ASN = "16496";

SELECT DISTINCT MsgTime,MsgPath.MsgPathID,MsgPath.ASN,MsgPath.PathOrder from Message, MsgPath 
where MsgTime >= '2012-10-27 00:27:44' and MsgTime < '2012-10-28 00:27:44'  and 
Message.MsgPathID = MsgPath.MsgPathID and MsgPath.ASN = "16496";

select * from Message where MsgPathID!=0;
select * from IPTable where ID=8;
select * from MsgPath where MsgPathID=1;

select distinct OutageInfo.BlockAggr,OutageInfo.BGP_LPM from iodb.OutageInfo where peerIP like '12.%';


select count(*) from (select distinct PingOutage.BlockAggr,OutageInfo.BGP_LPM from iodb.PingOutage inner join iodb.OutageInfo 
where PingOutage.OutageID=OutageInfo.OutageID and BGP_LPM not like 'default'
and peerIP="12.0.1.63") O
where O.BlockAggr != O.BGP_LPM;

select distinct PingOutage.BlockAggr,OutageInfo.BGP_LPM from iodb.PingOutage inner join iodb.OutageInfo 
where PingOutage.OutageID=OutageInfo.OutageID and BGP_LPM not like 'default'
and peerIP="12.0.1.63";

