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
use File::Copy;

use settings;

our ( @ISA, @EXPORT, @EXPORT_OK, $VERSION );
@ISA    = qw(Exporter);
@EXPORT = qw(&getParametersHTML &constructCombinedHash &createFile
     &createManagerFile &getSetCookie &getCookie &setCookie &getCacheFile &setCacheFile
     &loadManagerFile &loadFile &checkParameters &runPrimer3 &reverseSequence
     &getParametersForManager &loadServerSettFile &extractSelectedPrimers &addToArray
     &getDate &makeUniqueID &writeStatistics &readStatistics);

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
	$radioButtons = $cgi->param("SCRIPT_RADIO_BUTTONS_FIX");

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

##########################################################################
# createFile: Write all Information associated with Settings in a string #
# Type: S - Settings, Q - Sequence, A - All                              #
##########################################################################
sub createFile {
	my ($settings, $type, $saveKey, $returnString);
	$settings = shift;
	$type = shift;
	my (@saveSettingsKeys) = keys %$settings;
	my @sortkeys = sort @saveSettingsKeys;

	$returnString  = "Primer3 File - http://primer3.sourceforge.net\r\n";

    if ($type eq "S") {
        $returnString .= "P3_FILE_TYPE=settings\r\n";
    } elsif ($type eq "Q") {
        $returnString .= "P3_FILE_TYPE=sequence\r\n";
    } else {
        $returnString .= "P3_FILE_TYPE=all\r\n";
    }
    $returnString .= "\r\n";
    if ($type eq "S") {
        $returnString .= "P3_FILE_ID=User settings\r\n";
    }

	foreach $saveKey (@sortkeys) {
	    if ( ($type eq "A") or 
	         ($type eq "Q" and $saveKey =~ /^SEQUENCE_/) or
	         ($type eq "S" and (($saveKey =~ /^PRIMER_/)
	                       or ($saveKey =~ /^P3P_/)))) {
	        $returnString .= $saveKey . "=" . $settings->{$saveKey} . "\r\n";
	    }		
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
	my %translator;

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
	if ( $fileString =~ /Primer3 File -/ ) {
		@fileContent = split '\n', $fileString;
		$readable = 0;
		# Figure out the type of File
		if ( $fileContent[1] =~ /P3_FILE_TYPE=sequence/ ) {
			$fileType = "Sequence";
			$readable = 1;
		}
        if ( $fileContent[1] =~ /P3_FILE_TYPE=settings/ ) {
            $fileType = "Settings";
            $readable = 1;
        }
        if ( $fileContent[1] =~ /P3_FILE_TYPE=all/ ) {
            $fileType = "All";
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

    # Read Primer3Plus file
	elsif ( $fileString =~ /Primer3Plus File/ ) {
		@fileContent = split '\n', $fileString;
		%translator = getTranslateOldVersion();
		# Read it directly to the Hash provided
        setMessage("Old Primer3Plus File loaded. Check if all values are correct.");
        setMessage("Save new Settings File to use latest version.");
		for ( my $i = 3 ; $i <= $#fileContent ; $i++ ) {
			$line = $fileContent[$i];
			if ( ( index( $line, "=" ) ) > 2 ) {
                ( $lineKey, $lineValue ) = split "=", $line;
                if (($lineKey eq "SCRIPT_CONTAINS_JAVA_SCRIPT") ||
                    ($lineKey eq "SCRIPT_PRINT_INPUT")) {
			    } elsif (defined $translator{$lineKey}) {
                    $dataTarget->{$translator{$lineKey}} = $lineValue;
                } else {
                    setMessage("Unprocessed Tag: $lineKey = $lineValue");
                }
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
			    $dataTarget->{"SEQUENCE_ID"} = $name;
			    $dataTarget->{"SEQUENCE_TEMPLATE"} = $sequence;
			}
			else {
		        $dataTarget->{"SEQUENCE_ID_$sequenceCounter"} = $name;
		        $dataTarget->{"SEQUENCE_TEMPLATE_$sequenceCounter"} = $sequence;
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
        $dataTarget->{"SEQUENCE_TEMPLATE"} = $1; 
	    setMessage("Primer3Plus loaded SeqEdit-File");
    }

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
				    $dataTarget->{"SEQUENCE_ID"} = $name;
				    $dataTarget->{"SEQUENCE_TEMPLATE"}           = $sequence;
				}
				else {
			        $dataTarget->{"SEQUENCE_ID_$sequenceCounter"} = $name;
			        $dataTarget->{"SEQUENCE_TEMPLATE_$sequenceCounter"} = $sequence;
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
				    $dataTarget->{"SEQUENCE_ID"} = $name;
				    $dataTarget->{"SEQUENCE_TEMPLATE"}           = $sequence;
				}
				else {
			        $dataTarget->{"SEQUENCE_ID_$sequenceCounter"} = $name;
			        $dataTarget->{"SEQUENCE_TEMPLATE_$sequenceCounter"} = $sequence;
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
		
		$dataTarget->{"SEQUENCE_TEMPLATE"} = $sequence;
		setMessage("Error: Primer3Plus could not identify File Format");
	}

	return;
}


####################################################################
# checkParameters: Checks the Parameter in Hash for wrong settings #
####################################################################
sub checkParameters (\%) {
	my ($dataStorage);
	$dataStorage = shift;
	my %misLibrary      = getMisLibrary();
	my $libary;
	
    ## A hidden way to obtain a example sequence for demonstration
    if ( defined( $dataStorage->{"Default_Settings"} ) ) {
        my $choosenSequence = $dataStorage->{"SEQUENCE_TEMPLATE"};
        if ( $choosenSequence eq "example" ) {
            $dataStorage->{"SEQUENCE_TEMPLATE"} = getLyk3Sequence();
            $dataStorage->{"SEQUENCE_ID"} = "Medicago Lyk3";
        } else {
            $dataStorage->{"SEQUENCE_TEMPLATE"} = "";
            $dataStorage->{"SEQUENCE_ID"} = "";
        }
    }

    ## Copy the selected sequence of a multiSequence file to the input
    if ( defined( $dataStorage->{"SelectOneSequence"} ) ) {
        my $choosenSequence = $dataStorage->{"SCRIPT_SELECTED_SEQUENCE"};
        if ( $choosenSequence != 0 ) {
            $dataStorage->{"SEQUENCE_TEMPLATE"} = $dataStorage->{"SEQUENCE_TEMPLATE_$choosenSequence"};
            $dataStorage->{"SEQUENCE_ID"} = $dataStorage->{"SEQUENCE_ID_$choosenSequence"};
        }
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
	
	$libary = $dataStorage->{"PRIMER_INTERNAL_MISHYB_LIBRARY"};
	if ( !defined( $misLibrary{$libary} ) ) {
		setMessage("Error: Oligo Mispriming Library $libary does not exist on this server!");
		setMessage("Oligo Mispriming Library was changed to: NONE");
		$libary = "NONE";
		$dataStorage->{"PRIMER_INTERNAL_MISHYB_LIBRARY"} = $libary;
	}
	if ( ( $libary ne "NONE" ) and !( -r $misLibrary{$libary} ) ) {
		setMessage("Error: Oligo Mispriming Library $libary can not be read!");
		setMessage("Oligo Mispriming Library was changed to: NONE");
		$libary = "NONE";
		$dataStorage->{"PRIMER_INTERNAL_MISHYB_LIBRARY"} = $libary;
	}

	## Check first base index
	if ( ( $dataStorage->{"PRIMER_FIRST_BASE_INDEX"} ) ne "1" ) {
		$dataStorage->{"PRIMER_FIRST_BASE_INDEX"} = "0";
	}

	## Read fasta-sequence and the regions
	my $firstBaseIndex   = $dataStorage->{"PRIMER_FIRST_BASE_INDEX"};
	my $sequenceID       = $dataStorage->{"SEQUENCE_ID"};
	my $realSequence     = $dataStorage->{"SEQUENCE_TEMPLATE"};
	my $excludedRegion   = $dataStorage->{"SEQUENCE_EXCLUDED_REGION"};
	my $target           = $dataStorage->{"SEQUENCE_TARGET"};
    my $includedRegion   = $dataStorage->{"SEQUENCE_INCLUDED_REGION"};
    my $overlapPos       = $dataStorage->{"SEQUENCE_PRIMER_OVERLAP_POS"};

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
    my ($m_target, $m_excluded_region, $m_included_region, $m_overlap_pos)
        = read_sequence_markup($realSequence, (['[', ']'], ['<','>'], ['{','}'], ['-','-']));
	$realSequence =~ s/[\[\]\<\>\{\}]//g;
	$realSequence =~ s/-//g;
	if ($m_target && @$m_target) {
		if ($target) {
			setMessage("WARNING: Targets specified both as sequence".
			           " markups and in Other Per-Sequence Inputs");
		}
		$target = add_start_len_list( $target, $m_target, $firstBaseIndex );
	}
	if ($m_excluded_region && @$m_excluded_region) {
		if ($excludedRegion) {
			setMessage("WARNING: Excluded Regions specified both as sequence".
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
    if ($m_overlap_pos && @$m_overlap_pos) {
        if ($overlapPos) {
            setMessage("WARNING: Primer overlap positions specified both as sequence".
                       " markups and in Other Per-Sequence Inputs");
        }
        $overlapPos = add_start_only_list( $overlapPos, $m_overlap_pos,  $firstBaseIndex );
    }
	$dataStorage->{"SEQUENCE_ID"} = $sequenceID;
	$dataStorage->{"SEQUENCE_TEMPLATE"}           = $realSequence;
	$dataStorage->{"SEQUENCE_EXCLUDED_REGION"}    = $excludedRegion;
	$dataStorage->{"SEQUENCE_TARGET"}             = $target;
	$dataStorage->{"SEQUENCE_INCLUDED_REGION"}    = $includedRegion;
    $dataStorage->{"SEQUENCE_PRIMER_OVERLAP_POS"} = $overlapPos;

	## Remove Commas in Product size ranges
	$dataStorage->{"PRIMER_PRODUCT_SIZE_RANGE"} =~ s/,/ /g;

	## If sequence quality contains newlines (or other non-space whitespace) change them to space.
	$dataStorage->{"SEQUENCE_QUALITY"} =~ s/\s/ /sg;

	## Cut primers and internal oligo to max size primer3 can handle
	my $primerLeft    = $dataStorage->{"SEQUENCE_PRIMER"};
	my $internalOligo = $dataStorage->{"SEQUENCE_INTERNAL_OLIGO"};
	my $primerRight   = $dataStorage->{"SEQUENCE_PRIMER_REVCOMP"};
	my $maxPrimerSize  = getMachineSetting("MAX_PRIMER_SIZE");
	my $cutPosition;
	my $cutLeft  = "";
	my $cutOligo = "";
	my $cutRight = "";

	if ( ( length $primerLeft ) > $maxPrimerSize ) {
		$cutLeft = substr( $primerLeft, 0, $maxPrimerSize );
		setMessage("ERROR: Left Primer longer than $maxPrimerSize ".
			       "bp. Additional bases were removed on the 3' end");
		$dataStorage->{"SEQUENCE_PRIMER"} = $cutLeft;
	}
	if ( ( length $internalOligo ) > $maxPrimerSize ) {
		$cutOligo = substr( $internalOligo, 0, $maxPrimerSize );
		setMessage("ERROR: Internal Oligo longer than $maxPrimerSize ".
			       "bp. Additional bases were removed on the 3' end");
		$dataStorage->{"SEQUENCE_INTERNAL_OLIGO"} = $cutOligo;
	}
	if ( ( length $primerRight ) > $maxPrimerSize ) {
		$cutRight = substr( $primerRight, 0, $maxPrimerSize );
		setMessage("ERROR: Right Primer longer than $maxPrimerSize ".
			       "bp. Additional bases were removed on the 3' end");
		$dataStorage->{"SEQUENCE_PRIMER_REVCOMP"} = $cutRight;
	}

	return;
}

##########################################################
# Functions for the region functionality from primer3web #
##########################################################
sub add_start_len_list($$$) {
    my ($list_string, $list, $plus) = @_;
    my $sp = $list_string ? ' ' : '' ;
    for (@$list) {
    $list_string .= ($sp . ($_->[0] + $plus) . "," . $_->[1]);
    $sp = ' ';
    }
    return $list_string;
}

sub add_start_only_list($$$) {
    my ($list_string, $list, $plus) = @_;
    my $sp = $list_string ? ' ' : '' ;
    for (@$list) {
    $list_string .= ($sp . ($_->[0] + $plus));
    $sp = ' ';
    }
    return $list_string;
}

sub read_sequence_markup($@) {
    my ($s, @delims) = @_;
    # E.g. ['/','/'] would be ok in @delims, but
    # no two pairs in @delims may share a character.
    my @out = (); 
    for (@delims) {
        push @out, read_sequence_markup_1_delim($s, $_, @delims);
    }
    @out;
}

sub read_sequence_markup_1_delim($$@) {
    my ($s,  $d, @delims) = @_;
    my ($d0, $d1) = @$d;
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
    my @s = split(//, $s);
    my ($c, $pos) = (0, 0);
    my @out = ();
    my $len;
    while (@s) {
    $c = shift(@s);
    next if ($c eq ' '); # Already used delimeters are set to ' '
    if (($c eq $d0) && ($d0 eq $d1)) {
        push @out, [$pos, 0];
    }elsif ($c eq $d0) {
        $len = len_to_delim($d0, $d1, \@s);
        return undef if (!defined $len);
        push @out, [$pos, $len];
    } elsif ($c eq $d1) {
        # There is a closing delimiter with no opening
        # delimeter, an input error.
        setDoNotPick("1");
        print "<br>ERROR IN SEQUENCE: closing delimiter $d1 not preceded by $d0\n";
        return undef;
    } else {
        $pos++;
    }
    }
    return \@out;
}

sub len_to_delim($$$) {
    my ($d0, $d1, $s) = @_;
    my $i;
    my $len = 0;
    for $i (0..$#{$s}) {
      if ($s->[$i] eq $d0) {
         # ignore it;
      } elsif ($s->[$i] eq $d1) {
         $s->[$i] = ' ';
         return $len;
      } else { $len++ }
    }
    # There was no terminating delim;
    setDoNotPick("1");
    print "<br>ERROR IN SEQUENCE: closing delimiter $d1 did not follow $d0\n";
    return undef;
}

##################################################
# runPrimer3: run primer3 and interprete results #
##################################################
sub runPrimer3 ($$$) {
    my ( $completeHash, $defaultHash, $resultsHash );
    $completeHash = shift;
    $defaultHash = shift;
    $resultsHash  = shift;

    my ($p3cOutputKeys, $p3cParametersKey, $readLine, $lineKey, $lineValue);
    my ($outputLine, $p3cInputKeys, $value, $openError);
    my (@p3cParameters, @readTheLine);
    my (%p3cInput, %p3cOutput );
        
    my $primer3BIN = getMachineSetting("PRIMER_BIN");
    my $callPrimer3 = $primer3BIN . getMachineSetting("PRIMER_RUNTIME");
    my $inputFile = getMachineSetting("USER_CACHE_FILES_PATH");
    $inputFile .= "Input_";
    $inputFile .= makeUniqueID();
    $inputFile .= ".txt";

###### First check if it makes sense to run primer3

    ## Do not run if there is not any sequence information
    if (  (( $completeHash->{"SEQUENCE_TEMPLATE"} ) eq "" )
          && (( $completeHash->{"SEQUENCE_PRIMER"} ) eq "" )
          && (( $completeHash->{"SEQUENCE_INTERNAL_OLIGO"} ) eq "" )
          && (( $completeHash->{"SEQUENCE_PRIMER_REVCOMP"} ) eq "" )) {
        setMessage("ERROR: you must supply a source sequence or ".
                   "primers/oligos to evaluate");
        setDoNotPick("1");
    }

###### Create a hash with parameters primer3 understands
    
    # We copy over only the keys from the default hash to be save
    # from broken tags provided by the user
    @p3cParameters = keys(%{$defaultHash});
    foreach $p3cParametersKey (@p3cParameters) {
        if (($p3cParametersKey =~ /^PRIMER_/)
             || ($p3cParametersKey =~ /^SEQUENCE_/)) {
            $p3cInput{"$p3cParametersKey"} = $completeHash->{"$p3cParametersKey"};
        }
    }
    $p3cInput{PRIMER_PICK_ANYWAY}  = "1";
    $p3cInput{P3_FILE_FLAG}        = "0";
    $p3cInput{PRIMER_EXPLAIN_FLAG} = "1";

###### Set all the tags to special values for the run

    ## Set the parameters to use optimal Product size input
    if ( $completeHash->{"PRIMER_PRODUCT_OPT_SIZE"} ne "" ) {
        my $minSize = $completeHash->{"SCRIPT_PRODUCT_MIN_SIZE"};
        my $maxSize = $completeHash->{"SCRIPT_PRODUCT_MAX_SIZE"};
        $p3cInput{"PRIMER_PRODUCT_SIZE_RANGE"} = "$minSize-$maxSize";
    }

    # replace the names by the filenames
    my %misLibrary = getMisLibrary();
    my $libary;
    if ( defined $p3cInput{"PRIMER_MISPRIMING_LIBRARY"} ) {
        $libary = $p3cInput{"PRIMER_MISPRIMING_LIBRARY"};
        $p3cInput{"PRIMER_MISPRIMING_LIBRARY"} = $misLibrary{$libary};
    }
    if ( defined $p3cInput{"PRIMER_INTERNAL_MISHYB_LIBRARY"} ) {
        $libary = $p3cInput{"PRIMER_INTERNAL_MISHYB_LIBRARY"};
        $p3cInput{"PRIMER_INTERNAL_MISHYB_LIBRARY"} = $misLibrary{$libary};
    }

    # Be sure to get all sequencing primers
    if (($completeHash->{"PRIMER_TASK"}) eq "pick_sequencing_primers") {
        $p3cInput{"PRIMER_NUM_RETURN"} = 1000;
    }

###### Check if Primer3 can be run
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

    ## Only continue here if everything is OK
    if ( getDoNotPick() != 0 ) {
         setMessage("Primer3 did not run due to an internal conflict.");
         return;
    }

###### Create input file
    $openError = 0;
    open( FILE, ">$inputFile" ) or $openError = 1;
    if ($openError == 0) {
        foreach $p3cInputKeys ( keys( %p3cInput ) ) {
            $value = $p3cInput{"$p3cInputKeys"};
            if ( $value ne "" ) {
                print FILE qq{$p3cInputKeys=$p3cInput{"$p3cInputKeys"}\n};
            }
        }
        print FILE qq{=\n};
        close(FILE);
    } else {
        setMessage("cannot write $inputFile");
        return;
    }


###### Really run primer3
    open(PRIMER3OUTPUT, "$callPrimer3 $inputFile 2>&1 |")
        or setMessage("could not start primer3");
    while (<PRIMER3OUTPUT>) {
        push @readTheLine, $_;
    }
    close PRIMER3OUTPUT;
    unlink $inputFile;

###### Interprete the output
    foreach $readLine (@readTheLine) {
        ( $lineKey, $lineValue ) = split "=", $readLine;
        $lineKey   =~ s/\s//g;
        $lineValue =~ s/\n//g;
        #Write everything in the Output Hash
        $resultsHash->{"$lineKey"} = $lineValue;

        # Make a Name for each primer
        if ( $lineKey =~ /_SEQUENCE$/ ) {
            createPrimerName($lineKey, $completeHash, $resultsHash);
        }
    }
  
    return;
}

###############################
# createName: Name the primer #
###############################
sub createPrimerName ($$$) {
    my ($inName, $completeHash, $resultsHash);
    $inName       = shift;
    $completeHash = shift;
    $resultsHash  = shift;

    my @nameKeyComplete;
    my ( $namePrimerType, $nameNumber, $nameKeyName, $nameKeyValue );
        
    my $acronymLeft  = $completeHash->{"P3P_PRIMER_NAME_ACRONYM_LEFT"};
    my $acronymRight = $completeHash->{"P3P_PRIMER_NAME_ACRONYM_RIGHT"};
    my $acronymOligo = $completeHash->{"P3P_PRIMER_NAME_ACRONYM_INTERNAL"};
    my $acronymSpace = $completeHash->{"P3P_PRIMER_NAME_ACRONYM_SPACER"};
    my $sequenceName = $completeHash->{"SEQUENCE_ID"};

    if ( $inName =~ /_SEQUENCE$/ ) {
            @nameKeyComplete = split "_", $inName;
            $namePrimerType = $nameKeyComplete[1];
            $nameNumber = $nameKeyComplete[2];
            $nameKeyName = $inName;
            $nameKeyName =~ s/SEQUENCE/NAME/;
            $nameKeyValue = "";

            # Use the Name or Primer for the ID
            if ( ( length $sequenceName ) > 2 ) {
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
            $resultsHash->{"$nameKeyName"} = $nameKeyValue;
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
sub makeUniqueID () {
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
	$time = sprintf "%4d%02d%02d_%02d%02d%02d_", 
	        $year, $month, $dayOfMonth, $hour, $minute, $second;
	$UID = $time . $randomNumber;

	return $UID;
}

####################################################################################
# getDate: Returns the Date as a string: D is format DD_MM_YY, Y is format YY_MM_DD#
####################################################################################
sub getDate ($$){
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

################################################
# writeStatistics: Updates the statistics file #
################################################
sub readStatistics ($) {
    my $fileName;
    $fileName = shift;
    my $fileInAString;
    my $processedDate;
    my $processedCount;
    my $compressedFile;
    my $line;
    my $date;
    my $dateCout = 0;
    my $oldLine = "...";
    my @rawDates;
    my %dates;

    my $today = getDate("Y", ".");
    my $completeFileName = getMachineSetting("USER_STATISTICS_FILES_PATH"). $fileName . ".txt";
    my $completeTmpFileName;

    open( TEMPLATEFILE, "<$completeFileName" ) or return %dates;
    binmode TEMPLATEFILE;
    my $data;
    while ( read TEMPLATEFILE, $data, 1024 ) {
        $fileInAString .= $data;
    }
    close(TEMPLATEFILE);
    
    @rawDates = split '\n', $fileInAString;
    foreach $line (@rawDates) {
        $line =~ s/\s//g;
        if ($line =~ /\d/ ) {
            $date = $line;
            if ($line =~ /=/ ) {
                if ($oldLine ne "...") {
                    $compressedFile .= $oldLine ."=". $dateCout . "\n";
                }
                ($processedDate, $processedCount) = split '=', $line;
                $dates{$processedDate} = $processedCount;
                $oldLine = $processedDate;
                $dateCout = $processedCount;
            } elsif ($line eq $oldLine) {
                $dateCout++;
            } elsif ($oldLine eq "...") {
                $dateCout = 1;
                $oldLine = $line;
            }else {
                $dates{$oldLine} = $dateCout;
                $compressedFile .= $oldLine ."=". $dateCout . "\n";
                $dateCout = 1;
                $oldLine = $line;
            }
        }
    }
    $dates{$oldLine} = $dateCout;
    $compressedFile .= $oldLine ."=". $dateCout . "\n";
    
    $completeTmpFileName = getMachineSetting("USER_STATISTICS_FILES_PATH"). "TMP_" . $fileName . ".txt";

    open( TEMPLATEFILE, ">$completeTmpFileName" ) or return %dates;
    print TEMPLATEFILE $compressedFile;
    close(TEMPLATEFILE);
    
    copy($completeTmpFileName,$completeFileName) or setMessage("Copy did not work");

    return %dates;
}

################################################
# writeStatistics: Updates the statistics file #
################################################
sub writeStatistics ($) {
    my $fileName;
    $fileName = shift;

    # If we do not want statistics stop here
    if (getMachineSetting("STATISTICS") eq "N") {
        return;
    }

    my $completeFileName = getMachineSetting("USER_STATISTICS_FILES_PATH"). $fileName . ".txt";

    open( TEMPLATEFILE, ">>$completeFileName" ) or return;
    print TEMPLATEFILE getDate("Y", ".");
    print TEMPLATEFILE "\n";
    close(TEMPLATEFILE);

    return;
}

############################################################################
# getLyk3Sequence: Returns an example sequence for demonstration purpurses #
############################################################################
sub getLyk3Sequence () {
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
