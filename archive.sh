#!/bin/bash
echo "-----------------" >> /var/log/archive.log
echo `date` >> /var/log/archive.log

BACKUP_REPO=$(curl --silent -XGET "http://localhost:9200/_snapshot/_all?pretty" | grep "location" | awk '{print $3}')

if [[ "${BACKUP_REPO}" != "\"/mnt/archived/esbackup"\" ]]

then
        echo "Before running this script, you need to run below steps for very first time:"

        echo "1:- Add below line to /etc/elasticsearch/elasticsearch.yml"

        echo "path.repo: [\"/mnt/archived/esbackup\"]"

        echo "2:- Rolling restart:"

        echo "2.1:- first disable shard allocation:"

        echo "curl -XPUT /_cluster/settings { \"transient\" : { \"cluster.routing.allocation.enable\" : \"none\" } }"

        echo "2.2:- restart the node service elasticsearch restart"

        echo "2.3:- Enable shard allocation:"

        echo "curl -XPUT /_cluster/settings { \"transient\" : { \"cluster.routing.allocation.enable\" : \"all\" } }"

        echo "3: Create backup repo:"

        echo "curl -XPUT -H \"Content-Type: application/json;charset=UTF-8\" 'http://localhost:9200/_snapshot/esbackup' -d '{"
        echo  " \"type\": \"fs\","
        echo  " \"settings\": {"
        echo  " \"location\": \"/mnt/archived/esbackup\","
        echo  " \"compress\": true"
        echo  " }"
        echo "}'"
else
        echo "Backup Repo esbackup found"
fi

echo "For Restoring Index of particular Month, Reffer file stored here: /mnt/archived/restore_ref" | tee -a /var/log/archive.log
echo "-----------------" >> /mnt/archived/restore_ref
echo `date` >> /mnt/archived/restore_ref

curl -s -XGET localhost:9200/_cat/indices?h=i,creation.date.string | grep graylog_ | sort -n|awk '{print $1,$2}' >> /mnt/archived/restore_ref

CURRENT_DATE=$(date +%F)

/usr/bin/curl -s -XGET localhost:9200/_cat/indices?h=i,creation.date | grep graylog_ | sort -rn|awk '{print $1,$2}'| tail -5  > /tmp/olderindices

FILE="/tmp/olderindices"

FILE_LENGTH=$(wc -l < ${FILE})

STARTING_FROM=0

while read  -r line ; do

        STARTING_FROM=$((${STARTING_FROM} + 1 ))

        #Get he Index Name:

        INDEX_NAME=$(awk 'NR=='${STARTING_FROM}' {print $1}' "${FILE}")

        #Index creation time in Miliseconds

        INDEX_CREATION_DATE_MS=$(awk 'NR=='${STARTING_FROM}' {print $2}' "${FILE}")

        #Convert to  Regular Date

        INDEX_CREATION_DATE=$(date -d @$(( (${INDEX_CREATION_DATE_MS} + 500) / 1000 )) +%F )

        #Calculating Index Date

        AGE_OF_INDEX=$(( ($(date -d $CURRENT_DATE +%s) - $(date -d $INDEX_CREATION_DATE +%s)) / 86400 ))

        if (( "${AGE_OF_INDEX}" >= "90" )); then

                echo "$INDEX_NAME is 90 days older: Checking in archived Repo.." | tee -a /var/log/archive.log

                #Check for already in archived:

                CHECK_ARCHIVED=`/usr/bin/curl -s -XGET http://localhost:9200/_cat/snapshots/esbackup | grep ${INDEX_NAME} | awk {'print $2'}`

                if [[ "${CHECK_ARCHIVED}" == "SUCCESS" ]]

                then

                        echo "${INDEX_NAME} is already archived" | tee -a /var/log/archive.log

                        echo "Deleting ${INDEX_NAME} as it is already Archived" | tee -a /var/log/archive.log

                        /usr/bin/curl -s -X DELETE "http://localhost:9200/${INDEX_NAME}?pretty"  | tee -a /var/log/archive.log > /dev/null 2>&1

                        if [[ "$?" == "0" ]]
                       
                       then
                               
                               DELETED=$(/usr/bin/curl --silent 'http://127.0.0.1:9200/_cat/indices/' | grep ${INDEX_NAME}|awk '{print $3'})
                       
                       fi
                       
                       if [[ "${DELETED}" != "${INDEX_NAME}" ]]

                        then

                                echo "${INDEX_NAME} has been deleted.." | tee -a /var/log/archive.log

                        else

                                echo "${INDEX_NAME} Could not be deleted.." | tee -a /var/log/archive.log

                        fi

                else

                        echo "${INDEX_NAME} is not yet Archived, archiving it, please wait till finish.." | tee -a /var/log/archive.log

                        /usr/bin/curl --silent -XPUT -H "Content-Type: application/json;charset=UTF-8" "http://localhost:9200/_snapshot/esbackup/${INDEX_NAME}?wait_for_completion=true" -d '{ "indices":"'${INDEX_NAME}'", "ignore_unavailable":"true", "include_global_state": false }' | tee -a /var/log/archive.log  > /dev/null 2>&1

                        if [[ "$?" == "0" ]]; then

                                OUTPUT=`/usr/bin/curl -s -XGET http://localhost:9200/_cat/snapshots/esbackup | grep ${INDEX_NAME} | awk {'print $2'}`

                                if [[ "${OUTPUT}" == "SUCCESS" ]]

                                then

                                        echo "Successfully Archived ${INDEX_NAME}" | tee -a /var/log/archive.log

                                        echo "Now, Deleting from Index list.."

                                        /usr/bin/curl --silent -X DELETE "http://localhost:9200/${INDEX_NAME}?pretty"  | tee -a /var/log/archive.log > /dev/null 2>&1

                                        /usr/bin/curl --silent 'http://127.0.0.1:9200/_cat/indices/' |awk '{print $3,$4,$9'}| grep ${INDEX_NAME}|wc -l | tee -a /var/log/archive.log > /dev/null 2>&1

                                        if [[ "$?" == 0 ]]

                                        then

                                                echo "${INDEX_NAME} has been deleted.." | tee -a /var/log/archive.log

                                        else

                                                echo "${INDEX_NAME} Could not be deleted.." | tee -a /var/log/archive.log

                                        fi
                                else

                                        echo "Error Occured while Archiving ${INDEX_NAME}" | tee -a /var/log/archive.log

                                fi

                        else

                                echo "Archiving ${INDEX_NAME} failed!!" | tee -a /var/log/archive.log

                        fi
                fi

        else
                echo "$INDEX_NAME is not 90 days older" | tee -a /var/log/archive.log

        fi

done < ${FILE}
