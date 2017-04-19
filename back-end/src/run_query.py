
#!/usr/bin/python


from __future__ import print_function
from collections import defaultdict
from contextlib import closing

import MySQLdb
import sys

def run_query(db,query):
    toReturn=[]
    with closing( db.cursor() ) as cur:
	try:
	    cur.execute(query)
	    row=cur.fetchone()
	    while row is not None:
		print(row)
		toReturn.append(row)
		row=cur.fetchone()

        except:
           raise Exception('Query Failed')
    return toReturn

#Preapre DB info
db = MySQLdb.connect(host="proton.netsec.colostate.edu",
                     user="root", 
                     passwd="n3ts3cm5q1", 
                     db="iodb") 

result=run_query(db,'SELECT PeerIPID FROM Message;')
#for result_v in result:
#	print(result_v)

db.close()
