#Output file name format: pings.isi-ant.j.2012.10.27.00.27.44
#IP|NumRounds|Density|Outage-Rounds
awk -F'\t' '{if(NR>1 && $12!="-")print$2"|"$4"|"$5"|"$6}'
