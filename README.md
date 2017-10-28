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

