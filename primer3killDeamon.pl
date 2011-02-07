#!/usr/bin/perl -w
# 2007 December 4  by Harm Nijveen
# Watchdog, a script to monitor processes and kill those that run too long
# Add process names to the $commandHash and users to the $user variable  # Can be run as an hourly cron job                                      
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
