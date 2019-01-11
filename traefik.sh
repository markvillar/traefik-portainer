#!/bin/bash

############################################################
##  This script parses traefik's api                      ##
##  in order to retrieve ip addresses and domain names    ## 
##  to add them to the /etc/hosts file for local access.  ##
############################################################

#############################################
##  FUNCTION FROM http://regexraptor.net/  ##
#############################################
function regex_return_all_matches() {
    # Input
    pattern=$1
    text=$2

    #
    # Enter loop to find all regex matches

    # text_step is used in the loop below for the next string group to check
    text_step=$text
    # r_match[0] here is probably unnecessary, but helps me know it will be used below
    declare -g r_match[0]=""
    # Loop counter. Very important!
    i=0
    # Loop max. Ensures we don't hang on the webserver
    loop_max=${#text}
    for (( ; ; ))
    do
            #
            #Compute the regex, see if it is present
            #
            [[ "$text_step" =~ $pattern ]]
            regex_computed="${BASH_REMATCH[0]}"
            
            #
            # Exit if there are NO matches
            #
            if [[ ${#BASH_REMATCH[*]} -eq 0 ]]
            then
                    break
            fi
            
            #
            # Capture the match in the numbered array variable
            #
            r_match[i]="$regex_computed"
            
            #
            # Prepare the next text_step
            #
            text_step=${text_step#*$regex_computed}

            #
            # Increment the index array counter
            #
            i=$((i+1))
            
            # safety check: Ensure that loop doesn't hang on webserver indefinitely
            #       Done by doing a sanity check: can't loop for more than the # of 
            #       Characters in the input text string
            if [[ $i -gt $loop_max ]]
            then
                    break
            fi
    done
}


####################
##   DEFINE VAR   ##
####################
SERVER_LIST=$(curl -u admin:admin -s "http://traefik.docker.for.mac.localhost:8080/api/providers/docker/backends" | jq . | grep server- | egrep -v portainer | egrep -v traefik)
PATTERN_SERVER='[a-z0-9\-]+'
PATTERN_IP='[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}'


#######################
##  GET ALL SERVERS  ##
#######################

declare -g r_match=""
regex_return_all_matches $PATTERN_SERVER "$SERVER_LIST"

result_count=${#r_match[*]}
for (( i=0; i<$result_count; i++))
do
    servers[$i]="${r_match[i]:7}"
done


############################
##  GET ALL IP BY SERVER  ##
##  AND ADD IN HOST FILE  ##
############################
for server in ${servers[*]}
do
    unset r_match
    STRING_IP_NOT_CLEAN=$(curl -u admin:admin -s "http://traefik.docker.for.mac.localhost:8080/api/providers/docker/backends/backend-$server/servers/server-$server" | jq . | grep url )
    regex_return_all_matches $PATTERN_IP "$STRING_IP_NOT_CLEAN"
    
    result_count=${#r_match[*]}
    for (( i=0; i<$result_count; i++))
    do
        retval=$(grep "${r_match[i]} $server.docker.for.mac.localhost" /etc/hosts)
        if [ ${#retval} -ge 1 ]  
            then echo "${r_match[i]} $server.docker.for.mac.localhost is already in /etc/hosts" 
        else 
            echo "${r_match[i]} $server.docker.for.mac.localhost" >> /etc/hosts
            echo "${r_match[i]} $server.docker.for.mac.localhost has been added to /etc/hosts" 
        fi
    done
done

