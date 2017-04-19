
#!/usr/bin/python


from __future__ import print_function
from collections import defaultdict
from contextlib import closing
import pymysql
import re
import sys
import os
from os import listdir
from os.path import isfile, join

def run_query(db,query): 
    with closing( db.cursor() ) as cur:
	try:
	    cur.execute(query)
	    row=cur.fetchone()
	    while row is not None:
		print(row)
		row=cur.fetchone()

	except:
	    raise Exception('Query Failed')
        

#Preapre DB info
db = pymysql.connect(host="proton.netsec.colostate.edu",
                     user="root", 
                     passwd="n3ts3cm5q1", 
                     db="iodb") 

run_query(db,'select distinct PingOutage.BlockAggr,OutageInfo.BGP_LPM from iodb.PingOutage inner join iodb.OutageInfo where PingOutage.OutageID=OutageInfo.OutageID and BGP_LPM not like "default" and peerIP="12.0.1.63"')

db.close()
