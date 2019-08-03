#!/bin/bash
#
# Supposed to run from a VM that's connected via ensX to a
# Gluon-VM. You need a passwordless ssh key installed on the
# Gluon-VM, it's br-client's link-local IPv6 address. Have
# fun ;)
#
GW=$(/sbin/ip -4 route show | /usr/bin/awk '/^default/ {if($2=="via") {printf("%s", $3);}}')
NOW="$(date +'%Y-%m-%d %H:%M:%S')"
TMPFILE=/var/tmp/$$.tmp
KEYFILE="-i .ssh/UU-FF"
GWLLADDR="fe80::37ff:feb0:bd4d%ens3"
MAXWAIT=90

echo -n > ${TMPFILE}

(echo -n "$(date +'%H:%M:%S') - " > ${TMPFILE}-pingext; /bin/ping -c 10 -q 1.1.1.1 >> ${TMPFILE}-pingext 2>&1; echo $? > ${TMPFILE}-pingext-rc) & 2>/dev/null
if [ -n "$GW" ]; then
 (echo -n "$(date +'%H:%M:%S') - " > ${TMPFILE}-pingdef; /bin/ping -c 10 -q "$GW" >> ${TMPFILE}-pingdef 2>&1; echo $? > ${TMPFILE}-pingdef-rc) & 2>/dev/null
fi

echo "$(date +'%H:%M:%S') - Batman status:" > ${TMPFILE}-batman
/usr/bin/ssh ${KEYFILE} ${GWLLADDR} batctl gwl >${TMPFILE}-2
gws=$(sed -e 's/^=> /   /g' -e 's/^\* /  /g' <${TMPFILE}-2 | awk '/Bit/ {printf("%s ", $1);}')
cat ${TMPFILE}-2 >> ${TMPFILE}-batman
/bin/rm ${TMPFILE}-2
echo "${gws}" | /bin/grep : >/dev/null
if [ $? -eq 0 ]; then
 for i in ${gws}
 do
  (echo -ne "\n$(date +'%H:%M:%S') - " > ${TMPFILE}-batman-${i}; /usr/bin/ssh ${KEYFILE} ${GWLLADDR} batctl tr $i >> ${TMPFILE}-batman-${i}; echo $? > ${TMPFILE}-batman-${i}-rc) & 2>/dev/null
 done

 for i in ${gws}
 do
  cnt=0
  while [ ! -e ${TMPFILE}-batman-${i}-rc ]; do sleep 1; cnt=$(expr $cnt + 1 ); if [ $cnt -gt $MAXWAIT ]; then echo "TIMEOUT batman trace ${i}" >> ${TMPFILE}-batman-${i}; fi; done
 done

 for i in ${gws}
 do
  cat ${TMPFILE}-batman-${i} >>${TMPFILE}-batman
 done
fi

cnt=0
while [ ! -e ${TMPFILE}-pingext-rc ]; do sleep 1; cnt=$(expr $cnt + 1 ); if [ $cnt -gt $MAXWAIT ]; then echo "TIMEOUT ping ext"; fi; done
extrc="$(cat ${TMPFILE}-pingext-rc)"

if [ -n "$GW" ]; then
 cnt=0
 while [ ! -e ${TMPFILE}-pingdef-rc ]; do sleep 1; cnt=$(expr $cnt + 1 ); if [ $cnt -gt $MAXWAIT ]; then echo "TIMEOUT ping int"; fi; done
 defrc="$(cat ${TMPFILE}-pingdef-rc)"
fi

if [ "${extrc}" = "0" ]; then
 echo -n "${NOW}: EXT. OK   " >> ${TMPFILE}
else
 echo -n "${NOW}: EXT. FAIL " >> ${TMPFILE}
fi

if [ -n "$GW" ]; then
 if [ "${defrc}" = "0" ]; then
  echo -n "/ DEFAULT OK    " >> ${TMPFILE}
 else
  echo -n "/ DEFAULT FAIL  " >> ${TMPFILE}
 fi
else
 echo -n "/ DEFAULT MISSING " >> ${TMPFILE}
fi
echo >> ${TMPFILE}

echo >> ${TMPFILE}
cat ${TMPFILE}-pingext >> ${TMPFILE}

if [ -n "$GW" ]; then
 echo >> ${TMPFILE}
 cat ${TMPFILE}-pingdef >> ${TMPFILE}
fi

echo >> ${TMPFILE}
cat ${TMPFILE}-batman >> ${TMPFILE}
echo -e "\n==========\n" >> ${TMPFILE}
cat ${TMPFILE}
/bin/rm ${TMPFILE} ${TMPFILE}-*
