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
package primer3plusFunctions;
use CGI;
use Carp;
#use CGI::Carp qw(fatalsToBrowser);
use CGI::Cookie;
use FileHandle;
use IPC::Open3;
use Exporter;
use File::Copy;
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );

use settings;

our ( @ISA, @EXPORT, @EXPORT_OK, $VERSION );
@ISA    = qw(Exporter);
@EXPORT = qw(&getParametersHTML &constructCombinedHash &createFile &checkPrefold
     &getSetCookie &getCookie &setCookie &getCacheFile &setCacheFile
     &loadManagerFile &loadFile &checkParameters &runPrimer3 &runUnafold &reverseSequence
     &loadServerSettFile &extractCompleteManagerHash &addToManagerHash
     &exportFastaForManager &loadFastaForManager &saveRDMLForManager 
     &readRDMLForManager &zipAndCacheIt &unzipItCache &printFile &getParametersManagerHTML
     &getDate &makeUniqueID &writeStatistics &readStatistics);

$VERSION = "1.00";

$CGI::POST_MAX = 1024 * 5000;

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
	if ((defined $radioButtons) and ($radioButtons ne "" )) {
		@radioButtonsList = split ',', $radioButtons;
		foreach $radioKey (@radioButtonsList) {
			$dataTarget->{$radioKey} = 0;
		}
	}
	
	# Load the sequence file in a string to read it later
	if ((defined $seqFile) and ($seqFile ne "" )) {
		binmode $seqFile;
		my $data;
		while ( read $seqFile, $data, 1024 ) {
			$dataTarget->{"SCRIPT_SEQUENCE_FILE_CONTENT"} .= $data;
		}
	}

	# Load the settings file in a string to read it later
	if ((defined $settFile) and ($settFile ne "" )) {
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


sub getParametersManagerHTML {
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
	if ((defined $radioButtons) and ($radioButtons ne "" )) {
		@radioButtonsList = split ',', $radioButtons;
		foreach $radioKey (@radioButtonsList) {
			$dataTarget->{$radioKey} = 0;
		}
	}
	
	# Load the sequence file in a string to read it later
	if ((defined $seqFile) and ($seqFile ne "" )) {
		my $status = 0;
		my $filehandle = $cgi->upload('SCRIPT_SEQUENCE_FILE');
		binmode $filehandle;
		my $fileName = getMachineSetting("USER_CACHE_FILES_PATH"). makeUniqueID() . "_UPLOAD.rdml";
		
		open(TARGET,">$fileName") or $status = 1;
		
		if ($status == 1) {
			setMessage("Error opening submitted RDML-file on disk: $!");
		} else {
			binmode TARGET;
			my ($buffer);
			while(read $filehandle,$buffer,1024){
				print TARGET $buffer;
			}
			close TARGET;
			
			my $zip = Archive::Zip->new();
			
			$status = $zip->read($fileName);
			
			if ($status != AZ_OK) {
				setMessage("Error reading the RDML-file.");
			} else {
				$dataTarget->{"SCRIPT_SEQUENCE_FILE_CONTENT"} = $zip->contents("rdml_data.xml"); 
			}
			unlink $fileName;
		}
	}

	# Load the settings file in a string to read it later
	if ((defined $settFile) and ($settFile ne "" )) {
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
	my $returnValue;
	my $val;
	
	$oldValue = $cgi->cookie( -name => 'Primer3Manager' );
	$returnValue = "";
	
	if (!(defined $oldValue)) {
		return $returnValue;
	}
	
	# Just to be sure there is no crap in the cookie (like commands)
	$oldValue =~ s/ //g;
	$oldValue =~ s/\///g;
	$oldValue =~ s/\\//g;
	$oldValue =~ s/\|//g;
	$oldValue =~ s/\.//g;
	
	for (my $i = 0; $i < length($oldValue); $i++) {
		$val = substr($oldValue, $i, 1);
		if ($val =~ /[a-zA-Z0-9_]/) {
			$returnValue .= $val;
		}
	}

	return $returnValue;
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


#################################
# To make a counter for Primers #
#################################
my $primerNumber = -1;

sub getPrimerNumber {
	$primerNumber++;
return $primerNumber;
}


###########################################################################
# extractCompleteManagerHash: extract the manager Hash out $comp of $add  #
###########################################################################
sub extractCompleteManagerHash {
	my ( $comp, $add, $deleteSelected, $selectAll );
	$comp = shift;
	$add  = shift;
	
	my (@hashKeys, @nameKeyComplete);
	my ($hashKey,$primerType, $counter, $outCounter);
	my %defHash;
	
	%defHash = getDefaultSettings();
	
	$deleteSelected = 0;
	$selectAll = 0;
	
	# First copy over basic information: 
    if ((defined $add->{"SCRIPT_DISPLAY_DEBUG_INFORMATION"}) 
         and ($add->{"SCRIPT_DISPLAY_DEBUG_INFORMATION"} ne "")) {
        $comp->{"SCRIPT_DISPLAY_DEBUG_INFORMATION"} = $add->{"SCRIPT_DISPLAY_DEBUG_INFORMATION"}; 
    } 
    if ((defined $add->{"P3P_PRIMER_NAME_ACRONYM_LEFT"}) 
         and ($add->{"P3P_PRIMER_NAME_ACRONYM_LEFT"} ne "")) {
        $comp->{"P3P_PRIMER_NAME_ACRONYM_LEFT"} = $add->{"P3P_PRIMER_NAME_ACRONYM_LEFT"}; 
    } else {
        $comp->{"P3P_PRIMER_NAME_ACRONYM_LEFT"} = $defHash{"P3P_PRIMER_NAME_ACRONYM_LEFT"};
    }
    if ((defined $add->{"P3P_PRIMER_NAME_ACRONYM_INTERNAL"}) 
         and ($add->{"P3P_PRIMER_NAME_ACRONYM_INTERNAL"} ne "")) {
        $comp->{"P3P_PRIMER_NAME_ACRONYM_INTERNAL"} = $add->{"P3P_PRIMER_NAME_ACRONYM_INTERNAL"}; 
    } else {
        $comp->{"P3P_PRIMER_NAME_ACRONYM_INTERNAL"} = $defHash{"P3P_PRIMER_NAME_ACRONYM_INTERNAL"};
    }
    if ((defined $add->{"P3P_PRIMER_NAME_ACRONYM_RIGHT"}) 
         and ($add->{"P3P_PRIMER_NAME_ACRONYM_RIGHT"} ne "")) {
        $comp->{"P3P_PRIMER_NAME_ACRONYM_RIGHT"} = $add->{"P3P_PRIMER_NAME_ACRONYM_RIGHT"}; 
    } else {
        $comp->{"P3P_PRIMER_NAME_ACRONYM_RIGHT"} = $defHash{"P3P_PRIMER_NAME_ACRONYM_RIGHT"};
    }
    if ((defined $add->{"P3P_PRIMER_NAME_ACRONYM_SPACER"}) 
         and ($add->{"P3P_PRIMER_NAME_ACRONYM_SPACER"} ne "")) {
        $comp->{"P3P_PRIMER_NAME_ACRONYM_SPACER"} = $add->{"P3P_PRIMER_NAME_ACRONYM_SPACER"}; 
    } else {
        $comp->{"P3P_PRIMER_NAME_ACRONYM_SPACER"} = $defHash{"P3P_PRIMER_NAME_ACRONYM_SPACER"};
    }
    
    # Then set the RDML Values if they are not defined:
    if ((defined $add->{"P3P_RDML_VERSION"}) 
         and ($add->{"P3P_RDML_VERSION"} ne "")) {
        $comp->{"P3P_RDML_VERSION"} = $add->{"P3P_RDML_VERSION"}; 
    } else {
        $comp->{"P3P_RDML_VERSION"} = "1.0";
    }

    # Sort out Delete-Mode and Order-Mode:
    if ((defined $add->{"SCRIPT_PRIMER_MANAGER"}) 
         and ($add->{"SCRIPT_PRIMER_MANAGER"} eq "PRIMER3MANAGER_DELETEMODE")) {
        $comp->{"SCRIPT_PRIMER_MANAGER"} = "PRIMER3MANAGER_DELETEMODE"; 
    } else {
        $comp->{"SCRIPT_PRIMER_MANAGER"} = "PRIMER3MANAGER_DISPLAYMODE";
    }
    if ((defined $add->{"Submit"}) 
         and ($add->{"Submit"} eq "Delete Mode")) {
        $comp->{"SCRIPT_PRIMER_MANAGER"} = "PRIMER3MANAGER_DELETEMODE";
    }
    if ((defined $add->{"Submit"}) 
         and ($add->{"Submit"} eq "Order Mode")) {
        $comp->{"SCRIPT_PRIMER_MANAGER"} = "PRIMER3MANAGER_DISPLAYMODE";
    }
    if ((defined $add->{"Submit"}) 
         and ($add->{"Submit"} eq "Delete selected Primers")) {
        $deleteSelected = 1;
    }

    # And select all primers if requested:
    if ((defined $add->{"SELECT_ALL_PRIMERS"}) 
         and ($add->{"SELECT_ALL_PRIMERS"} == 1)) {
        $selectAll = 1; 
    } 


    # Work on information from Primer3Plus:
    if ((defined $add->{"SCRIPT_PRIMER_MANAGER"}) 
         and ($add->{"SCRIPT_PRIMER_MANAGER"} eq "PRIMER3PLUS" )) {

        # Now extract the primer pairs and add the missing information:
        if ((defined $add->{"PRIMER_PAIR_NUM_RETURNED"}) 
             and ($add->{"PRIMER_PAIR_NUM_RETURNED"} != 0 )) {

            for($counter = 0; $counter < $add->{"PRIMER_PAIR_NUM_RETURNED"}; $counter++) {
            	# Only add the selected Primers
                if (((defined $add->{"PRIMER_PAIR_$counter\_SELECT"}) 
                     and ($add->{"PRIMER_PAIR_$counter\_SELECT"} != 0 ))
                     or ($selectAll == 1)) {
                    $outCounter = getPrimerNumber();
                    $comp->{"PRIMER_PAIR_$outCounter\_SELECT"} = 1;
                    $comp->{"PRIMER_PAIR_$outCounter\_DATE"} = getDate( "D", "." );
                    
                    if ((defined $add->{"PRIMER_PAIR_$counter\_NAME"}) 
                         and ($add->{"PRIMER_PAIR_$counter\_NAME"} ne "")) {
                        $comp->{"PRIMER_PAIR_$outCounter\_NAME"} = $add->{"PRIMER_PAIR_$counter\_NAME"}; 
                    } else {
                        $comp->{"PRIMER_PAIR_$outCounter\_NAME"} = "";
                    }
                    
                    if ((defined $add->{"PRIMER_PAIR_$counter\_AMPLICON"}) 
                         and ($add->{"PRIMER_PAIR_$counter\_AMPLICON"} ne "")) {
                        $comp->{"PRIMER_PAIR_$outCounter\_AMPLICON"} = $add->{"PRIMER_PAIR_$counter\_AMPLICON"}; 
                    } else {
                        $comp->{"PRIMER_PAIR_$outCounter\_AMPLICON"} = "";
                    }

                    if ((defined $add->{"PRIMER_LEFT_$counter\_SEQUENCE"}) 
                         and ($add->{"PRIMER_LEFT_$counter\_SEQUENCE"} ne "")) {
                        $comp->{"PRIMER_LEFT_$outCounter\_SEQUENCE"} = $add->{"PRIMER_LEFT_$counter\_SEQUENCE"}; 
                    } else {
                        $comp->{"PRIMER_LEFT_$outCounter\_SEQUENCE"} = "";
                    }
                
                    if ((defined $add->{"PRIMER_INTERNAL_$counter\_SEQUENCE"}) 
                         and ($add->{"PRIMER_INTERNAL_$counter\_SEQUENCE"} ne "")) {
                        $comp->{"PRIMER_INTERNAL_$outCounter\_SEQUENCE"} = $add->{"PRIMER_INTERNAL_$counter\_SEQUENCE"}; 
                    } else {
                        $comp->{"PRIMER_INTERNAL_$outCounter\_SEQUENCE"} = "";
                    }
                
                    if ((defined $add->{"PRIMER_RIGHT_$counter\_SEQUENCE"}) 
                         and ($add->{"PRIMER_RIGHT_$counter\_SEQUENCE"} ne "")) {
                        $comp->{"PRIMER_RIGHT_$outCounter\_SEQUENCE"} = $add->{"PRIMER_RIGHT_$counter\_SEQUENCE"}; 
                    } else {
                        $comp->{"PRIMER_RIGHT_$outCounter\_SEQUENCE"} = "";
                    }
                
                }
            }
            $comp->{"PRIMER_PAIR_NUM_RETURNED"} = $outCounter;
        } # Now extract the primer pairs and add the missing information
    
        # Now extract the single primers and add the missing information:
        if ((defined $add->{"PRIMER_PAIR_NUM_RETURNED"}) 
             and ($add->{"PRIMER_PAIR_NUM_RETURNED"} == 0 )) {
            @hashKeys = keys(%{$add});
            foreach $hashKey (@hashKeys) {
                if ($hashKey =~ /_SEQUENCE$/) {
                    @nameKeyComplete = split "_", $hashKey;
                    $primerType = $nameKeyComplete[1];
                    $counter = $nameKeyComplete[2];
                    if (((defined $add->{"PRIMER_$primerType\_$counter\_SELECT"}) 
                          and ($add->{"PRIMER_$primerType\_$counter\_SELECT"} != 0 ))
                          or ($selectAll == 1)) {
                        $outCounter = getPrimerNumber();
                        $comp->{"PRIMER_PAIR_$outCounter\_SELECT"} = 1;
                        $comp->{"PRIMER_PAIR_$outCounter\_AMPLICON"} = "";
                        $comp->{"PRIMER_PAIR_$outCounter\_DATE"} = getDate( "D", "." );
                    
                        # Now the name has to be moved to pair
                        if ((defined $add->{"PRIMER_$primerType\_$counter\_NAME"}) 
                             and ($add->{"PRIMER_$primerType\_$counter\_NAME"} ne "")) {
                            $comp->{"PRIMER_PAIR_$outCounter\_NAME"} = $add->{"PRIMER_$primerType\_$counter\_NAME"}; 
                        } else {
                            $comp->{"PRIMER_PAIR_$outCounter\_NAME"} = "";
                        }
                     	
                        if ($primerType eq "LEFT") {
                            $comp->{"PRIMER_LEFT_$outCounter\_SEQUENCE"} = $add->{"PRIMER_LEFT_$counter\_SEQUENCE"}; 
                        } else {
                            $comp->{"PRIMER_LEFT_$outCounter\_SEQUENCE"} = "";
                        }
                
                        if ($primerType eq "INTERNAL") {
                            $comp->{"PRIMER_INTERNAL_$outCounter\_SEQUENCE"} = $add->{"PRIMER_INTERNAL_$counter\_SEQUENCE"}; 
                        } else {
                            $comp->{"PRIMER_INTERNAL_$outCounter\_SEQUENCE"} = "";
                        }
                
                        if ($primerType eq "RIGHT") {
                            $comp->{"PRIMER_RIGHT_$outCounter\_SEQUENCE"} = $add->{"PRIMER_RIGHT_$counter\_SEQUENCE"}; 
                        } else {
                            $comp->{"PRIMER_RIGHT_$outCounter\_SEQUENCE"} = "";
                        }
                    }	
                }
            }
            $comp->{"PRIMER_PAIR_NUM_RETURNED"} = $outCounter;
        } # Now extract the primer pairs and add the missing information
    } # Work on information from Primer3Plus

    # Work on information from Primer3Manager:
    if ((defined $add->{"SCRIPT_PRIMER_MANAGER"}) 
         and (($add->{"SCRIPT_PRIMER_MANAGER"} eq "PRIMER3MANAGER_DISPLAYMODE" )
         or ($add->{"SCRIPT_PRIMER_MANAGER"} eq "PRIMER3MANAGER_DELETEMODE" ))) {

        # If no primers need to be added, we finsish here
        if ((defined $add->{"Submit"}) 
             and ($add->{"Submit"} eq "Delete all Primers")) {
            return;
        }
        
        # Now extract all information:
        for($counter = 0; $counter <= $add->{"PRIMER_PAIR_NUM_RETURNED"}; $counter++) {
            # Only add the selected Primers
        	if (!(($deleteSelected == 1) and ($add->{"PRIMER_PAIR_$counter\_SELECT"} == 1 ))
        		and !(      ($add->{"PRIMER_PAIR_$counter\_NAME"} eq "") 
        		        and ($add->{"PRIMER_PAIR_$counter\_AMPLICON"} eq "") 
        		        and ($add->{"PRIMER_LEFT_$counter\_SEQUENCE"} eq "") 
        		        and ($add->{"PRIMER_INTERNAL_$counter\_SEQUENCE"} eq "") 
        		        and ($add->{"PRIMER_RIGHT_$counter\_SEQUENCE"} eq ""))) {
        		        	
        		$outCounter = getPrimerNumber();
	        	if ($add->{"PRIMER_PAIR_$counter\_SELECT"} == 1 ) {
	        		if ((defined $add->{"SCRIPT_PRIMER_MANAGER"}) 
                         and ($add->{"SCRIPT_PRIMER_MANAGER"} eq "PRIMER3MANAGER_DELETEMODE")){
	        		    $comp->{"PRIMER_PAIR_$outCounter\_SELECT"} = 0;
	        		} else {
	        			$comp->{"PRIMER_PAIR_$outCounter\_SELECT"} = 1;
	        		}
	        	} else {
	        		if ((defined $add->{"SCRIPT_PRIMER_MANAGER"}) 
                         and ($add->{"SCRIPT_PRIMER_MANAGER"} eq "PRIMER3MANAGER_DELETEMODE")){
	        		    $comp->{"PRIMER_PAIR_$outCounter\_SELECT"} = 1;
	        		} else {
	        			$comp->{"PRIMER_PAIR_$outCounter\_SELECT"} = 0;
	        		}        		
	        	}
	            $comp->{"PRIMER_PAIR_$outCounter\_DATE"} = $add->{"PRIMER_PAIR_$counter\_DATE"};
	            $comp->{"PRIMER_PAIR_$outCounter\_NAME"} = $add->{"PRIMER_PAIR_$counter\_NAME"}; 
	            $comp->{"PRIMER_PAIR_$outCounter\_AMPLICON"} = $add->{"PRIMER_PAIR_$counter\_AMPLICON"}; 
	            $comp->{"PRIMER_LEFT_$outCounter\_SEQUENCE"} = $add->{"PRIMER_LEFT_$counter\_SEQUENCE"}; 
	            $comp->{"PRIMER_INTERNAL_$outCounter\_SEQUENCE"} = $add->{"PRIMER_INTERNAL_$counter\_SEQUENCE"}; 
	            $comp->{"PRIMER_RIGHT_$outCounter\_SEQUENCE"} = $add->{"PRIMER_RIGHT_$counter\_SEQUENCE"}; 
	            $comp->{"PRIMER_PAIR_NUM_RETURNED"} = $outCounter;
        	}
        } # Now extract the primer pairs and add the missing information
    
    
        
    } # Work on information from Primer3Manager

	return;
}

#################################################################
# addToManagerHash: extract the manager Hash out $comp of $add  #
#################################################################
sub addToManagerHash {
	my ( $comp, $add);
	$comp = shift;
	$add  = shift;
	
	my (@hashKeys, @nameKeyComplete, @counterKey, @sortCounterKey);
	my ($hashKey,$primerType, $counter, $outCounter);

    @hashKeys = keys(%{$add});
    foreach $hashKey (@hashKeys) {
        if ($hashKey =~ /_NAME$/) {
            @nameKeyComplete = split "_", $hashKey;
            $counter = $nameKeyComplete[2];
			push(@counterKey,$counter);
        }
    }

    @sortCounterKey = sort(@counterKey);
            	
    foreach $counter (@sortCounterKey) {        	
        $outCounter = getPrimerNumber();
        $comp->{"PRIMER_PAIR_$outCounter\_SELECT"} = $add->{"PRIMER_PAIR_$counter\_SELECT"};
        $comp->{"PRIMER_PAIR_$outCounter\_AMPLICON"} = $add->{"PRIMER_PAIR_$counter\_AMPLICON"};
        $comp->{"PRIMER_PAIR_$outCounter\_DATE"} = $add->{"PRIMER_PAIR_$counter\_DATE"};
        $comp->{"PRIMER_PAIR_$outCounter\_NAME"} = $add->{"PRIMER_PAIR_$counter\_NAME"};
        $comp->{"PRIMER_LEFT_$outCounter\_SEQUENCE"} = $add->{"PRIMER_LEFT_$counter\_SEQUENCE"};
        $comp->{"PRIMER_RIGHT_$outCounter\_SEQUENCE"} = $add->{"PRIMER_RIGHT_$counter\_SEQUENCE"};
        $comp->{"PRIMER_INTERNAL_$outCounter\_SEQUENCE"} = $add->{"PRIMER_INTERNAL_$counter\_SEQUENCE"};
        $comp->{"PRIMER_PAIR_NUM_RETURNED"} = $outCounter;
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

####################################################################
# exportFastaForManager: Write Primers in Fasta format in a string #
####################################################################
sub exportFastaForManager {
    my ($hash, $counter, $name, $fullName, $selected) ; 
    $hash = shift;

    my $returnString;
    
    $returnString = "";

    for($counter = 0; $counter <= $hash->{"PRIMER_PAIR_NUM_RETURNED"}; $counter++) {
        if ($hash->{"PRIMER_PAIR_$counter\_SELECT"} == 1) {
        	$selected = "     |X|";
        } else {
        	$selected = "     |O|";
        }
        $selected .= $hash->{"PRIMER_PAIR_$counter\_DATE"};
        $selected .= "\r\n";
        
   	    $name = ">" . $hash->{"PRIMER_PAIR_$counter\_NAME"};

        if ($hash->{"PRIMER_LEFT_$counter\_SEQUENCE"} ne "") {
            $fullName = $name . $hash->{"P3P_PRIMER_NAME_ACRONYM_SPACER"} . $hash->{"P3P_PRIMER_NAME_ACRONYM_LEFT"} . $selected;
            $returnString .= $fullName;
            $returnString .= $hash->{"PRIMER_LEFT_$counter\_SEQUENCE"};
            $returnString .= "\r\n\r\n";
        }
        if ($hash->{"PRIMER_RIGHT_$counter\_SEQUENCE"} ne "") {
            $fullName = $name . $hash->{"P3P_PRIMER_NAME_ACRONYM_SPACER"} . $hash->{"P3P_PRIMER_NAME_ACRONYM_RIGHT"} . $selected;
            $returnString .= $fullName;
            $returnString .= $hash->{"PRIMER_RIGHT_$counter\_SEQUENCE"};
            $returnString .= "\r\n\r\n";
        }
        if ($hash->{"PRIMER_INTERNAL_$counter\_SEQUENCE"} ne "") {
            $fullName = $name . $hash->{"P3P_PRIMER_NAME_ACRONYM_SPACER"} . $hash->{"P3P_PRIMER_NAME_ACRONYM_INTERNAL"} . $selected;
            $returnString .= $fullName;
            $returnString .= $hash->{"PRIMER_INTERNAL_$counter\_SEQUENCE"};
            $returnString .= "\r\n\r\n";
        }
       
    }

  return $returnString;

}

##################################################################
# loadFastaForManager: Write Primers in Fasta format in a string #
##################################################################
sub loadFastaForManager {
	my ( $hash, $fileString);
	$hash       = shift;
	$fileString = shift;
	my ( @fileContent, @nameLine );
	my ( $select, $primerCounter );

	# solve the newline problem with other platforms
	if ($fileString =~ /\r\n/ ) {
		$fileString =~ s/\r\n/\n/g;
	}
	if ($fileString =~ /\r/ ) {
		$fileString =~ s/\r/\n/g;
	}

	@fileContent = split '\n', $fileString;

	$primerCounter = 0;
	for ( my $lineCounter = 0 ; $lineCounter <= $#fileContent ; $lineCounter++ ) {
		if ( $fileContent[$lineCounter] =~ /^>/ ) {
			$fileContent[$lineCounter] =~ s/^>//;
			$fileContent[$lineCounter] =~ s/^\s +//;

			@nameLine = split '\|', $fileContent[$lineCounter];
			$nameLine[0] =~ s/\s+$//;
			$hash->{"PRIMER_PAIR_$primerCounter\_NAME"} = $nameLine[0];

			if (defined $nameLine[1]) {
				if ( $nameLine[1] eq "X" ) {
					$hash->{"PRIMER_PAIR_$primerCounter\_SELECT"} = 1;
				}
			} else {
					$hash->{"PRIMER_PAIR_$primerCounter\_SELECT"} = 0;
			}

			if (defined $nameLine[2]) {
				$hash->{"PRIMER_PAIR_$primerCounter\_DATE"} = $nameLine[2];
			} else {
				$hash->{"PRIMER_PAIR_$primerCounter\_DATE"} = "";
			}
			
			$lineCounter++;
			$hash->{"PRIMER_LEFT_$primerCounter\_SEQUENCE"} = $fileContent[$lineCounter];

			$primerCounter++;
		}
	}

	return;
}

#############################################################################
# saveRDMLForManager: Write Primers in uncompressed RDML format in a string #
#############################################################################
sub saveRDMLForManager {
    my ($hash, $counter) ; 
    $hash = shift;

    my %uniqueNames;
    my ($name, $endName, $nameCount);
    my $returnString;
    
    $returnString = qq{<rdml version='};
    $returnString .= $hash->{"P3P_RDML_VERSION"};
    $returnString .= qq{1.0' xmlns:rdml='http://www.rdml.org' xmlns='http://www.rdml.org'>\n};

    for($counter = 0; $counter <= $hash->{"PRIMER_PAIR_NUM_RETURNED"}; $counter++) {
    	$returnString .= qq{<target id='};
    	
    	# RDML requires that an Id is unique
    	$name = $hash->{"PRIMER_PAIR_$counter\_NAME"};
    	$name =~ s/_DOUBLE_NAME_\d+$//g;
    	$nameCount = 0;
    	$endName = $name;
    	while ((defined $uniqueNames{$endName}) and ($nameCount < 100)) {
    		$nameCount++;
    		$endName = $name . "_DOUBLE_NAME_" . $nameCount;
    	} 
    	$uniqueNames{$endName} = "1";
    	
    	$returnString .= xmlIt($endName);
    	$returnString .= qq{'>\n};
    	
    	$returnString .= qq{<description>};
    	$returnString .= "Primer3Plus result from ";
    	$returnString .= xmlIt($hash->{"PRIMER_PAIR_$counter\_DATE"});
        if ($hash->{"PRIMER_PAIR_$counter\_SELECT"} == 1) {
        	$returnString .= " - display as selected";
        }
    	$returnString .= qq{</description>\n};

    	$returnString .= qq{<type>toi</type>\n};

    	$returnString .= qq{<sequences>\n};

        if ($hash->{"PRIMER_LEFT_$counter\_SEQUENCE"} ne "") {
            $returnString .= qq{<forwardPrimer>\n<sequence>};
            $returnString .= xmlIt($hash->{"PRIMER_LEFT_$counter\_SEQUENCE"});
            $returnString .= qq{</sequence>\n</forwardPrimer>\n};
        }
        if ($hash->{"PRIMER_RIGHT_$counter\_SEQUENCE"} ne "") {
            $returnString .= qq{<reversePrimer>\n<sequence>};
            $returnString .= xmlIt($hash->{"PRIMER_RIGHT_$counter\_SEQUENCE"});
            $returnString .= qq{</sequence>\n</reversePrimer>\n};
        }
        if ($hash->{"PRIMER_INTERNAL_$counter\_SEQUENCE"} ne "") {
            $returnString .= qq{<probe1>\n<sequence>};
            $returnString .= xmlIt($hash->{"PRIMER_INTERNAL_$counter\_SEQUENCE"});
            $returnString .= qq{</sequence>\n</probe1>\n};
        }
        if ($hash->{"PRIMER_PAIR_$counter\_AMPLICON"} ne "") {
            $returnString .= qq{<amplicon>\n<sequence>};
            $returnString .= xmlIt($hash->{"PRIMER_PAIR_$counter\_AMPLICON"});
            $returnString .= qq{</sequence>\n</amplicon>\n};
        }

    	$returnString .= qq{</sequences>\n};

        $returnString .= qq{</target>\n};
    }
    $returnString .= qq{</rdml>\n};

  return $returnString;

}

############################################################################
# readRDMLForManager: Read Primers in uncompressed RDML format in a string #
############################################################################
sub readRDMLForManager {
    my ($hash, $string, $counter) ; 
    $hash = shift;
    $string = shift;

    my @targets;

    # Check if the file is an RDML file and contains at least one target
    if (!($string =~ /rdml version/)) {
    	return;
    }
    if (!($string =~ /<\/target>/)) {
    	return;
    }
    
    # Now we only have to deal with ':
    $string =~ s/"/'/g;
    
    # Split it in several probes
    @targets = split '</target>', $string;
    
    # Extract the information for each probe
    for($counter = 0; $counter < $#targets; $counter++) {
    	
        if ($targets[$counter] =~ /<target id='(.+)?'>/) {
        	$hash->{"PRIMER_PAIR_$counter\_NAME"} = deXmlIt($1);
        }else {
        	$hash->{"PRIMER_PAIR_$counter\_NAME"} = "";
        }
        
        if ($targets[$counter] =~ /- display as selected<\/description>/) {
        	$hash->{"PRIMER_PAIR_$counter\_SELECT"} = 1;
        } else {
        	$hash->{"PRIMER_PAIR_$counter\_SELECT"} = 0;
        }
        
        if ($targets[$counter] =~ /<description>Primer3Plus result from ([0-9\.]+)?/) {
        	$hash->{"PRIMER_PAIR_$counter\_DATE"} = deXmlIt($1);
        } else {
        	$hash->{"PRIMER_PAIR_$counter\_DATE"} = "";
        }
        
        if ($targets[$counter] =~ /<forwardPrimer>\s+<sequence>(.+)?<\/sequence>\s+<\/forwardPrimer>/) {
        	$hash->{"PRIMER_LEFT_$counter\_SEQUENCE"} = deXmlIt($1);
        }else {
        	$hash->{"PRIMER_LEFT_$counter\_SEQUENCE"} = "";
        }
    	
        if ($targets[$counter] =~ /<reversePrimer>\s+<sequence>(.+)?<\/sequence>\s+<\/reversePrimer>/) {
        	$hash->{"PRIMER_RIGHT_$counter\_SEQUENCE"} = deXmlIt($1);
        }else {
        	$hash->{"PRIMER_RIGHT_$counter\_SEQUENCE"} = "";
        }
    	
        if ($targets[$counter] =~ /<probe1>\s+<sequence>(.+)?<\/sequence>\s+<\/probe1>/) {
        	$hash->{"PRIMER_INTERNAL_$counter\_SEQUENCE"} = deXmlIt($1);
        }else {
        	$hash->{"PRIMER_INTERNAL_$counter\_SEQUENCE"} = "";
        }
    	
        if ($targets[$counter] =~ /<amplicon>\s+<sequence>(.+)?<\/sequence>\s+<\/amplicon>/) {
        	$hash->{"PRIMER_PAIR_$counter\_AMPLICON"} = deXmlIt($1);
        }else {
        	$hash->{"PRIMER_PAIR_$counter\_AMPLICON"} = "";
        }
    	
    }

  return;

}

sub xmlIt {
    my $string ; 
    $string = shift;

    my $returnString;
    
    $returnString = $string;
    
    $returnString =~ s/&/&amp;/g;
    $returnString =~ s/>/&gt;/g;
    $returnString =~ s/</&lt;/g;
    $returnString =~ s/'/&apos;/g;
    $returnString =~ s/"/&quot;/g;

    return $returnString;

}


sub deXmlIt {
    my $string ; 
    $string = shift;

    my $returnString;
    
    $returnString = $string;
    
    $returnString =~ s/&gt;/>/g;
    $returnString =~ s/&lt;/</g;
    $returnString =~ s/&apos;/'/g;
    $returnString =~ s/&quot;/"/g;
    $returnString =~ s/&amp;/&/g;

    return $returnString;

}


sub zipAndCacheIt {
    my ($string, $uniqueID) ; 
    $string = shift;
    $uniqueID = shift;

	my $zip = Archive::Zip->new();
	
    my $addFile = Archive::Zip::Member->newFromString( $string, "rdml_data.xml" ) 
        or setMessage("Error adding content to the RDML-file.");
        
    $addFile->desiredCompressionMethod(COMPRESSION_DEFLATED);
    $addFile->desiredCompressionLevel(COMPRESSION_LEVEL_BEST_COMPRESSION);
    
    $zip->addMember($addFile);
    
    my $status = $zip->writeToFileNamed(getMachineSetting("USER_CACHE_FILES_PATH"). $uniqueID . ".rdml");
    if ($status != AZ_OK) {
    	setMessage("Error writing RDML-file for caching.");
    }

    return;

}

sub unzipItCache {
    my ($uniqueID, $cacheFile, $returnString, $status) ; 
    $uniqueID = shift;
    
    my $fileName;
    
    $returnString = "";
    
    $fileName = getMachineSetting("USER_CACHE_FILES_PATH"). $uniqueID . ".rdml";
    
    if (!(( -r $fileName ) and ( -e $fileName ))) {
    	return $returnString;
    }

	my $zip = Archive::Zip->new();
	
	$status = $zip->read($fileName);
	
	if ($status != AZ_OK) {
		setMessage("Error reading the RDML-file.");
		return $returnString;
	}
    
    $returnString = $zip->contents("rdml_data.xml");
    
    return $returnString;

}


sub printFile {
	my $uniqueID; 
    $uniqueID = shift;
    
    my $fileName = getMachineSetting("USER_CACHE_FILES_PATH"). $uniqueID . ".rdml";

	if ( ( -r $fileName ) and ( -e $fileName ) ) {
		open( TEMPLATEFILE, "<$fileName" );
		binmode(TEMPLATEFILE);
		while (<TEMPLATEFILE>) {
			print $_;
		}
		close(TEMPLATEFILE);
	}
	
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
					if (($lineKey =~ /^PRIMER_/) or ($lineKey =~ /^P3P_/)
					      or ($lineKey =~ /^P3_/) or ($lineKey =~ /^SEQUENCE_/)) {
						$dataTarget->{"$lineKey"} = $lineValue;
					}
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
    my $overlapPos       = $dataStorage->{"SEQUENCE_OVERLAP_JUNCTION_LIST"};

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
	$dataStorage->{"SEQUENCE_TEMPLATE"}              = $realSequence;
	$dataStorage->{"SEQUENCE_EXCLUDED_REGION"}       = $excludedRegion;
	$dataStorage->{"SEQUENCE_TARGET"}                = $target;
	$dataStorage->{"SEQUENCE_INCLUDED_REGION"}       = $includedRegion;
    $dataStorage->{"SEQUENCE_OVERLAP_JUNCTION_LIST"} = $overlapPos;

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

#####################################################################
# checkPrefold: Checks the Size of the sequence and Included Region #
#####################################################################
sub checkPrefold {
	my ($dataStorage);
	$dataStorage = shift;
	
	my ($pos, $leng, $seqLength);
	
	my $sizeLimit = getMachineSetting("MAX_PREFOLD_SEQUENCE");
	
	if (defined $dataStorage->{"SEQUENCE_TEMPLATE"}) {
	    $seqLength = length $dataStorage->{"SEQUENCE_TEMPLATE"};
	} else {
		$seqLength = 0;
	}
	
	if (!($seqLength > $sizeLimit )) {
        return 0;
	} else {
		if ((defined $dataStorage->{"SEQUENCE_INCLUDED_REGION"})
             and ($dataStorage->{"SEQUENCE_INCLUDED_REGION"} =~ /,/)) {
            ($pos, $leng) = split "," , $dataStorage->{"SEQUENCE_INCLUDED_REGION"};
		} else {
			$leng = $sizeLimit + 10;
		}	
        if ($leng < $sizeLimit) {
        	return 0;
        } else {
            setMessage("ERROR: Sequence length is over $sizeLimit bp. ".
			       "Select an Included Region < $sizeLimit bp.");
			return 1;
        }
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
    my ($errorFileText, $debugInput, $debugOutput);
    my ($primerPairCount, $ampliconLeft, $ampliconRight, $ampliconLength, $ampliconDel, $ampliconSequence);
    my (@p3cParameters, @readTheLine);
    my (%p3cInput, %p3cOutput );
        
    my $primer3BIN = getMachineSetting("PRIMER_BIN");
    my $callPrimer3 = $primer3BIN . getMachineSetting("PRIMER_RUNTIME");
    my $inputFile = getMachineSetting("USER_CACHE_FILES_PATH");
    $inputFile .= "Input_";
    $inputFile .= makeUniqueID();
    $inputFile .= ".txt";
    my $errorFile = getMachineSetting("USER_ERROR_FILES_PATH");
    $errorFile .= makeUniqueID();
    $errorFile .= ".txt";
    $debugInput = "";
    $debugOutput = "";

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
            if ($value ne "") {
                print FILE qq{$p3cInputKeys=$p3cInput{"$p3cInputKeys"}\n};
                $debugInput .= qq{$p3cInputKeys=$p3cInput{"$p3cInputKeys"}\n};
            }
        }
        print FILE qq{=\n};
        close(FILE);
    } else {
        setMessage("cannot write $inputFile");
        return;
    }
	$resultsHash->{"SCRIPT_DEBUG_INPUT"} = $debugInput;
    $resultsHash->{"SCRIPT_DISPLAY_DEBUG_INFORMATION"} = $completeHash->{"SCRIPT_DISPLAY_DEBUG_INFORMATION"};
    
    #Copy over the information for Primer3Manager
    $resultsHash->{"P3P_PRIMER_NAME_ACRONYM_LEFT"} = $completeHash->{"P3P_PRIMER_NAME_ACRONYM_LEFT"};
    $resultsHash->{"P3P_PRIMER_NAME_ACRONYM_INTERNAL"} = $completeHash->{"P3P_PRIMER_NAME_ACRONYM_INTERNAL"};
    $resultsHash->{"P3P_PRIMER_NAME_ACRONYM_RIGHT"} = $completeHash->{"P3P_PRIMER_NAME_ACRONYM_RIGHT"};
    $resultsHash->{"P3P_PRIMER_NAME_ACRONYM_SPACER"} = $completeHash->{"P3P_PRIMER_NAME_ACRONYM_SPACER"};


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
        $debugOutput .= qq{$lineKey=$lineValue\n};

        # Make a Name for each primer
        if ( $lineKey =~ /_SEQUENCE$/ ) {
            createPrimerName($lineKey, $completeHash, $resultsHash);
        }
    }

	$resultsHash->{"SCRIPT_DEBUG_OUTPUT"} = $debugOutput;
	    
###### In case primer3_core does not provide standard output (crashed, etc...),
###### write the input in an error file for later analysis
	
	if (!(defined($resultsHash->{"PRIMER_LEFT_NUM_RETURNED"}))) {
		setMessage("Error running primer3 - unusual output detected.<br />This usually occures if primer3 was terminated due to too high processor load for over 1 minute. Try less strict settings.");
		
		$errorFileText = createFile( $completeHash, "A" );
		$errorFileText =~ s/\r\n/\n/g;

	    $openError = 0;
	    open( FILE, ">$errorFile" ) or $openError = 1;
	    if ($openError == 0) {
            print FILE qq{$errorFileText};
	        close(FILE);
	    } else {
	        setMessage("Error writing $errorFile");
	        return;
	    }
		
	}
    # Calculate the Amplicon to hand it over to Primer3Manager  
	if (defined($resultsHash->{"PRIMER_PAIR_NUM_RETURNED"})) {
        for($primerPairCount = 0; $primerPairCount < $resultsHash->{"PRIMER_PAIR_NUM_RETURNED"}; $primerPairCount++) {
            ($ampliconLeft, $ampliconDel) = split ",", $resultsHash->{"PRIMER_LEFT_$primerPairCount"};
            ($ampliconRight, $ampliconDel) = split ",", $resultsHash->{"PRIMER_RIGHT_$primerPairCount"};
            
            $ampliconLength = $ampliconRight - $ampliconLeft + 1;
            
            $ampliconSequence = substr($resultsHash->{"SEQUENCE_TEMPLATE"}, 
                                       $ampliconLeft - $resultsHash->{"PRIMER_FIRST_BASE_INDEX"}, 
                                       $ampliconLength);
            
            $resultsHash->{"PRIMER_PAIR_$primerPairCount\_AMPLICON"} = $ampliconSequence;
        }
	}
    return;
}

##################################################
# runUnafold: run primer3 and interprete results #
##################################################
sub runUnafold ($$$) {
    my ( $completeHash, $defaultHash, $resultsHash );
    $completeHash = shift;
    $defaultHash = shift;
    $resultsHash  = shift;

    my ($sequence, $seqLength, $openError, $temp, $seqSize);
    my ($cut, $pos, $leng);
    my (@excl, @readTheLine, @lineArray, $readLine);
    my ($regStart, $regLength, $ionsDiv, $ionsMono);
        
    my $unafoldBIN = getMachineSetting("UNAFOLD_BIN");
    my $inputFile = getMachineSetting("USER_UNAFOLD_CACHE_PATH");
    my $unafoldParameters = "";
    my $unafoldOutput = "";
    my $unafoldResults = "";
    
    $inputFile .= "Input_";
    $inputFile .= makeUniqueID();
    $inputFile .= ".txt";
    
###### First check if it makes sense to run UNAFold

    ## Do not run if there is not any sequence information
    if ( $completeHash->{"SEQUENCE_TEMPLATE"} eq "" ) {
        setMessage("ERROR: You must supply a source sequence to evaluate");
        return;
    }

###### Create input
    $seqLength = length $completeHash->{"SEQUENCE_TEMPLATE"};

    if ((defined $completeHash->{"SEQUENCE_INCLUDED_REGION"})
         and ($completeHash->{"SEQUENCE_INCLUDED_REGION"} =~ /,/)) {
        ($pos, $leng) = split "," , $completeHash->{"SEQUENCE_INCLUDED_REGION"};
        $pos--;
        $cut = 1;
    } else {
		$cut = 0;
		$pos = 0;
	}
	
	if ($pos < 0){
		$pos = 0;
	} 
	if ($leng < 0) {
		$leng = 0;
	}
    if ( ($leng == 0) or (($pos + $leng + 1) > $seqLength)) {
        $leng = $seqLength - $pos;
	}
	
    $sequence = substr($completeHash->{"SEQUENCE_TEMPLATE"}, $pos, $leng);

    $openError = 0;
    open( FILE, ">$inputFile" ) or $openError = 1;
    if ($openError == 0) {
        print FILE qq{$sequence\n};
        close(FILE);
    } else {
        setMessage("Error: Cannot write $inputFile");
        return;
    }
    
    # To avoid crap like commands on the command line:
    if ($completeHash->{PRIMER_OPT_TM} =~ /^[\.\d]+$/) {
    	$temp = $completeHash->{PRIMER_OPT_TM};
    } else {
    	$temp = $defaultHash->{PRIMER_OPT_TM};
    }
    if ($completeHash->{PRIMER_SALT_DIVALENT} =~ /^[\.\d]+$/) {
    	$ionsDiv = $completeHash->{PRIMER_SALT_DIVALENT};
    } else {
    	$ionsDiv = $defaultHash->{PRIMER_SALT_DIVALENT};
    }
    if ($completeHash->{PRIMER_SALT_MONOVALENT} =~ /^[\.\d]+$/) {
    	$ionsMono = $completeHash->{PRIMER_SALT_MONOVALENT};
    } else {
    	$ionsMono = $defaultHash->{PRIMER_SALT_MONOVALENT};
    }

    $unafoldParameters  = "-n DNA -M";
    $unafoldParameters .= " -M " . ($ionsDiv / 1000);
    $unafoldParameters .= " -N " . ($ionsMono / 1000);
    $unafoldParameters .= " -t " . $temp;
    $unafoldParameters .= " -T " . $temp;
    $unafoldParameters .= " -o " . $inputFile;
    
    
    $resultsHash->{"SEQUENCE_ID"} = $completeHash->{"SEQUENCE_ID"};
    $resultsHash->{"SEQUENCE_TEMPLATE"} = $completeHash->{"SEQUENCE_TEMPLATE"};
    $resultsHash->{"PRIMER_SALT_MONOVALENT"} = $completeHash->{"PRIMER_SALT_MONOVALENT"};
    $resultsHash->{"PRIMER_SALT_DIVALENT"} = $completeHash->{"PRIMER_SALT_DIVALENT"};
    $resultsHash->{"PRIMER_OPT_TM"} = $completeHash->{"PRIMER_OPT_TM"};
    $resultsHash->{"PRIMER_FIRST_BASE_INDEX"} =  "1";
    
    $resultsHash->{"SCRIPT_UNAFOLD_COMMANDLINE_INPUT"} = $unafoldParameters;
    $resultsHash->{"SCRIPT_DISPLAY_DEBUG_INFORMATION"} = $completeHash->{"SCRIPT_DISPLAY_DEBUG_INFORMATION"};
    
###### Really run UNAFold
    open(UNAFOLDOUTPUT, "$unafoldBIN $inputFile $unafoldParameters 2>&1 |")
        or setMessage("Error: Could not run UNAFold");
    while (<UNAFOLDOUTPUT>) {
        $unafoldOutput .= $_;
    }
    close UNAFOLDOUTPUT;
    unlink $inputFile;
    
    $resultsHash->{"SCRIPT_UNAFOLD_COMMANDLINE_OUTPUT"} = $unafoldOutput;
    
###### Clean up
    if (-e "$inputFile.run") {
    	unlink "$inputFile.run";
    }

    if (-e "$inputFile.dG") {
    	unlink "$inputFile.dG";
    }
    
    if ($unafoldOutput =~ /t = (\d+)/) {
    	$temp = $1;
    }

    if (-e "$inputFile.$temp.ext") {
    	unlink "$inputFile.$temp.ext";
    }

    if (-e "$inputFile.$temp.plot") {
    	unlink "$inputFile.$temp.plot";
    }

###### Interprete the output
    open( OUTFILE, "<$inputFile.ct" ) or $openError = 1;
    if ($openError == 0) {
        while (<OUTFILE>) {
            $unafoldResults .= $_;
        }
        close(OUTFILE);
        unlink "$inputFile.ct";
    } else {
        setMessage("Error: Cannot write $inputFile");
        return;
    }
    
#   $resultsHash->{"SCRIPT_UNAFOLD_RESULTS"} = $unafoldResults;

###### Extract the excluded regions
    $seqSize = length($sequence);
    
    # Set the array to 0
    for (my $i = 0; $i < $seqSize; $i++) {
    	$excl[$i] = 0;
    }
    
    # Read the output
    @readTheLine = split "\n", $unafoldResults;
    foreach $readLine (@readTheLine) {
        @lineArray = split "\t", $readLine;
        if (!($lineArray[1] =~ /^dG/)) {
        	if ($lineArray[4] != 0) {
        		$excl[($lineArray[0] - 1)] = 1;
        	}
        }
    }

    # Build an excluded region list
    if (($cut == 1) and ($pos != 0)) {
    	$resultsHash->{"SEQUENCE_EXCLUDED_REGION"} .= "1,$pos ";
    }
    
    $regStart = 0;
    $regLength = 0;
    for (my $i = 0; $i < $seqSize; $i++) {
        if ($excl[$i] == 1) {
            if ($regStart == 0) {
                $regStart = $i;
            }
            if ($regStart != 0) {
                $regLength++;
            }
        }
        if ($excl[$i] == 0) {
            if ($regStart != 0) {
                $resultsHash->{"SEQUENCE_EXCLUDED_REGION"} .= ($regStart + $pos + 1) . ",";
                $resultsHash->{"SEQUENCE_EXCLUDED_REGION"} .= $regLength . " ";
                $regStart = 0;
                $regLength = 0;
            }
        }
    }
    if ($cut == 1) {
    	$resultsHash->{"SEQUENCE_EXCLUDED_REGION"} .= ($pos + $leng + 1);
    	$resultsHash->{"SEQUENCE_EXCLUDED_REGION"} .= ",";
    	$resultsHash->{"SEQUENCE_EXCLUDED_REGION"} .= ($seqLength - $pos - $leng);
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
    my ( $namePrimerType, $nameNumber, $nameKeyName, $nameKeyPair, $nameKeyValue );
        
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
            $nameKeyPair = "PRIMER_PAIR_$nameNumber\_NAME";
            $nameKeyValue = "";

            # Use the Name or Primer for the ID
            if ( ( length $sequenceName ) > 2 ) {
                $nameKeyValue .= $sequenceName;
            }
            else {
                $nameKeyValue .= "Primer";
            }
            # Add a Number
            if ( $nameNumber ne "0" ) {
                $nameKeyValue .= $acronymSpace.$nameNumber;
            }
            
            $resultsHash->{"$nameKeyPair"} = $nameKeyValue;
            
            $nameKeyValue .= $acronymSpace;
            
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
