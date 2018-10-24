Primer3Plus is a webinterface for Primer3
-----------------------------------------

It requires the primer3, PERL and Apache.

Perl requires the module archive-zip from Adam Kennedy
by calling (on Debian): 
`aptitude install libarchive-zip-perl`

It should run unaltered on windows and linux systems if you 
checkout from GitHub:
`git clone https://github.com/primer3-org/primer3plus.git primer3plus`

To install copy the folder in the cgi-folder. Obtain a copy
of [Primer3](https://github.com/primer3-org) and install it into this folder. Adjust the 
settings in settings.pl to match your configuration.

To set the proper rights on linux call on commandline:
./primer3setLinuxRights.sh

Genome browser support needs a folder to store downloadable file:
- create folder genBro in the pages section.
- update the settingsfile to this path and also to have the correct html path
- do:
    chmod g+w geneBro
    chgrp www-data geneBro

Problems you may encounter:
If you run encounter problems, please check the newlines to 
get them right for your platform (unix2dos).

Please check carefully the executable and writing rights:
- All cgi-scripts should be executable by the webserver user.
    chmod a+x *.cgi
- This user should have write access to all subfolders.
- All subfolders should be writable/readable by the cgi-skripts
  and the primer3_core executable. 

Install Version 3.0.0
---------------------
# Primer3Plus
Primer3Plus is a webinterface for Primer3

Dependencies
------------

Primer3Plus requires Primer3, please intall first:

`https://github.com/primer3-org/primer3`


Install a local copy for testing
--------------------------------

`git clone https://github.com/primer3-org/primer3plus.git`

`cd primer3plus`

Setup and run the server
------------------------

The server runs in a terminal

Install the dependencies:

`sudo apt install python python-pip`

`pip install flask flask_cors`

Start the server:

`cd PATH_TO_PRIMER3PLUS/primer3plus`

`export PATH=$PATH:/PATH_TO_PRIMER3/src`

`echo $PATH`

`python server/server.py`

Setup and run the client
------------------------

The client requires a different terminal

Install the dependencies:

`cd PATH_TO_PRIMER3PLUS/primer3plus/client`

`sudo apt install npm`

`npm install`

Start the client:

`cd PATH_TO_PRIMER3PLUS/primer3plus/client`

`npm run dev`


