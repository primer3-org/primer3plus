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

package primer3plusFunctions;
use strict;
use CGI;
use Carp;
#use CGI::Carp qw(fatalsToBrowser);
use CGI::Cookie;
use FileHandle;
use IPC::Open3;
use Exporter;
use settings;

our ( @ISA, @EXPORT, @EXPORT_OK, $VERSION );
@ISA    = qw(Exporter);
@EXPORT = qw(&getParametersHTML &constructCombinedHash &createSequenceFile &createSettingsFile
     &createManagerFile &getSetCookie &getCookie &setCookie &getCacheFile &setCacheFile
     &loadManagerFile &loadFile &checkParameters &findAllPrimers &reverseSequence
     &getParametersForManager &loadServerSettFile &extractSelectedPrimers &addToArray
     &getDate &makeUniqueID);

$VERSION = "1.00";

my $cgi = new CGI;

#########################################################################
# getParametersHTML: retrieve all paratemeters from the input HTML form #
#########################################################################
sub getParametersHTML {
	my $dataTarget;
	$dataTarget = shift;
	my @radioButtonsList;
	my ( $name, $value, $seqFile, $settFile, $radioButtons, $radioKey );

	$seqFile      = $cgi->param("SCRIPT_SEQUENCE_FILE");
	$settFile     = $cgi->param("SCRIPT_SETTINGS_FILE");
	$radioButtons = $cgi->param("HTML_RADIO_BUTTONS");

    # unselected radiobuttons dont appear - this is a workaround
    # it loads a 0 to all radiobuttons and overwrites later
    # the selected ones with 1 
	if ( $radioButtons ne "" ) {
		@radioButtonsList = split ',', $radioButtons;
		foreach $radioKey (@radioButtonsList) {
			$dataTarget->{$radioKey} = 0;
		}
	}
	
	# Load the sequence file in a string to read it later
	if ( $seqFile ne "" ) {
		binmode $seqFile;
		my $data;
		while ( read $seqFile, $data, 1024 ) {
			$dataTarget->{"SCRIPT_SEQUENCE_FILE_CONTENT"} .= $data;
		}
	}

	# Load the settings file in a string to read it later
	if ( $settFile ne "" ) {
		binmode $settFile;
		my $data;
		while ( read $settFile, $data, 1024 ) {
			$dataTarget->{"SCRIPT_SETTINGS_FILE_CONTENT"} .= $data;
		}
	}

	# The usual things to read from the HTML
	foreach $name ( $cgi->param ) {
		$value = $cgi->param($name);
		$name  =~ tr/+/ /;
		$name  =~ s/%([\da-f][\da-f])/chr( hex($1) )/egi;
		$value =~ tr/+/ /;
		$value =~ s/%([\da-f][\da-f])/chr( hex($1) )/egi;
		$dataTarget->{$name} = $value;
	}

	return;
}

###############################################################################
# getParametersForManager: retrieve all paratemeters from the input HTML form #
###############################################################################
sub getParametersForManager {
	my ( $sequencesHTML, $namesHTML, $toOrderHTML, $dateHTML);
	my ( $name, $value,	$controlParameter, $fileContent, $File );
	
	$sequencesHTML    = shift;
	$namesHTML        = shift;
	$toOrderHTML      = shift;
	$dateHTML         = shift;
	$controlParameter = shift;
	$fileContent      = shift;

	$File = $cgi->param("DATABASE_FILE");

	# Load the file in a string to read it later
	if ( $File && $File ne "" ) {
		binmode $File;
		my $data;
		while ( read $File, $data, 1024 ) {
			${$fileContent} .= $data;
		}
	}

	# Read from HTML in an array or a Hash
	my @splitName;
	foreach $name ( $cgi->param ) {
		$value = $cgi->param($name);
		$name  =~ tr/+/ /;
		$name  =~ s/%([\da-f][\da-f])/chr( hex($1) )/egi;
		$value =~ tr/+/ /;
		$value =~ s/%([\da-f][\da-f])/chr( hex($1) )/egi;
		
		# Read the keys and put it in the correct array
		# The primer number gives the position
		if ( $name =~ /PRIMER_/ ) {
			@splitName = split "_", $name;
			if ( $splitName[2] =~ /NAME/ ) {
				$value =~ s/\|/_/g;
				$namesHTML->[ $splitName[1] ] = $value;
			}
			if ( $splitName[2] =~ /SEQUENCE/ ) {
				$sequencesHTML->[ $splitName[1] ] = $value;
			}
			if ( $splitName[2] =~ /SELECT/ ) {
				$toOrderHTML->[ $splitName[1] ] = $value;
			}
			if ( $splitName[2] =~ /DATE/ ) {
				$dateHTML->[ $splitName[1] ] = $value;
			}
		}
		# What is not a primer goes in the controlParameter-Hash
		else {
			$controlParameter->{$name} = $value;
		}
	}

	return;
}

################################################
# Functions for loading and saving cookies :-) #
################################################
sub setCookie {
	my ($newValue, $expires);
	$newValue = shift;
	$expires = getMachineSetting("MAX_STORAGE_TIME");
	
	my $newCookie = $cgi->cookie(
		-name    => 'Primer3Manager',
		-value   => $newValue,
		-expires => $expires,
		-path    => '/');

	print $cgi->header( -cookie => $newCookie );

	return;
}

sub getCookie {
	my $oldValue;
	$oldValue = $cgi->cookie( -name => 'Primer3Manager' );

	return $oldValue;
}

###########################################
# Functions to load and save a cache-file #
###########################################
sub getCacheFile {
	my ( $uniqueID, $cacheContent );
	$uniqueID     = shift;
	$cacheContent = shift;

	my $fileName = getMachineSetting("USER_CACHE_FILES_PATH"). ${$uniqueID} . ".fas";
	my $fileContent;

	if ( ( -r $fileName ) and ( -e $fileName ) ) {
		open( TEMPLATEFILE, "<$fileName" );
		binmode(TEMPLATEFILE);
		while (<TEMPLATEFILE>) {
			$fileContent .= $_;
		}
		close(TEMPLATEFILE);
	}

	if ($fileContent && $fileContent =~ /\w/ ) {
		${$cacheContent} = $fileContent;
	}
	else {
		${$cacheContent} = -1;
	}

	return;
}

sub setCacheFile {
	my ( $uniqueID, $cacheContent );
	$uniqueID     = shift;
	$cacheContent = shift;

	my $fileName    = getMachineSetting("USER_CACHE_FILES_PATH"). ${$uniqueID} . ".fas";
	my $fileContent = ${$cacheContent};

	open( TEMPLATEFILE, ">$fileName" );
	binmode(TEMPLATEFILE);
	print TEMPLATEFILE $fileContent;
	close(TEMPLATEFILE);

	return;
}

##################################################
# 
#######################
sub loadServerSettFile {
  my $fileName = shift;
  my $filePath = getMachineSetting("USER_PARAMETERS_FILES_PATH") . $fileName;
  my $FileContent = "";
  my $StringExist;
  my $FileContentBasic = "";
  
  # Try to read the Parameter file
  if (!-r $filePath){
		setMessage("Error loading Parameter-Template file: $fileName is not readable!");
  }

  if (!-e $filePath){
        setMessage("Error loading Parameter-Template file: $fileName does not exist!");
  }

  if ((-r $filePath) and (-e $filePath)){
	open (TEMPLATEFILE, "<$filePath") or 
						setMessage("Parameter: Cannot open template file: $fileName") ;
	
	while (<TEMPLATEFILE>) {
        	$FileContent .= $_;
  	}
    close(TEMPLATEFILE);

	# Find out if the string for the replacement could be found
	$StringExist = index ( $FileContent , "<!-- Primer3Plus will include code here -->" );
  }
  else {
    $FileContent = "";
  }

  return $FileContent;
};


