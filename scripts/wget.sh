#!/bin/bash
mkdir -p tmp

i=0
WGET_EXIT_CODE=1

set +eu
wget -P ./tmp ${WebAppLink} &>/dev/null && WGET_EXIT_CODE=$? || WGET_EXIT_CODE=$?

while [ WGET_EXIT_CODE ]
do 
    rm ./tmp/* &>/dev/null
    sleep 30
    ((i++))
    if [[ "$i" == 9 ]]
    then
        break
    fi
    wget -P ./tmp ${WebAppLink} &>/dev/null && WGET_EXIT_CODE=$? || WGET_EXIT_CODE=$?
done

rm ./tmp/* &>/dev/null
i=0

wget -P ./tmp ${SlotWebAppLink} &>/dev/null && WGET_EXIT_CODE=$? || WGET_EXIT_CODE=$?

while [ WGET_EXIT_CODE ]
do 
    rm ./tmp/* &>/dev/null
    sleep 30
    ((i++))
    if [[ "$i" == 9 ]]
    then
        break
    fi
    wget -P ./tmp ${SlotWebAppLink} &>/dev/null && WGET_EXIT_CODE=$? || WGET_EXIT_CODE=$?
done

sleep ${SleepTime}