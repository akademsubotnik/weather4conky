#!/bin/bash

########################################################################
# Setting Defaults
########################################################################

apiKey="c4d3d5b684b507cc18a434305d02b8ea"
defaultLocation="703447"
Conky="True"
Terminal="True"
degreeCharacter="c"
data=0
lastUpdateTime=0
dynamicUpdates=0
UseIcons="True"
colors="True"

source "$HOME/.bashcolors"

if [ -z $apiKey ];then
    echo "No API Key specified in rc, script, or command line."
    exit
fi

########################################################################
# Do we need a new datafile? If so, get it.
########################################################################

if [ -z "${CachePath}" ];then
    dataPath="/tmp/fore-$defaultLocation.json"
else
    dataPath="${CachePath}/fore-$defaultLocation.json"
fi

if [ ! -e $dataPath ];then
    touch $dataPath
    data=$(curl -s "http://api.openweathermap.org/data/2.5/forecast?id=$defaultLocation&units=metric&appid=$apiKey")

    echo $data > $dataPath
else
    data=$(cat $dataPath)
fi

    check=$(echo "$data" | grep -c -e '"cod":"40')
    check2=$(echo "$data" | grep -c -e '"cod":"30')
    sum=$(( $check + $check2 ))
    if [ $sum -gt 0 ];then
        exit 99
    fi

lastUpdateTime=$(($(date +%s) -600))

while true; do
    lastfileupdate=$(date -r $dataPath +%s)
    if [ $(($(date +%s)-$lastfileupdate)) -ge 600 ];then
        data=$(curl -s "http://api.openweathermap.org/data/2.5/forecast?id=$defaultLocation&units=metric&appid=$apiKey")

        echo $data > $dataPath
    else
        if [ "$Conky" != "True" ];then
            echo "Cache age: $(($(date +%s)-$lastfileupdate)) seconds."
        fi
    fi

    if [ $(($(date +%s)-$lastUpdateTime)) -ge 600 ]; then
        lastUpdateTime=$(date +%s)


        ########################################################################
        # Location Data
        ########################################################################
        Station=$(echo $data | jq -r .city.name)
        NumEntries=$(echo $data |jq -r .cnt)
        let i=0

        while [ $i -lt $NumEntries ]; do
            # Get the date...unix format
            NixDate[$i]=$(echo $data | jq -r  .list[$i].dt  | tr '\n' ' ')
            ####################################################################
            # Current conditions (and icon)
            ####################################################################
            if [ "$UseIcons" = "True" ];then
                icons[$i]=$(echo $data | jq -r .list[$i].weather[] | jq -r .icon | tr '\n' ' ')
                iconval=${icons[$i]%?}
                case $iconval in
                    01*) icon[$i]="☀️";;
                    02*) icon[$i]="🌤";;
                    03*) icon[$i]="🌥";;
                    04*) icon[$i]="☁";;
                    09*) icon[$i]="🌧";;
                    10*) icon[$i]="🌦";;
                    11*) icon[$i]="🌩";;
                    13*) icon[$i]="🌨";;
                    50*) icon[$i]="🌫";;
                esac
            else
                icon[$i]=""
            fi
            ShortWeather[$i]=$(echo $data | jq -r .list[$i].weather[] | jq -r .main | tr '\n' ' '| awk '{$1=$1};1' )
            LongWeather[$i]=$(echo $data | jq -r .list[$i].weather[] | jq -r .description | sed -E 's/\S+/\u&/g' | tr '\n' ' '| awk '{$1=$1};1' )

            ####################################################################
            # Temperature
            ####################################################################
            tempinc[$i]=$(echo $data | jq -r .list[$i].main.temp | tr '\n' ' ')
            temperature[$i]=$tempinc[$i]
            case $degreeCharacter in
                "f")
                temperature[$i]=$(echo "scale=2; 32+1.8*${tempinc[$i]}" | bc) ;;

                "c")
                temperature[$i]=$(echo "${tempinc[$i]}") ;;
            esac
            i=$((i + 1))
        done
    fi

    AsOf=$(date +"%Y-%m-%d %R" -d @$lastfileupdate)
    TomorrowDate=$(date -d '+1 day' +"%s")
    NowHour=$(date +"%-H")
    NowLow=$((NowHour + 1))
    NowHigh=$((NowHour - 1))

    if [ "$Conky" = "True" ]; then
            let i=0
            bob=""
            while [ $i -lt 5 ]; do
                CastDate=$(date +"%s" -d @${NixDate[$i]})
                if [ $CastDate -le $TomorrowDate ]; then
                    ShortDate=$(date +"%R" -d @${NixDate[$i]})
                    bob=$(printf "%s %-4s%-2s %-4s |" "$bob" "$ShortDate:" "${ShortWeather[$i]}" "${temperature[$i]}°${degreeCharacter^^}")
                fi
                i=$((i + 1))
            done
        #bob=$(echo "$icon $ShortWeather $temperature°${degreeCharacter^^}")
        #bob
        echo "$bob"
    fi
    if [ "$Terminal" = "True" ];then
        echo "Forecast for $Station as of: ${YELLOW}$AsOf${RESTORE} "
        let i=0
        while [ $i -lt 40 ]; do
            CastDate=$(date +"%s" -d @${NixDate[$i]})
            CastHour=$(date +"%-H" -d @${NixDate[$i]})
            if [ "$CastHour" -ge "$NowHigh" ] && [ "$CastHour" -le "$NowLow" ]; then
                ShortDate=$(date +"%m/%d@%R" -d @${NixDate[$i]})
                printf "${RED}%-11s${RESTORE}: ${CYAN}%-2s%-16s${RESTORE} Temp:${CYAN}%-6s${RESTORE} \n" "$ShortDate" "${icon[$i]} " "${LongWeather[$i]}" "${temperature[$i]}°${degreeCharacter^^}"
            fi
            i=$((i + 1))
        done
        fi

    if [ $dynamicUpdates -eq 0 ];then
        break
    fi
done
