#!/bin/bash
mkdir -p tmp

i=0
set +eu
wget -P ./tmp ${WebAppLink}
set -eu

while [ $? ]
do 
    rm ./tmp/*
    sleep 30
    ((i++))
    if [[ "$i" == 9 ]]
    then
        break
    fi
    set +eu
    wget -P ./tmp ${WebAppLink}
    set -eu
done

rm ./tmp/*
i=0
set +eu
wget -P ./tmp ${SlotWebAppLink}
set -eu

while [ $? ]
do 
    rm ./tmp/*
    sleep 30
    ((i++))
    if [[ "$i" == 9 ]]
    then
        break
    fi
    set +eu
    wget -P ./tmp ${SlotWebAppLink}
    set -eu
done

sleep ${SleepTime}