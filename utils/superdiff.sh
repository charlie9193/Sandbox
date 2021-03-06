#!/bin/bash
function usage {
   echo "Usage: $0 <file1> <file2>"
   echo "Will run vimdiff on the two files in question, if they differ"
   echo "Primarily meant for pulling remote changes and comparing"
   echo "For remote files, do username?password@IP:file"
   echo "For local files, just the filename will do"
}

function get_ip_and_file {
    IP_AND_FILE=$(echo $1 | awk '{split($1,x,"@");print x[2]}')
    echo $IP_AND_FILE
}

function get_username_and_password {
    USERNAME=$(echo $1 | awk '{split($1,x,"@");print x[1]}')
    echo $USERNAME
}

function local_or_remote {
    #Will 1 for remote, 0 for local
    if [[ -z $(get_ip_and_file $1) ]];then
        echo 0
    else
        echo 1
    fi
}

function get_username {
    USERNAME=$(echo $1 | awk '{split($1,x,"?");print x[1]}')
    echo $USERNAME
}

function get_password {
    PASSWORD=$(echo $1 | awk '{split($1,x,"?");print x[2]}')
    echo $PASSWORD
}

function get_ip {
    IP_ADDR=$(echo $1 | awk '{split($1,x,":");print x[1]}')
    echo $IP_ADDR
}
function get_filename {
    FILENAME=$(echo $1 | awk '{split($1,x,":");print x[2]}')
    echo $FILENAME
}

function get_remote {
OUTFILE=$1
        /usr/bin/expect << EOF > $OUTFILE 
spawn $SSH_CALL_BASE$USERNAME@$IP_ADDR
expect -re {.*?assword:.*} 
send $PASSWORD\n
expect -re {.*[#$] $}
send "$CAT_CMD\n"
expect -re {.*[#$] $} 
exit
EOF
        sed -i '$d' $OUTFILE
        SUPERDIFF_TAG="SUPERDIFF"
        sed -i "1s/^/$SUPERDIFF_TAG/" $OUTFILE
        #Use end tag to avoid issues with / in path
        sed -i "/$SUPERDIFF_TAG/,/${FILENAME##*/}/d" $OUTFILE
        #Get rid of non-standard newlines
        tr -d '\r' < $OUTFILE > stmp.superdiff
        mv stmp.superdiff $OUTFILE
}

if [[ $# -lt 2 ]];then
    usage
    exit 1
fi

SSH_CALL_BASE="ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no "
TEMP_EXT=".superdiff"
DIFF_FILES=""
ITR=1
for i in $1 $2; do
    if [[ $(local_or_remote $i) -eq 1 ]]; then
        #echo "$i seems to be a remote file"
        USERNAME_AND_PASSWORD=$(get_username_and_password $i) 
        IP_AND_FILE=$(get_ip_and_file $i)
        USERNAME=$(get_username $USERNAME_AND_PASSWORD)
        PASSWORD=$(get_password $USERNAME_AND_PASSWORD)
        FILENAME=$(get_filename $IP_AND_FILE)
        IP_ADDR=$(get_ip $IP_AND_FILE)
        CAT_CMD="cat $FILENAME"
        EXPECT_OUTFILE=${FILENAME##*/}$TEMP_EXT.remote.$ITR
        get_remote $EXPECT_OUTFILE
        DIFF_FILES+=" $(echo $EXPECT_OUTFILE)"
    else
        #echo "$i seems to be a local file"
        FILENAME=$i
        if [[ ! -f $FILENAME ]]; then
            echo "Local file $FILENAME does not exist!"
            rm *$TEMP_EXT.*.[1-9]
            exit 1 
        fi
        LOCAL_OUTFILE=${FILENAME##*/}$TEMP_EXT.local.$ITR
        ln -s $FILENAME $LOCAL_OUTFILE
        DIFF_FILES+=" $(echo $LOCAL_OUTFILE)"
    fi
    ITR=$((ITR + 1))
done
echo "Preparing to diff files $DIFF_FILES"
if [[ -z $(diff $DIFF_FILES) ]];then
    echo "These files are identical"
    rm *$TEMP_EXT.*.[1-9]
else
    vimdiff $DIFF_FILES
    rm *$TEMP_EXT.*.[1-9]
fi
