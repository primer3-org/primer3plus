#!/usr/bin/perl -w

#  Copyright (c) 2007 - 2011
#  by Andreas Untergasser and Harm Nijveen
#  All rights reserved.
# 
#  This file is part of Primer3Plus. Primer3Plus is a webinterface to primer3.
# 
#  The Primer3Plus is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
# 
#  Primer3Plus is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
# 
#  You should have received a copy of the GNU General Public License
#  along with Primer3Plus (file gpl.txt in the source distribution);
#  if not, write to the Free Software Foundation, Inc., 51 Franklin St,
#  Fifth Floor, Boston, MA  02110-1301  USA

# Watchdog, a script to monitor processes and kill those that run too long
# Add process names to the $commandHash and users to the $user variable  
# Can be run as an hourly cron job                                      

use strict;

#location of the ps binary
my $PS = "/bin/ps";
#user(s) to check, add additional users separated by a comma
my $user = "www-data"; # Could be user www or www-data
#hash with program names and max cpu times
#value program name, key time with format: hhmmss
my %commandHash = (
    "primer3plus" => 1100,
    "primer3_core" => 500,
);

my $commandline = "$PS -o pid,time,comm -u $user|";
open PS, $commandline or die "cannot run ps";
while (<PS>) {
    my ($pid,$time,$nTime,$comm);
    if(m/^ *(\d+) ([0-9-]*\d\d:\d\d:\d\d) (\S+)$/) {
        ($pid,$time,$comm) = ($1,$2,$3);
        $nTime = $time;
        $nTime =~ s/[:-]//g;
        if ($commandHash{$comm} && $nTime > $commandHash{$comm}) {
            print "Killing pid $pid running command \"$comm\" with cpu time $time\n";
            kill 15,$pid or die "Could not kill $pid\n";
        }
    }
}

close PS;
