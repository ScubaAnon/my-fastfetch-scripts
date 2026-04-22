## A script which inserts container and VM information into your fastfetch config.jsonc.

This script doesn't generate a fastfetch config.jsonc from scratch though. Instead it ingeniuosly makes use of a temoplate.json file,
meaning a normal config.jsonc without these inserted containers is always used as a base, making this script nondestructive as long as
you cp (or mv) the config.jsonc to template.json in the fastfetch config directory.

## Usage (IMPORTANT: config.jsonc contents needs to go to template.json)
Edit FastfetchConfDir (if nonstandard), NsenterScriptDir, and Array_index, then rename your config.jsonc to template.json. Finally, add
two lines in your sudoers file so you don't need to type your password to run the scripts (guixcontainersinfo.sh and nsenter.sh).

However you invoke the script, ensure it's ran with sudo. I have an alias for fastfetch in my bashrc which first executes
guixcontainersinfo.sh (with sudo) before running fastfetch (&&), then simply add the fastfetch command to the end of my bash_profile.

The reason template.json is important is because it'll serve as the base for constructing the final config.jsonc. Therefore, anything
you have in there will never be destroyed (no guarantee, I hold no liability, etc, etc, yada, yada).

As for the nsenster script, it gets a little weird without it. Even though you run the script with sudo, you'll still need sudo inside
the script in order for nsenter to work with you. So either you run the script with sudo having set NOPASSWD in your sudoers, or you
have NOPASSWD set for the nsenter command itself and adjust the script (line 32). Below are sample entries for both cases:
* user ALL=NOPASSWD: /home/user/bin/nsenter.sh ^[0-9]{4,5} (0|1)$
* user ALL=NOPASSWD: /run/current-system/profile/bin/nsenter ^[0-9]{4,5}$ hostname
