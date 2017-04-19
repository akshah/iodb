#Output file name format: pings.isi-ant.A.YYYY.MM.DD.hh.mm.ss
#HexIP|VantageStatus|Uncertainty|OutageStart|Duration
awk -F'\t' '{print$1"|"$5"|"$4"|"$2"|"$3}' | grep -v "fsdb" | grep [a-z]