##################################################################################################
# extractSelectedPrimers: extract the selected primers out of array 1 and write them in array 2  #
# modus          "A"  copy primer including the selection parameters to the new array            #
#                "U"  copy primer to the new array and select them                               #
#                "S"  copy only the selected primer to the new array                             #
#                "D"  copy only the not selected primer to the new array                         #
##################################################################################################
sub extractSelectedPrimers {
	my ( $sequences1, $names1, $selected1, $date1, $mode,
		 $sequences2, $names2, $selected2, $date2 );
		 
	$sequences1 = shift;
	$names1     = shift;
	$selected1  = shift;
	$date1      = shift;
	$mode       = shift;
	$sequences2 = shift;
	$names2     = shift;
	$selected2  = shift;
	$date2      = shift;

	# $counter2 counts the target numbers 
	my $counter2 = 0;
	my $maxPrimers = getMachineSetting("MAX_NUMBER_PRIMER_MANAGER");

	for ( my $counter1 = 0 ; (($counter1 <= $#{$sequences1}) and ($counter1 <= $maxPrimers)) ; $counter1++ ) {
		if (   ( ${$mode} eq "A" ) or ( ${$mode} eq "U" )
			or ( ( $selected1->[$counter1] && $selected1->[$counter1] == 1 ) and ( ${$mode} eq "S" ) )
			or ( ( !($selected1->[$counter1]) || $selected1->[$counter1] != 1 ) and ( ${$mode} eq "D" ) ) ) {
			
			$sequences2->[$counter2] = $sequences1->[$counter1];
			$names2->[$counter2]     = $names1->[$counter1];
			if ( ${$mode} eq "U" ) {
			    $selected2->[$counter2] = 1;
			}
			else {
			    $selected2->[$counter2] = $selected1->[$counter1];
			}
			if ( $date1->[$counter1] && $date1->[$counter1] =~ /\d/ ) {
				$date2->[$counter2] = $date1->[$counter1];
			}
			else {
				$date2->[$counter2] = getDate( "D", "." );
			}
			$counter2++;
		}

	}
	return;
}

##################################################################################################
# addToArray: extract the selected primers out of an array and add them at the end of array 2    #
#             it compares each primer with all the already existing primers and only copies new  #
##################################################################################################
sub addToArray {
	my ($sequences1, $names1, $selected1, $date1,
		$sequences2, $names2, $selected2, $date2 );
		
	$sequences1 = shift;
	$names1     = shift;
	$selected1  = shift;
	$date1      = shift;
	$sequences2 = shift;
	$names2     = shift;
	$selected2  = shift;
	$date2      = shift;

	my ( $copy, $array2end, @nameArray1, @nameArray2 );

	for ( my $counter1 = 0 ; $counter1 <= $#{$sequences1} ; $counter1++ ) {
		$copy = 1;
		@nameArray1 = split '\|', $names1->[$counter1];
		
		for ( my $counter2 = 0 ; $counter2 <= $#{$sequences2} ; $counter2++ ) {
			@nameArray2 = split '\|', $names2->[$counter2];
			if (    ( $sequences2->[$counter2] eq $sequences1->[$counter1] )
				and ( $nameArray2[0] eq $nameArray1[0] ) ) {
				$copy = 0;
			}
		}
		
		if ( $copy eq 1 ) {
			$array2end                = $#{$sequences2} + 1;
			$sequences2->[$array2end] = $sequences1->[$counter1];
			$names2->[$array2end]     = $names1->[$counter1];
			$selected2->[$array2end]   = $selected1->[$counter1];
			if ( $date1->[$counter1] =~ /\d/ ) {
				$date2->[$array2end] = $date1->[$counter1];
			}
			else {
				$date2->[$array2end] = getDate( "D", "." );
			}
		}
	}

	return;
}

#################################################################################
# constructCombinedHash: combine two hashes - "overwrite" overwriting "default" #
#################################################################################
sub constructCombinedHash {
	my ( %default, %overwrite ) = @_;
	my %combined;

	my ( $defKey, $overKey, $value );
	foreach $defKey ( keys %default ) {
		$value = ( defined $overwrite{$defKey} ) ? $overwrite{$defKey} : $default{$defKey};
		$combined{$defKey} = $value;
	}

	foreach $overKey ( keys %overwrite ) {
		if ( undef $default{$overKey} ) {	
			$combined{$overKey} = $overwrite{$overKey};
		}
	}

	return %combined;
}

######################################################################################
# createSequenceFile: Write all Information associated with the Sequence in a string #
######################################################################################
sub createSequenceFile {
	my ($settings, $saveKey, $returnString);
	$settings = shift;
	my @saveSequenceKeys = getSaveSequenceParameters();

	$returnString = "Primer3Plus File - Do not Edit\r\n";
	$returnString .= "Type: Sequence\r\n";
	$returnString .= "\r\n";

	foreach $saveKey (@saveSequenceKeys) {
		$returnString .= $saveKey . "=" . $settings->{$saveKey} . "\r\n";
	}

	$returnString .= "\r\n";

	return $returnString;
}

##################################################################################
# createSettingsFile: Write all Information associated with Settings in a string #
##################################################################################
sub createSettingsFile {
	my ($settings, $saveKey, $returnString);
	$settings = shift;
	my (@saveSettingsKeys) = getSaveSettingsParameters();

	$returnString = "Primer3Plus File - Do not Edit\r\n";
	$returnString .= "Type: Settings\r\n";
	$returnString .= "\r\n";

	foreach $saveKey (@saveSettingsKeys) {
		$returnString .= $saveKey . "=" . $settings->{$saveKey} . "\r\n";
	}

	$returnString .= "\r\n";

	return $returnString;
}

################################################################
# createManagerFile: Write Primers in Fasta format in a string #
################################################################
sub createManagerFile {
	my ( $sequences, $names, $selected, $date );
	$sequences = shift;
	$names     = shift;
	$selected  = shift;
	$date      = shift;
	my $returnString = "";
	my $select;

	for ( my $counter = 0 ; $counter <= $#{$sequences} ; $counter++ ) {
		if ( $selected->[$counter] eq 1 ) {
			$select = "X";
		}
		else {
			$select = "O";
		}
		$returnString .=
		  ">$names->[$counter]     |$select|$date->[$counter]\r\n";
		$returnString .= "$sequences->[$counter]\r\n";
		$returnString .= "\r\n";
	}

	$returnString .= "\r\n";

	return $returnString;
}

################################################################
# loadManagerFile: Write Primers in Fasta format in a string #
################################################################
sub loadManagerFile {
	my ( $fileString, $sequences, $names, $selected, $date );
	$fileString = shift;
	$sequences  = shift;
	$names      = shift;
	$selected    = shift;
	$date       = shift;
	my ( @fileContent, @nameLine );
	my ( $select,      $arrayCounter );

	if (!${$fileString}) {
		return;
	}

	# solve the newline problem with other platforms
	if (${$fileString} =~ /\r\n/ ) {
		${$fileString} =~ s/\r\n/\n/g;
	}
	if (${$fileString} =~ /\r/ ) {
		${$fileString} =~ s/\r/\n/g;
	}

	@fileContent = split '\n', ${$fileString};

	$arrayCounter = 0;
	for ( my $counter = 0 ; $counter <= $#fileContent ; $counter++ ) {
		if ( $fileContent[$counter] =~ /^>/ ) {
			$fileContent[$counter] =~ s/^>//;
			$fileContent[$counter] =~ s/^\s +//;

			@nameLine = split '\|', $fileContent[$counter];
			$nameLine[0] =~ s/\s+$//;
			$names->[$arrayCounter] = $nameLine[0];

			if ( $nameLine[1] eq "X" ) {
				$selected->[$arrayCounter] = 1;
			}
			else {
				$selected->[$arrayCounter] = 0;
			}

			$date->[$arrayCounter] = $nameLine[2];

			$counter++;
			$sequences->[$arrayCounter] = $fileContent[$counter];

			$arrayCounter++;
		}
	}

	return;
}

#######################################################
# loadFile: Loads a Primer3Plus-File back in the hash #
#            -> loads also sequence Files in the hash #
#######################################################
sub loadFile {
	my ( $fileString, $dataTarget, $makeMessage);
	$fileString  = shift;
	$dataTarget = shift;
	$makeMessage = shift;
	my @fileContent;
	my ( $line, $lineKey, $lineValue, $fileType, $readable, $sequenceCounter, $multiName );

    $sequenceCounter = 0;

	# solve the newline problem with other platforms
	if ( $fileString =~ /\r\n/ ) {
		$fileString =~ s/\r\n/\n/g;
	}
	if ( $fileString =~ /\r/ ) {
		$fileString =~ s/\r/\n/g;
	}

	# Cut off empty lines at the beginning
	$fileString =~ s/^\s*//;

	# Read Primer3Plus file
	if ( $fileString =~ /Primer3Plus File/ ) {
		@fileContent = split '\n', $fileString;
		$readable = 0;
		# Figure out the type of File
		if ( $fileContent[1] =~ /Type: Sequence/ ) {
			$fileType = "Sequence";
			$readable = 1;
		}
		if ( $fileContent[1] =~ /Type: Settings/ ) {
			$fileType = "Settings";
			$readable = 1;
		}
		# Read it directly to the Hash provided
		if ($readable == 1) {
			for ( my $i = 3 ; $i <= $#fileContent ; $i++ ) {
				$line = $fileContent[$i];
				if ( ( index( $line, "=" ) ) > 2 ) {
					( $lineKey, $lineValue ) = split "=", $line;
					$dataTarget->{"$lineKey"} = $lineValue;
				}
			}
			if ($makeMessage == 1) {
				setMessage("Primer3Plus loaded $fileType File");
			}
		}
	}

	# Read Fasta file format
	elsif ( $fileString =~ /^>/ ) {
		my ( $name, $sequence, $temp );
		@fileContent = split '\n', $fileString;

		for ( my $i = 0 ; $i <= $#fileContent ;  ) {
			( $temp, $name ) = split ">", $fileContent[$i];
			$i++;
			for ( my $stop = 0; $i <= $#fileContent and $stop == 0 ;  ) {
				if ( $fileContent[$i]=~ />/ ) {
					$stop = 1;
				}
				else {
					$sequence .= $fileContent[$i];
					$i++;
				}
			}
			if ($sequenceCounter == 0) {
			    $dataTarget->{"PRIMER_SEQUENCE_ID"} = $name;
			    $dataTarget->{"SEQUENCE"}           = $sequence;
			}
			else {
		        $dataTarget->{"PRIMER_SEQUENCE_ID_$sequenceCounter"} = $name;
		        $dataTarget->{"SEQUENCE_$sequenceCounter"} = $sequence;
			}		
			$sequenceCounter++;
			$sequence="";
		};
		
		$dataTarget->{"SCRIPT_SEQUENCE_COUNTER"} = $sequenceCounter;
		setMessage("Primer3Plus loaded Fasta-File");
	}

	# Read SeqEdit file format
	elsif ( $fileString=~ /\^\^/ ) {
	    my $sequence;
	    $fileString=~ s/\n//g ;
	    $fileString=~ /\^\^(\w+)/ ;
        $dataTarget->{"SEQUENCE"} = $1; 
	    setMessage("Primer3Plus loaded SeqEdit-File");
    }

	# Read GeneBank file format old way
#	elsif ( $fileString =~ /ORIGIN/ ) {
#		my ( $name, $sequence, $temp );
#		( $name,     $sequence ) = split "ORIGIN", $fileString;
#		( $sequence, $temp )     = split "//",     $sequence;
#		$sequence =~ s/\d//g;
#
#		( $temp, $name ) = split "DEFINITION", $name;
#		( $name, $temp ) = split "\n",         $name;
#		$name =~ s/^\s*//;
#
#		$dataTarget->{"PRIMER_SEQUENCE_ID"} = $name;
#		$dataTarget->{"SEQUENCE"}           = $sequence;
#		setMessage("Primer3Plus loaded GenBank-File");
#	}

	# Read GenBank file format
	elsif ( ( $fileString =~ /ORIGIN/ ) and ( $fileString =~ /LOCUS/ ) ) {
		my ( $name, $sequence, $temp, $inSeq, $sequenceCounter );
		@fileContent = split '\n', $fileString;
		
		$sequenceCounter = 0;
		$inSeq = 0;
		for ( my $i = 0 ; $i <= $#fileContent ; $i++ ) {
			if ( $fileContent[$i] =~ /^DEFINITION/ ) {
				( $temp, $name ) = split "DEFINITION", $fileContent[$i];
			}
			if (( $fileContent[$i] =~ /\/\// )
			     and ($inSeq == 1)) {
				$inSeq = 0;

	  	        $name     =~ s/^\s*//;
		        $sequence =~ s/\d//g;
		        $sequence =~ s/\W//g;

				if ($sequenceCounter == 0) {
				    $dataTarget->{"PRIMER_SEQUENCE_ID"} = $name;
				    $dataTarget->{"SEQUENCE"}           = $sequence;
				}
				else {
			        $dataTarget->{"PRIMER_SEQUENCE_ID_$sequenceCounter"} = $name;
			        $dataTarget->{"SEQUENCE_$sequenceCounter"} = $sequence;
				}		
				$sequenceCounter++;
				$sequence="";
			}
			if ( $inSeq == 1 ) {
				$sequence .= $fileContent[$i];
			}
			if ( $fileContent[$i] =~ /^ORIGIN/ ) {
				$inSeq = 1;
			}
		}
		$dataTarget->{"SCRIPT_SEQUENCE_COUNTER"} = $sequenceCounter;
		setMessage("Primer3Plus loaded GenBank-File");
	}
	# Read EMBL file format
	elsif ( ( $fileString =~ /Sequence/ ) and ( $fileString =~ /SQ/ ) ) {
		my ( $name, $sequence, $temp, $inSeq, $sequenceCounter );
		@fileContent = split '\n', $fileString;
		
		$sequenceCounter = 0;
		$inSeq = 0;
		for ( my $i = 0 ; $i <= $#fileContent ; $i++ ) {
			if ( $fileContent[$i] =~ /^KW/ ) {
				( $temp, $name ) = split "KW", $fileContent[$i];
			}
			if (( $fileContent[$i] =~ /\/\// )
			     and ($inSeq == 1)) {
				$inSeq = 0;

	  	        $name     =~ s/^\s*//;
		        $sequence =~ s/\d//g;
		        $sequence =~ s/\W//g;

				if ($sequenceCounter == 0) {
				    $dataTarget->{"PRIMER_SEQUENCE_ID"} = $name;
				    $dataTarget->{"SEQUENCE"}           = $sequence;
				}
				else {
			        $dataTarget->{"PRIMER_SEQUENCE_ID_$sequenceCounter"} = $name;
			        $dataTarget->{"SEQUENCE_$sequenceCounter"} = $sequence;
				}		
				$sequenceCounter++;
				$sequence="";
			}
			if ( $inSeq == 1 ) {
				$sequence .= $fileContent[$i];
			}
			if (    ( $fileContent[$i] =~ /Sequence/ )
				and ( $fileContent[$i] =~ /SQ/ ) ) {
				$inSeq = 1;
			}
		}
		$dataTarget->{"SCRIPT_SEQUENCE_COUNTER"} = $sequenceCounter;
		setMessage("Primer3Plus loaded EMBL-File");
	}	
	else {
		my $sequence;

  	    $sequence = $fileString;

  	    $sequence =~ s/^\s*//;
        $sequence =~ s/\d//g;
        $sequence =~ s/\W//g;
		
		$dataTarget->{"SEQUENCE"} = $sequence;
		setMessage("Error: Primer3Plus could not identify File Format");
	}

	return;
}

#####################################################################
# runSeqRet: Try to read the file with SeqRet and retun it as fasta #
#####################################################################

sub runSeqRet {
	my ($inputFile, $returnFile);
	$inputFile = shift;
	$returnFile = $returnFile;
	
	$returnFile = $inputFile;
	
	return $returnFile;
}


####################################################################
# checkParameters: Checks the Parameter in Hash for wrong settings #
####################################################################
sub checkParameters (\%) {
	my ($dataStorage);
	$dataStorage = shift;
	my %misLibrary      = getMisLibrary();
	my ( $fixPrimerEnd, $libary );
	
    ## A hidden way to obtain a example sequence for demonstration
    if ( defined( $dataStorage->{"Default_Settings"} ) ) {
        my $choosenSequence = $dataStorage->{"SEQUENCE"};
        if ( $choosenSequence eq "example" ) {
            $dataStorage->{"SEQUENCE"} = getLyk3Sequence();
            $dataStorage->{"PRIMER_SEQUENCE_ID"} = "Medicago NSP2";
        } else {
            $dataStorage->{"SEQUENCE"} = "";
            $dataStorage->{"PRIMER_SEQUENCE_ID"} = "";
        }
    }

    ## Copy the selected sequence of a multiSequence file to the input
    if ( defined( $dataStorage->{"SelectOneSequence"} ) ) {
        my $choosenSequence = $dataStorage->{"SCRIPT_SELECTED_SEQUENCE"};
        if ( $choosenSequence != 0 ) {
            $dataStorage->{"SEQUENCE"} = $dataStorage->{"SEQUENCE_$choosenSequence"};
            $dataStorage->{"PRIMER_SEQUENCE_ID"} = $dataStorage->{"PRIMER_SEQUENCE_ID_$choosenSequence"};
        }
    }

	## Check from which end to cut a primer
	$fixPrimerEnd = $dataStorage->{"SCRIPT_FIX_PRIMER_END"};
	if ( $fixPrimerEnd ne "3" ) {
		$fixPrimerEnd = "5";
		$dataStorage->{"SCRIPT_FIX_PRIMER_END"} = $fixPrimerEnd;
	}

	## Check if the mispriming libarys exist and can be used
	$libary = $dataStorage->{"PRIMER_MISPRIMING_LIBRARY"};
	if ( !defined( $misLibrary{$libary} ) ) {
		setMessage("Error: Mispriming Library $libary does not exist on this server!");
		setMessage("Mispriming Library was changed to: NONE");
		$libary = "NONE";
		$dataStorage->{"PRIMER_MISPRIMING_LIBRARY"} = $libary;
	}
	if ( ( $libary ne "NONE" ) and !( -r $misLibrary{$libary} ) ) {
		setMessage("Error: Mispriming Library $libary can not be read!");
		setMessage("Mispriming Library was changed to: NONE");
		$libary = "NONE";
		$dataStorage->{"PRIMER_MISPRIMING_LIBRARY"} = $libary;
	}
	
	$libary = $dataStorage->{"PRIMER_INTERNAL_OLIGO_MISHYB_LIBRARY"};
	if ( !defined( $misLibrary{$libary} ) ) {
		setMessage("Error: Oligo Mispriming Library $libary does not exist on this server!");
		setMessage("Oligo Mispriming Library was changed to: NONE");
		$libary = "NONE";
		$dataStorage->{"PRIMER_INTERNAL_OLIGO_MISHYB_LIBRARY"} = $libary;
	}
	if ( ( $libary ne "NONE" ) and !( -r $misLibrary{$libary} ) ) {
		setMessage("Error: Oligo Mispriming Library $libary can not be read!");
		setMessage("Oligo Mispriming Library was changed to: NONE");
		$libary = "NONE";
		$dataStorage->{"PRIMER_INTERNAL_OLIGO_MISHYB_LIBRARY"} = $libary;
	}

	## Check first base index
	if ( ( $dataStorage->{"PRIMER_FIRST_BASE_INDEX"} ) ne "1" ) {
		$dataStorage->{"PRIMER_FIRST_BASE_INDEX"} = "0";
	}

	## Read fasta-sequence and the regions
	my $firstBaseIndex   = $dataStorage->{"PRIMER_FIRST_BASE_INDEX"};
	my $sequenceID       = $dataStorage->{"PRIMER_SEQUENCE_ID"};
	my $realSequence     = $dataStorage->{"SEQUENCE"};
	my $excludedRegion   = $dataStorage->{"EXCLUDED_REGION"};
	my $target           = $dataStorage->{"TARGET"};
	my $includedRegion   = $dataStorage->{"INCLUDED_REGION"};

	if ( $realSequence =~ /^\s*>([^\n]*)/ ) {

		# Sequence is in Fasta format.
		my $fastaID = $1;
		$fastaID =~ s/^\s*//;
		$fastaID =~ s/\s*$//;
		if ( $sequenceID eq "" ) {
			$sequenceID = $fastaID;
		}
		else {
			setMessage("WARNING: 2 Sequence Ids provided: $sequenceID".
			           " and $fastaID; using $sequenceID|$fastaID");
			$sequenceID .= "|$fastaID";
		}
		$realSequence =~ s/^\s*>([^\n]*)//;
	}
	if ( $realSequence =~ /\d/ ) {
		setMessage("WARNING: Numbers in input sequence were deleted.");
		$realSequence =~ s/\d//g;
	}
	$realSequence =~ s/\s//g;
	my ( $m_target, $m_excluded_region, $m_included_region ) =
	          read_sequence_markup( $realSequence, ( [ '[', ']' ], [ '<', '>' ], [ '{', '}' ] ) );
	$realSequence =~ s/[\[\]\<\>\{\}]//g;
	if ($m_target && @$m_target) {
		if ($target) {
			setMessage("WARNING Targets specified both as sequence".
			           " markups and in Other Per-Sequence Inputs");
		}
		$target = add_start_len_list( $target, $m_target, $firstBaseIndex );
	}
	if ($m_excluded_region && @$m_excluded_region) {
		if ($excludedRegion) {
			setMessage("WARNING Excluded Regions specified both as sequence".
			           " markups and in Other Per-Sequence Inputs");
		}
		$excludedRegion =
		  add_start_len_list( $excludedRegion, $m_excluded_region,	$firstBaseIndex );
	}
	if ($m_included_region && @$m_included_region) {
		if ( scalar @$m_included_region > 1 ) {
			setMessage("ERROR: Too many included regions");
		}
		elsif ($includedRegion) {
			setMessage("ERROR: Included region specified both as sequence".
			           " markup and in Other Per-Sequence Inputs");
		}
		$includedRegion =  add_start_len_list( $includedRegion, $m_included_region, $firstBaseIndex );
	}
	$dataStorage->{"PRIMER_SEQUENCE_ID"} = $sequenceID;
	$dataStorage->{"SEQUENCE"}           = $realSequence;
	$dataStorage->{"EXCLUDED_REGION"}    = $excludedRegion;
	$dataStorage->{"TARGET"}             = $target;
	$dataStorage->{"INCLUDED_REGION"}    = $includedRegion;

	## Remove Commas in Product size ranges
	$dataStorage->{"PRIMER_PRODUCT_SIZE_RANGE"} =~ s/,/ /g;

	## If sequence quality contains newlines (or other non-space whitespace) change them to space.
	$dataStorage->{"PRIMER_SEQUENCE_QUALITY"} =~ s/\s/ /sg;

	## Cut primers and internal oligo to max size primer3 can handle
	my $primerLeft    = $dataStorage->{"PRIMER_LEFT_INPUT"};
	my $internalOligo = $dataStorage->{"PRIMER_INTERNAL_OLIGO_INPUT"};
	my $primerRight   = $dataStorage->{"PRIMER_RIGHT_INPUT"};
	my $maxPrimerSize  = getMachineSetting("MAX_PRIMER_SIZE");
	my $cutPosition;
	my $cutLeft  = "";
	my $cutOligo = "";
	my $cutRight = "";

	if ( ( length $primerLeft ) > $maxPrimerSize ) {
		if ( $fixPrimerEnd eq "5" ) {
			$cutLeft = substr( $primerLeft, 0, $maxPrimerSize );
			setMessage("ERROR: Left Primer longer than $maxPrimerSize ".
			           "bp. Additional bases were removed on the 3' end");
		}
		else {
			$cutPosition = ( ( length $primerLeft ) - $maxPrimerSize );
			$cutLeft = substr( $primerLeft, $cutPosition, $maxPrimerSize );
			setMessage("ERROR: Left Primer longer than $maxPrimerSize ".
			           "bp. Additional bases were removed on the 5' end");
		}
		$dataStorage->{"PRIMER_LEFT_INPUT"} = $cutLeft;
	}
	if ( ( length $internalOligo ) > $maxPrimerSize ) {
		if ( $fixPrimerEnd eq "5" ) {
			$cutOligo = substr( $internalOligo, 0, $maxPrimerSize );
			setMessage("ERROR: Internal Oligo longer than $maxPrimerSize ".
			           "bp. Additional bases were removed on the 3' end");
		}
		else {
			$cutPosition = ( ( length $internalOligo ) - $maxPrimerSize );
			$cutOligo = substr( $internalOligo, $cutPosition, $maxPrimerSize );
			setMessage("ERROR: Internal Oligo longer than $maxPrimerSize ".
			           "bp. Additional bases were removed on the 5' end");
		}
		$dataStorage->{"PRIMER_INTERNAL_OLIGO_INPUT"} = $cutOligo;
	}
	if ( ( length $primerRight ) > $maxPrimerSize ) {
		if ( $fixPrimerEnd eq "5" ) {
			$cutRight = substr( $primerRight, 0, $maxPrimerSize );
			setMessage("ERROR: Right Primer longer than $maxPrimerSize ".
			           "bp. Additional bases were removed on the 3' end");
		}
		else {
			$cutPosition = ( ( length $primerRight ) - $maxPrimerSize );
			$cutRight = substr( $primerRight, $cutPosition, $maxPrimerSize );
			setMessage("ERROR: Right Primer longer than $maxPrimerSize ".
			           "bp. Additional bases were removed on the 5' end");
		}
		$dataStorage->{"PRIMER_RIGHT_INPUT"} = $cutRight;
	}

	return;
}

##########################################################
# Functions for the region functionality from primer3web #
##########################################################
sub add_start_len_list($$$) {
	my ( $list_string, $list, $plus ) = @_;
	my $sp = $list_string ? ' ' : '';
	for (@$list) {
		$list_string .= ( $sp . ( $_->[0] + $plus ) . "," . $_->[1] );
		$sp = ' ';
	}
	return $list_string;
}

sub read_sequence_markup($@) {
	my ( $s, @delims ) = @_;

	# E.g. ['/','/'] would be ok in @delims, but
	# no two pairs in @delims may share a character.
	my @out = ();
	for (@delims) {
		push @out, read_sequence_markup_1_delim( $s, $_, @delims );
	}
	@out;
}

sub read_sequence_markup_1_delim($$@) {
	my ( $s, $d, @delims ) = @_;
	my ( $d0, $d1 ) = @$d;
	my $other_delims = '';
	for (@delims) {
		next if $_->[0] eq $d0 and $_->[1] eq $d1;
		confess 'Programming error' if $_->[0] eq $d0;
		confess 'Programming error' if $_->[1] eq $d1;
		$other_delims .= '\\' . $_->[0] . '\\' . $_->[1];
	}
	if ($other_delims) {
		$s =~ s/[$other_delims]//g;
	}

	# $s now contains only the delimters of interest.
	my @s = split( //, $s );
	my ( $c, $pos ) = ( 0, 0 );
	my @out = ();
	my $len;
	while (@s) {
		$c = shift(@s);
		next if ( $c eq ' ' );    # Already used delimeters are set to ' '
		if ( $c eq $d0 ) {
			$len = len_to_delim( $d0, $d1, \@s );
			return undef if ( !defined $len );
			push @out, [ $pos, $len ];
		}
		elsif ( $c eq $d1 ) {

			# There is a closing delimiter with no opening
			# delimeter, an input error.
			setDoNotPick("1");
			setMessage("ERROR IN SEQUENCE: closing delimiter $d1 not preceded by $d0");
			return undef;
		}
		else {
			$pos++;
		}
	}
	return \@out;
}

sub len_to_delim($$$) {
	my ( $d0, $d1, $s ) = @_;
	my $i;
	my $len = 0;
	for $i ( 0 .. $#{$s} ) {
		if ( $s->[$i] eq $d0 ) {

			# ignore it;
		}
		elsif ( $s->[$i] eq $d1 ) {
			$s->[$i] = ' ';
			return $len;
		}
		else { $len++ }
	}

	# There was no terminating delim;
	setDoNotPick("1");
	setMessage("ERROR IN SEQUENCE: closing delimiter $d1 did not follow $d0");
	return undef;
}

#####################################################################
# prepareForPrimer3: Prepares some variables for Primer3 before use #
#####################################################################
sub prepareForPrimer3 ($) {
	my $p3cInput;
	$p3cInput = shift;
	my %misLibrary = getMisLibrary();
	my $libary;
	if ( defined $p3cInput->{"PRIMER_MISPRIMING_LIBRARY"} ) {
		$libary = $p3cInput->{"PRIMER_MISPRIMING_LIBRARY"};
		$p3cInput->{"PRIMER_MISPRIMING_LIBRARY"} = $misLibrary{$libary};
	}
	if ( defined $p3cInput->{"PRIMER_INTERNAL_OLIGO_MISHYB_LIBRARY"} ) {
		$libary = $p3cInput->{"PRIMER_INTERNAL_OLIGO_MISHYB_LIBRARY"};
		$p3cInput->{"PRIMER_INTERNAL_OLIGO_MISHYB_LIBRARY"} = $misLibrary{$libary};
	}

	return;
}

#####################################################################
# findAllPrimers: selects between the tasks and returns the results #
#####################################################################
sub findAllPrimers {
	my ( $completeHash, $resultsHash );
	$completeHash = shift;
	$resultsHash  = shift;
	my %tempResults;
	my ( $HashKeys, $task );

	$task = $completeHash->{"SCRIPT_TASK"};
	$resultsHash->{"SCRIPT_TASK"} = $completeHash->{"SCRIPT_TASK"};

	if ( $task eq "Detection" ) {
		detection( $completeHash, $resultsHash, "0", "0" );
	}
	elsif ( $task eq "Primer_List" ) {
		detection( $completeHash, $resultsHash, "1", "0" );
	}
	elsif ( $task eq "Primer_Check" ) {
		checkPrimer( $completeHash, $resultsHash );
	}
	elsif ( $task eq "Cloning" ) {
		cloning( $completeHash, $resultsHash );
	}
	elsif ( $task eq "Sequencing" ) {
		detection( $completeHash, \%tempResults, "1", "1" );
		sortSequencing( $completeHash, \%tempResults, $resultsHash );
	}
	else {
		setMessage("Primer3Plus can not run the function: $task");
		setMessage("This was the given input:");
		foreach $HashKeys ( keys(%$completeHash) ) {
			$resultsHash->{"$HashKeys"} = $completeHash->{"$HashKeys"};
		}
	}
	return;
}

####################################################################
# detection: functionality equivalent to the old primer3 interface #
####################################################################
sub detection ($$$$) {
	my ( $completeHash, $resultsHash, $makeList, $Sequencing );
	$completeHash = shift;
	$resultsHash  = shift;
	$makeList     = shift;
	$Sequencing   = shift;
	if ( $makeList ne "1" ) {
		$makeList = 0;
	}
	if ( $Sequencing ne "1" ) {
		$Sequencing = 0;
	}
	
	# p3c stands for primer3core and relays to parameters for the primer3 programm
	my @p3cParameters;
	@p3cParameters = getPrimer3CompleteParameters();
	my ( %p3cInput, %p3cOutput );
	my ( $p3cOutputKeys, $p3cParametersKey );

	## Set the parameters to use optimal Product size input
	if ( ( $completeHash->{"SCRIPT_DETECTION_USE_PRODUCT_SIZE"} ) ne "0" ) {
		my $minSize = $completeHash->{"SCRIPT_DETECTION_PRODUCT_MIN_SIZE"};
		$completeHash->{"PRIMER_PRODUCT_OPT_SIZE"} =
		     $completeHash->{"SCRIPT_DETECTION_PRODUCT_OPT_SIZE"};
		my $maxSize = $completeHash->{"SCRIPT_DETECTION_PRODUCT_MAX_SIZE"};
		$completeHash->{"PRIMER_PRODUCT_SIZE_RANGE"}      = "$minSize-$maxSize";
	}

	## Figure out the Task for primer3
	my $pick_left  = $completeHash->{"SCRIPT_DETECTION_PICK_LEFT"};
	my $pick_hyb   = $completeHash->{"SCRIPT_DETECTION_PICK_HYB_PROBE"};
	my $pick_right = $completeHash->{"SCRIPT_DETECTION_PICK_RIGHT"};

	if ( ( $completeHash->{"PRIMER_LEFT_INPUT"} ) ne "" ) {
		$pick_left = "1";
	}
	if ( ( $completeHash->{"PRIMER_INTERNAL_OLIGO_INPUT"} ) ne "" ) {
		$pick_hyb = "1";
	}
	if ( ( $completeHash->{"PRIMER_RIGHT_INPUT"} ) ne "" ) {
		$pick_right = "1";
	}
	my $task;
	if ( $pick_hyb eq "1" ) {
		if ( ( $pick_right eq "1" ) || ( $pick_left eq "1" ) ) {
			$task = "pick_pcr_primers_and_hyb_probe";
			if ( !( $pick_right eq "1" ) ) {
				setMessage("WARNING: Assuming you want to pick a right primer because you".
				           " are picking a left primer and internal oligo" );
			}
			if ( !( $pick_left eq "1" ) ) {
				setMessage("WARNING: Assuming you want to pick a left primer because you".
                           " are picking a right primer and internal oligo" );
			}
		}
		else {
			$task = "pick_hyb_probe_only";
		}
	}
	else {
		if ( ( $pick_right eq "1" ) && ( $pick_left eq "1" ) ) {
			$task = "pick_pcr_primers";
		}
		elsif ( $pick_right eq "1" ) {
			$task = "pick_right_only";
		}
		elsif ( $pick_left eq "1" ) {
			$task = "pick_left_only";
		}
		else {
			setMessage("WARNING: assuming you want to pick PCR primers");
			$task = "pick_pcr_primers";
		}
	}
	$completeHash->{"PRIMER_TASK"} = $task;

	## Copy the oligos to sequence if no sequence is given
	my $inferred_sequence = "";
	if ( ( $completeHash->{"SEQUENCE"} ) eq "" ) {
		if ( ( $completeHash->{"PRIMER_LEFT_INPUT"} ) ne "" ) {
			$inferred_sequence .= $completeHash->{"PRIMER_LEFT_INPUT"};
		}
		if ( ( $completeHash->{"PRIMER_INTERNAL_OLIGO_INPUT"} ) ne "" ) {
			$inferred_sequence .= $completeHash->{"PRIMER_INTERNAL_OLIGO_INPUT"};
		}
		if ( ( $completeHash->{"PRIMER_RIGHT_INPUT"} ) ne "" ) {
			my $tmpRevSeq = reverseSequence( $completeHash->{"PRIMER_RIGHT_INPUT"} );
			$inferred_sequence .= $tmpRevSeq;
		}
		if ( $inferred_sequence eq "" ) {
			setMessage("ERROR: you must supply a source sequence or".
			           "primers/oligos to evaluate");
			setDoNotPick("1");
		}
		$completeHash->{"SEQUENCE"} = $inferred_sequence;
	}

	# Copy all necessary parmeters
	foreach $p3cParametersKey (@p3cParameters) {
		$p3cInput{"$p3cParametersKey"} = $completeHash->{"$p3cParametersKey"};
	}
    
    # The Seuencing function uses the Targets in a different way
	if ( $Sequencing eq "1" ) {
		$p3cInput{INCLUDED_REGION} = "";
		$p3cInput{TARGET}          = "";
		$p3cInput{EXCLUDED_REGION} = "";
	}

	# Set some parameters to enable primer3 to work
	$p3cInput{PRIMER_PICK_ANYWAY}  = "1";
	$p3cInput{PRIMER_FILE_FLAG}    = $makeList;
	$p3cInput{PRIMER_EXPLAIN_FLAG} = "1";

	my $uniID;
	my $sequenceID = $p3cInput{PRIMER_SEQUENCE_ID};

	# Save Sequence ID for later and add UniID for file name
	# to avoid confusion on the harddisk
	if ( $makeList eq "1" ) {
		$uniID = makeUniqueID();
		$p3cInput{PRIMER_SEQUENCE_ID} = $uniID;

		# File Lists with Mispriming Librarys just take to long to compute
		$p3cInput{"PRIMER_MISPRIMING_LIBRARY"}            = "NONE";
		$p3cInput{"PRIMER_INTERNAL_OLIGO_MISHYB_LIBRARY"} = "NONE";
		if ( $Sequencing eq "1" ) {
			$completeHash->{"PRIMER_TASK"} = "pick_pcr_primers";
		}
	}

	# prepare parameters for primer3
	prepareForPrimer3( \%p3cInput );
	
	# Execute primer3
	runPrimer3( \%p3cInput, \%p3cOutput, $completeHash );
	
	if ( $makeList eq "1" ) {

		# Put the Sequence ID back and read the files
		$resultsHash->{"PRIMER_SEQUENCE_ID"} = $sequenceID;
		$resultsHash->{"SEQUENCE"} = $completeHash->{"SEQUENCE"};
		$resultsHash->{"PRIMER_FIRST_BASE_INDEX"} = $completeHash->{"PRIMER_FIRST_BASE_INDEX"};

		if ( $pick_right eq "1" ) {
			readPrimerFile( $resultsHash, $completeHash,
							"$uniID.rev", "RIGHT", $Sequencing );
		}
		if ( $pick_hyb eq "1" ) {
			readPrimerFile( $resultsHash, $completeHash,
							"$uniID.int", "INTERNAL_OLIGO", $Sequencing );
		}
		if ( $pick_left eq "1" ) {
			readPrimerFile( $resultsHash, $completeHash,
							"$uniID.for", "LEFT", $Sequencing );
		}
	}
	else {
		foreach $p3cOutputKeys ( keys(%p3cOutput) ) {
			$resultsHash->{"$p3cOutputKeys"} = $p3cOutput{"$p3cOutputKeys"};
		}
	}

	return;
}

######################################################
# readPrimerFile: Reads Primer3 output Files to Hash #
######################################################
sub readPrimerFile ($$$) {
	my ( $resultsHash, $completeHash, $fileName, $primerType, $Sequencing );
	$resultsHash   = shift;
	$completeHash  = shift;
	$fileName      = shift;
	$primerType    = shift;
	$Sequencing    = shift;
	
	my ( $data, $fileContent, $fileLine );
	my ( @fileArray, @lineArray );
	my ( $primerCounter,  $primerName, $primerPosition,
         $primerSequence, $primerGC,  $primerTm, $primerAny, $primerEnd,
         $primerPenalty, $lastBase, $primerInitial );

    if ($primerType eq "LEFT"){
    	$primerInitial  = $completeHash->{"PRIMER_NAME_ACRONYM_LEFT"};
    }
    elsif ($primerType eq "RIGHT"){
		$primerInitial = $completeHash->{"PRIMER_NAME_ACRONYM_RIGHT"};
    }
    elsif ($primerType eq "INTERNAL_OLIGO"){
		$primerInitial = $completeHash->{"PRIMER_NAME_ACRONYM_INTERNAL_OLIGO"};
    }
    else {
		$primerInitial = "??";
    }
   	my $acronymSpace = $completeHash->{"PRIMER_NAME_ACRONYM_SPACER"};
	my $sequenceName = $resultsHash->{"PRIMER_SEQUENCE_ID"};

	if ( ( length($fileName) > 5 ) ) {
		open TEMPLATEFILE, "<$fileName"
		  or setMessage("cannot open template file $fileName");
		binmode(TEMPLATEFILE);
		while (<TEMPLATEFILE>) {
			$fileContent .= $_;
		}
		close(TEMPLATEFILE);
		unlink("$fileName");

		# solve the newline problem with other platforms
		if ( $fileContent =~ /\r\n/ ) {
			$fileContent =~ s/\r\n/\n/g;
		}
		if ( $fileContent =~ /\r/ ) {
			$fileContent =~ s/\r/\n/g;
		}

		$fileContent =~ s/ +/ /g;
		$fileContent =~ s/^\s +/ /;
		$fileContent =~ s/\s+$/ /g;

		# read string to Array
		@fileArray = split '\n', $fileContent;

		shift(@fileArray);
		shift(@fileArray);
		shift(@fileArray);

		foreach $fileLine (@fileArray) {

			@lineArray = split ' ', $fileLine;

			$primerCounter  = $lineArray[0];
			$primerSequence = $lineArray[1];
			if ( $Sequencing ne 1 ) {
				if ($primerCounter == 0){
					$primerName = $sequenceName.$acronymSpace.$primerInitial;
				}
				else {
					$primerName = $sequenceName.$acronymSpace.
								$primerCounter.$acronymSpace.$primerInitial;
				}
			}
			else {
				$lastBase   = $lineArray[2] + $lineArray[3];
				$primerName = $sequenceName.$acronymSpace.
							$lastBase.$acronymSpace.$primerInitial;
			}
			$primerPosition = $lineArray[2] . "," . $lineArray[3];
			$primerGC       = $lineArray[5];
			$primerTm       = $lineArray[6];
			$primerAny      = $lineArray[7];
			$primerEnd      = $lineArray[8];
			$primerPenalty  = $lineArray[9];

			$primerCounter = "_" . $primerCounter;
			
			$resultsHash->{"PRIMER_$primerType$primerCounter"} = $primerPosition;
			$resultsHash->{"PRIMER_$primerType$primerCounter\_SEQUENCE"} = $primerSequence;
			$resultsHash->{"PRIMER_$primerType$primerCounter\_NAME"} = $primerName;
			$resultsHash->{"PRIMER_$primerType$primerCounter\_TM"} = $primerTm;
			$resultsHash->{"PRIMER_$primerType$primerCounter\_GC_PERCENT"} = $primerGC;
			$resultsHash->{"PRIMER_$primerType$primerCounter\_SELF_ANY"} = $primerAny;
			$resultsHash->{"PRIMER_$primerType$primerCounter\_SELF_END"} = $primerEnd;
			$resultsHash->{"PRIMER_$primerType$primerCounter\_PENALTY"} = $primerPenalty;
		}
	}

	return;
}

##########################################################
# checkPrimer: Checks one Primer with the given settings #
##########################################################
sub checkPrimer ($$) {
	my ( $completeHash, $resultsHash );
	$completeHash = shift;
	$resultsHash  = shift;
	my @primerCheckParameters;
	my @message;
	@primerCheckParameters = getPrimerCheckParameters();
	my ( %p3cInput, %p3cOutput );
	my ( $p3cOutputKeys,$checkParameterKey, $primerName );

	# Check if a primer sequence was provided and the length meet the limits
	my $leftPrimerLength = length( $completeHash->{"PRIMER_LEFT_INPUT"} );
	if ( $completeHash->{"PRIMER_LEFT_INPUT"} eq "" ) {
		setDoNotPick("1");
		setMessage("Error: Primer3Plus can not calculate".
		           " primer parameters without a primer sequence");
	}
	if ( $leftPrimerLength > $completeHash->{"PRIMER_MAX_SIZE"} ) {
		$resultsHash->{"PRIMER_LEFT_0_MESSAGE"} = "Primer bigger than ".
					   "PRIMER_MAX_SIZE of $completeHash->{PRIMER_MAX_SIZE}";
	}
	if ( $leftPrimerLength < $completeHash->{"PRIMER_MIN_SIZE"} ) {
		$resultsHash->{"PRIMER_LEFT_0_MESSAGE"} = "Primer smaller than ".
		        	   "PRIMER_MIN_SIZE of $completeHash->{PRIMER_MIN_SIZE}";
	}

	# Copy all necessary parmeters
	foreach $checkParameterKey (@primerCheckParameters) {
		$p3cInput{"$checkParameterKey"} = $completeHash->{"$checkParameterKey"};
	}

	# Set some parameters to enable primer3 to work
	$p3cInput{PRIMER_TASK}         = "pick_left_only";
	$p3cInput{PRIMER_PICK_ANYWAY}  = "1";
	$p3cInput{PRIMER_FILE_FLAG}    = "0";
	$p3cInput{PRIMER_EXPLAIN_FLAG} = "0";
	$p3cInput{PRIMER_MIN_SIZE}     = "1";
	$p3cInput{PRIMER_MAX_SIZE}     = getMachineSetting("MAX_PRIMER_SIZE");
	$p3cInput{PRIMER_NUM_RETURN}   = "1";
	$p3cInput{SEQUENCE}            = $p3cInput{PRIMER_LEFT_INPUT};

	# prepare parameters for primer3
	prepareForPrimer3( \%p3cInput );

	# Execute primer3
	runPrimer3( \%p3cInput, \%p3cOutput, $completeHash );

	foreach $p3cOutputKeys ( keys(%p3cOutput) ) {
		$resultsHash->{"$p3cOutputKeys"} = $p3cOutput{"$p3cOutputKeys"};
	}

	if ( ( length( $p3cInput{"PRIMER_SEQUENCE_ID"} ) ) > 2 ) {
		$primerName = qq{$p3cInput{"PRIMER_SEQUENCE_ID"}};
	}
	else {
		$primerName = "Primer";
	}
	$resultsHash->{"PRIMER_LEFT_0_NAME"} = "$primerName";

	return;
}

#################################################
# cloning: Picks Primer with the given position #
#################################################
sub cloning ($$) {
	my ( $completeHash, $resultsHash );
	$completeHash = shift;
	$resultsHash  = shift;
	my ( @goodResults,        @badResults );
	my ( @goodResultsReverse, @badResultsReverse );
	my @primerCheckParameters;
	@primerCheckParameters = getPrimerCheckParameters();
	my %p3cInput;
	my ( $p3cOutputKeys, $checkParametersKey, $complementPrimer, $primerCounter );
	my ( $regionStart,  $regionLength,  $primerStart,
		 $primerLength, $maxPrimerSize, $minPrimerSize,
		 $fixPrimerEnd, $bigestPrimer,  $counter );

	# Get the constant Values
	$minPrimerSize = 8;
	$maxPrimerSize = getMachineSetting("MAX_PRIMER_SIZE");
	$fixPrimerEnd  = $completeHash->{"SCRIPT_FIX_PRIMER_END"};

	# Check if a sequence an included region was provided
	if ( $completeHash->{"SEQUENCE"} eq "" ) {
		setDoNotPick("1");
		setMessage("Error: Primer3Plus can not pick".
		           " primers without a  sequence");
	}
	if ( $completeHash->{"INCLUDED_REGION"} eq "" ) {
		setDoNotPick("1");
		setMessage("Error: Primer3Plus can not pick cloning".
		           " primes without given included region");
	}

	# Copy all necessary parmeters
	$resultsHash->{"SEQUENCE"}        = $completeHash->{"SEQUENCE"};
	$resultsHash->{"INCLUDED_REGION"} = $completeHash->{"INCLUDED_REGION"};
	$resultsHash->{"PRIMER_FIRST_BASE_INDEX"} = $completeHash->{"PRIMER_FIRST_BASE_INDEX"};
	$resultsHash->{"PRIMER_NUM_RETURN"}  = $completeHash->{"PRIMER_NUM_RETURN"};
	$resultsHash->{"PRIMER_SEQUENCE_ID"} = $completeHash->{"PRIMER_SEQUENCE_ID"};

	foreach $checkParametersKey (@primerCheckParameters) {
		$p3cInput{"$checkParametersKey"} = $completeHash->{"$checkParametersKey"};
	}

	# Set some parameters to enable primer3 to work
	$p3cInput{PRIMER_LEFT_INPUT} = "";
	
	# Get starting parameters for the left primer
	( $regionStart, $regionLength ) = split ",", $completeHash->{"INCLUDED_REGION"};
	$regionStart = $regionStart - $completeHash->{"PRIMER_FIRST_BASE_INDEX"};
	$bigestPrimer = $maxPrimerSize;

    # Figue out if there is enough sequence to pick the primers from
	if ( $fixPrimerEnd eq "5" ) {
		if ( ( length( $completeHash->{"SEQUENCE"} ) ) 
		         < ( $regionStart + $maxPrimerSize ) ) {
			$bigestPrimer = ( length( $completeHash->{"SEQUENCE"} ) ) - $regionStart;
		}
	}
	else {
		if ( $regionStart < $maxPrimerSize ) {
			$bigestPrimer = $regionStart + 1;
		}
	}

	for ( $counter = $minPrimerSize ; $counter <= $bigestPrimer ; $counter++ ) {
		my %p3cOutput;
		if ( $fixPrimerEnd eq "5" ) {
			$primerStart = $regionStart;
			$p3cInput{PRIMER_LEFT_INPUT} =
			  substr( $completeHash->{"SEQUENCE"}, $primerStart, $counter );
		}
		else {
			$primerStart = $regionStart - $counter + 1;
			$p3cInput{PRIMER_LEFT_INPUT} =
			  substr( $completeHash->{"SEQUENCE"}, $primerStart, $counter );
		}

		checkPrimer( \%p3cInput, \%p3cOutput );
		$primerStart = $primerStart + $completeHash->{"PRIMER_FIRST_BASE_INDEX"};
		$p3cOutput{"PRIMER_LEFT_0"} = "$primerStart,$counter";

		if (   $p3cOutput{PRIMER_LEFT_0_TM} >= $p3cOutput{PRIMER_MIN_TM}
			&& $p3cOutput{PRIMER_LEFT_0_TM} <= $p3cOutput{PRIMER_MAX_TM} ) {
			push @goodResults, \%p3cOutput;
		}
		else {
			push @badResults, \%p3cOutput;
		}
	}

	$primerCounter = 0;

	extractPrimerParameters( $completeHash, \@goodResults, $resultsHash,
							 "LEFT", \$primerCounter );

	extractPrimerParameters( $completeHash, \@badResults, $resultsHash,
							 "LEFT", \$primerCounter );

	# Now the same for the right primer
	# Set some parameters to enable primer3 to work
	( $regionStart, $regionLength ) = split ",",
	  $completeHash->{"INCLUDED_REGION"};
	$regionStart = $regionStart + $regionLength -
	 				 $completeHash->{"PRIMER_FIRST_BASE_INDEX"} - 1;

	$bigestPrimer = $maxPrimerSize;

	# Get starting parameters for the left primer - include check left
	if ( $fixPrimerEnd eq "3" ) {
		if ( ( length( $completeHash->{"SEQUENCE"} ) ) <
			 ( $regionStart + $maxPrimerSize ) ) {
			$bigestPrimer =
			  ( length( $completeHash->{"SEQUENCE"} ) ) - $regionStart;
		}
	}
	else {
		if ( $regionStart < $maxPrimerSize ) {
			$bigestPrimer = $regionStart + 1;
		}
	}

	for ( $counter = $minPrimerSize ; $counter <= $bigestPrimer ; $counter++ ) {
		my %p3cOutput;
		if ( $fixPrimerEnd eq "3" ) {
			$primerStart      = $regionStart;
			$complementPrimer =
			  substr( $completeHash->{"SEQUENCE"}, $primerStart, $counter );
		}
		else {
			$primerStart      = $regionStart - $counter + 1;
			$complementPrimer =
			  substr( $completeHash->{"SEQUENCE"}, $primerStart, $counter );
		}
		$p3cInput{PRIMER_LEFT_INPUT} = reverseSequence($complementPrimer);

		checkPrimer( \%p3cInput, \%p3cOutput );
		
		$primerStart =
		  $primerStart + $counter + $completeHash->{"PRIMER_FIRST_BASE_INDEX"} -
		  1;
		$p3cOutput{"PRIMER_LEFT_0"} = "$primerStart,$counter";

		if (   $p3cOutput{PRIMER_LEFT_0_TM} >= $p3cOutput{PRIMER_MIN_TM}
			&& $p3cOutput{PRIMER_LEFT_0_TM} <= $p3cOutput{PRIMER_MAX_TM} ) {
			push @goodResultsReverse, \%p3cOutput;
		}
		else {
			push @badResultsReverse, \%p3cOutput;
		}
	}

	$primerCounter = 0;

	extractPrimerParameters( $completeHash, \@goodResultsReverse, $resultsHash,
							"RIGHT", \$primerCounter );

	extractPrimerParameters( $completeHash, \@badResultsReverse, $resultsHash,
							"RIGHT", \$primerCounter );

	makeProductSize($resultsHash);

	return;
}

sub extractPrimerParameters ($$$$) {
	my ( $completeHash, $resultArray, $resultsHash, $primerType, $primerCounter );
	$completeHash   = shift;
	$resultArray    = shift;
	$resultsHash    = shift;
	$primerType     = shift;
	$primerCounter  = shift;
	
	# Get the names and rules for names
	my ( $counter, $resultArrayLine, $primerAcro, $spacer );
	my $seqID = $resultsHash->{"PRIMER_SEQUENCE_ID"};
	if ( ( length $seqID ) < 3 ) {
		$seqID = "Primer";
	}
	$spacer = $completeHash->{"PRIMER_NAME_ACRONYM_SPACER"};
	if ( $primerType eq "LEFT" ) {
		$primerAcro = $completeHash->{"PRIMER_NAME_ACRONYM_LEFT"};
	}
	if ( $primerType eq "RIGHT" ) {
		$primerAcro = $completeHash->{"PRIMER_NAME_ACRONYM_RIGHT"};
	}

	foreach $resultArrayLine ( sort sortByPenalty @$resultArray ) {
		$counter = ${$primerCounter};
		$resultsHash->{"PRIMER_$primerType\_$counter"} =
		  $resultArrayLine->{"PRIMER_LEFT_0"};
		$resultsHash->{"PRIMER_$primerType\_$counter\_SEQUENCE"} =
		  $resultArrayLine->{"PRIMER_LEFT_0_SEQUENCE"};
		$resultsHash->{"PRIMER_$primerType\_$counter\_TM"} =
		  $resultArrayLine->{"PRIMER_LEFT_0_TM"};
		$resultsHash->{"PRIMER_$primerType\_$counter\_GC_PERCENT"} =
		  $resultArrayLine->{"PRIMER_LEFT_0_GC_PERCENT"};
		$resultsHash->{"PRIMER_$primerType\_$counter\_SELF_ANY"} =
		  $resultArrayLine->{"PRIMER_LEFT_0_SELF_ANY"};
		$resultsHash->{"PRIMER_$primerType\_$counter\_SELF_END"} =
		  $resultArrayLine->{"PRIMER_LEFT_0_SELF_END"};
		$resultsHash->{"PRIMER_$primerType\_$counter\_END_STABILITY"} =
		  $resultArrayLine->{"PRIMER_LEFT_0_END_STABILITY"};
		$resultsHash->{"PRIMER_$primerType\_$counter\_PENALTY"} =
		  $resultArrayLine->{"PRIMER_LEFT_0_PENALTY"};
		if ( $counter == 0 ) {  
			$resultsHash->{"PRIMER_$primerType\_$counter\_NAME"} =
		  		$seqID . $spacer . $primerAcro;
		} else {  
			$resultsHash->{"PRIMER_$primerType\_$counter\_NAME"} =
		  		$seqID . $spacer . $counter . $spacer . $primerAcro;
		}
		
		if ( defined( $resultArrayLine->{"PRIMER_ERROR"} ) ) {
			$resultsHash->{"PRIMER_$primerType\_$counter\_ERROR"} =
			  $resultArrayLine->{"PRIMER_ERROR"};
		}
		if ( defined( $resultArrayLine->{"PRIMER_WARNING"} ) ) {
			$resultsHash->{"PRIMER_$primerType\_$counter\_WARNING"} =
			  $resultArrayLine->{"PRIMER_WARNING"};
		}
		if ( defined( $resultArrayLine->{"PRIMER_LEFT_0_MESSAGE"} ) ) {
			$resultsHash->{"PRIMER_$primerType\_$counter\_MESSAGE"} =
			  $resultArrayLine->{"PRIMER_LEFT_0_MESSAGE"};
		}
		if ( defined( $resultArrayLine->{"PRIMER_LEFT_MISPRIMING_SCORE"} ) ) {
			$resultsHash->{"PRIMER_$primerType\_$counter\_MISPRIMING_SCORE"} =
			  $resultArrayLine->{"PRIMER_LEFT_0_MISPRIMING_SCORE"};
		}
		${$primerCounter}++;
	}

	return;
}


sub sortByPenalty() {
	$$a{"PRIMER_LEFT_0_PENALTY"} <=> $$b{"PRIMER_LEFT_0_PENALTY"};
}

sub makeProductSize ($) {
	my $resultsHash;
	$resultsHash = shift;

	my $counter = 0;
	my ( $leftPosition, $rightPosition, $temp );
	for ( my $run = 1 ; $run eq 1 ; $counter++ ) {
		if (   ( !( defined $resultsHash->{"PRIMER_LEFT\_$counter\_SEQUENCE"} ) )
			or ( $resultsHash->{"PRIMER_LEFT\_$counter\_SEQUENCE"} eq "" ) )
		{
			$run = 0;
		}
		if (   ( !( defined $resultsHash->{"PRIMER_RIGHT\_$counter\_SEQUENCE"} ) )
			or ( $resultsHash->{"PRIMER_RIGHT\_$counter\_SEQUENCE"} eq "" ) )
		{
			$run = 0;
		}
		if ( $run ne 0 ) {
			( $leftPosition, $temp ) = split ",",
			  $resultsHash->{"PRIMER_LEFT\_$counter"};
			( $rightPosition, $temp ) = split ",",
			  $resultsHash->{"PRIMER_RIGHT\_$counter"};
			$temp = $rightPosition - $leftPosition + 1;
			$resultsHash->{"PRIMER_PRODUCT_SIZE\_$counter"} = $temp;
		}
	}
}

####################################################################
# sortSequencing: picks Sequencing primers from the right position #
####################################################################
sub sortSequencing ($$$) {
	my ( $completeHash, $tempHash, $resultsHash );
	$completeHash = shift;
	$tempHash     = shift;
	$resultsHash  = shift;
	
	my ( @targets, @forwardPositions, @reversePositions );
	my ( $target, $targetStart, $targetLength, $primerNumber,
		 $temp, $extraSequence, $primerPosition, $primerCounter );
		 
	# Get some parameters for calculations
	my $lead           = $completeHash->{"SCRIPT_SEQUENCING_LEAD"};
	my $spacing        = $completeHash->{"SCRIPT_SEQUENCING_SPACING"};
	my $reverse        = $completeHash->{"SCRIPT_SEQUENCING_REVERSE"};
	my $interval       = $completeHash->{"SCRIPT_SEQUENCING_INTERVAL"};
	my $accuracy       = $completeHash->{"SCRIPT_SEQUENCING_ACCURACY"};
	my $sequenceLength = length( $completeHash->{"SEQUENCE"} );
	my $firstBase 	   = $completeHash->{"PRIMER_FIRST_BASE_INDEX"};

	# Copy some elementary parameters to the results
	$resultsHash->{"SEQUENCE"} = $completeHash->{"SEQUENCE"};
	$resultsHash->{"TARGET"}   = $completeHash->{"TARGET"};
	$resultsHash->{"PRIMER_FIRST_BASE_INDEX"} 
	                           = $completeHash->{"PRIMER_FIRST_BASE_INDEX"};

	# Read the Targets into a array or select the whole sequence
	if ( $completeHash->{"TARGET"} eq "" ) {
		$targetStart  = $firstBase;
		$targetLength = $sequenceLength + $firstBase;
		push @targets, "$targetStart,$targetLength";
	}
	else {
		@targets = split ' ', $completeHash->{"TARGET"};
	}

	# Calculate the primer positions for each target
	foreach $target (@targets) {
		( $targetStart, $targetLength ) = split ",", $target;
		
		# Match the bigger sequenced area to the smaller target
		$primerNumber = 0;
		$temp         = 0;
		# Find out how many Primers are needed for the target
		while ( $targetLength > $temp ) {
			$primerNumber++;
			$temp = $spacing * $primerNumber;
		}
		# Interval should be smaller then spacing
		while ( $interval > $spacing ) {
			$interval = $interval - $spacing;
		}
		# extra Sequence is the too much sequenced part
		if ( $targetLength < $interval) {
			$extraSequence = ( $interval - $targetLength ) / 2;
		} else {
			$extraSequence = ( ($spacing * $primerNumber) - $targetLength ) / 2;	
		}
		
		$extraSequence = int($extraSequence);

		# Calculate the primer positions
		for ( my $step = 0 ; $step < $primerNumber ; $step++ ) {
			$primerPosition =
			  $targetStart - $extraSequence + ( $spacing * $step ) - $lead;
			  
			# Set the position to the start or the end
			# if the position is outside the sequence
			if ( $primerPosition < 0 ) {
				$primerPosition = $accuracy + 2;
			}
			if ( $primerPosition > $sequenceLength ) {
				$primerPosition = $sequenceLength - $accuracy - 2;
				$step++; # to end the loop
			}
			push @forwardPositions, $primerPosition;
		}
		for ( my $step = 0 ; $step <= $primerNumber ; $step++ ) {
			$primerPosition =
			  $targetStart - $extraSequence + $interval + ( $spacing * $step ) +
			  $lead;
			  
			# Set the position to the start or the end
			# if the position is outside the sequence
			if ( $primerPosition < 0 ) {
				$primerPosition = $accuracy + 2;
			}
			if ( $primerPosition > $sequenceLength ) {
				$primerPosition = $sequenceLength - $accuracy - 2;
				$step++; # to end the loop
			}
			
			# Check if the first and the last primer would be able 
			# to sequence something and copy it only then
			if ( $step eq 0 ) {
				if ( $targetStart < ( $primerPosition - $lead ) ) {
					push @reversePositions, $primerPosition;
				}
			}
			else {
				if ( ( $targetStart + $targetLength ) >
					( $primerPosition - $spacing - $lead ) ) {
					push @reversePositions, $primerPosition;
				}
			}
		}

		# Pick the primers at the calculated positions
		$primerCounter = 0;
		foreach $primerPosition (@forwardPositions) {
			copyPrimerArray( $tempHash, $resultsHash, $accuracy,
							 $primerPosition, "LEFT", \$primerCounter );
			$primerCounter++;
		}

		# Pick primers for the reverse positions if asked for
		if ( $reverse ne 0 ) {
			$primerCounter = 0;
			foreach $primerPosition (@reversePositions) {
				copyPrimerArray( $tempHash, $resultsHash, $accuracy, $primerPosition,
								 "RIGHT", \$primerCounter );
				$primerCounter++;
				if ( $targetLength < $interval) {
					last;
				}
			}
		}
	}

	return;
}

########################################################################
# copyPrimerArray: finds the best primer in a region of primerPosition #
#                  +/- accuracy and copies it with number primerConter #
#                  and type from the tempHash in the result hash       #
########################################################################
sub copyPrimerArray ($$$$$) {
	my ( $tempHash, $resultsHash, $accuracy, $primerPosition, $type,
		 $primerCounterPointer, $primerCounter );
	$tempHash             = shift;
	$resultsHash          = shift;
	$accuracy             = shift;
	$primerPosition       = shift;
	$type                 = shift;
	$primerCounterPointer = shift;
	$primerCounter        = ${$primerCounterPointer};

	my ( $run, $counter, $preCount, $primerStart, $primerLength, $primerEnd,
		$resultArrayLine );
	$run     = 1;
	$counter = 0;

	my ( @good, @bad, @sortedGood, @sortedBad );
	for ( my $listCounter = 0 ; $run eq 1 ; $listCounter++ ) {
		my %loopHash;

		# Stop the loop if there are no more Primers
		if ( !( defined( $tempHash->{"PRIMER_$type\_$listCounter"} ) )
			or ( $tempHash->{"PRIMER_$type\_$listCounter"} eq "" ) )
		{
			$run = 0;
		}
		
		# Check the primer if its in the range
		else {
			( $primerStart, $primerLength ) = split ",",
			  $tempHash->{"PRIMER_$type\_$listCounter"};
			$primerEnd = $primerStart + $primerLength;
			
			# If the primer is in the good area copy it to the loop Hash
			if (    ( $primerEnd > ( $primerPosition - $accuracy ) )
				and ( $primerEnd < ( $primerPosition + $accuracy ) ) )
			{
				copyPrimer( $tempHash, $listCounter, $type, \%loopHash, "0", "LEFT" );
				push @good, \%loopHash;
			}
			
			# Select primers from bigger area to have alternatives
			elsif ( ( $primerEnd > ( $primerPosition - ( 3 * $accuracy ) ) )
				and ( $primerEnd < ( $primerPosition + ( 3 * $accuracy ) ) ) )
			{
				copyPrimer( $tempHash, $listCounter, $type, \%loopHash, "0", "LEFT" );
				push @bad, \%loopHash;
			}

		}
	}

	@sortedGood = ( sort sortByPenalty @good );
	@sortedBad  = ( sort sortByPenalty @bad );

	my $selectedHash;
	if ( $#sortedGood > -1 ) {
		$selectedHash = $sortedGood[0];
		copyPrimer( $selectedHash, "0", "LEFT", $resultsHash, $primerCounter,
			$type );
	}
	elsif ( $#sortedBad > -1 ) {
		$selectedHash = $sortedBad[0];
		copyPrimer( $selectedHash, "0", "LEFT", $resultsHash, $primerCounter,
			$type );
		setMessage("Did not find Sequencing primer at $type ".
		           "position $primerPosition within $accuracy bp!");
	}
	else {
		setMessage("Did not find Sequencing primer at $type ".
				   "position $primerPosition!");
		$primerCounter--;
		${$primerCounterPointer} = $primerCounter;
	}

	return;
}

###############################################################
# copyPrimer: copies one primer out of a hash into other hash #
###############################################################
sub copyPrimer ($$$$$$) {
	my ( $fromHash, $fromCounter, $fromType, $toHash, $toCounter, $toType );
	$fromHash    = shift;
	$fromCounter = shift;
	$fromType    = shift;
	$toHash      = shift;
	$toCounter   = shift;
	$toType      = shift;

	$toHash->{"PRIMER_$toType\_$toCounter"} =
	  $fromHash->{"PRIMER_$fromType\_$fromCounter"};
	$toHash->{"PRIMER_$toType\_$toCounter\_SEQUENCE"} =
	  $fromHash->{"PRIMER_$fromType\_$fromCounter\_SEQUENCE"};
	$toHash->{"PRIMER_$toType\_$toCounter\_NAME"} =
	  $fromHash->{"PRIMER_$fromType\_$fromCounter\_NAME"};
	$toHash->{"PRIMER_$toType\_$toCounter\_TM"} =
	  $fromHash->{"PRIMER_$fromType\_$fromCounter\_TM"};
	$toHash->{"PRIMER_$toType\_$toCounter\_GC_PERCENT"} =
	  $fromHash->{"PRIMER_$fromType\_$fromCounter\_GC_PERCENT"};
	$toHash->{"PRIMER_$toType\_$toCounter\_SELF_ANY"} =
	  $fromHash->{"PRIMER_$fromType\_$fromCounter\_SELF_ANY"};
	$toHash->{"PRIMER_$toType\_$toCounter\_SELF_END"} =
	  $fromHash->{"PRIMER_$fromType\_$fromCounter\_SELF_END"};
	$toHash->{"PRIMER_$toType\_$toCounter\_PENALTY"} =
	  $fromHash->{"PRIMER_$fromType\_$fromCounter\_PENALTY"};

	return;
}


###############################################################
# runPrimer3: Executes primer3 and puts the results in a Hash #
###############################################################
sub runPrimer3 ($$$) {
	my $p3cInput;
	my $p3cOutput;
	my $completeHash;
	$p3cInput  = shift;
	$p3cOutput = shift;
	$completeHash = shift;
	
	my $outputLine;
	my $primer3BIN = getMachineSetting("PRIMER_BIN");
	my %zeroReplacements = getZeroReplacements();
	my $p3cInputKeys;
	my $callPrimer3 = $primer3BIN . getMachineSetting("PRIMER_RUNTIME");

	## Check if Primer3 can be run
	if ( !( -e $primer3BIN ) ) {
		setMessage("Configuration Error: $primer3BIN ".
		           "can not be found!");
		setDoNotPick("1");
	}
	if ( !( -x $primer3BIN ) ) {
		setMessage("Configuration Error: $primer3BIN ".
		           "is not executable!");
		setDoNotPick("1");
	}

	if ( getDoNotPick() == 0 ) {
		my $value;
		
		my $inputFile = getMachineSetting("USER_CACHE_FILES_PATH")."Input_$$.txt";
		open( FILE, ">$inputFile" ) or 
			setMessage("cannot write $inputFile");
		foreach $p3cInputKeys ( keys( %{$p3cInput} ) ) {
			$value = $p3cInput->{"$p3cInputKeys"};
			if ( $value ne "" ) {
				print FILE qq{$p3cInputKeys=$p3cInput->{"$p3cInputKeys"}\n};
			}
		}
		print FILE qq{=\n};
		close(FILE);

		my @readTheLine;
		open PRIMER3OUTPUT, "$callPrimer3 < $inputFile 2>&1 |"
		  or setMessage("could not start primer3");
		while (<PRIMER3OUTPUT>) {
			push @readTheLine, $_;
		}
		close PRIMER3OUTPUT;
		unlink $inputFile;
		
		my ( $readLine, $lineKey, $lineValue );
		my @nameKeyComplete = "";
		my ( $namePrimerType, $nameNumber, $nameKeyName, $nameKeyValue );
		
		my $acronymLeft  = $completeHash->{"PRIMER_NAME_ACRONYM_LEFT"};
		my $acronymRight = $completeHash->{"PRIMER_NAME_ACRONYM_RIGHT"};
		my $acronymOligo = $completeHash->{"PRIMER_NAME_ACRONYM_INTERNAL_OLIGO"};
		my $acronymSpace = $completeHash->{"PRIMER_NAME_ACRONYM_SPACER"};
		my $sequenceName = $completeHash->{"PRIMER_SEQUENCE_ID"};

		foreach $readLine (@readTheLine) {
			( $lineKey, $lineValue ) = split "=", $readLine;
			$lineKey   =~ s/\s//g;
			$lineValue =~ s/\n//g;

            # Make the name replacement for the primer_0 parameters:
            if (defined $zeroReplacements{$lineKey}) {
            	$lineKey = $zeroReplacements{$lineKey};            
            }
            #Write everything in the Output Hash
			$p3cOutput->{"$lineKey"} = $lineValue;

			# Make a Name for each primer
			if ( $lineKey =~ /_SEQUENCE$/ ) {
				@nameKeyComplete = split "_", $lineKey;
				$namePrimerType = $nameKeyComplete[1];
				
				# INTERNAL_OLIGO has one "_" more thats why:
				if ( $namePrimerType eq "INTERNAL" ) {
					$nameNumber = $nameKeyComplete[3];
				}
				else {
					$nameNumber = $nameKeyComplete[2];
				}
				
				$nameKeyName = $lineKey;
				$nameKeyName =~ s/SEQUENCE/NAME/;
				$nameKeyValue = "";

				# Use the Name or Primer for the ID
				if ( ( length $sequenceName ) > 2 )
				{
					$nameKeyValue .= $sequenceName;
				}
				else {
					$nameKeyValue .= "Primer";
				}
				# Add a Number
				if ( $nameNumber eq "0" ) {
					$nameKeyValue .= $acronymSpace;
				}
				else {
					$nameKeyValue .= $acronymSpace.$nameNumber.$acronymSpace;
				}
				
				# Add a Type
				if ( $namePrimerType eq "RIGHT" ) {
					$nameKeyValue .= $acronymRight;
				}
				elsif ( $namePrimerType eq "INTERNAL" ) {
					$nameKeyValue .= $acronymOligo;
				}
				elsif ( $namePrimerType eq "LEFT" ) {
					$nameKeyValue .= $acronymLeft;
				}
				else {
					$nameKeyValue .= "??";
				}
				$p3cOutput->{"$nameKeyName"} = $nameKeyValue;
				@nameKeyComplete = "";
			}
		}
	}
	return;
}

###################################################
# reverseSequence: Reverse-complements a Sequence #
###################################################
sub reverseSequence ($) {
	my ( $Sequence, $reverseSequence );
	$Sequence = shift;

	$reverseSequence = reverse($Sequence);
	$reverseSequence =~ tr/acgtACGT/tgcaTGCA/;

	return $reverseSequence;
}

#####################################
# makeUniqueID: Returns a unique ID #
#####################################
sub makeUniqueID {
	my ( $UID, $randomNumber, $time );
	my ($second,     $minute,    $hour,
		$dayOfMonth, $month,     $yearOffset,
		$dayOfWeek,  $dayOfYear, $daylightSavings);
	(	$second,     $minute,    $hour,
		$dayOfMonth, $month,     $yearOffset,
		$dayOfWeek,  $dayOfYear, $daylightSavings ) = localtime();
	my $year = 1900 + $yearOffset;
	$month++;
	my $length = 7;
	for ( my $i = 0 ; $i < $length ; ) {
		my $j = chr( int( rand(127) ) );
		if ( $j =~ /[a-zA-Z0-9]/ ) {
			$randomNumber .= $j;
			$i++;
		}
	}
	$time = sprintf "%4d%02d%02d%02d%02d%02d", 
	        $year, $month, $dayOfMonth, $hour, $minute, $second;
	$UID = $time . $randomNumber;

	return $UID;
}

####################################################################################
# getDate: Returns the Date as a string: D is format DD_MM_YY, Y is format YY_MM_DD#
####################################################################################
sub getDate {
	my $style     = shift;
	my $separator = shift;
	my $date;
	my ($second,     $minute,    $hour,
		$dayOfMonth, $month,     $yearOffset,
		$dayOfWeek,  $dayOfYear, $daylightSavings );
	(	$second,     $minute,    $hour,
		$dayOfMonth, $month,     $yearOffset,
		$dayOfWeek,  $dayOfYear, $daylightSavings ) = localtime();
	my $year = 1900 + $yearOffset;
	$month++;
	if ( $style eq "Y" ) {
		$date = sprintf "%04d$separator%02d$separator%02d", $year, $month, $dayOfMonth;
	}
	else {
		$date = sprintf "%02d$separator%02d$separator%04d", $dayOfMonth, $month, $year;
	}

	return $date;
}

############################################################################
# getLyk3Sequence: Returns an example sequence for demonstration purpurses #
############################################################################
sub getLyk3Sequence {
    my $sequence = qq {acaatattgtattggtgagatcatataagatttgatgtcaacatcttcgtaaaggtctcagatt
        cgattctccccggtatcaatttaagtgagctaatttagcttcttaaaaaataaaatcaaacaacttttacataaactca
        gtgaaaacttggatataaagtatccttatactactctttagtcttgattagtctctgcaaagatatttatatgtacttt
        gtattatcataagaacattcattgacattttaagttaatgaattactaacatgtcaactcttattctagccaacagtta
        ctttgttccctccacattctctttgaaatagtcaaacgtatccaatcatgcatgtctgttctgatcataacagcaaaag
        catgtgtatagaaaattgatagttgaattagagtcattttccataaaaaaatattcaataagtgtgacattatttttcg
        tatgaattaatccattttttgctgatttgagattctttctttctttgcttcttgctttccttcatcagccatttttttt
        gttttctctttctctctctcttcttgattcaatgaatctcaaaaatggattactattgttcattctgtttctggattgt
        gtttttttcaaagttgaatccaaatgtgtaaaagggtgtgatgtagctttagcttcctactatattataccatcaattc
        aactcagaaatatatcaaactttatgcaatcaaagattgttcttaccaattcctttgatgttataatgagctacaatag
        agacgtagtattcgataaatctggtcttatttcctatactagaatcaacgttccgttcccatgtgaatgtattggaggt
        gaatttctaggacatgtgtttgaatatacaacaaaagaaggagacgattatgatttaattgcaaatacttattacgcaa
        gtttgacaactgttgagttattgaaaaagttcaacagctatgatccaaatcatatacctgttaaggctaagattaatgt
        cactgtaatttgttcatgtgggaatagccagatttcaaaagattatggcttgtttgttacctatccactcaggtctgat
        gatactcttgcgaaaattgcgaccaaagctggtcttgatgaagggttgatacaaaatttcaatcaagatgccaatttca
        gcataggaagtgggatagtgttcattccaggaagaggtatgtattttctcattttctgccaactgtggttggcacagat
        ggtttgaacttctgtcacatccgttgtaactttgataagtctgaaattccgcagtttgtagattactggtaaattccat
        tataaatgtttaatgtgatttggtgattcttatcaaaagtacttgtataagtatgcgagttagataaaaaaaattatga
        ccatcttgttctcgtggaaatggactctgataattcataaagtctagccagtgattgtaacaaccaggctttgaacttg
        gtacttccaatcaacttgaccttcaccagacctcattgaccacttgagtcgaaccctttaatttcagttagagtatatt
        taaatgctaagttactctattatttttcaaagtatatacatggtataaattttgaagttttatgtagttattgtttact
        ttgcagatcaaaatggacatttttttcctttgtattctaggtaagtaacattgattatctcaattttcatttttgaatg
        atttatagaagaagtaaatattgcttcatataatttggttatatttttctaactttcattttctttttatttttccatt
        cttgcagaacaggtttgtcttttgctattaagatgattatttgttagcttgttcacaaaaatatgagaatggacaaaag
        gtcaatgcttcctgtgagcttaaatttggttcaatataagcaggtattgctaagggttcagctgttggtatagctatgg
        caggaatatttggacttctattatttgttatctatatatatgccaaatacttccaaaagaaggaagaagagaaaactaa
        acttccacaaacttctagggcattttcaactcaagatggtaatatttttaaacattcatattctaagttcttattaaaa
        atatttcttttaacctatcttatgatataagtatttatttcagtatttgagagagcttgcgaaaatagcttataacatg
        tttgtttcattaaactgtatttatttcattaaatagtttatacttgctgatttttgtttatgttattggtgaagcctca
        ggtagtgcagaatatgaaacttcaggatccagtgggcatgctactggtagtgctgccggccttacaggcattatggtgg
        caaagtcgacagagtttacgtatcaagaattagccaaggcgacaaataatttcagcttggataataaaattggtcaagg
        tggatttggagctgtctattatgcagaacttagaggcgaggtacgaaactacatgaatttgtttaatagagtgtacttt
        gattttagttttgaacaagttctataaaatattttcaaaaaacttttattttttgtcataacttggaaagaaagtaaag
        ccatttttttttccttcacgttttcattgatttcctctcatgcaacttattgtatgcagaaaacagcaattaagaagat
        ggatgtacaagcatcgtccgaatttctctgtgagttgaaggtcttaacacatgttcatcacttgaatctggtataccat
        ccttttaaaaatcttaagccatatataatatatttaggagatataatcatttatttttatatatggtttgaagaatcat
        cgtttaactacaaagcaaataaccagtgttagttttgagaacataagaactctataactatcaagcaaaacataatctg
        tagtagctgtttacaattatctgtcctacacagttagcgaataatttgaaacacactgcagaacattatttgtatgtac
        ttcttgattttgtacatgtttgtatactttttgtataatcagttttgtatttgttctagatattactctgaatttgcct
        aaattttatgaacaatgtaggtgcggttgattggatattgcgttgaagggtcacttttcctcgtatatgaacatattga
        caatggaaacttgggtcaatatttacatggtataggtaagattaacaaaaatgtgctaatatttttatgtgattttaca
        atattgtcaaacagtcattaatgatggttagatgatttcaggtacagaaccattaccatggtctagtagagtgcagatt
        gctctagattcagccagaggcctagaatacattcatgaacacactgtgcctgtttatatccatcgcgacgtaaaatcag
        caaatatattgatagacaaaaatttgcgtggaaaggttgcaatttgaccaatcttaatgatctatattataaattttaa
        tttatcacttcttcttttacattaattaactctatgaatggttttgaattcaggttgctgattttggcttgaccaaact
        tattgaagttggaaactcgacacttcacactcgtcttgtgggaacatttggatacatgccaccagagtatgattcgttt
        gtattaaattttgagtttaatattagtacaaaaagtacaacaaaaattcagtgattcattcacatttcacaatacatat
        gtcactttgttatattataaaatgggatatgaccagatgattgtacaattttttttataacaaatgatatttgtataac
        ccttttagtatgtccatggattataaactatcttcaactttcttaattgtagaaaacatgtttgtttattagctgtttt
        ttttctctgttgcagatatgctcaatatggcgatgtttctccaaaaatagatgtatatgcttttggcgttgttctttat
        gaacttattactgcaaagaatgctgtcctgaagacaggtgaatctgttgcagaatcaaagggtcttgtacaattggtag
        gtctagataccatatttattaagaaaacactcatttcatgtatatttttagtaaaatatttttaagttagtaattatgt
        acattttaaattcagtaaactgaatgcattcacttaaaccagaacaaaagttatccttgattattttgtattgcagttt
        gaagaagcacttcatcgaatggatcctttagaaggtcttcgaaaattggtggatcctaggcttaaagaaaactatccca
        ttgattctgttctcaaggtgggaagcattttttcttagcaaaaaattgaatgttatttctttttcttctcaatttgcat
        tatataccaacaaaaaaaaaatgcatatttatgtggtatagcctttcaaatcattgtagtacataagcaaagttcatgt
        tattaaaatataattaaatgtatgcaaaagtgtatagtttgtaaagttactaaactcatttgttttagcactagatttt
        gtcattgaacataacttaagatatgtgaatatttgaattgcagatggctcaacttgggagagcatgtacgagagacaat
        ccgctactacgcccaagcatgagatctatagttgttgctcttatgacactttcatcaccaactgaagattgtgatgatg
        actcttcatatgaaaatcaatctctcataaatctgttgtcaactagatgaagattttgtgtgacaaattgaattgtgtt
        tgttaaaacatgtagaaagcatacaacaaatggtttgtactttacttgtatatgaaatattgcagttggagagttttta
        cttttcttacctcaattatccatcttgaacattgttttgtatgtggcaagagttcaaacactggtgtactcattgaaaa
        gttatggtgagaaaatcactgatcagatgattcttgagaaagataatgagaactctgtcacc};
        
    $sequence =~ s/\W//g;

    return $sequence;
}

1;
