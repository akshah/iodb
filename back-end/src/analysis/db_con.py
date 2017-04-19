#!/usr/bin/python
import MySQLdb
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.mlab as mlab
from scipy.optimize import curve_fit


def standard(data):
	mean=np.mean(data)
	std=np.std(data)
	return (data - mean)/std

db = MySQLdb.connect(host="proton.netsec.colostate.edu", # your host, usually localhost
		             user="root", # your username
				passwd="n3ts3cm5q1", # your password
		db="bgpdata") # name of the data base

# you must create a Cursor object. It will let
#  you execute all the queries you need
cur = db.cursor() 


time='2014-08-01 00%'
# Use all the SQL you like
cur.execute("select o.IPBlock,o.BGP_LPM, m.MsgType,unix_timestamp(m.MsgTime),o.BlockAggr, unix_timestamp(o.OutageStart), unix_timestamp(o.OutageEnd)  from Message m, IPTable ip, PingOutage o where m.PrefixID = ip.id and ip.IP=substring_index(o.BGP_LPM,'/',1) and o.BlockAggr='68.181.0.0/16' order by o.OutageStart;")
#cur.execute("select * from bgpdata.PingOutage;")

IPBlock=[]
BGP_LPM=[]
MsgType=[]
MsgTime=[]
BlockAggr='68.181.0.0/16'
OutageStart=[]
OutageEnd=[]

# print all the first cell of all the rows
row = ''
num_entries=0
row=cur.fetchone()
start_epoch=1351036800
ylist = [0] * 691200
while row:
	IPBlock.append(row[0])
	BGP_LPM.append(row[1])
	MsgTime.append(row[3])
	if row[2]=='A':
		MsgType.append('1')
		ylist[row[3]-start_epoch]=1
	else:
		MsgType.append('-1')
		ylist[row[3]-start_epoch]=-1	
#	BlockAggr.append(row[4])
	OutageStart.append(row[5]-start_epoch)
	OutageEnd.append(row[6]-start_epoch)
	num_entries+=1
	row=cur.fetchone()

ydata=[]
outagetimes=[]
index=0
xdata = np.arange(691200)
it=0
while it <=691140:
	#ydata[it] = np.sum(ylist[it:it+59])
	val=np.sum(ylist[it:it+59])
	val=np.sum(ylist[it:it+59])
	ydata.append(val)
	it+=60
	index+=1

plt.figure(1)
plt.suptitle('Block 68.181.0.0/16')
plt.subplot(1,1,1)
plt.plot(ylist,'-b')
for ot in OutageEnd:
	plt.plot(ot,0,'ro')

plt.show()
