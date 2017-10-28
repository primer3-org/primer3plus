#!/usr/bin/perl -w

#  Copyright (c) 2006 - 2011
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

use strict;
use primer3plusFunctions;
use settings;
use HtmlFunctions;

my %parametersHTML;
my %fileOne;
my %fileTwo;
my $fileOnePresent = 0;
my $fileTwoPresent = 0;
my $serverFilePresent = 0;
my %complServerFile;
my %serverFile;
my $theKey;

my %allPossibleKeys;

my %resEqualServer;
my %resDiffServer;
my %resEqualFiles;
my %resDiffFiles;

# Get the HTML-Input
getParametersHTML(\%parametersHTML);

# Load the Sequence- and Settings-File in %parametersHTML
if ( defined $parametersHTML{SCRIPT_SEQUENCE_FILE_CONTENT} ) {
	loadFile( $parametersHTML{SCRIPT_SEQUENCE_FILE_CONTENT}, \%fileOne, "0" );
	$fileOnePresent = 1;
}
if ( defined $parametersHTML{SCRIPT_SETTINGS_FILE_CONTENT} ) {
    loadFile( $parametersHTML{SCRIPT_SETTINGS_FILE_CONTENT}, \%fileTwo, "0");
    $fileTwoPresent = 1;
}

# Load the server-stored Settings-File in %parametersHTML
if ( defined $parametersHTML{SCRIPT_SERVER_PARAMETER_FILE} ) {
    my $settingsName = $parametersHTML{SCRIPT_SERVER_PARAMETER_FILE};
    if ( $settingsName eq "None"){
        $serverFilePresent = 0;
    } elsif ( $settingsName eq "Default"){
        %complServerFile = getDefaultSettings();
        $serverFilePresent = 1;
    }
	else {
	    my %translateFileName = getServerParameterFiles();
	    my $fileName = $translateFileName{$settingsName};
	    my $serverFileString = loadServerSettFile($fileName);
    	loadFile( $serverFileString, \%complServerFile, "0" );
    	$serverFilePresent = 1;
	}
}


#Extract all Keys first into one Hash
foreach $theKey (keys(%complServerFile)){
    if (($theKey =~ /^PRIMER_/) or ($theKey =~ /^P3P_/)) {
        $serverFile{$theKey} = $complServerFile{$theKey};
    }
}

#Extract all Keys first into one Hash
foreach $theKey (keys(%fileOne)){
    $allPossibleKeys{$theKey} = 1;
}
foreach $theKey (keys(%fileTwo)){
    $allPossibleKeys{$theKey} = 1;
}
foreach $theKey (keys(%serverFile)){
    $allPossibleKeys{$theKey} = 1;
}

#Now split the Hashes 
if (($fileOnePresent == 1) && ($fileTwoPresent == 1) && ($serverFilePresent == 1)) {
    foreach $theKey (keys(%allPossibleKeys)){
        if (defined $serverFile{$theKey}) {
            if (((defined $fileOne{$theKey}) and
                 (defined $fileTwo{$theKey})) and
                 ($serverFile{$theKey} eq $fileOne{$theKey}) and
                 ($serverFile{$theKey} eq $fileTwo{$theKey})) {
                $resEqualServer{$theKey} = $serverFile{$theKey};
            } else {
                if (!(defined $fileOne{$theKey})) {
                    $fileOne{$theKey} = "Not defined";
                }
                 if (!(defined $fileTwo{$theKey})) {
                    $fileTwo{$theKey} = "Not defined";
                }
                $resDiffServer{$theKey} = "1";
            }
        } else {
            if (((defined $fileOne{$theKey}) and
                 (defined $fileTwo{$theKey})) and
                 ($fileOne{$theKey} eq $fileTwo{$theKey})) {
                $resEqualFiles{$theKey} = "1";
            } else {
                if (!(defined $fileOne{$theKey})) {
                    $fileOne{$theKey} = "Not defined";
                }
                 if (!(defined $fileTwo{$theKey})) {
                    $fileTwo{$theKey} = "Not defined";
                }
                 if (!(defined $serverFile{$theKey})) {
                    $serverFile{$theKey} = "Not defined";
                }
                $resDiffFiles{$theKey} = "1";
            }
            
        }
    }
} elsif (($fileOnePresent == 1) && ($fileTwoPresent == 0) && ($serverFilePresent == 1)) {
    foreach $theKey (keys(%allPossibleKeys)){
        if (defined $serverFile{$theKey}) {
            if ((defined $fileOne{$theKey}) and
                 ($serverFile{$theKey} eq $fileOne{$theKey})) {
                $resEqualServer{$theKey} = "1";
                $fileTwo{$theKey} = "";
            } else {
                if (!(defined $fileOne{$theKey})) {
                    $fileOne{$theKey} = "Not defined";
                }
                 if (!(defined $serverFile{$theKey})) {
                    $serverFile{$theKey} = "Not defined";
                }
                $resDiffServer{$theKey} = "1";
                $fileTwo{$theKey} = "";
            }
        }            
    }
} elsif (($fileOnePresent == 0) && ($fileTwoPresent == 1) && ($serverFilePresent == 1)) {
    foreach $theKey (keys(%allPossibleKeys)){
        if (defined $serverFile{$theKey}) {
            if ((defined $fileTwo{$theKey}) and
                 ($serverFile{$theKey} eq $fileTwo{$theKey})) {
                $resEqualServer{$theKey} = "1";
                $fileOne{$theKey} = "";
            } else {
                if (!(defined $fileTwo{$theKey})) {
                    $fileTwo{$theKey} = "Not defined";
                }
                 if (!(defined $serverFile{$theKey})) {
                    $serverFile{$theKey} = "Not defined";
                }
                $resDiffServer{$theKey} = "1";
                $fileOne{$theKey} = "";
            }
        }            
    }
} elsif (($fileOnePresent == 1) && ($fileTwoPresent == 1) && ($serverFilePresent == 0)) {
    foreach $theKey (keys(%allPossibleKeys)){
        if (((defined $fileOne{$theKey}) and
             (defined $fileTwo{$theKey})) and
             ($fileOne{$theKey} eq $fileTwo{$theKey})) {
            $resEqualFiles{$theKey} = "1";
        } else {
            if (!(defined $fileOne{$theKey})) {
                $fileOne{$theKey} = "Not defined";
            }
            if (!(defined $fileTwo{$theKey})) {
                $fileTwo{$theKey} = "Not defined";
            }
            $resDiffFiles{$theKey} = "1";
        }
    }
}

# print the result
if ( defined $parametersHTML{Compare_Files} ) {
	print "Content-type: text/html\n\n";
	print createResultCompareFileHTML(\%fileOne, \%fileTwo, 
	          \%serverFile, \%resEqualServer, \%resDiffServer, 
	          \%resEqualFiles, \%resDiffFiles), "\n";
}
else {
	print "Content-type: text/html\n\n";
	print createCompareFileHTML(), "\n";
}

