#!/usr/bin/env bash
set -euo pipefail

# Transform KB number into a meaningful string
kb_to_human_readable() {
    if (( $1 >= 1024 * 1024 )); then
        printf "%.2f GiB" $(echo "scale=2; $1 / 1024 / 1024" | bc)
    elif (( $1 >= 1024 )); then
        printf "%.2f MiB" $(echo "scale=2; $1 / 1024" | bc)
    else
        echo "${1} KiB"
    fi
}

# Create an array containing Guix container PIDs running
mapfile -t containers < <(pgrep -f shepherd.conf | awk -F ' ' 'NR>1 {print $1;}')
# Create an array containing names of running docker containers
mapfile -t dockercontainers < <(docker ps --format '{{.Names}}' 2>/dev/null)
# Create an array containing names of running QEMU/KVM VMs
mapfile -t vms < <(virsh list --name | head -n -1) # head removes trailing newline

FastfetchConfDir="/home/${SUDO_USER:-$(logname)}/.config/fastfetch/"
# Sanity check
if [[ ! -f "${FastfetchConfDir}template.json" ]]; then
  echo "Error: template.json not found." >&2
  exit 1
fi
# Needed to fetch names of Guix containers
Num_of_containers=$((${#containers[@]}+${#dockercontainers[@]}))
Num_of_vms=${#vms[@]}
# Point in your template.json where you want to insert container information.
Array_index=11

# First object to be inserted
jq --arg num "$Num_of_containers" --argjson index "$Array_index" \
'.modules |= .[:$index] + [{ "type": "custom", "format": "\u001b[1;38;5;63m🖧 C#\u001b[0m: " + $num }] + .[$index:]' \
"${FastfetchConfDir}template.json" > "${FastfetchConfDir}tmp.json"

# Fetch information for each Guix container, then create and insert objects to config
# TODO: Should maybe have a check on whether $containers is empty too, but eh.
KB_Total=0
for pid in "${containers[@]}"; do
    ((++Array_index))
    hostname=$(sudo /run/current-system/profile/bin/nsenter "$pid" hostname)
    KB=$(ps -o rss -p "$pid" --ppid "$pid" | awk -F ' ' 'NR>1 {print $1;}' | awk '{printf "%s+",$0} END {print "0"}' | bc)
    (( KB_Total += KB ))

    KB_Human=$(kb_to_human_readable "$KB")

    jq --arg PID "$pid" --arg hostname "$hostname" --arg KB "$KB_Human" --argjson index "$Array_index" \
	'.modules |= .[:$index] + [{ "type": "custom", "format": "\u001b[1;38;5;63m  ├ \u001b[0m " + $hostname + ": " + $KB + " memory usage - PID " + $PID }] + .[$index:]' \
	"${FastfetchConfDir}tmp.json" | sponge "${FastfetchConfDir}tmp.json"
done

if [[ -n ${#dockercontainers[@]} ]]; then
    for d in "${dockercontainers[@]}"; do
	    ((++Array_index))
	    name="${d#docker-}"
        name="${name^}"
		container_id=$(docker inspect --format '{{.Id}}' "$d")
		mem_bytes=$(cat "/sys/fs/cgroup/docker/${container_id}/memory.current")
		KB=$((mem_bytes / 1024))
		(( KB_Total += KB ))
		mem=$(units_handler "$KB")
		
        jq --arg name "$name" --arg mem "$mem" --argjson index "$Array_index" \
		'.modules |= .[:$index] + [{ "type": "custom", "format": "\u001b[1;38;5;63m  ├ \u001b[0m " + $name + ": " + $mem + " memory usage" }] + .[$index:]' \
		"${FastfetchConfDir}tmp.json" | sponge "${FastfetchConfDir}tmp.json"
    done
fi

KB_Total=$(kb_to_human_readable "$KB_Total")

# Finish container section, proceed (else) with VMs sections if VMs are detected
if [[ -z ${#vms[@]} ]]; then
    ((++Array_index))
    jq --arg total "$KB_Total" --argjson index "$Array_index" \
	'.modules |= .[:$index] + [{ "type": "custom", "format": "\u001b[1;38;5;63m  ╰┈➤\u001b[0m Total: " + $total + " of memory" }] + .[$index:]' \
	"${FastfetchConfDir}tmp.json" > "${FastfetchConfDir}config.jsonc"
else
    ((++Array_index))
    jq --arg total "$KB_Total" --argjson index "$Array_index" \
	'.modules |= .[:$index] + [{ "type": "custom", "format": "\u001b[1;38;5;63m  ╰┈➤\u001b[0m Total: " + $total + " of memory" }] + .[$index:]' \
	"${FastfetchConfDir}tmp.json" | sponge "${FastfetchConfDir}tmp.json"

    # Simple linebreak
    ((++Array_index))
    jq --argjson index "$Array_index" \
	'.modules |= .[:$index] + ["break"] + .[$index:]' \
	"${FastfetchConfDir}tmp.json" | sponge "${FastfetchConfDir}tmp.json"

    # Add VMs section
    ((++Array_index))
    jq --arg num "$Num_of_vms" --argjson index "$Array_index" \
	'.modules |= .[:$index] + [{ "type": "custom", "format": "\u001b[1;38;5;63m🖧 VM#\u001b[0m: " + $num }] + .[$index:]' \
	"${FastfetchConfDir}tmp.json" | sponge "${FastfetchConfDir}tmp.json"

    KB_Total=0
    for vm in "${vms[@]}"; do
        ((++Array_index))
        KB=$(virsh dommemstat "$vm" | awk '/^actual/{print $2}')
        (( KB_Total += KB ))
        
        # Transform $KB into a meaningful string
        KB_Human=$(kb_to_human_readable "$KB")
        
        jq --arg vm "$vm" --arg KB "$KB_Human" --argjson index "$Array_index" \
		'.modules |= .[:$index] + [{ "type": "custom", "format": "\u001b[1;38;5;63m  ├ \u001b[0m " + $vm + ": " + $KB + " memory usage" }] + .[$index:]' \
		"${FastfetchConfDir}tmp.json" | sponge "${FastfetchConfDir}tmp.json"
    done

    KB_Total=$(kb_to_human_readable "$KB_Total")

    ((++Array_index))
    jq --arg total "$KB_Total" --argjson index "$Array_index" \
	'.modules |= .[:$index] + [{ "type": "custom", "format": "\u001b[1;38;5;63m  ╰┈➤\u001b[0m Total: " + $total + " of memory" }] + .[$index:]' \
	"${FastfetchConfDir}tmp.json" > "${FastfetchConfDir}config.jsonc"
fi

rm "${FastfetchConfDir=}tmp.json"

exit 0
