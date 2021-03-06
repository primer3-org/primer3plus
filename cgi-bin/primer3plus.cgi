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

my %defaultSettings;
my %parametersHTML;
my %completeParameters;
my %resultsHash;

# Get the HTML-Input and the default settings
getParametersHTML(\%parametersHTML);
%defaultSettings = getDefaultSettings();

# Load the Sequence- and Settings-File in %parametersHTML
if ( defined $parametersHTML{SCRIPT_SETTINGS_FILE_CONTENT} ) {
	loadFile( $parametersHTML{SCRIPT_SETTINGS_FILE_CONTENT}, \%parametersHTML, "1");
}
if ( defined $parametersHTML{SCRIPT_SEQUENCE_FILE_CONTENT} ) {
	loadFile( $parametersHTML{SCRIPT_SEQUENCE_FILE_CONTENT}, \%parametersHTML, "1" );
}

# Load the server-stored Settings-File in %parametersHTML
if (    ( !defined $parametersHTML{SCRIPT_SETTINGS_FILE_CONTENT} )
	and ( defined $parametersHTML{Activate_Settings} ) ) {
    my $settingsName = $parametersHTML{SCRIPT_SERVER_PARAMETER_FILE};
	if ( $settingsName eq "Default"){
		%parametersHTML = getDefaultSettings();
	}
	else {
	    my %translateFileName = getServerParameterFiles();
	    my $fileName = $translateFileName{$settingsName};
	    my $serverFile = loadServerSettFile($fileName);
    	loadFile( $serverFile, \%parametersHTML, "0" );
	}
}

# Add missing parameters from the defaultSettings
%completeParameters = constructCombinedHash( %defaultSettings, %parametersHTML );

# check for parameters which make no sense and correct them
checkParameters(%completeParameters);


# do the selected job
if ( defined $parametersHTML{Default_Settings} ) {
	print "Content-type: text/html\n\n";
	# Required for the hidden example sequence
    $defaultSettings{"SEQUENCE_TEMPLATE"} = $completeParameters{"SEQUENCE_TEMPLATE"};
    $defaultSettings{"SEQUENCE_ID"} = $completeParameters{"SEQUENCE_ID"};
	print mainStartUpHTML( \%defaultSettings ), "\n";
	writeStatistics("primer3plus_main_start");
}

elsif (( defined $parametersHTML{Upload_File} )
        or ( defined $parametersHTML{Activate_Settings} )) {
	if (    ( !defined $parametersHTML{SCRIPT_SEQUENCE_FILE_CONTENT} )
		and ( !defined $parametersHTML{SCRIPT_SETTINGS_FILE_CONTENT} )
		and ( !defined $parametersHTML{Activate_Settings} ) ) {
		setMessage("Error: no file to upload");
	}
	if ( defined $parametersHTML{Activate_Settings} ) {
		setMessage("Active Settings: $parametersHTML{SCRIPT_SERVER_PARAMETER_FILE} ");
	}
	if ( $parametersHTML{SCRIPT_SEQUENCE_COUNTER} > 1 ) {
        setMessage("Multiple Sequences uploaded");
        
    	print "Content-type: text/html\n\n";
	    print createSelectSequence( \%completeParameters ), "\n";
	    writeStatistics("primer3plus_main_start");
	}
	else {
		print "Content-type: text/html\n\n";
		print mainStartUpHTML( \%completeParameters ), "\n";
		writeStatistics("primer3plus_main_start");
	}
}

elsif ( defined $parametersHTML{Save_Sequence} ) {
	my $fName = ( length( $completeParameters{SEQUENCE_ID} ) > 2 ) ?
	           $completeParameters{SEQUENCE_ID} : "Sequence";
	print "Content-disposition: attachment; filename=$fName.txt\n\n";
	print createFile( \%completeParameters, "Q" );
    writeStatistics("primer3plus_main_start");
}

elsif ( defined $parametersHTML{Save_Settings} ) {
	print "Content-disposition: attachment; filename=Primer3plus_Settings.txt\n\n";
	print createFile( \%completeParameters, "S" );
    writeStatistics("primer3plus_main_start");
}


elsif ( defined $parametersHTML{Pick_Primers} ) {
	runPrimer3( \%completeParameters, \%defaultSettings, \%resultsHash );
	print "Content-type: text/html\n\n";
	print mainResultsHTML( \%completeParameters, \%resultsHash ), "\n";
    writeStatistics("primer3plus_run_primer3");
}

else {
	print "Content-type: text/html\n\n";
	print mainStartUpHTML( \%completeParameters ), "\n";
    writeStatistics("primer3plus_main_start");
}

