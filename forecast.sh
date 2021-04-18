#!/bin/bash

########################################################################
# Setting Defaults
########################################################################

apiKey="c4d3d5b684b507cc18a434305d02b8ea"
defaultLocation="703447"

Conky="False"
Terminal="False"

degreeCharacter="c"
data=0
lastUpdateTime=0
FeelsLike=0
dynamicUpdates=0
UseIcons="True"
colors="True"
temp="True"
source "$HOME/.bashcolors"

########################################################################
# Reading in options
########################################################################

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
        if [ "$CityID" = "True" ];then
            data=$(curl -s "http://api.openweathermap.org/data/2.5/forecast?id=$defaultLocation&units=metric&appid=$apiKey")
        else
            data=$(curl -s "http://api.openweathermap.org/data/2.5/forecast?q=$defaultLocation&units=metric&appid=$apiKey")
        fi
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
            Humidity[$i]=$(echo $data | jq -r .list[$i].main.humidity | tr '\n' ' '| awk '{$1=$1};1' )
            CloudCover[$i]=$(echo $data | jq -r .list[$i].clouds.all | tr '\n' ' '| awk '{$1=$1};1' )

            ####################################################################
            # Parse Wind Info
            ####################################################################
            WindSpeed[$i]=$(echo $data | jq -r .list[$i].wind.speed | tr '\n' ' ' | awk '{$1=$1};1' )

            #Conversion
            if  [ "$degreeCharacter" = "f" ]; then
                WindSpeed[$i]=$(echo "scale=2; ${WindSpeed[$i]}*0.6213712" | bc | xargs printf "%.2f" | awk '{$1=$1};1' )
                windunit="mph"
            else
                windunit="kph"
            fi

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

    Terminal="True"

    if [ "$Conky" = "True" ]; then
        if [ "$colors" = "True" ]; then
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
        else
            let i=0
            bob=""
            while [ $i -lt 5 ]; do
                CastDate=$(date +"%s" -d @${NixDate[$i]})
                if [ $CastDate -le $TomorrowDate ]; then
                    ShortDate=$(date +"%R" -d @${NixDate[$i]})
                    bob=$(printf "%s %-5s %-6s %-4s |" "$bob" "$ShortDate:" "${ShortWeather[$i]}" "${temperature[$i]}°${degreeCharacter^^}")
                fi
                i=$((i + 1))
            done
        fi

        #bob=$(echo "$icon $ShortWeather $temperature°${degreeCharacter^^}")
        #bob
        echo "$bob"
    fi
    if [ "$Terminal" = "True" ];then
        if [ "$colors" = "True" ]; then
            echo "Forecast for $Station as of: ${YELLOW}$AsOf${RESTORE} "
        else
            echo "Forecast for $Station as of: $AsOf "
        fi
        let i=0
        while [ $i -lt 40 ]; do
            CastDate=$(date +"%s" -d @${NixDate[$i]})
            if [ $CastDate -le $TomorrowDate ]; then
                ShortDate=$(date +"%m/%d@%R" -d @${NixDate[$i]})
                if [ "$colors" = "True" ]; then
                    printf "${YELLOW}%-11s${RESTORE}: ${CYAN}%-2s%-16s${RESTORE} Temp:${CYAN}%-6s${RESTORE} Wind:${MAGENTA}%-6s${RESTORE} Humidity:${GREEN}%-4s${RESTORE} Clouds:${GREEN}%-4s${RESTORE}\n" "$ShortDate" "${icon[$i]} " "${LongWeather[$i]}" "${temperature[$i]}°${degreeCharacter^^}" "${WindSpeed[$i]}$windunit" "${Humidity[$i]}%" "${CloudCover[$i]}%"
                else
                    printf "%-12s %-2s%-20s %-15s %-14s %-14s %-14s\n" "$ShortDate:" "${icon[$i]} " "${LongWeather[$i]}" "Temp:${temperature[$i]}°${degreeCharacter^^}" "Wind:${WindSpeed[$i]}$windunit" "Humidity:${Humidity[$i]}%" "Cloud Cover:${CloudCover[$i]}%"
                fi
            else
                CastHour=$(date +"%-H" -d @${NixDate[$i]})
                if [ "$CastHour" -ge "$NowHigh" ] && [ "$CastHour" -le "$NowLow" ]; then
                    ShortDate=$(date +"%m/%d@%R" -d @${NixDate[$i]})
                    if [ "$colors" = "True" ]; then
                        printf "${RED}%-11s${RESTORE}: ${CYAN}%-2s%-16s${RESTORE} Temp:${CYAN}%-6s${RESTORE} Wind:${MAGENTA}%-6s${RESTORE} Humidity:${GREEN}%-4s${RESTORE} Clouds:${GREEN}%-4s${RESTORE}\n" "$ShortDate" "${icon[$i]} " "${LongWeather[$i]}" "${temperature[$i]}°${degreeCharacter^^}" "${WindSpeed[$i]}$windunit" "${Humidity[$i]}%" "${CloudCover[$i]}%"
                    else
                        printf "%-12s %-2s%-20s %-15s %-14s %-14s %-14s\n" "$ShortDate:" "${icon[$i]} " "${LongWeather[$i]}" "Temp:${temperature[$i]}°${degreeCharacter^^}" "Wind:${WindSpeed[$i]}$windunit" "Humidity:${Humidity[$i]}%" "Cloud Cover:${CloudCover[$i]}%"
                    fi
                fi
            fi
            i=$((i + 1))
        done
        fi


    if [ $dynamicUpdates -eq 0 ];then
        break
    fi
done
