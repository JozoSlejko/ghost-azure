#!/bin/bash
mkdir -p tmp

i=0
wget -P ./tmp ${WebAppLink}

while [ $? ]
do 
    rm ./tmp/*
    sleep 30
    ((i++))
    if [[ "$i" == 9]]; then
        break
    fi
    wget -P ./tmp ${WebAppLink}
done

rm ./tmp/*
i=0
wget -P ./tmp ${SlotWebAppLink}

while [ $? ]
do 
    rm ./tmp/*
    sleep 30
    ((i++))
    if [[ "$i" == 9]]; then
        break
    fi
    wget -P ./tmp ${SlotWebAppLink}
done

sleep ${SleepTime}