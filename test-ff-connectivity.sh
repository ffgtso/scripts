#!/bin/bash
#
# Supposed to run from a VM that's connected via ensX to a
# Gluon-VM. You need a passwordless ssh key installed on the
# Gluon-VM, it's br-client's link-local IPv6 address.
#
# Run via cron, e. g. ...
#
# * * * * * /root/test-ff-connectivity.sh >>/var/tmp/ff.log
#
# Have fun ;)
#
GW=$(/sbin/ip -4 route show | /usr/bin/awk '/^default/ {if($2=="via") {printf("%s", $3);}}')
NOW="$(date +'%Y-%m-%d %H:%M:%S')"
TMPFILE=/var/tmp/$$.tmp
KEYFILE="-i .ssh/YourPrivKey"
GWLLADDR="fe80::dcca:fbff:fead:4201%ens8"

/bin/ping -c 10 -q 1.1.1.1 > ${TMPFILE} 2>&1
extrc=$?
echo >> ${TMPFILE}
if [ -n "$GW" ]; then
 /bin/ping -c 10 -q "$GW" >> ${TMPFILE} 2>&1
 defrc=$?
  echo >> ${TMPFILE}
fi

if [ $extrc -eq 0 ]; then
 echo -n "${NOW}: EXT. OK   " >> ${TMPFILE}
else
 echo -n "${NOW}: EXT. FAIL " >> ${TMPFILE}
fi

if [ -n "$GW" ]; then
 if [ $defrc -eq 0 ]; then
  echo -n "/ DEFAULT OK    " >> ${TMPFILE}
 else
  echo -n "/ DEFAULT FAIL  " >> ${TMPFILE}
 fi
else
 echo -n "/ DEFAULT MISSING " >> ${TMPFILE}
fi
echo >> ${TMPFILE}
echo >> ${TMPFILE}
echo "Gateway status:" >> ${TMPFILE}
/usr/bin/ssh ${KEYFILE} ${GWLLADDR} batctl gwl >${TMPFILE}-2
gws=$(sed -e 's/^=> /   /g' <${TMPFILE}-2 | awk '/Bit/ {printf("%s ", $1);}')
cat ${TMPFILE}-2 >> ${TMPFILE}
/bin/rm ${TMPFILE}-2
echo "${gws}" | /bin/grep : >/dev/null && for i in ${gws} ; do /usr/bin/ssh ${KEYFILE} ${GWLLADDR} echo \; batctl tr $i >> ${TMPFILE} ; done
echo -e "\n==========\n" >> ${TMPFILE}
cat ${TMPFILE}
/bin/rm ${TMPFILE}
