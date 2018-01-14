#!/bin/sh
# Script to search data in Elasticsearch that was imported with the sanitizePasswordDump.sh script
# This script is mainly useful when the regular kibana interface shows too much info, and or if you want
# the search data to be presented in the username:password format

# Only parameter is the search parameter for the Domain field.
# Example: searchPasswordDump.sh *gmail.com*

# Author: Outflank B.V. / Marc Smeets / @mramsmeets
#
#

if [ $# -eq 0 ] ; then
    echo '[X] Error - need Domain search as 1st parameter.'
    exit 1
fi

DOMAINSEARCH=$1

QUERY=$(cat <<EOF
{ "query": { "query_string" : { "fields" : ["Email", "Password"], "query" : "Domain:$DOMAINSEARCH", "use_dis_max" : true } } }
EOF
)

curl -s -XGET 'localhost:9200/_search?size=10000&pretty' -H 'Content-Type: application/json' -d "$QUERY" | grep -E 'Email|DumpName|Domain|Password'|awk -F: '{print $2}' | awk 'BEGIN { FS="\",\n";RS="\"\n";OFS=":"} {print $1,$4}' | tr -d '" '