#!/usr/bin/perl

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
    my $settingsName = $parametersHTML{SERVER_PARAMETER_FILE};
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
	print mainStartUpHTML( \%defaultSettings ), "\n";
}

elsif (( defined $parametersHTML{Upload_File} )
        or ( defined $parametersHTML{Activate_Settings} )) {
	if (    ( !defined $parametersHTML{SCRIPT_SEQUENCE_FILE_CONTENT} )
		and ( !defined $parametersHTML{SCRIPT_SETTINGS_FILE_CONTENT} )
		and ( !defined $parametersHTML{Activate_Settings} ) ) {
		setMessage("Error: no file to upload");
	}
	if ( defined $parametersHTML{Activate_Settings} ) {
		setMessage("Active Settings: $parametersHTML{SERVER_PARAMETER_FILE} ");
	}
	print "Content-type: text/html\n\n";
	print mainStartUpHTML( \%completeParameters ), "\n";
}

elsif ( defined $parametersHTML{Save_Sequence} ) {
	my $fName = ( length( $completeParameters{PRIMER_SEQUENCE_ID} ) > 2 ) ?
	           $completeParameters{PRIMER_SEQUENCE_ID} : "Sequence";
	print "Content-disposition: attachment; filename=$fName.txt\n\n";
	print createSequenceFile( \%completeParameters );
}

elsif ( defined $parametersHTML{Save_Settings} ) {
	print "Content-disposition: attachment; filename=Primer3plus_Settings.txt\n\n";
	print createSettingsFile( \%completeParameters );
}

elsif ( defined $parametersHTML{Pick_Primers} ) {
	findAllPrimers( \%completeParameters, \%resultsHash );
	print "Content-type: text/html\n\n";
	print mainResultsHTML( \%resultsHash ), "\n";
}

else {
	print "Content-type: text/html\n\n";
	print mainStartUpHTML( \%completeParameters ), "\n";
}

