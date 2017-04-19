import matplotlib.pyplot as plt
import numpy as np


zd1=np.loadtxt('pfxlen2',delimiter=',',usecols=(0,0))
xd1=np.loadtxt('pfxlen2',delimiter=',',usecols=(1,1))
yd1=np.loadtxt('pfxlen2',delimiter=',',usecols=(2,2))
xd=xd1[:,0]
yd=yd1[:,0]
zd=zd1[:,0]

plt.figure(figsize=(15, 10))
ax1 = plt.subplot(211)
#dx_in_points = np.diff(ax1.transData.transform(zip([0]*len(zd), zd))) 
colors = np.random.rand(len(xd))
ax1.scatter(xd,yd, c='r',alpha=0.85, s=(zd), edgecolors='red')
ax1.set_xlabel('Length of block that suffered an outage')
ax1.set_ylabel('Length of BGP Prefex \nthat covered the outage prefix')
ax1.set_title('Scatter plot: Length of outage prefix vs length of corresponding BGP Prefex')
plt.annotate('Most commonly /24 blocks with a /16 suffered an outage', xy=(23.2,16),xytext=(17,4),fontsize=12,arrowprops=dict(arrowstyle='->', connectionstyle='arc3,rad=0.4', color='blue'))
plt.annotate('Few points along 45 degree show cases\nwhere entire BGP block suffered an outage', xy=(16,16),xytext=(12,20),fontsize=12,arrowprops=dict(arrowstyle='->', connectionstyle='arc3,rad=0.4', color='blue'))
#area = np.pi * (20 * n for n in range(len(xd)))
#ax1.scatter(xd, yd, s=area, c=colors, alpha=0.5)

ax1.set_ylim([0,32])
ax1.set_xlim([10,25])
#plt.show()



x1=np.loadtxt('headpfxlen.csv',delimiter=';',usecols=(0,0))
x=x1[:,0]
y=["24,16","24,13","24,19","24,12","24,17","24,18","24,14","24,15","24,20","24,11","24,24","24,21","24,10","24,22","24,8","24,23","24,9","23,16","23,15","23,12"]
ax = plt.subplot(212)
#ax.scatter(x,y)
width=0.8
ax.bar(range(len(x)),x,width=width)

#ax.set_ylim([0,32])
#ax.set_xlim([0,32])
ax.set_xticks(np.arange(len(y)) + width/2)
ax.set_xticklabels(y, rotation=70)

plt.annotate('Most commonly /24 blocks with a /16 suffered an outage', xy=(1,8000),xytext=(6,5000),fontsize=12,arrowprops=dict(arrowstyle='->', connectionstyle='arc3,rad=0.2', color='red'))
ax.set_xlabel('Length of Outage prefix , Length of covering BGP Block\ne.g.,(23,12): Cases where /23 block with a /12 block suffered an outage')
ax.set_ylabel('#Number of Outages')
ax.set_title('Count of outages for top 20 length of outage prefix and length of corresponding BGP Prefex')
plt.show()
