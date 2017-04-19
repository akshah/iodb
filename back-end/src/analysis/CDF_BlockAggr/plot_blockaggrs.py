import pylab as pl
import datetime

data = """10525 16
0 17
0 18
78 19
0 20
1048 21
284 22
4178 23
162893 24"""
values = []
prefix = []

for line in data.split("\n"):
    x, y = line.split()
    values.append(int(x))
    prefix.append(int(y))
fig = pl.figure()
ax = pl.subplot(111)
ax.bar(prefix, values, align='center')
ax.set_xticks(prefix)
#ax.set_xticklabels(["16","17","18","19","20","21","22","23","24"])
ax.set_xlabel("Aggregated Prefix")
pl.show()
