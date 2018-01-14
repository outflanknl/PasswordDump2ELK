#!/bin/sh
# Script to sanitize the input files of password dumps, and to send it to a logstash instance running on localhost:3515
#
# Run: ./sanitizePasswordDump.sh $inputfile $DumpName
#
# Inputfile is expected to contain per line: username:password
# Exports to logstash in the form of: DumpName EmailAddress Passowrd EmailDomain
#
# Author: Outflank B.V. / Marc Smeets / @mramsmeets
#
#

if [ $# -eq 0 ] ; then
    echo '[X] Error - need name of file to work on as 1st parameter, and optinally name of dump as 2nd parameter.'
    exit 1
fi

if [ ! -f $1 ] ; then
    echo "[X] ERROR - $1 not found."
    exit 1
fi

if  [ ! hash uconv 2>/dev/null ] ; then
       echo '[X] ERROR - uconv required (apt install icu-devtools)'
       exit 1
    fi

echo "[*] Working on file $1"

if [ $# -eq 1 ] ; then
    echo '[!] Warning - missing name of dump as 2nd parameter, setting it to NoDumpName.'
    DUMPNAME=NoDumpName
else
    DUMPNAME=$2
fi

FILENAME=`basename $1`
STARTNRLINES=`wc -l $1|awk '{print $1}'`
echo "[*] Source file has $STARTNRLINES lines."
echo "[*] Will perform the following actions: "
echo "[+]   Remove spaces"
echo "[+]   Convert to all ASCII"
echo "[+]   Remove non printable characters"
echo "[+]   Remove lines without proper email address format"
echo "[+]   Remove lines without a colon (errors)"
echo "[+]   Remove lines with empty username"
echo "[+]   Remove lines with empty passwords"
echo "[+]   Remove really long lines (60+ char)"
echo "[+]   Remove Russian email addresses (.ru)"

# remove spaces and convert to ASCII
cat $1|tr -d " "|uconv -i -c -s -t ASCII | \
# remove non printable chars
tr -dC '[:print:]\t\n' | \
# only valid email addresses
grep -E "\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,6}\b" | \
# remove without colon
grep -E \:  | \
# remove empty usernames
grep -v -E ^\: | \
# remove empty passwords - find emailaddress folowd by :$
grep -v -E "\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,6}\b\:$"  | \
# remove long lines
grep -v '.\{60\}' | \
# remove Russion addresses
grep -v -i ".ru" > /tmp/sanitized$FILENAME

ENDNRLINES=`wc -l /tmp/sanitized$FILENAME|awk '{print $1}'`
echo "[*] Halfway: sanitized file has $ENDNRLINES lines."

echo "[+] Rearranging in desired format"
# prefered input is name@emaildomain.com:password - we need these in format: Dumpname name@emaildomain.com password emaildomain.
# we use awk -v to insert the var of the Dumpname, and we use the split function to get only the domainname of the email address.
# However, the split function returns a number for the amount of items in the array. So we end up with:
# Dumpname name@emaildomain.com password 2 emaildomain.
# The if statement in the awk oneliner makes sure that in case of input file errors where the password field starts with a ":", we pick skip over that ":"

# We use the 2 to grep for all lines that have a username and password.
# We also grep for lines ending with a 1, for the highly unlikely cases where there was a 2 inserted due to input file errors

awk -v d="$DUMPNAME" -F":" '{if ($2=="")print d,$1,":"$3, split($1,a,"@")  " " a[2]; else print d,$1,$2, split($1,a,"@") " " a[2]}' /tmp/sanitized$FILENAME |grep " 2 " |grep -v -E ' 1 $'| awk '{print $1,$2,$3,$5}'  > /tmp/sanitized2$FILENAME

ENDNRLINES=`wc -l /tmp/sanitized2$FILENAME|awk '{print $1}'`
echo "[*] Sanitized file has $ENDNRLINES lines."

echo "[+] Sending to Logstash"
cat /tmp/sanitized2$FILENAME | nc -v 127.0.0.1 3515

echo "[*] Cleaning up /tmp dir"
rm /tmp/sanitized*$FILENAME

echo "[*] Done with file $1"
echo ""