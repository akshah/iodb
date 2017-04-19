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
		db="iodb") # name of the data base

cur = db.cursor() 


print('Connected to DB')

# Use all the SQL you like
#cur.execute("SELECT p.IPBlock,o.PeerIP,o.BGP_LPM,p.OutageStart,p.OutageEnd FROM iodb.PingOutage p,iodb.OutageInfo o,iodb.IPTable ip where p.OutageID=o.OutageID and o.PeerIP=ip.IP and o.BGP_LPM != 'default'")

cur.execute("SELECT * from PingOutage")

print('Executing Querry')
#IPBlock=[]
#BGP_LPM=[]
#MsgType=[]
#MsgTime=[]
#BlockAggr='68.181.0.0/16'
#OutageStart=[]
#OutageEnd=[]

# print all the first cell of all the rows
row = ''
num_entries=0
row=cur.fetchone()
print('Will fetch more')
while row:
    if num_entries == 3:
	break
    #(IPBlock,PeerIP,BGP_LPM,OutageStart,OutageEnd)=row
    print(row)
    num_entries+=1
    row=cur.fetchone()

