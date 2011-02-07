#!/usr/bin/perl -w

#  Copyright (c) 2006, 2007
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
use CGI;
use Carp;
#use CGI::Carp qw(fatalsToBrowser);
use primer3plusFunctions;
use settings;
use HtmlFunctions;
use customPrimerOrder;

my $selectAllPrimers = 0;
my $maxPrimerNumber = 100000; # maximal Number of primers
my %controlParameter;
my (@sequencesHTML, @namesHTML, @toOrderHTML, @dateHTML);
my (@sequencesFile, @namesFile, @toOrderFile, @dateFile);
my (@sequencesCache, @namesCache, @toOrderCache, @dateCache);
my (@sequencesFinal, @namesFinal, @toOrderFinal, @dateFinal);
my $modus = "S";
my ($fileContent, $cacheContent);
my ($uniqueID, $cookieID, $fromCache, $saveFile);

getParametersForManager(\@sequencesHTML, \@namesHTML, \@toOrderHTML, \@dateHTML, \%controlParameter, \$fileContent);

## Get the ID which is used as filename from the cookie or make a new one
$cookieID = getCookie();
if ($cookieID && $cookieID =~ /\d/) {
    $uniqueID = $cookieID;
}
else {
    $uniqueID = makeUniqueID();
}

## Figure out how to add a the primers to the existing list
if (!$controlParameter{"Submit"}) {
	$modus = "S";
}
elsif ($controlParameter{"Submit"} eq "Submit") {
    $modus = "S";
}
elsif ($controlParameter{"Submit"} eq "Refresh") {
    $modus = "A";
}
elsif ($controlParameter{"Submit"} eq "Delete selected Primers") {
    $modus = "D";
}
elsif ($controlParameter{"Submit"} eq "Order selected Primers") {
    $modus = "S";
}
elsif ($controlParameter{"Submit"} eq "Upload File") {
    $modus = "A";
}
elsif ($controlParameter{"Submit"} eq "Save File") {
    $modus = "A";
}
else {
    $modus = "S";
}

if ($controlParameter{"SELECT_ALL_PRIMERS"} && $controlParameter{"SELECT_ALL_PRIMERS"} == 1) {
    $modus = "U";
}

## Add the primers from the HTML to the final list
extractSelectedPrimers(\@sequencesHTML, \@namesHTML, \@toOrderHTML, \@dateHTML, 
				\$modus, \@sequencesFinal, \@namesFinal, \@toOrderFinal, \@dateFinal);

## Add the primers from the uploaded File to the final list
loadManagerFile(\$fileContent, \@sequencesFile, \@namesFile, \@toOrderFile, \@dateFile);
addToArray(\@sequencesFile, \@namesFile, \@toOrderFile, \@dateFile, 
			\@sequencesFinal, \@namesFinal, \@toOrderFinal, \@dateFinal);

## Load the primers from the cache to the final list
if (!(defined ($controlParameter{"HTML_MANAGER"}))) {
    getCacheFile(\$uniqueID, \$cacheContent);
    loadManagerFile(\$cacheContent, \@sequencesCache, \@namesCache, \@toOrderCache, \@dateCache);
    addToArray(\@sequencesCache, \@namesCache, \@toOrderCache, \@dateCache, 
    			\@sequencesFinal, \@namesFinal, \@toOrderFinal, \@dateFinal);
}

## Save the final list in the cache file
$saveFile = createManagerFile(\@sequencesFinal, \@namesFinal, \@toOrderFinal, \@dateFinal);
setCacheFile(\$uniqueID, \$saveFile);

if ($controlParameter{"Submit"} && $controlParameter{"Submit"} eq "Save File") {
    my $fileDate = getDate("Y","_");	
    print "Content-disposition: attachment; filename=Primers_$fileDate.fas\n\n";
    print $saveFile;
    writeStatistics("primer3manager");
}
elsif ($controlParameter{"Submit"} && $controlParameter{"Submit"} eq "Order selected Primers") {
    print "Content-type: text/html\n\n";
    print customPrimerOrder(\@sequencesFinal, \@namesFinal, \@toOrderFinal),"\n";
    writeStatistics("primer3manager");
}
else {
    $cookieID = setCookie($uniqueID);
    print createManagerHTML(\@sequencesFinal, \@namesFinal, \@toOrderFinal, \@dateFinal),"\n";
    writeStatistics("primer3manager");
}


