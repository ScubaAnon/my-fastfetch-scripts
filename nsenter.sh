#!/home/user/.guix-home/profile/bin/bash

# Create a newline separated array of relevant PIDs
mapfile -t containers <<< "$(pgrep -f shepherd.conf | awk -F ' ' 'NR>1 {print $1;}')"

# Check if command line argument is in the array
bool=0
for pid in "${containers[@]}"
do
    if [ "$pid" == "$1" ]; then
        nsenter -a -t "$1" hostname
        bool=1
        break
    fi
done

if [ "$bool" == 0 ]; then echo "PID not found"; fi

exit 0
