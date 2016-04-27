smib
====
smib (the So Make It Bot) is an IRC bot which never directly says anything. All output into the channels is produced by scripts in the script directory that may be written in any language desired.

Scripts
-------
Scripts in the script directory will be called when anyone in a channel smib has joined says ?scriptname where "scriptname" is the file name of the script. The script will be run with the following arguments:
 * $1 - User, Nick of the person who spoke.
 * $2 - Channel, the channel it was said in, or 'null' if it was a /msg.
 * $3 - Where, the channel name or user name of where it was said.
 * $4 - What was said, excluding the command.
 * $5 - The command (in $5 to support legacy scripts).

Anything your script prints to STDOUT will be said where the command was invoked (channel or as /msg to the user) (there is flood control).

Logging
-------
Your script can trigger on anything anyone says, in a channel or directly, by placing a link or script in the log directory, eg: ./log/myscript. Smib will queue other commands while processing log scripts, so keep them short and time out fast.

Your script will be called with these arguments in the case of a log:
 * $1 - User, Nick of the person who spoke.
 * $2 - Channel, the channel it was said in, or 'null' if it was a /msg.
 * $3 - Where, the channel name or user name of where it was said.
 * $4 - What was said.
 * $5 - The command.
 * $6 - 'log'.

Anything your script prints to STDOUT will be said where the command was invoked by smib.

Logging
-------
Your script can trigger in the background once a minute (plus background scripts running time), by placing a link or script in the background directory, eg: ./background/myscript. Smib will queue other commands while processing background scripts, so keep them short and time out fast.

Your script will be called with these arguments in the case of a log:
 * $1 - 'null'.
 * $2 - 'null'.
 * $3 - 'null'.
 * $4 - 'null'.
 * $5 - The command.
 * $6 - 'background'.

Anything your script prints to STDOUT will be said in the first channel smib joined.

Listen Port
-----------
Smib will listen on a TCP port (default 1337), anything you send to that port will be said in the first channel smib joined.

General
-------
Scripts are run with full privialages of the user which runs smib, appropriare care should be taken to vette scripts.
Anything a script prints to STDERR will be printed to STDERR by smib.
Script can also mean compiled program.
    iptables -A OUTPUT -m owner --uid-owner 1001 -p udp --destination-port 53 -d 10.0.0.1 -j ACCEPT     # Where 1001 is smib's user's uid and 10.0.0.1 is the dns server in the router
    iptables -A OUTPUT -m owner --uid-owner 1001 -d 10.0.0.0/8 -j REJECT
    iptables -A OUTPUT -m owner --uid-owner 1001 -d 192.168.0.0/16 -j REJECT
    iptables -A OUTPUT -m owner --uid-owner 1001 -d 127.0.0.0/8 -j REJECT

