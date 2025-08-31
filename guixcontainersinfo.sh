#!/bin/bash

# Create an array containing all the container PIDs running right now
mapfile -t containers <<< "$(pgrep -f shepherd.conf | awk -F ' ' 'NR>1 {print ""$1"";}')"
Num_of_containers=${#containers[@]}

# First object to be inserted
jq --arg num "$Num_of_containers" '.modules |= .[:11] + [{ "type": "custom", "format": "\u001b[1;38;5;63m🖧 C#\u001b[0m: " + $num }] + .[11:]' /home/guix/.config/fastfetch/template.json > /home/guix/.config/fastfetch/tmp.json

# Fetch information for each container, then create and insert objects to config
KB_Total=0
Array_index=11
for i in "${containers[@]}"; do
    ((++Array_index))
    PID=$i
    hostname=$(sudo /home/guix/bin/nsenter.sh "$i")
    KB=$(ps -o rss -p "$i" --ppid "$i" | awk -F ' ' 'NR>1 {print ""$1"";}' | awk '{printf "%s+",$0} END {print "0"}' | bc)
    (( KB_Total += KB ))

    # Transform $KB into a meaningful string
    if [[ "$KB" -ge 10240 ]]; then
        KB="$(echo "scale=2; $KB / 1024" | bc) MB"
    else
        KB="$KB KB"
    fi

    jq --arg PID "$PID" --arg hostname "$hostname" --arg KB "$KB" --argjson index "$Array_index" '.modules |= .[:$index] + [{ "type": "custom", "format": "\u001b[1;38;5;63m  ├ \u001b[0m " + $hostname + ": " + $KB + " memory usage - PID " + $PID }] + .[$index:]' /home/guix/.config/fastfetch/tmp.json | sponge /home/guix/.config/fastfetch/tmp.json
done

# Transform $KB_Total into a meaningful string
if [[ "$KB_Total" -ge 10240 ]]; then
    KB_Total="$(echo "scale=2; $KB_Total / 1024" | bc) MB"
else
    KB_Total="$KB_Total KB"
fi

((++Array_index))
jq --arg total "$KB_Total" --argjson index "$Array_index" '.modules |= .[:$index] + [{ "type": "custom", "format": "\u001b[1;38;5;63m  ╰┈➤\u001b[0m Total: " + $total + " of memory" }] + .[$index:]' /home/guix/.config/fastfetch/tmp.json > /home/guix/.config/fastfetch/config.jsonc

rm /home/guix/.config/fastfetch/tmp.json

exit 0
