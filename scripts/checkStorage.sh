#!/bin/bash
echo "Check ${StorageName} storage..."

i=0
while [ $(az storage account check-name -n "${StorageName}" --query nameAvailable) ]
do 
    sleep 30
    ((i++))
    if [[ "$i" == 9 ]]; then
        break
    fi
done

echo "Done"