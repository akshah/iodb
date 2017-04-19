
#!/usr/bin/python
import MySQLdb
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.mlab as mlab
from scipy.optimize import curve_fit


db = MySQLdb.connect(host="proton.netsec.colostate.edu", # your host, usually localhost
		             user="root", # your username
				passwd="n3ts3cm5q1", # your password
		db="iodb") # name of the data base

# you must create a Cursor object. It will let
#  you execute all the queries you need
cur = db.cursor() 



# Use all the SQL you like

cur.execute("select BlockAggr from PingOutage;")

# print all the first cell of all the rows
row = ''
num_entries=0
row=cur.fetchone()

while row:
	result=row
	print(result[0])
	num_entries+=1
	row=cur.fetchone()
