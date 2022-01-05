#!/bin/bash
mkdir -p tmp

i=0
WGET_EXIT_CODE=0

set +eu
wget -P ./tmp ${WebAppLink} || WGET_EXIT_CODE=$?
set -eu

while [ WGET_EXIT_CODE ]
do 
    rm ./tmp/*
    sleep 30
    ((i++))
    if [[ "$i" == 9 ]]
    then
        break
    fi
    set +eu
    wget -P ./tmp ${WebAppLink} || WGET_EXIT_CODE=$?
    set -eu
done

rm ./tmp/*
i=0
set +eu
wget -P ./tmp ${SlotWebAppLink} || WGET_EXIT_CODE=$?
set -eu

while [ WGET_EXIT_CODE ]
do 
    rm ./tmp/*
    sleep 30
    ((i++))
    if [[ "$i" == 9 ]]
    then
        break
    fi
    set +eu
    wget -P ./tmp ${SlotWebAppLink} || WGET_EXIT_CODE=$?
    set -eu
done

sleep ${SleepTime}