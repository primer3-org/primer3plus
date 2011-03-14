Primer3plus is a webinterface for the primer3 program.

It requires the primer3, PERL and Apache.

Perl requires the module archive-zip from Adam Kennedy
by calling (on Debian): aptitude install libarchive-zip-perl

It should run unaltered on windows and linux systems if you 
checkout from subversion.
If you run encounter problems, please check the newlines to 
get them right for your platform (unix2dos).

To install copy the folder in the cgi-folder. Obtain a copy
of primer3 and install it into this folder. Adjust the 
settings in settings.pl to match your configuration.

Please check carefully the executable and writing rights:
- All cgi-scripts should be executable by the webserver user.
    chmod a+x *.cgi
- This user should have write access to all subfolders.
- All subfolders should be writable/readable by the cgi-skripts
  and the primer3_core executable. 

