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

Powncing
--------
Your script can pownce on a user by placing a symlink or script into the pownce directory for that user, eg: ./pownce/brackendawson/myscript
You must clean up the link/script yourself when you are done. You will have to create nonexistent direcotries yourself.

A better method is to run the smib-pownce-register script with the user this script wants to pownce: smib-pownce-register \<nick\>
Then unregister when you are done in the same manor: smib-pownce-unregister \<nick\>

Users will be pownced in these cases:
 * Joined a channel smib is in.
 * Spoke in a channel smib is in.
 * Changed their name from nick\_away or nick\_afk to nick.
 * Came out of away status (TODO: Work out how to do actually this).

Yor script will be run with these arguments in the case of a pownce:
 * $1 - User, Nick of the person the pownce is for.
 * $2 - Channel, the channel they spoke in or joined, or 'null' if it was a /msg.
 * $3 - Where, the channel name or user name of where the user spoke or joined.
 * $4 - What was said, or 'null'.
 * $5 - 'null'.
 * $6 - 'pownce'.

Anything your script prints to STDOUT will be said where the command was invoked (channel or as /msg to the user) (there is flood control).

Logging
-------
Your script can trigger on anything anyone says, in a channel or directly, by placing a link or script in the log directory, eg: ./log/myscript

Your script will be called with these arguments in the case of a log:
 * $1 - User, Nick of the person who spoke.
 * $2 - Channel, the channel it was said in, or 'null' if it was a /msg.
 * $3 - Where, the channel name or user name of where it was said.
 * $4 - What was said, excluding the command.
 * $5 - 'null'.
 * $6 - 'log'.

Anything your script prints to STDOUT will be printed to STDOUT by smib.

General
-------
Scripts are run with full privialages of the user which runs smib, appropriare care should be taken to vette scripts.
Anything a script prints to STDERR will be printed to STDERR by smib.
Script can also mean compiled program.
