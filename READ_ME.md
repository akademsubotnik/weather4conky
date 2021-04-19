Upstream (https://github.com/uriel1998/weather.sh)

Bash script that will give 3 day forcast(day/temperature/weather pattern)

Edit apiKey, defaultLocation, degreeCharacter to suit your needs

Calling from Conky
I have a single line config for my secondary screen with the weather config in it:

Now: ${execi 300 weather.sh -y} Forecast: ${execi 300 forecast.sh -y}

The conky output is currently limited via code to just the next five outputs.

