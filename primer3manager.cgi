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


# Primer3Plus will send two types of information, pairs and lists of primers.
# Pairs are selected and named at the pair level and can be used directly.
# Primerlists from Primer3Plus will have to be realigned. In P3P left and right
# primers coexist without being a pair. In Primer3Manager, each of this primers
# must form a "pair" which has only one primer to match RDML later.
# For primerlists the name and selection is on the primer level, which has to 
# be realigned for Primer3Manager, for each PRIMER_PAIR_4_NAME all missing 
# information is created.
# After the realignment each pair will have a PRIMER_PAIR_4_NAME, 
# a PRIMER_PAIR_4_SELECT, a PRIMER_PAIR_4_AMPLICON, a PRIMER_PAIR_4_DATE and
# PRIMER_LEFT_4_SEQUENCE, PRIMER_INTERNAL_4_SEQUENCE, a PRIMER_RIGHT_4_SEQUENCE.
# They will contain information or empty strings "".

use strict;
use primer3plusFunctions;
use settings;
use HtmlFunctions;
use customPrimerOrder;

my %parametersHTML;
my %completeParameters;
my %cachedFileHash;
my %rdmlFileHash;
my %fastaFileHash;
my %resultsHash;
my $primerUnitsCounter;
my $cookieID;
my $uniqueID;
my $saveFile;
my $cacheContent;
my $rdmlFileContent;

$primerUnitsCounter = 0;

# Get the HTML-Input and the default settings
getParametersHTML(\%parametersHTML);

# Get the ID which is used as filename from the cookie or make a new one
$cookieID = getCookie();
if (($cookieID ne "") && ($cookieID =~ /\d/)) {
    $uniqueID = $cookieID;
}
else {
    $uniqueID = makeUniqueID();
}

# Handy for testing:
# $parametersHTML{"SCRIPT_OLD_COOKIE"} = $cookieID;
# $parametersHTML{"SCRIPT_NEW_COOKIE"} = $uniqueID;
 $parametersHTML{"SCRIPT_DISPLAY_DEBUG_INFORMATION"} = 1;

# Extract all useful parameters to the main hash
# Here the main calculations happen:
extractCompleteManagerHash(\%completeParameters, \%parametersHTML);

# Load the cache file if data come from P3P
if (!((defined $parametersHTML{"SCRIPT_PRIMER_MANAGER"}) 
     and (($parametersHTML{"SCRIPT_PRIMER_MANAGER"} eq "PRIMER3MANAGER_DISPLAYMODE" )
     or ($parametersHTML{"SCRIPT_PRIMER_MANAGER"} eq "PRIMER3MANAGER_DELETEMODE" )))) {
    getCacheFile(\$uniqueID, \$cacheContent);
    loadFile($cacheContent, \%cachedFileHash, "1");
    addToManagerHash(\%completeParameters, \%cachedFileHash);
} 
# Load the provided files if data come from P3M
else {
    if ((defined $parametersHTML{"SCRIPT_SETTINGS_FILE_CONTENT"}) 
     and ($parametersHTML{"SCRIPT_SETTINGS_FILE_CONTENT"} ne "" )) {
        loadFastaForManager(\%fastaFileHash, $parametersHTML{"SCRIPT_SETTINGS_FILE_CONTENT"});
        addToManagerHash(\%completeParameters, \%fastaFileHash);
    }
    if ((defined $parametersHTML{"SCRIPT_SEQUENCE_FILE_CONTENT"}) 
     and ($parametersHTML{"SCRIPT_SEQUENCE_FILE_CONTENT"} ne "" )) {
     	$rdmlFileContent = unzipIt($uniqueID, $parametersHTML{"SCRIPT_SEQUENCE_FILE_CONTENT"});
        readRDMLForManager(\%rdmlFileHash, $rdmlFileContent);
        addToManagerHash(\%completeParameters, \%rdmlFileHash);
    }
}

## Save the final list in the cache file
$saveFile = createFile(\%completeParameters, "A");
setCacheFile(\$uniqueID, \$saveFile);

zipAndCacheIt(saveRDMLForManager(\%completeParameters), $uniqueID);


if ($parametersHTML{"Submit"} && ($parametersHTML{"Submit"} eq "Save RDML File")) {
    my $fileDate = getDate("Y","_");	
    print "Content-disposition: attachment; filename=Primers_$fileDate.rdml\n\n";
    print printFile($uniqueID);
    writeStatistics("primer3manager");
}
elsif ($parametersHTML{"Submit"} && ($parametersHTML{"Submit"} eq "Export as Fasta")) {
    my $fileDate = getDate("Y","_");	
    print "Content-disposition: attachment; filename=Primers_$fileDate.fas\n\n";
    print exportFastaForManager(\%completeParameters);
    writeStatistics("primer3manager");
}
elsif ($parametersHTML{"Submit"} && ($parametersHTML{"Submit"} eq "Order selected Primers")) {
    print "Content-type: text/html\n\n";
    print customPrimerOrder(\%completeParameters),"\n";
    writeStatistics("primer3manager");
}
else {
    $cookieID = setCookie($uniqueID);
    print createManagerDisplayHTML( \%completeParameters, \%parametersHTML), "\n";
    writeStatistics("primer3manager");
}






