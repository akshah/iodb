import numpy as np
import statsmodels.api as sm # recommended import according to the docs
import matplotlib.pyplot as plt
import matplotlib.ticker as mtick

with open("/raid/akshah/BGP-Ping-Data/raw_data/demo_data/iodb2_durations", "r") as ins:
    sample = []
    for line in ins:
	line=line.rstrip()
	if not line.isdigit():
	    print("ERROR")
	    break
	sample.append(float(line)/3600)

#print(sample)
#sample =[0,0,0,1,2,3,4,4,4,4,4,4,56,56,56,64,47,0,1,3,34,34,45,57,57,58,58,56,88]
ecdf = sm.distributions.ECDF(sample)

x = np.linspace(min(sample), max(sample))
y = ecdf(x)
plt.step(x, y)
plt.ylim(0.92,1)
#plt.xlim(0,3)
plt.ylabel('Ratio')
plt.xlabel('Hours')
plt.show()
