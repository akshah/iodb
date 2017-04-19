select m.PrefixID, ip.IP, count(*) from bgpdata.Message m, bgpdata.IPTable ip where ip.id = m.PrefixID and ip.IP like '68.181.%' group by PrefixID;
select * from Message m, IPTable ip where ip.id = m.PrefixID and ip.IP like '68.181.%'; 
use bgpdata; select o.IPBlock,o.BGP_LPM, m.MsgType,o.BlockAggr, o.OutageStart, o.OutageEnd  from Message m, IPTable ip, PingOutage o where m.PrefixID = ip.id and ip.IP=substring_index(o.BGP_LPM,'/',1) and o.BlockAggr='68.181.0.0/16' order by o.OutageStart limit 2000;
select * from PingOutage where IPBlock != BGP_LPM and IPBlock != BlockAggr;
select * from bgpdata.Message order by MsgTime DESC;
select * from bgpdata.Community;
select * from bgpdata.DataSet;
select MsgID,MsgTime,IP.ip,PrefixMask,MsgType,Med,LocalPref,msg.MsgPathID,path.PathOrder,IP.ip,PeerAS,ASN from bgpdata.Community as Com,bgpdata.Message as msg, bgpdata.MsgPath as path , bgpdata.IPTable IP where msg.MsgPathID=path.MsgPathID and IP.id=msg.PrefixID and Com.CommunityID=msg.CommunityID;
select m.MsgTime, ip.IP, m.PrefixMask, m.MsgType from bgpdata.Message m, bgpdata.IPTable ip where ip.id = m.PrefixID;

use bgpdata; select o.IPBlock,o.BGP_LPM, m.MsgTime, m.MsgType,o.BlockAggr, o.OutageStart, o.OutageEnd  from Message m, IPTable ip, PingOutage o where m.PrefixID = ip.id and ip.IP=substring_index(o.BGP_LPM,'/',1) and o.BlockAggr='68.181.0.0/16' order by o.OutageStart DESC;
select * from LookupTable;
select count(*) from IPTable;
select count(*) from GeoInfo;

SELECT DISTINCT Message.PrefixID,IPTable.ip,Message.PrefixMask FROM Message INNER JOIN `IPTable` on Message.PrefixID=IPTable.id;