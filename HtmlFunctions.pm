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
package HtmlFunctions;
use Carp;
#use CGI::Carp qw(fatalsToBrowser);
use Exporter;
use settings;
our (@ISA, @EXPORT, @EXPORT_OK, $VERSION);

@ISA = qw(Exporter);
@EXPORT = qw(&mainStartUpHTML &createHelpHTML &createAboutHTML &mainResultsHTML
			 &createManagerHTML &getWrapper &createSelectSequence);
$VERSION = "1.00";

##########################################################################
##########################################################################
#### Attention: Do not format this file or the HTML looks terrible!!! ####
##########################################################################
##########################################################################

my %machineSettings = getMachineSettings();
my %repeatLibraries = getMisLibrary();
my @libraryList = getLibraryList();
my @scriptTask = getScriptTask();


#################################
# To make a counter for Primers #
#################################
my $primerNumber = -1;

sub getPrimerNumber {
	$primerNumber++;
return $primerNumber;
}

##################################################################
# mainStartUpHTML: Will select the function to write a HTML-Form #
##################################################################
sub mainStartUpHTML {
  my $settings; 
  $settings = shift;

  my $returnString;
  my $javaScript = $settings->{"SCRIPT_CONTAINS_JAVA_SCRIPT"};

  if ($javaScript == 1) {
      $returnString = createStartUpUseScript($settings);
  }
  else {
      $returnString = createStartUpNoScript($settings);
  }

  return $returnString;
}

##################################################################
# mainResultsHTML: Will select the function to write a HTML-Form #
##################################################################
sub mainResultsHTML {
  my ($completeParameters, $results); 
  $completeParameters = shift;
  $results = shift;

  my $returnString;
  my $task = $results->{"SCRIPT_TASK"};

  if ($task eq "Detection") {
      $returnString = createResultsDetection($completeParameters, $results);
  }
  elsif ($task eq "Primer_Check") {
      $returnString = createResultsPrimerCheck($completeParameters, $results);
  }
  elsif ($task eq "Cloning") {
      $returnString = createResultsDetection($completeParameters, $results);
  }
  elsif ($task eq "Primer_List") {
      $returnString = createResultsPrimerList($completeParameters, $results, "1");
  }
  elsif ($task eq "Sequencing") {
      $returnString = createResultsPrimerList($completeParameters, $results, "0");
  }
  else {
      $returnString = createResultsList($results);
  }

  return $returnString;
}

################################################################################
# getWrapper: Reads the template file in which Primer3plus pastes it's content #
#             ATTENTION - this has to be done BEFORE the Messages are printed  #
#             otherwhise the errors are lost                                   #
################################################################################
sub getWrapper {
  my $fileName = $machineSettings{URL_HTML_TEMPLATE};
  my $FileContent = "";
  my $StringExist;
  my $FileContentBasic = "";
  
  # Read the basic template file as a fallback option
  open (TEMPLATEFILE, "<HtmlTemplate.html") or 
  						setMessage("Error: Cannot open template file: HtmlTemplate.html");
  while (<TEMPLATEFILE>) {
    	$FileContentBasic .= $_;
  }
  close(TEMPLATEFILE);

  # Try to read the real template file
  if (!-r $fileName){
		setMessage("Error loading HTML-Template file: $fileName is not readable!");
  }

  if (!-e $fileName){
        setMessage("Error loading HTML-Template file: $fileName does not exist!");
  }

  if ((-r $fileName) and (-e $fileName)){
	open (TEMPLATEFILE, "<$fileName") or 
						setMessage("Error: Cannot open template file: $fileName") ;
	
	while (<TEMPLATEFILE>) {
        	$FileContent .= $_;
  	}
    close(TEMPLATEFILE);

	# Find out if the string for the replacement could be found
	$StringExist = index ( $FileContent , "<!-- Primer3plus will include code here -->" );

	if ( $StringExist < "0"){
		setMessage("Error loading HTML-Template file: $fileName does not contain".
				   " the replacement string &lt;!-- Primer3plus will include code here --&gt; !");
		# Use the basic as fallback
		$FileContent = $FileContentBasic;
  	}
  }
  else {
    $FileContent = $FileContentBasic;
  }

  return $FileContent;
};

##########################################################
# divMessages: Writes all the messages in an HTML - Form #
##########################################################
sub divMessages {
	my @messages = getMessages();
	my $formHTML = "";
	
	if ($#messages > -1 ) {
	$formHTML = qq{
<div id="primer3plus_messages">
   <table class="primer3plus_table_no_border">};

my $note;
foreach $note (@messages) {
	$formHTML .= qq{
     <tr>
       <td class="primer3plus_note">$note</td>
     </tr>} ;
};
$formHTML .= qq{
   </table>
</div>

};
	}
	else {
	$formHTML = "";
	}
	return $formHTML;
}

########################################################### 
# divNoJavascript:                                        #
# Writes a message that is hidden by JavaScript, so only  #
# JavaScript disabled browser show it.                    #
###########################################################
sub divNoJavascript {
	my $urlFormAction = getMachineSetting("URL_FORM_ACTION");
	$urlFormAction .= "?SCRIPT_CONTAINS_JAVA_SCRIPT=0";
	my $formHTML = qq{
<script type="text/javascript">
	document.write("<style type=\\"text/css\\">div#primer3plus_no_javascript { display: none; }</style>");
</script>

<div id="primer3plus_no_javascript">
   <table class="primer3plus_table_no_border">
     <tr>
       <td class="primer3plus_note">
       		JavaScript is not enabled, please enable JavaScript and refresh the browser, 
       		or click this link for the <a href="$urlFormAction">non-Javascript version</a>.
       </td>
     </tr>
   </table>
</div>
};

	return $formHTML;
}


#############################################
# divTopBar: Writes the TopBar for the Form #    
#############################################
sub divTopBar {
	my $type;
	$type = shift;
	
	my ($title, $explain, $topLeft, $topRight, $lowLeft, $lowRight);
	
	if ($type eq "Manager") {
	$title    = "Primer3Manager";
	$explain  = "manage your primer library";
	$topLeft  = qq{<a class="primer3plus_top_bar_link" href="$machineSettings{URL_FORM_ACTION}">Primer3Plus</a>};
	$topRight = qq{<a class="primer3plus_top_bar_link" href="$machineSettings{URL_HELP}">Help</a>};
	$lowLeft  = qq{<a class="primer3plus_top_bar_link" href="$machineSettings{URL_ABOUT}">About</a>};
	$lowRight = qq{<a class="primer3plus_top_bar_link" href="$machineSettings{URL_SOURCE}">Source Code</a>};
	}
	elsif ($type eq "About") {
	$title    = "Primer3Plus - About";
	$explain  = "pick primers from a DNA sequence";
	$topLeft  = qq{<a class="primer3plus_top_bar_link" href="$machineSettings{URL_PRIMER_MANAGER}">Primer3Manager</a>};
	$topRight = qq{<a class="primer3plus_top_bar_link" href="$machineSettings{URL_HELP}">Help</a>};
	$lowLeft  = qq{<a class="primer3plus_top_bar_link" href="$machineSettings{URL_FORM_ACTION}">back to Form</a>};
	$lowRight = qq{<a class="primer3plus_top_bar_link" href="$machineSettings{URL_SOURCE}">Source Code</a>};
	}
	elsif ($type eq "Help") {
	$title    = "Primer3Plus - Help";
	$explain  = "pick primers from a DNA sequence";
	$topLeft  = qq{<a class="primer3plus_top_bar_link" href="$machineSettings{URL_PRIMER_MANAGER}">Primer3Manager</a>};
	$topRight = qq{<a class="primer3plus_top_bar_link" href="$machineSettings{URL_ABOUT}">About</a>};
	$lowLeft  = qq{<a class="primer3plus_top_bar_link" href="$machineSettings{URL_FORM_ACTION}">back to Form</a>};
	$lowRight = qq{<a class="primer3plus_top_bar_link" href="$machineSettings{URL_SOURCE}">Source Code</a>};
	}
	else {
	$title    = "Primer3Plus";
	$explain  = "pick primers from a DNA sequence";
	$topLeft  = qq{<a class="primer3plus_top_bar_link" href="$machineSettings{URL_PRIMER_MANAGER}">Primer3Manager</a>};
	$topRight = qq{<a class="primer3plus_top_bar_link" href="$machineSettings{URL_HELP}">Help</a>};
	$lowLeft  = qq{<a class="primer3plus_top_bar_link" href="$machineSettings{URL_ABOUT}">About</a>};
	$lowRight = qq{<a class="primer3plus_top_bar_link" href="$machineSettings{URL_SOURCE}">Source Code</a>};
	}	
		
	my $formHTML = qq{
<div id="primer3plus_top_bar">
   <table class="primer3plus_top_bar_table">
     <colgroup>
       <col width="60%" class="primer3plus_background">
       <col width="20%" class="primer3plus_background">
       <col width="20%" class="primer3plus_background">
     </colgroup>
     <tr>
       <td class="primer3plus_top_bar_cell" rowspan="2"><a class="primer3plus_top_bar_title">$title</a><br>
       <a class="primer3plus_top_bar_explain" id="top">$explain</a>
       </td>
       <td class="primer3plus_top_bar_cell">$topLeft
       </td>
       <td class="primer3plus_top_bar_cell">$topRight
       </td>
     </tr>
     <tr>
       <td class="primer3plus_top_bar_cell">$lowLeft
       </td>
       <td class="primer3plus_top_bar_cell">$lowRight
       </td>
     </tr>
   </table>
</div>

};
	return $formHTML;
}

###############################################
# divTaskBar: Writes the TaskBar for the Form #
###############################################
sub divTaskBar {
        my %settings;
	%settings = %{(shift)};

	my $formHTML = qq{
<div id="primer3plus_task_bar">
   <table class="primer3plus_table_no_border">
     <colgroup>
       <col width="25%">
       <col width="55%">

       <col width="20%">
     </colgroup>
	<tr>
	<td class="primer3plus_cell_no_border">
	
<input name="SCRIPT_RADIO_BUTTONS_FIX" id="SCRIPT_RADIO_BUTTONS_FIX" value="SCRIPT_CONTAINS_JAVA_SCRIPT,SCRIPT_DETECTION_PICK_LEFT,SCRIPT_DETECTION_PICK_HYB_PROBE,SCRIPT_DETECTION_PICK_RIGHT,SCRIPT_SEQUENCING_REVERSE,SCRIPT_DETECTION_USE_PRODUCT_SIZE,PRIMER_LIBERAL_BASE,SCRIPT_PRINT_INPUT,PRIMER_LIB_AMBIGUITY_CODES_CONSENSUS" type="hidden">

         <a id="SCRIPT_TASK_INPUT" name="SCRIPT_TASK_INPUT" href="$machineSettings{URL_HELP}#SCRIPT_TASK">
         Task:</a>&nbsp;
        <select id="SCRIPT_TASK" name="SCRIPT_TASK" class="primer3plus_task" onchange="showSelection(this);" onkeyup="showSelection(this)">
};

        my $option;
        foreach $option (@scriptTask) {
                my $selectedStatus = "";
                if ($option eq $settings{SCRIPT_TASK} ) {$selectedStatus = " selected=\"selected\"" };
                $formHTML .= "         <option class=\"primer3plus_task\"$selectedStatus>$option</option>\n";
        }

        $formHTML .= qq{         </select>
       </td>};

        $formHTML .= qq{
        <td class="primer3plus_cell_no_border_explain">
   <div id="primer3plus_explain_Detection"
        };

        if ($settings{SCRIPT_TASK} ne "Detection")  {
                $formHTML .= qq{style="display: none;" };
        }
$formHTML .= qq{>
     <a>Select primer pairs to detect the given template sequence. Optionally targets and included/excluded regions can be specified.</a>
   </div>
   <div id="primer3plus_explain_Cloning" };

        if ($settings{SCRIPT_TASK} ne "Cloning")  {
                $formHTML .= qq{style="display: none;" };
        }
$formHTML .= qq{>
     <a>Mark an included region to pick primers fixed at its the boundaries. The quality of the primers might be low.</a>
   </div>
   <div id="primer3plus_explain_Sequencing" };

        if ($settings{SCRIPT_TASK} ne "Sequencing")  {
                $formHTML .= qq{style="display: none;" };
        }
$formHTML .= qq{>
     <a>Pick a series of primers on both strands for sequencing. Optionally the regions of interest can be marked using targets.</a>
   </div>
   <div id="primer3plus_explain_Primer_List" };

        if ($settings{SCRIPT_TASK} ne "Primer_List")  {
                $formHTML .= qq{style="display: none;" };
        }
$formHTML .= qq{>
     <a>Returns a list of all possible primers the can be designed on the template sequence. Optionally targets and included/exlcuded regions can be specified.</a>
   </div>
   <div id="primer3plus_explain_Primer_Check" };

        if ($settings{SCRIPT_TASK} ne "Primer_Check")  {
                $formHTML .= qq{style="display: none;" };
        }
$formHTML .= qq{>
     <a>Evaluate a primer of known sequence with the given settings.</a>
   </div>
         </td><td class="primer3plus_cell_no_border" align="right">};

$formHTML .= divPickPrimerButton();

$formHTML .= qq{
        </td>
        </tr>
   </tbody></table>
</div>
};

	return $formHTML;
}

##############################################
# divActionButtons: Writes the Action Button #    
##############################################
sub divActionButtons {
	my $formHTML = qq{   
	<table>
           <tr>
                <td><input name="Pick_Primers" value="Pick Primers" type="submit" style="background: #83db7b; "></td><td><input value="Reset Form" type="reset"></td>
                <td><input name="Default_Settings" value="Reset Form" type="submit"></td>
           </tr>
        </table>
};
	return $formHTML;
}

#################################################
# divPickPrimerButton: Writes the Action Button #    
#################################################
sub divPickPrimerButton {
	my $formHTML = qq{   
	<table><tr>
	<td><input id="primer3plus_pick_primers_button" class="primer3plus_action_button" name="Pick_Primers" value="Pick Primers" type="submit" style="background: #83db7b;"></td>
	<td><input class="primer3plus_action_button" name="Default_Settings" value="Reset Form" type="submit"></td>
	</tr></table>
};
	return $formHTML;
}

###################################################
# divStatistics: Writes the Statistics in a table #    
###################################################
sub divStatistics {
	my %settings; 
    %settings = %{(shift)};
	
	my $formHTML;
	my $notEmpty;
	$notEmpty = 0;


$formHTML .= qq{  <div id="primer3plus_statictics" class="primer3plus_tab_page_no_border">
  <table class="primer3plus_table_with_border">
      <colgroup>
        <col width="20%">
        <col width="80%">
      </colgroup>
     <tr>
       <td class="primer3plus_cell_with_border" colspan="2">Statistics:</td>
     </tr>
};
if (defined ($settings{"PRIMER_LEFT_EXPLAIN"}) and (($settings{"PRIMER_LEFT_EXPLAIN"}) ne "")) {
$notEmpty = 1;
$formHTML .= qq{     <tr>
       <td class="primer3plus_cell_with_border">Left Primer:</td>
       <td class="primer3plus_cell_with_border">$settings{"PRIMER_LEFT_EXPLAIN"}</td>
     </tr>
};
}
if (defined ($settings{"PRIMER_INTERNAL_OLIGO_EXPLAIN"}) and (($settings{"PRIMER_INTERNAL_OLIGO_EXPLAIN"}) ne "")) {
$notEmpty = 1;
$formHTML .= qq{     <tr>
       <td class="primer3plus_cell_with_border">Internal Oligo:</td>
       <td class="primer3plus_cell_with_border">$settings{"PRIMER_INTERNAL_OLIGO_EXPLAIN"}</td>
     </tr>
};
}
if (defined ($settings{"PRIMER_RIGHT_EXPLAIN"}) and (($settings{"PRIMER_RIGHT_EXPLAIN"}) ne "")) {
$notEmpty = 1;
$formHTML .= qq{     <tr>
       <td class="primer3plus_cell_with_border">Right Primer:</td>
       <td class="primer3plus_cell_with_border">$settings{"PRIMER_RIGHT_EXPLAIN"}</td>
     </tr>
};
}
if (defined ($settings{"PRIMER_PAIR_EXPLAIN"}) and (($settings{"PRIMER_PAIR_EXPLAIN"}) ne "")) {
$notEmpty = 1;
$formHTML .= qq{     <tr>
       <td class="primer3plus_cell_with_border">Primer Pair:</td>
       <td class="primer3plus_cell_with_border">$settings{"PRIMER_PAIR_EXPLAIN"}</td>
     </tr>
};
}
$formHTML .= qq{  </table>
  </div>
};

if ($notEmpty == 0) {
$formHTML = "";
}
	 
	return $formHTML;
}


###############################################################################################
# createStartUpNoScript: Will write an HTML-Form based on the parameters in the Hash supplied #
###############################################################################################
sub createStartUpNoScript {
  my %settings; 
  %settings = %{(shift)};

  my $templateText = getWrapper();

  my $formHTML = qq{
<div id="primer3plus_complete">

<form action="$machineSettings{URL_FORM_ACTION}" method="post" enctype="multipart/form-data">
};

$formHTML .= divTopBar("Basic");

$formHTML .= divMessages();

$formHTML .= qq{
<div id="primer3plus_task" class="primer3plus_tab_page">
<input type="hidden" id="SCRIPT_RADIO_BUTTONS_FIX" name="SCRIPT_RADIO_BUTTONS_FIX"
value="SCRIPT_CONTAINS_JAVA_SCRIPT,SCRIPT_DETECTION_PICK_LEFT,SCRIPT_DETECTION_PICK_HYB_PROBE,SCRIPT_DETECTION_PICK_RIGHT,SCRIPT_SEQUENCING_REVERSE,SCRIPT_DETECTION_USE_PRODUCT_SIZE,PRIMER_LIBERAL_BASE,SCRIPT_PRINT_INPUT,PRIMER_LIB_AMBIGUITY_CODES_CONSENSUS">
   <table class="primer3plus_table_no_border">
     <colgroup>
       <col width="65%">
       <col width="35%">
     </colgroup>
     <tr>
       <td class="primer3plus_cell_no_border" valign="top">
         <a name="SCRIPT_TASK_INPUT" href="$machineSettings{URL_HELP}#SCRIPT_TASK">
         Please select the Task here:</a>&nbsp;&nbsp;        
         <select name="SCRIPT_TASK">
};

	my $option;
	foreach $option (@scriptTask) {
		my $selectedStatus = "";
		if ($option eq $settings{SCRIPT_TASK} ) {$selectedStatus = " selected=\"selected\"" };
		$formHTML .= "         <option$selectedStatus>$option</option>\n";
	} 	

        $formHTML .= qq{         </select>
       </td>
       <td class="primer3plus_cell_no_border" valign="top"><input name="SCRIPT_CONTAINS_JAVA_SCRIPT" value="0" type="hidden">
         <a name="SCRIPT_CONTAINS_JAVA_SCRIPT_INPUT" href="$machineSettings{URL_FORM_ACTION}?SCRIPT_CONTAINS_JAVA_SCRIPT=1">
         Go to Javascript version</a>
         <br>
       </td>
     </tr>
   </table>

   <table  class="primer3plus_table_no_border">
     <colgroup>
       <col width="20%">
       <col width="80%">
     </colgroup>
      <tr>
        <td class="primer3plus_cell_no_border_uli_bd">Detection:</td>
        <td class="primer3plus_cell_no_border">Pick primers anywhere in the Sequence using targets and regions.</td>
      </tr>
      <tr>
        <td class="primer3plus_cell_no_border_uli_bd">Cloning:</td>
        <td class="primer3plus_cell_no_border">Pick primers exactly at the border of included region.</td>
      </tr>
      <tr>
        <td class="primer3plus_cell_no_border_uli_bd">Sequencing:</td>
        <td class="primer3plus_cell_no_border">Pick primers for sequencing along the sequence using targets and regions</td>
      </tr>
      <tr>
        <td class="primer3plus_cell_no_border_uli_bd">Primer List:</td>
        <td class="primer3plus_cell_no_border"> Pick a list of primers along the sequence using targets and regions</td>
      </tr>
      <tr>
        <td class="primer3plus_cell_no_border_uli_bd">Primer Check:</td>
        <td class="primer3plus_cell_no_border">Check a primer provided in left primer input</td>
      </tr>
   </table>
<br>
</div>

<div id="primer3plus_sequence" class="primer3plus_tab_page">
   <table  class="primer3plus_table_no_border">
     <colgroup>
       <col width="45%">
       <col width="55%">
     </colgroup>
     <tr>
       <td class="primer3plus_cell_no_border">
         <a name="SEQUENCE_ID_INPUT" href="$machineSettings{URL_HELP}#SEQUENCE_ID">Sequence Id:</a>
         <input name="SEQUENCE_ID" value="$settings{SEQUENCE_ID}" type="text">
       </td>
       <td class="primer3plus_cell_no_border">
         <a name="PRIMER_MISPRIMING_LIBRARY_INPUT" href="$machineSettings{URL_HELP}#PRIMER_MISPRIMING_LIBRARY">
         Mispriming/Repeat Library:</a>
         <select name="PRIMER_MISPRIMING_LIBRARY">
};

	my $mishyb1;
	foreach $mishyb1 (@libraryList) {
		my $selectedStatus = "";
		if ($mishyb1 eq $settings{PRIMER_MISPRIMING_LIBRARY} ) {$selectedStatus = " selected=\"selected\"" };
		$formHTML .= "         <option$selectedStatus>$mishyb1</option>\n";
	} 	

        $formHTML .= qq{         </select>
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border">&nbsp;&nbsp;A name to identify your output.
       </td>
       <td class="primer3plus_cell_no_border">&nbsp;&nbsp;Or N-out undesirable sequence (vector, ALUs, LINEs...)
       </td>
     </tr>
   </table>
   <table class="primer3plus_table_no_border">
     <colgroup>
       <col width="100%">
     </colgroup>
     <tr>
       <td class="primer3plus_cell_no_border">
         <a name="SCRIPT_SEQUENCE_FILE_INPUT">To upload or save any sequence from your local computer, choose here:</a>
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border">
         <input name="SCRIPT_SEQUENCE_FILE" type="file">&nbsp;&nbsp;
	 <input name="Upload_File" value="Upload File" type="submit">&nbsp;&nbsp;&nbsp;
         <input name="Save_Sequence" value="Save Sequence" type="submit">&nbsp;&nbsp;
         <input name="Save_Settings" value="Save Settings" type="submit">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border">
         <a name="SEQUENCE_TEMPLATE_INPUT" href="$machineSettings{URL_HELP}#SEQUENCE_TEMPLATE">Paste source sequence below:</a>
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"> <textarea name="SEQUENCE_TEMPLATE" rows="6" cols="80">$settings{SEQUENCE_TEMPLATE}</textarea>
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border">&nbsp;&nbsp;5'-&gt;3', as ACGTNacgtn -- other letters treated as N --
         numbers and blanks ignored FASTA format ok.
       </td>
     </tr>
   </table>
   <table class="primer3plus_table_no_border">
     <colgroup>
       <col width="32%">
       <col width="32%">
       <col width="36%">
     </colgroup>
     <tr>
       <td class="primer3plus_cell_no_border_bg" valign="top">
         <input name="SCRIPT_DETECTION_PICK_LEFT" value="1" };

	$formHTML .= ($settings{SCRIPT_DETECTION_PICK_LEFT}) ? "checked=\"checked\" " : "";
 
	$formHTML .= qq{ type="checkbox"> Pick left primer<br>
         or use left primer below.
       </td>
       <td class="primer3plus_cell_no_border_bg" valign="top">
         <input name="SCRIPT_DETECTION_PICK_HYB_PROBE" value="1" };

	$formHTML .= ($settings{SCRIPT_DETECTION_PICK_HYB_PROBE}) ? "checked=\"checked\" " : "";
 
	$formHTML .= qq{type="checkbox">Pick hybridization probe<br>
         (internal oligo) or use oligo below.
       </td>
       <td class="primer3plus_cell_no_border_bg" valign="top">
         <input name="SCRIPT_DETECTION_PICK_RIGHT" value="1" };

	$formHTML .= ($settings{SCRIPT_DETECTION_PICK_RIGHT}) ? "checked=\"checked\" " : "";
 
	$formHTML .= qq{ type="checkbox">Pick right primer
         or use right primer<br>
         below (5'-&gt;3' on opposite strand).
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border_bg">&nbsp;&nbsp;<input size="30" name="SEQUENCE_PRIMER" value="$settings{SEQUENCE_PRIMER}" type="text">
       </td>
       <td class="primer3plus_cell_no_border_bg">&nbsp;&nbsp;<input size="30" name="SEQUENCE_INTERNAL_OLIGO" value="$settings{SEQUENCE_INTERNAL_OLIGO}"
         type="text">
       </td>
       <td class="primer3plus_cell_no_border_bg">&nbsp;&nbsp;<input size="30" name="SEQUENCE_PRIMER_REVCOMP" value="$settings{SEQUENCE_PRIMER_REVCOMP}" type="text">
       </td>
     </tr>
  </table>
  <br>
  <table class="primer3plus_table_no_border">
     <colgroup>
       <col width="20%">
       <col width="80%">
     </colgroup>
     <tr>
       <td class="primer3plus_cell_no_border">
         <a name="SEQUENCE_EXCLUDED_REGION_INPUT" href="$machineSettings{URL_HELP}#SEQUENCE_EXCLUDED_REGION">Excluded Regions:</a>
       </td>
       <td class="primer3plus_cell_no_border">&lt;&nbsp;<input size="40" name="SEQUENCE_EXCLUDED_REGION" value="$settings{SEQUENCE_EXCLUDED_REGION}" type="text">&nbsp;&gt;
       </td>
       </tr>
     <tr>
       <td class="primer3plus_cell_no_border" colspan="2">E.g. 401,7 68,3 forbids selection of primers in the 7 bases starting at 401 and the 3 bases at 68.
         Or mark the source sequence with &lt; and &gt;: e.g. ...ATCT&lt;CCCC&gt;TCAT.. forbids primers in the central CCCC.
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="SEQUENCE_TARGET_INPUT" href="$machineSettings{URL_HELP}#SEQUENCE_TARGET">Targets:</a>
       </td>
       <td class="primer3plus_cell_no_border">[&nbsp;<input size="40" name="SEQUENCE_TARGET" value="$settings{SEQUENCE_TARGET}" type="text" />&nbsp;]
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border" colspan="2">E.g. 50,2 requires primers to surround the 2 bases at positions 50 and 51. Or mark the
         source sequence with <br> [ and ]: e.g. ...ATCT[CCCC]TCAT.. means that primers must flank the central CCCC.
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="SEQUENCE_INCLUDED_REGION_INPUT" href="$machineSettings{URL_HELP}#SEQUENCE_INCLUDED_REGION">Included Region:</a>
       </td>
       <td class="primer3plus_cell_no_border">{&nbsp;<input size="40" name="SEQUENCE_INCLUDED_REGION" value="$settings{SEQUENCE_INCLUDED_REGION}" type="text">&nbsp;}
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border" colspan="2"> E.g. 20,400: only pick primers in the 400 base region starting at position 20. Or use
       { and } in the <br> source sequence to mark the beginning and end of the included region:<br>
       e.g. in ATC{TTC...TCT}AT the included region is TTC...TCT.
     </td>
     </tr>
  </table>
</div>
<div class="primer3plus_submit">

<br>

<input name="Pick_Primers" value="Pick Primers" type="submit"> <input value="Reset Form" type="reset">
<input name="Default_Settings" value="Default Settings" type="submit">

<br>
</div>

<div id="primer3plus_general_primer_picking" class="primer3plus_tab_page">
   <table class="primer3plus_table_no_border">
     <colgroup>
       <col width="100%">
     </colgroup>
      <tr>
      <td class="primer3plus_cell_no_border">
         <a name="SERVER_PARAMETER_FILE_INPUT" href="$machineSettings{URL_HELP}#SERVER_PARAMETER_FILE">
         Please select special settings here:</a>&nbsp;&nbsp;        
         <select name="SERVER_PARAMETER_FILE">
};

	my @ServerParameterFiles = getServerParameterFilesList;
	foreach $option (@ServerParameterFiles) {
		my $selectedStatus = "";
		if ($option eq $settings{SERVER_PARAMETER_FILE} ) {$selectedStatus = " selected=\"selected\"" };
		$formHTML .= "         <option$selectedStatus>$option</option>\n";
	} 	

        $formHTML .= qq{         </select>
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border" colspan="2"><a name="SCRIPT_SETTINGS_FILE_INPUT">To upload or save a settings file from
         your local computer, choose here:</a>
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border" colspan="2"><input name="SCRIPT_SETTINGS_FILE" type="file">&nbsp;&nbsp;
	 <input name="Activate_Settings" value="Activate Settings" type="submit">&nbsp;&nbsp;&nbsp;
         <input name="Save_Settings" value="Save Settings" type="submit">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border" colspan="2">
         <a name="PRIMER_PRODUCT_SIZE_RANGE_INPUT" href="$machineSettings{URL_HELP}#PRIMER_PRODUCT_SIZE_RANGE">
         Product Size Ranges</a>&nbsp;&nbsp;<input size="80" name="PRIMER_PRODUCT_SIZE_RANGE"
         value="$settings{PRIMER_PRODUCT_SIZE_RANGE}" type="text">
       </td>
     </tr>
   </table>

   <table class="primer3plus_table_no_border">
     <colgroup>
       <col width="18%">
       <col width="14%">
       <col width="14%">
       <col width="14%">
       <col width="40%">
     </colgroup>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="PRIMER_OPT_SIZE_INPUT" href="$machineSettings{URL_HELP}#PRIMER_SIZE">Primer Size</a>
       </td>
       <td class="primer3plus_cell_no_border">Min: <input size="4" name="PRIMER_MIN_SIZE" value="$settings{PRIMER_MIN_SIZE}" type="text">
       </td>
       <td class="primer3plus_cell_no_border">Opt: <input size="4" name="PRIMER_OPT_SIZE" value="$settings{PRIMER_OPT_SIZE}" type="text">
       </td>
       <td class="primer3plus_cell_no_border">Max: <input size="4" name="PRIMER_MAX_SIZE" value="$settings{PRIMER_MAX_SIZE}" type="text">
       </td>
       <td class="primer3plus_cell_no_border">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="PRIMER_OPT_TM_INPUT" href="$machineSettings{URL_HELP}#PRIMER_TM">Primer Tm</a>
       </td>
       <td class="primer3plus_cell_no_border">Min: <input size="4" name="PRIMER_MIN_TM" value="$settings{PRIMER_MIN_TM}" type="text">
       </td>
       <td class="primer3plus_cell_no_border">Opt: <input size="4" name="PRIMER_OPT_TM" value="$settings{PRIMER_OPT_TM}" type="text">
       </td>
       <td class="primer3plus_cell_no_border">Max: <input size="4" name="PRIMER_MAX_TM" value="$settings{PRIMER_MAX_TM}" type="text">
       </td>
       <td class="primer3plus_cell_no_border">&nbsp;&nbsp;&nbsp;&nbsp;
         <a name="PRIMER_PAIR_MAX_DIFF_TM_INPUT" href="$machineSettings{URL_HELP}#PRIMER_PAIR_MAX_DIFF_TM">
         Max Tm Difference:</a> <input size="4" name="PRIMER_PAIR_MAX_DIFF_TM"
         value="$settings{PRIMER_PAIR_MAX_DIFF_TM}" type="text">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="PRIMER_GC_PERCENT_INPUT" href="$machineSettings{URL_HELP}#PRIMER_GC_PERCENT">Primer GC%</a>
       </td>
       <td class="primer3plus_cell_no_border">Min: <input size="4" name="PRIMER_MIN_GC" value="$settings{PRIMER_MIN_GC}" type="text">
       </td>
       <td class="primer3plus_cell_no_border">Opt: <input size="4" name="PRIMER_OPT_GC_PERCENT" value="$settings{PRIMER_OPT_GC_PERCENT}" type="text">
       </td>
       <td class="primer3plus_cell_no_border">Max: <input size="4" name="PRIMER_MAX_GC" value="$settings{PRIMER_MAX_GC}" type="text">
       </td>
       <td class="primer3plus_cell_no_border">
       </td>
     </tr>
   </table>
   <table class="primer3plus_table_no_border">
     <colgroup>
       <col width="32%">
       <col width="18%">
       <col width="50%">
     </colgroup>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="PRIMER_SALT_MONOVALENT_INPUT" href="$machineSettings{URL_HELP}#PRIMER_SALT_MONOVALENT">Salt Concentration:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_SALT_MONOVALENT" value="$settings{PRIMER_SALT_MONOVALENT}" type="text">
       </td>
       <td class="primer3plus_cell_no_border"><a name="SCRIPT_FIX_PRIMER_END_INPUT" href="$machineSettings{URL_HELP}#SCRIPT_FIX_PRIMER_END">Fix the</a>
         <input size="2" name="SCRIPT_FIX_PRIMER_END" value="$settings{SCRIPT_FIX_PRIMER_END}" type="text">
         <a href="$machineSettings{URL_HELP}#SCRIPT_FIX_PRIMER_END"> prime end of the primer</a>
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="PRIMER_DNA_CONC_INPUT" href="$machineSettings{URL_HELP}#PRIMER_DNA_CONC">
         Annealing Oligo Concentration:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_DNA_CONC" value="$settings{PRIMER_DNA_CONC}" type="text">
       </td>
       <td class="primer3plus_cell_no_border" rowspan="2">Select which end of the primer is fixed and which end can be extended or shortened
         by Primer3Plus fo find optimal primers.
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border" colspan="2"><a name="PRIMER_DNA_CONC_INPUT" href="$machineSettings{URL_HELP}#PRIMER_DNA_CONC">
        (Not the concentration of oligos in the reaction mix<br>but of those annealing to template.)</a>
       </td>
     </tr>
   </table>
</div>

<div class="primer3plus_submit">
<br>

<input name="Pick_Primers" value="Pick Primers" type="submit"> <input value="Reset Form" type="reset">
<input name="Default_Settings" value="Default Settings" type="submit">

<br>
</div>

<div id="primer3plus_sequencing" class="primer3plus_tab_page">
   <h3> General Sequencing Conditions </h3>
   <table class="primer3plus_table_no_border">
     <colgroup>
       <col width="12%">
       <col width="4%">
       <col width="10%">
       <col width="74%">
     </colgroup>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="SCRIPT_SEQUENCING_LEAD_INPUT" href="$machineSettings{URL_HELP}#SCRIPT_SEQUENCING_LEAD">Lead</a>
       </td>
       <td class="primer3plus_cell_no_border">Bp:
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="SCRIPT_SEQUENCING_LEAD" value="$settings{SCRIPT_SEQUENCING_LEAD}" type="text">
       </td>
       <td class="primer3plus_cell_no_border">Space between primer binding site and the start of readable sequencing
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="SCRIPT_SEQUENCING_SPACING_INPUT" href="$machineSettings{URL_HELP}#SCRIPT_SEQUENCING_SPACING">
         Spacing</a>
       </td>
       <td class="primer3plus_cell_no_border">Bp: </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="SCRIPT_SEQUENCING_SPACING" value="$settings{SCRIPT_SEQUENCING_SPACING}" type="text">
       </td>
       <td class="primer3plus_cell_no_border">Space between the primers on one DNA strand
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="SCRIPT_SEQUENCING_ACCURACY_INPUT"
         href="$machineSettings{URL_HELP}#SCRIPT_SEQUENCING_ACCURACY">Accuracy</a>
       </td>
       <td class="primer3plus_cell_no_border">Bp:
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="SCRIPT_SEQUENCING_ACCURACY" value="$settings{SCRIPT_SEQUENCING_ACCURACY}" type="text">
       </td>
       <td class="primer3plus_cell_no_border">Space in which Primer3Plus picks the optimal primer
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border" colspan="3"><input name="SCRIPT_SEQUENCING_REVERSE" value="1" };

	$formHTML .= ($settings{SCRIPT_SEQUENCING_REVERSE}) ? "checked=\"checked\" " : "";
 
	$formHTML .= qq{type="checkbox">
         <a name="SCRIPT_SEQUENCING_REVERSE_INPUT" href="$machineSettings{URL_HELP}#SCRIPT_SEQUENCING_REVERSE">Pick Reverse Primers</a>
       </td>
       <td class="primer3plus_cell_no_border">Pick also primers on the reverse DNA strand</td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="SCRIPT_SEQUENCING_INTERVAL_INPUT" href="$machineSettings{URL_HELP}#SCRIPT_SEQUENCING_INTERVAL">
         Interval</a>
       </td>
       <td class="primer3plus_cell_no_border">Bp:
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="SCRIPT_SEQUENCING_INTERVAL" value="$settings{SCRIPT_SEQUENCING_INTERVAL}" type="text">
       </td>
       <td class="primer3plus_cell_no_border">Space between primers on the forward and the reverse strand
       </td>
     </tr> 
   </table>
</div>

<div class="primer3plus_submit">
<br>

<input name="Pick_Primers" value="Pick Primers" type="submit"> <input value="Reset Form" type="reset">
<input name="Default_Settings" value="Default Settings" type="submit">

<br>
</div>

<div id="primer3plus_advanced_primer_picking" class="primer3plus_tab_page">
   <table class="primer3plus_table_no_border">
     <colgroup>
       <col width="30%">
       <col width="15%">
       <col width="30%">
       <col width="25%">
     </colgroup>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="PRIMER_MAX_NS_ACCEPTED_INPUT" href="$machineSettings{URL_HELP}#PRIMER_MAX_NS_ACCEPTED">Max #N's:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_MAX_NS_ACCEPTED" value="$settings{PRIMER_MAX_NS_ACCEPTED}" type="text">
       </td>
       <td class="primer3plus_cell_no_border"><a name="PRIMER_MAX_POLY_X_INPUT" href="$machineSettings{URL_HELP}#PRIMER_MAX_POLY_X">Max Poly-X:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_MAX_POLY_X" value="$settings{PRIMER_MAX_POLY_X}" type="text">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="PRIMER_NUM_RETURN_INPUT" href="$machineSettings{URL_HELP}#PRIMER_NUM_RETURN">Number To Return:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_NUM_RETURN" value="$settings{PRIMER_NUM_RETURN}" type="text">
       </td>
       <td class="primer3plus_cell_no_border"><a name="PRIMER_GC_CLAMP_INPUT" href="$machineSettings{URL_HELP}#PRIMER_GC_CLAMP">CG Clamp:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_GC_CLAMP" value="$settings{PRIMER_GC_CLAMP}" type="text">
       </td>
    </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="PRIMER_MAX_SELF_ANY_INPUT" href="$machineSettings{URL_HELP}#PRIMER_MAX_SELF_ANY">Max Self Complementarity:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_MAX_SELF_ANY" value="$settings{PRIMER_MAX_SELF_ANY}" type="text">
       </td>
       <td class="primer3plus_cell_no_border"><a name="PRIMER_MAX_SELF_END_INPUT" href="$machineSettings{URL_HELP}#PRIMER_MAX_SELF_END">Max 3' Self Complementarity:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_MAX_SELF_END" value="$settings{PRIMER_MAX_SELF_END}" type="text">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"></td>
       <td class="primer3plus_cell_no_border"></td>
       <td class="primer3plus_cell_no_border"><a name="PRIMER_MAX_END_STABILITY_INPUT" href="$machineSettings{URL_HELP}#PRIMER_MAX_END_STABILITY">
         Max 3' Stability:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_MAX_END_STABILITY" value="$settings{PRIMER_MAX_END_STABILITY}" type="text">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"> <a name="PRIMER_MAX_LIBRARY_MISPRIMING_INPUT" href="$machineSettings{URL_HELP}#PRIMER_MAX_LIBRARY_MISPRIMING">Max Mispriming:</a>
       </td>
       <td class="primer3plus_cell_no_border"> <input size="4" name="PRIMER_MAX_LIBRARY_MISPRIMING" value="$settings{PRIMER_MAX_LIBRARY_MISPRIMING}" type="text">
       </td>
       <td class="primer3plus_cell_no_border"> <a name="PRIMER_PAIR_MAX_LIBRARY_MISPRIMING_INPUT" href="$machineSettings{URL_HELP}#PRIMER_PAIR_MAX_LIBRARY_MISPRIMING">
       Pair Max Mispriming:</a>
       </td>
       <td class="primer3plus_cell_no_border"> <input size="4" name="PRIMER_PAIR_MAX_LIBRARY_MISPRIMING" value="$settings{PRIMER_PAIR_MAX_LIBRARY_MISPRIMING}" type="text">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"> <a name="P3P_PRIMER_NAME_ACRONYM_LEFT_INPUT" href="$machineSettings{URL_HELP}#P3P_PRIMER_NAME_ACRONYM_LEFT">
       Left Primer Acronym:</a>
       </td>
       <td class="primer3plus_cell_no_border"> <input size="4" name="P3P_PRIMER_NAME_ACRONYM_LEFT" value="$settings{P3P_PRIMER_NAME_ACRONYM_LEFT}" type="text">
       </td>
       <td class="primer3plus_cell_no_border"> <a name="P3P_PRIMER_NAME_ACRONYM_INTERNAL_OLIGO_INPUT" href="$machineSettings{URL_HELP}#P3P_PRIMER_NAME_ACRONYM_INTERNAL_OLIGO">
       Internal Oligo Acronym:</a>
       </td>
       <td class="primer3plus_cell_no_border"> <input size="4" name="P3P_PRIMER_NAME_ACRONYM_INTERNAL_OLIGO" value="$settings{P3P_PRIMER_NAME_ACRONYM_INTERNAL_OLIGO}" type="text">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"> <a name="P3P_PRIMER_NAME_ACRONYM_RIGHT_INPUT" href="$machineSettings{URL_HELP}#P3P_PRIMER_NAME_ACRONYM_RIGHT">
       Right Primer Acronym:</a>
       </td>
       <td class="primer3plus_cell_no_border"> <input size="4" name="P3P_PRIMER_NAME_ACRONYM_RIGHT" value="$settings{P3P_PRIMER_NAME_ACRONYM_RIGHT}" type="text">
       </td>
       <td class="primer3plus_cell_no_border"> <a name="P3P_PRIMER_NAME_ACRONYM_SPACER_INPUT" href="$machineSettings{URL_HELP}#P3P_PRIMER_NAME_ACRONYM_SPACER">
       Primer Name Spacer:</a>
       </td>
       <td class="primer3plus_cell_no_border"> <input size="4" name="P3P_PRIMER_NAME_ACRONYM_SPACER" value="$settings{P3P_PRIMER_NAME_ACRONYM_SPACER}" type="text">
       </td>
     </tr>
   </table>
   <br>
   <table class="primer3plus_table_no_border">
     <colgroup>
       <col width="23%">
       <col width="16%">
       <col width="16%">
       <col width="16%">
       <col width="29%">
     </colgroup>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="PRIMER_PRODUCT_TM_INPUT" href="$machineSettings{URL_HELP}#PRIMER_PRODUCT_TM">Product Tm</a>
       </td>
       <td class="primer3plus_cell_no_border_right">Min: 
         <input size="6" name="PRIMER_PRODUCT_MIN_TM" value="$settings{PRIMER_PRODUCT_MIN_TM}" type="text">
       </td>
       <td class="primer3plus_cell_no_border_right">Opt: 
         <input size="6" name="PRIMER_PRODUCT_OPT_TM" value="$settings{PRIMER_PRODUCT_OPT_TM}" type="text">
       </td>
       <td class="primer3plus_cell_no_border_right">Max: 
         <input size="6" name="PRIMER_PRODUCT_MAX_TM" value="$settings{PRIMER_PRODUCT_MAX_TM}" type="text">
       </td>
       <td class="primer3plus_cell_no_border">
       </td>
     </tr>
   </table>
   <br>
   <table class="primer3plus_table_no_border">
     <colgroup>
       <col width="23%">
       <col width="16%">
       <col width="16%">
       <col width="16%">
       <col width="29%">
     </colgroup>
     <tr>
       <td class="primer3plus_cell_no_border" colspan="3">
         <input name="SCRIPT_DETECTION_USE_PRODUCT_SIZE"  value="1" };

	$formHTML .= ($settings{SCRIPT_DETECTION_USE_PRODUCT_SIZE}) ? "checked=\"checked\" " : "";
 
	$formHTML .= qq{type="checkbox">
         <a name="SCRIPT_DETECTION_USE_PRODUCT_SIZE_INPUT" href="$machineSettings{URL_HELP}#REVERSE">
         Use Product Size Input and ignore Product Size Range</a>
       </td>
       <td class="primer3plus_cell_no_border" colspan="2">Warning: slow and expensive!</td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border" colspan="5"><a>Select box to specify the min, opt, and max product sizes only if you absolutely must!<br>
         Using them is too slow (and too computationally intensive for our server).</a>
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="PRIMER_PRODUCT_SIZE_INPUT" href="primer3plusHelp.cgi#PRIMER_PRODUCT_SIZE">Product Size</a>
       </td>
       <td class="primer3plus_cell_no_border_right">Min: 
         <input size="6" name="SCRIPT_DETECTION_PRODUCT_MIN_SIZE" 
         value="$settings{SCRIPT_DETECTION_PRODUCT_MIN_SIZE}" type="text">
       </td>
       <td class="primer3plus_cell_no_border_right">Opt: 
         <input size="6" name="SCRIPT_DETECTION_PRODUCT_OPT_SIZE" 
         value="$settings{SCRIPT_DETECTION_PRODUCT_OPT_SIZE}" type="text">
       </td>
       <td class="primer3plus_cell_no_border_right">Max: 
         <input size="6" name="SCRIPT_DETECTION_PRODUCT_MAX_SIZE" 
         value="$settings{SCRIPT_DETECTION_PRODUCT_MAX_SIZE}" type="text">
       </td>
       <td class="primer3plus_cell_no_border">
       </td>
     </tr>
   </table>
   <br>
   <table class="primer3plus_table_no_border">
     <tr>
       <td class="primer3plus_cell_no_border"><input name="PRIMER_LIBERAL_BASE"  value="1" };

	$formHTML .= ($settings{PRIMER_LIBERAL_BASE}) ? "checked=\"checked\" " : "";
 
	$formHTML .= qq{type="checkbox">
         <a name="PRIMER_LIBERAL_BASE_INPUT" href="$machineSettings{URL_HELP}#PRIMER_LIBERAL_BASE">Liberal Base</a> </td>
       <td class="primer3plus_cell_no_border"><input name="SCRIPT_PRINT_INPUT"  value="1" };

	$formHTML .= ($settings{SCRIPT_PRINT_INPUT}) ? "checked=\"checked\" " : "";
 
	$formHTML .= qq{type="checkbox">
         <a name="SCRIPT_PRINT_INPUT_INPUT" href="$machineSettings{URL_HELP}#SCRIPT_PRINT_INPUT">Show Debuging Info</a> </td>
       <td class="primer3plus_cell_no_border"><input name="PRIMER_LIB_AMBIGUITY_CODES_CONSENSUS" value="1" };

	$formHTML .= ($settings{PRIMER_LIB_AMBIGUITY_CODES_CONSENSUS}) ? "checked=\"checked\" " : "";
 
	$formHTML .= qq{type="checkbox">Do not treat ambiguity codes in libraries as consensus </td>
     </tr>
   </table>
</div>

<div class="primer3plus_submit">
<br>

<input name="Pick_Primers" value="Pick Primers" type="submit"> <input value="Reset Form" type="reset">
<input name="Default_Settings" value="Default Settings" type="submit">

<br>
</div>

<div id="primer3plus_Internal_Oligo" class="primer3plus_tab_page">
   <table class="primer3plus_table_no_border">
     <colgroup>
       <col width="20%">
       <col width="15%">
       <col width="15%">
       <col width="15%">
       <col width="35%">
     </colgroup>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="PRIMER_INTERNAL_OLIGO_SIZE_INPUT" href="$machineSettings{URL_HELP}#PRIMER_SIZE">Hyb Oligo Size:</a>
       </td>
       <td class="primer3plus_cell_no_border">Min: <input size="4" name="PRIMER_INTERNAL_MIN_SIZE"
         value="$settings{PRIMER_INTERNAL_MIN_SIZE}" type="text">
       </td>
       <td class="primer3plus_cell_no_border">Opt: <input size="4" name="PRIMER_INTERNAL_OPT_SIZE"
         value="$settings{PRIMER_INTERNAL_OPT_SIZE}" type="text">
       </td>
       <td class="primer3plus_cell_no_border">Max: <input size="4" name="PRIMER_INTERNAL_MAX_SIZE"
         value="$settings{PRIMER_INTERNAL_MAX_SIZE}" type="text">
       </td>
       <td class="primer3plus_cell_no_border">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="PRIMER_OPT_TM_INPUT" href="$machineSettings{URL_HELP}#PRIMER_TM">Hyb Oligo Tm:</a> 
       </td>
       <td class="primer3plus_cell_no_border">Min: <input size="4" name="PRIMER_INTERNAL_MIN_TM"
         value="$settings{PRIMER_INTERNAL_MIN_TM}" type="text">
       </td>
       <td class="primer3plus_cell_no_border">Opt: <input size="4" name="PRIMER_INTERNAL_OPT_TM"
         value="$settings{PRIMER_INTERNAL_OPT_TM}" type="text"> 
       </td>
       <td class="primer3plus_cell_no_border">Max: <input size="4" name="PRIMER_INTERNAL_MAX_TM"
         value="$settings{PRIMER_INTERNAL_MAX_TM}" type="text">
       </td>
       <td class="primer3plus_cell_no_border">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="PRIMER_INTERNAL_OLIGO_GC_INPUT" href="$machineSettings{URL_HELP}#PRIMER_GC">Hyb Oligo GC%</a>
       </td>
       <td class="primer3plus_cell_no_border">Min: <input size="4" name="PRIMER_INTERNAL_MIN_GC"
         value="$settings{PRIMER_INTERNAL_MIN_GC}" type="text">
       </td>
       <td class="primer3plus_cell_no_border">Opt: <input size="4" name="PRIMER_INTERNAL_OPT_GC_PERCENT"
         value="$settings{PRIMER_INTERNAL_OPT_GC_PERCENT}" type="text">
       </td>
       <td class="primer3plus_cell_no_border">Max: <input size="4" name="PRIMER_INTERNAL_MAX_GC"
         value="$settings{PRIMER_INTERNAL_MAX_GC}" type="text">
       </td>
       <td class="primer3plus_cell_no_border">
       </td>
     </tr>
   </table>

   <table class="primer3plus_table_no_border">
     <colgroup>
       <col width="38%">
       <col width="12%">
       <col width="38%">
       <col width="12%">
     </colgroup>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="internal_oligo_generic_INPUT" href="$machineSettings{URL_HELP}#internal_oligo_generic">
         Hyb Oligo Salt Concentration:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_INTERNAL_SALT_MONOVALENT"
         value="$settings{PRIMER_INTERNAL_SALT_MONOVALENT}" type="text">
       </td>
       <td class="primer3plus_cell_no_border"><a name="internal_oligo_generic_INPUT" href="$machineSettings{URL_HELP}#internal_oligo_generic">
         Hyb Oligo DNA Concentration:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_INTERNAL_DNA_CONC"
         value="$settings{PRIMER_INTERNAL_DNA_CONC}" type="text">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="PRIMER_INTERNAL_MAX_NS_ACCEPTED_INPUT" href="$machineSettings{URL_HELP}#internal_oligo_generic">
         Max #Ns:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_INTERNAL_MAX_NS_ACCEPTED"
         value="$settings{PRIMER_INTERNAL_MAX_NS_ACCEPTED}" type="text">
       </td>
       <td class="primer3plus_cell_no_border"><a name="internal_oligo_generic_INPUT" href="$machineSettings{URL_HELP}#internal_oligo_generic">
         Hyb Oligo Max Poly-X:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_INTERNAL_MAX_POLY_X"
         value="$settings{PRIMER_INTERNAL_MAX_POLY_X}" type="text">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="internal_oligo_generic_INPUT" href="$machineSettings{URL_HELP}#internal_oligo_generic">
         Hyb Oligo Self Complementarity:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_INTERNAL_MAX_SELF_ANY"
         value="$settings{PRIMER_INTERNAL_MAX_SELF_ANY}" type="text">
       </td>
       <td class="primer3plus_cell_no_border"><a name="internal_oligo_generic_INPUT" href="$machineSettings{URL_HELP}#internal_oligo_generic">
         Hyb Oligo Max 3' Self Complementarity:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_INTERNAL_MAX_SELF_END"
         value="$settings{PRIMER_INTERNAL_MAX_SELF_END}" type="text">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="internal_oligo_generic_INPUT" href="$machineSettings{URL_HELP}#internal_oligo_generic">
         Hyb Oligo Max Mishyb:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_INTERNAL_MAX_LIBRARY_MISHYB"
         value="$settings{PRIMER_INTERNAL_MAX_LIBRARY_MISHYB}" type="text">
       </td>
       <td class="primer3plus_cell_no_border"><a name="internal_oligo_generic_INPUT" href="$machineSettings{URL_HELP}#internal_oligo_generic">
         Hyb Oligo Min Sequence Quality:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_INTERNAL_MIN_QUALITY"
         value="$settings{PRIMER_INTERNAL_MIN_QUALITY}" type="text">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="internal_oligo_generic_INPUT" href="$machineSettings{URL_HELP}#internal_oligo_generic">
         Hyb Oligo Mishyb Library:</a>
       </td>
       <td class="primer3plus_cell_no_border" colspan="3">
         <select name="PRIMER_INTERNAL_MISHYB_LIBRARY">
};

foreach $mishyb1 (@libraryList) {
	my $selectedStatus = "";
	if ($mishyb1 eq $settings{PRIMER_INTERNAL_MISHYB_LIBRARY} ) {$selectedStatus = " selected=\"selected\"" };
	$formHTML .= "         <option$selectedStatus>$mishyb1</option>\n";
} 	

$formHTML .= qq{         </select>
       </td>
     </tr>
   </table>
</div>

<div class="primer3plus_submit">
<br>

<input name="Pick_Primers" value="Pick Primers" type="submit"> <input value="Reset Form" type="reset">
<input name="Default_Settings" value="Default Settings" type="submit">

<br>
</div>

<div id="primer3plus_advanced_sequence" class="primer3plus_tab_page">
   <h4><a name="Internal_Oligo_Per_Sequence_Inputs">Hyb Oligo (Internal Oligo) Per-Sequence Inputs</a></h4>
   <table class="primer3plus_table_no_border">
     <colgroup>
       <col width="32%">
       <col width="68%">
     </colgroup>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="internal_oligo_generic_INPUT" href="$machineSettings{URL_HELP}#internal_oligo_generic">
         Hyb Oligo Excluded Region:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input name="SEQUENCE_INTERNAL_EXCLUDED_REGION"
         value="$settings{SEQUENCE_INTERNAL_EXCLUDED_REGION}" type="text">
       </td>
     </tr>
   </table>

   <h4> Other Per-Sequence Inputs </h4>

   <table class="primer3plus_table_no_border">
    <tr>
       <td class="primer3plus_cell_no_border"> <a name="PRIMER_FIRST_BASE_INDEX_INPUT" href="$machineSettings{URL_HELP}#PRIMER_FIRST_BASE_INDEX">
         First Base Index:</a>
       </td>
       <td class="primer3plus_cell_no_border"> <input size="4" name="PRIMER_FIRST_BASE_INDEX"
         value="$settings{PRIMER_FIRST_BASE_INDEX}" type="text">
       </td>
       <td class="primer3plus_cell_no_border"> <a name="SEQUENCE_QUALITY_INPUT" href="$machineSettings{URL_HELP}#SEQUENCE_QUALITY">
         Sequence Quality:</a>
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="SEQUENCE_START_CODON_POSITION_INPUT" href="$machineSettings{URL_HELP}#SEQUENCE_START_CODON_POSITION">
         Start Codon Position:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="SEQUENCE_START_CODON_POSITION"
         value="$settings{SEQUENCE_START_CODON_POSITION}" type="text">
       </td>
       <td class="primer3plus_cell_no_border" rowspan="5">
         <textarea rows="8" cols="40" name="SEQUENCE_QUALITY">$settings{SEQUENCE_QUALITY}</textarea>
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="PRIMER_MIN_QUALITY_INPUT" href="$machineSettings{URL_HELP}#PRIMER_MIN_QUALITY">
         Min Sequence Quality:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_MIN_QUALITY"
         value="$settings{PRIMER_MIN_QUALITY}" type="text">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="PRIMER_MIN_END_QUALITY_INPUT" href="$machineSettings{URL_HELP}#PRIMER_MIN_END_QUALITY">
         Min End Sequence Quality:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_MIN_END_QUALITY"
         value="$settings{PRIMER_MIN_END_QUALITY}" type="text">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="PRIMER_QUALITY_RANGE_MIN_INPUT" href="$machineSettings{URL_HELP}#PRIMER_QUALITY_RANGE_MIN">
         Sequence Quality Range Min:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_QUALITY_RANGE_MIN"
         value="$settings{PRIMER_QUALITY_RANGE_MIN}" type="text">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="PRIMER_QUALITY_RANGE_MAX_INPUT" href="$machineSettings{URL_HELP}#PRIMER_QUALITY_RANGE_MAX">
         Sequence Quality Range Max:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_QUALITY_RANGE_MAX"
         value="$settings{PRIMER_QUALITY_RANGE_MAX}" type="text">
       </td>
     </tr>
   </table>
</div>

<div class="primer3plus_submit">
<br>

<input name="Pick_Primers" value="Pick Primers" type="submit"> <input value="Reset Form" type="reset">
<input name="Default_Settings" value="Default Settings" type="submit">

<br>
</div>

<div id="area_penalties" class="primer3plus_tab_page">
   <table class="primer3plus_table_penalties">
     <colgroup>
       <col width="33%">
       <col width="34%">
       <col width="33%">
     </colgroup>
     <tr>
       <td class="primer3plus_cell_penalties">
       <h3>For Primers</h3>
       </td>
       <td class="primer3plus_cell_penalties">
       <h3>For Primer Pairs</h3>
       </td>
       <td class="primer3plus_cell_penalties">
       <h3>For Hyb Oligos</h3>
       </td>
     </tr>
   </table>
   <table class="primer3plus_table_penalties">
     <colgroup>
       <col width="10%">
       <col width="3%">
       <col width="8%">
       <col width="3%">
       <col width="9%">
       <col width="11%">
       <col width="3%">
       <col width="8%">
       <col width="3%">
       <col width="9%">
       <col width="10%">
       <col width="3%">
       <col width="8%">
       <col width="3%">
       <col width="9%">
     </colgroup>
     <tr>
       <td class="primer3plus_cell_penalties"><a name="WT_TM_INPUT" href="$machineSettings{URL_HELP}#generic_penalty_weights">Tm</a>
       </td>
       <td class="primer3plus_cell_penalties">Lt:
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_WT_TM_LT"
         value="$settings{PRIMER_WT_TM_LT}" type="text">
       </td>
       <td class="primer3plus_cell_penalties">Gt:
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_WT_TM_GT"
         value="$settings{PRIMER_WT_TM_GT}" type="text">
       </td>
       <td class="primer3plus_cell_penalties"><a name="PAIR_WT_PRODUCT_TM_INPUT" href="$machineSettings{URL_HELP}#generic_penalty_weights">Product Tm</a>
       </td>
       <td class="primer3plus_cell_penalties">Lt: 
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_PAIR_WT_PRODUCT_TM_LT"
         value="$settings{PRIMER_PAIR_WT_PRODUCT_TM_LT}" type="text"> 
       </td>
       <td class="primer3plus_cell_penalties">Gt:
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_PAIR_WT_PRODUCT_TM_GT"
         value="$settings{PRIMER_PAIR_WT_PRODUCT_TM_GT}" type="text">
       </td>
       <td class="primer3plus_cell_penalties"><a name="IO_WT_TM_INPUT" href="$machineSettings{URL_HELP}#generic_penalty_weights">Tm</a>
       </td>
       <td class="primer3plus_cell_penalties">Lt:
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_INTERNAL_WT_TM_LT"
         value="$settings{PRIMER_INTERNAL_WT_TM_LT}" type="text">
       </td>
       <td class="primer3plus_cell_penalties">Gt: 
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_INTERNAL_WT_TM_GT"
         value="$settings{PRIMER_INTERNAL_WT_TM_GT}" type="text">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_penalties"><a name="WT_SIZE_INPUT" href="$machineSettings{URL_HELP}#generic_penalty_weights">Size</a>
       </td>
       <td class="primer3plus_cell_penalties">Lt:
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_WT_SIZE_LT"
         value="$settings{PRIMER_WT_SIZE_LT}" type="text">
       </td>
       <td class="primer3plus_cell_penalties">Gt:
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_WT_SIZE_GT"
         value="$settings{PRIMER_WT_SIZE_GT}" type="text">
       </td>
       <td class="primer3plus_cell_penalties"><a name="PAIR_WT_PRODUCT_SIZE_INPUT" href="$machineSettings{URL_HELP}#generic_penalty_weights">Product Size</a>
       </td>
       <td class="primer3plus_cell_penalties">Lt: 
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_PAIR_WT_PRODUCT_SIZE_LT"
         value="$settings{PRIMER_PAIR_WT_PRODUCT_SIZE_LT}" type="text"> 
       </td>
       <td class="primer3plus_cell_penalties">Gt:
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_PAIR_WT_PRODUCT_SIZE_GT"
         value="$settings{PRIMER_PAIR_WT_PRODUCT_SIZE_GT}" type="text">
       </td>
       <td class="primer3plus_cell_penalties"><a name="IO_WT_SIZE_INPUT" href="$machineSettings{URL_HELP}#generic_penalty_weights">Size</a>
       </td>
       <td class="primer3plus_cell_penalties">Lt:
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_INTERNAL_WT_SIZE_LT"
         value="$settings{PRIMER_INTERNAL_WT_SIZE_LT}" type="text">
       </td>
       <td class="primer3plus_cell_penalties">Gt: 
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_INTERNAL_WT_SIZE_GT"
         value="$settings{PRIMER_INTERNAL_WT_SIZE_GT}" type="text">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_penalties"><a name="WT_GC_PERCENT_INPUT" href="$machineSettings{URL_HELP}#generic_penalty_weights">GC%</a> 
       </td>
       <td class="primer3plus_cell_penalties">Lt:
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_WT_GC_PERCENT_LT"
         value="$settings{PRIMER_WT_GC_PERCENT_LT}" type="text">
       </td>
       <td class="primer3plus_cell_penalties">Gt:
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_WT_GC_PERCENT_GT"
         value="$settings{PRIMER_WT_GC_PERCENT_GT}" type="text">
       </td>
       <td class="primer3plus_cell_penalties">
       </td>
       <td class="primer3plus_cell_penalties"> 
       </td>
       <td class="primer3plus_cell_penalties"> 
       </td>
       <td class="primer3plus_cell_penalties">
       </td>
       <td class="primer3plus_cell_penalties">
       </td>
       <td class="primer3plus_cell_penalties"><a name="IO_WT_GC_PERCENT_INPUT" href="$machineSettings{URL_HELP}#generic_penalty_weights">GC%</a>
       </td>
       <td class="primer3plus_cell_penalties">Lt:
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_INTERNAL_WT_GC_PERCENT_LT"
         value="$settings{PRIMER_INTERNAL_WT_GC_PERCENT_LT}" type="text">
       </td>
       <td class="primer3plus_cell_penalties">Gt: 
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_INTERNAL_WT_GC_PERCENT_GT"
         value="$settings{PRIMER_INTERNAL_WT_GC_PERCENT_GT}" type="text">
       </td>
     </tr>
   </table>
   <table class="primer3plus_table_penalties">
     <colgroup>
       <col width="24%">
       <col width="9%">
       <col width="25%">
       <col width="9%">
       <col width="24%">
       <col width="9%">
     </colgroup>
     <tr>
       <td class="primer3plus_cell_penalties"><a name="WT_REP_SIM_INPUT" href="$machineSettings{URL_HELP}#generic_penalty_weights">Mispriming</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_PAIR_WT_LIBRARY_MISPRIMING"
         value="$settings{PRIMER_PAIR_WT_LIBRARY_MISPRIMING}" type="text">
       </td>
       <td class="primer3plus_cell_penalties"><a name="PAIR_WT_REP_SIM_INPUT" href="$machineSettings{URL_HELP}#generic_penalty_weights">Pair Mispriming</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_PAIR_WT_LIBRARY_MISPRIMING"
         value="$settings{PRIMER_PAIR_WT_LIBRARY_MISPRIMING}" type="text">
       </td>
       <td class="primer3plus_cell_penalties"><a name="IO_WT_REP_SIM_INPUT" href="$machineSettings{URL_HELP}#generic_penalty_weights">Hyb Oligo Mishybing</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_INTERNAL_WT_LIBRARY_MISHYB"
         value="$settings{PRIMER_INTERNAL_WT_LIBRARY_MISHYB}" type="text">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_penalties"><a name="WT_COMPL_ANY_INPUT" href="$machineSettings{URL_HELP}#generic_penalty_weights">Self Complementarity</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_WT_SELF_ANY"
         value="$settings{PRIMER_WT_SELF_ANY}" type="text">
       </td>
       <td class="primer3plus_cell_penalties"><a name="PAIR_WT_COMPL_ANY_INPUT" href="$machineSettings{URL_HELP}#generic_penalty_weights">
         Self Complementarity</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_PAIR_WT_COMPL_ANY"
         value="$settings{PRIMER_PAIR_WT_COMPL_ANY}" type="text">
       </td>
       <td class="primer3plus_cell_penalties"><a name="IO_WT_COMPL_ANY_INPUT" href="$machineSettings{URL_HELP}#generic_penalty_weights">
         Self Complementarity</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_INTERNAL_WT_SELF_ANY"
         value="$settings{PRIMER_INTERNAL_WT_SELF_ANY}" type="text">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_penalties"><a name="WT_COMPL_END_INPUT" href="$machineSettings{URL_HELP}#generic_penalty_weights">3' Complementarity</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_WT_SELF_END"
         value="$settings{PRIMER_WT_SELF_END}" type="text">
       </td>
       <td class="primer3plus_cell_penalties"><a name="PAIR_WT_COMPL_END_INPUT" href="$machineSettings{URL_HELP}#generic_penalty_weights">3' Complementarity</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_PAIR_WT_COMPL_END"
         value="$settings{PRIMER_PAIR_WT_COMPL_END}" type="text">
       </td>
       <td class="primer3plus_cell_penalties">
       </td>
       <td class="primer3plus_cell_penalties">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_penalties"><a name="WT_NUM_NS_INPUT" href="$machineSettings{URL_HELP}#generic_penalty_weights">#N's</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_WT_NUM_NS"
         value="$settings{PRIMER_WT_NUM_NS}" type="text">
       </td>
       <td class="primer3plus_cell_penalties">
       </td>
       <td class="primer3plus_cell_penalties">
       </td>
       <td class="primer3plus_cell_penalties"><a name="IO_WT_NUM_NS_INPUT" href="$machineSettings{URL_HELP}#generic_penalty_weights">Hyb Oligo #N's</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_INTERNAL_WT_NUM_NS"
         value="$settings{PRIMER_INTERNAL_WT_NUM_NS}" type="text">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_penalties"><a name="WT_SEQ_QUAL_INPUT" href="$machineSettings{URL_HELP}#generic_penalty_weights">Sequence Quality</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_WT_SEQ_QUAL"
         value="$settings{PRIMER_WT_SEQ_QUAL}" type="text">
       </td>
       <td class="primer3plus_cell_penalties">
       </td>
       <td class="primer3plus_cell_penalties">
       </td>
       <td class="primer3plus_cell_penalties"><a name="IO_WT_SEQ_QUAL_INPUT" href="$machineSettings{URL_HELP}#generic_penalty_weights">Sequence Quality</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_INTERNAL_WT_SEQ_QUAL"
         value="$settings{PRIMER_INTERNAL_WT_SEQ_QUAL}" type="text">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_penalties"><a name="WT_END_QUAL_INPUT" href="$machineSettings{URL_HELP}#generic_penalty_weights">End Sequence Quality</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_WT_END_QUAL"
         value="$settings{PRIMER_WT_END_QUAL}" type="text">
       </td>
       <td class="primer3plus_cell_penalties">
       </td>
       <td class="primer3plus_cell_penalties">
       </td>
       <td class="primer3plus_cell_penalties">
       </td>
       <td class="primer3plus_cell_penalties">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_penalties"><a name="WT_POS_PENALTY_INPUT" href="$machineSettings{URL_HELP}#generic_penalty_weights">Position Penalty</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_WT_POS_PENALTY"
         value="$settings{PRIMER_WT_POS_PENALTY}" type="text">
       </td>
       <td class="primer3plus_cell_penalties"><a name="PAIR_WT_DIFF_TM_INPUT" href="$machineSettings{URL_HELP}#generic_penalty_weights">Tm Difference</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_PAIR_WT_DIFF_TM"
         value="$settings{PRIMER_PAIR_WT_DIFF_TM}" type="text">
       </td>
       <td class="primer3plus_cell_penalties">
       </td>
       <td class="primer3plus_cell_penalties">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_penalties"><a name="WT_END_STABILITY_INPUT" href="$machineSettings{URL_HELP}#generic_penalty_weights">End Stability</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_WT_END_STABILITY"
         value="$settings{PRIMER_WT_END_STABILITY}" type="text">
       </td>
       <td class="primer3plus_cell_penalties"><a name="PAIR_WT_PR_PENALTY_INPUT" href="$machineSettings{URL_HELP}#generic_penalty_weights">
         Primer Penalty Weight</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_PAIR_WT_PR_PENALTY"
         value="$settings{PRIMER_PAIR_WT_PR_PENALTY}" type="text">
       </td>
       <td class="primer3plus_cell_penalties">
       </td>
       <td class="primer3plus_cell_penalties">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_penalties"><a name="PRIMER_INSIDE_PENALTY_INPUT" href="$machineSettings{URL_HELP}#PRIMER_INSIDE_PENALTY">
         Inside Target Penalty:</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_INSIDE_PENALTY"
         value="$settings{PRIMER_INSIDE_PENALTY}" type="text">
       </td>
       <td class="primer3plus_cell_penalties"><a name="PAIR_WT_IO_PENALTY_INPUT" href="$machineSettings{URL_HELP}#generic_penalty_weights">
         Hyb Oligo Penalty Weight</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_PAIR_WT_IO_PENALTY"
         value="$settings{PRIMER_PAIR_WT_IO_PENALTY}" type="text">
       </td>
       <td class="primer3plus_cell_penalties">
       </td>
       <td class="primer3plus_cell_penalties">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_penalties"><a name="PRIMER_OUTSIDE_PENALTY_INPUT" href="$machineSettings{URL_HELP}#PRIMER_OUTSIDE_PENALTY">
         Outside Target Penalty:</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_OUTSIDE_PENALTY"
         value="$settings{PRIMER_OUTSIDE_PENALTY}" type="text">
       </td>
       <td class="primer3plus_cell_penalties">
       </td>
       <td class="primer3plus_cell_penalties">
       </td>
       <td class="primer3plus_cell_penalties">
       </td>
       <td class="primer3plus_cell_penalties">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_penalties" colspan="2"><a name="PRIMER_INSIDE_PENALTY_INPUT" href="$machineSettings{URL_HELP}#PRIMER_INSIDE_PENALTY">
         Set Inside Target Penalty to allow primers inside a target. </a>
       </td>
       <td class="primer3plus_cell_penalties">
       </td>
       <td class="primer3plus_cell_penalties">
       </td>
       <td class="primer3plus_cell_penalties">
       </td>
       <td class="primer3plus_cell_penalties">
       </td>
     </tr>
   </table>
</div>

<div class="primer3plus_submit">
<br>

<input name="Pick_Primers" value="Pick Primers" type="submit"> <input value="Reset Form" type="reset">
<input name="Default_Settings" value="Default Settings" type="submit">

<br>

</div>

<div id="primer3plus_footer" class="primer3plus_tab_page">
<br>

More about <a href="$machineSettings{URL_ABOUT}">Primer3Plus</a>...

</div>

</form>

</div>	
};

  my $returnString = $templateText;

  $returnString =~ s/<!-- Primer3plus will include code here -->/$formHTML/;

  return $returnString;
}

################################################################################################
# createStartUpUseScript: Will write an HTML-Form based on the parameters in the Hash supplied #
################################################################################################
sub createStartUpUseScript {
  my %settings; 
  %settings = %{(shift)};

  my $templateText = getWrapper();

  my $formHTML = qq{

<DIV id=toolTipLayer style="VISIBILITY: hidden; POSITION: absolute; z-index: 1">will be replace by tooltip text
</DIV>  	

<SCRIPT language=JavaScript>
var prevTabPage = "primer3plus_primer";
var prevTab = "tab1";

function showTab(tab,id) {
        if (id == "" || !document.getElementById(id)) {
                return;
        }
        if (prevTabPage != "" && document.getElementById(prevTabPage)) {
                document.getElementById(prevTabPage).style.display="none";
                document.getElementById(prevTab).style.background="white";
                document.getElementById(prevTab).style.top="0";
                document.getElementById(prevTab).style.zIndex="0";
        }
        if (tab != "" && document.getElementById(tab)) {
                document.getElementById(tab).style.background="rgb(255, 255, 230)";
                document.getElementById(tab).style.position="relative";
                document.getElementById(tab).style.top="2px";
                document.getElementById(tab).style.zIndex="1";
                prevTab = tab;
        }
        document.getElementById(id).style.display="inline";
        prevTabPage = id;
}

var prevSelectedid = "";
var prevSequence = 0;
var prevSequencing = 0;

function showSelection(selector) {
        x = selector.selectedIndex;
        id = "primer3plus_explain_" + selector.options[x].text
        showTopic(id);
}

function showTopic(id) {
    if (prevSelectedid != "" && document.getElementById(prevSelectedid)) {
        document.getElementById(prevSelectedid).style.display="none";
    }
    if (id != "" && document.getElementById(id)) {
        prevSelectedid = id;
        document.getElementById(id).style.display="inline";
		document.getElementById("primer3plus_pick_primers_button").value = "Pick Primers";

        if (id == "primer3plus_explain_Primer_Check") {
			setSelection("inline","none","none","none","none","none")
			document.getElementById("primer3plus_pick_primers_button").value = "Check Primer";             
        } else if (id == "primer3plus_explain_Detection") {
             setSelection("none","inline","inline","inline","inline","inline");
        } else if (id == "primer3plus_explain_Sequencing") {
             setSelection("none","inline","none","inline","none","none");
        } else if (id == "primer3plus_explain_Cloning") {
             setSelection("none","inline","none","none","inline","none");
        } else if (id == "primer3plus_explain_Primer_List") {
             setSelection("none","inline","inline","inline","none","none");
        }
    }
}

function setSelection(primer_only_state,sequenceState,excludedState,targetState,includedState,pickwhichState) {
        document.getElementById("primer3plus_primer_only").style.display=primer_only_state;
        document.getElementById("primer3plus_sequence").style.display=sequenceState;
        document.getElementById("primer3plus_excluded_region_box").style.display=excludedState;
        document.getElementById("primer3plus_excluded_region_button").style.display=excludedState;
        document.getElementById("primer3plus_target_region_box").style.display=targetState;
        document.getElementById("primer3plus_target_region_button").style.display=targetState;
        document.getElementById("primer3plus_included_region_box").style.display=includedState;
        document.getElementById("primer3plus_included_region_button").style.display=includedState;
        document.getElementById("primer3plus_pick_which").style.display=pickwhichState;
}

function selectSequencing() {
        var seqId = -1;
        var selector = document.getElementById('SCRIPT_TASK');
        for (var i = 0; i < selector.length; i++) {
                if (selector.options[i].text == 'Sequencing') {
                        seqId = i;
                }
        }
        if (seqId > -1) {
                document.getElementById('SCRIPT_TASK').options[seqId].selected='true';
                showSelection(document.getElementById('SCRIPT_TASK'));
        }
}

function updateSequence() {
    document.getElementById("SEQUENCE_PRIMER").value = document.getElementById("SEQUENCE_PRIMER_SCRIPT").value;  
}

function updatePrimer() {
    document.getElementById("SEQUENCE_PRIMER_SCRIPT").value = document.getElementById("SEQUENCE_PRIMER").value;  
}
};

my $primerSelected = 1;

if ( $settings{SCRIPT_TASK} eq "Primer_Check" ) {
    $primerSelected = 0;
}

$formHTML .= qq{
var ns4 = document.layers;
var ns6 = document.getElementById && !document.all;
var ie4 = document.all;
var offsetX = 0;
var offsetY = 20;
var toolTipSTYLE="";
var FG='fg';
var BG='bg';
var TEXTCOLOR='tc';
var WIDTH='tw';
var HEIGHT='th';
var FONT='font';
var fg, bg, tc, tw, th, font = 0;

function initToolTips() {
	if (ns4||ns6||ie4) {
		if (ns4) {
			toolTipSTYLE = document.toolTipLayer;
		} else if (ns6) {
			toolTipSTYLE = document.getElementById("toolTipLayer").style;
		} else if (ie4) {
			 toolTipSTYLE = document.all.toolTipLayer.style;
		}
	
		if (ns4) {
			document.captureEvents(Event.MOUSEMOVE);
		} else {
			toolTipSTYLE.visibility = "visible";
			toolTipSTYLE.display = "none";
		}
		document.onmousemove = moveToMouseLoc;
	}
}

function toolTip() {
	if(arguments.length < 1) { // hide
		if (ns4) {
			toolTipSTYLE.visibility = "hidden";
		} else {
			 toolTipSTYLE.display = "none";
		}
	} else { // show
		var msg = arguments[0];
		fg = "#666666";
		bg = "#EAEAFF";
		tc = "#000000";
		font = "Verdana,Arial,Helvetica";
		var content =
			'<table border="0" cellspacing="0" cellpadding="1" bgcolor="' + fg + '" width="' + tw + '" height="' + th + '"><td>' +
			'<table border="0" cellspacing="0" cellpadding="1" bgcolor="' + bg + '" width="' + tw + '" height="' + th + '">';
		content += '<td><font face="' + font + '" color="' + tc + '" size="-2">' + msg + '</font></td>';
		content += '</table></td></table>';
		if (ns4) {
			toolTipSTYLE.document.write(content);
			toolTipSTYLE.document.close();
			toolTipSTYLE.visibility = "visible";
		}
		else if (ns6) {
			//moveToMouseLoc(document);
			document.getElementById("toolTipLayer").innerHTML = content;
			toolTipSTYLE.display='block';
		}
		else if (ie4) {
			//moveToMouseLoc();
			document.all("toolTipLayer").innerHTML=content;
			toolTipSTYLE.display='block';
		}
	}
}

function moveToMouseLoc(e) {
	if (ns4||ns6) {
		x = e.pageX;
		y = e.pageY;
		if (tw && (x + offsetX + Number(tw) + 10 > window.innerWidth)) {
			x = window.innerWidth - offsetX - Number(tw) - 10;
		}
	} else {
		x = event.x + document.body.scrollLeft;
		y = event.y + document.body.scrollTop;
		if (tw && (x + offsetX + Number(tw) + 30 > document.body.offsetWidth)) {
			x = document.body.offsetWidth - offsetX - Number(tw) - 30;
		}
	}
	toolTipSTYLE.left = (x + offsetX) + "px";
	toolTipSTYLE.top = (y + offsetY) + "px";
	return true;
}

initToolTips();

function clearMarking() {
        var txtarea = document.mainForm.sequenceTextarea;
        txtarea.value = txtarea.value.replace(/[{}<>[\\]]/g,"");
        document.getElementById("SEQUENCE_INCLUDED_REGION").value="";
        document.getElementById("SEQUENCE_EXCLUDED_REGION").value="";
        document.getElementById("SEQUENCE_TARGET").value="";                
}

function setRegion(tagOpen,tagClose) {
        var txtarea = document.mainForm.sequenceTextarea;
        if (document.selection && document.selection.type == 'Text') {
                var theSelection = document.selection.createRange().text;
                txtarea.focus();
                if (theSelection.length > 0) {
                        document.selection.createRange().text = tagOpen + theSelection + tagClose;
                }
                document.selection.empty();
        // Mozilla
        } else if(txtarea.selectionStart || txtarea.selectionStart == '0') {
                var replaced = false;
                var startPos = txtarea.selectionStart;
                var endPos = txtarea.selectionEnd;
                if (endPos-startPos)
                        replaced = true;
                var scrollTop = txtarea.scrollTop;
                var myText = (txtarea.value).substring(startPos, endPos);
                if (myText.length < 1) {
                        return;
                }
                subst = tagOpen + myText + tagClose;

                txtarea.value = txtarea.value.substring(0, startPos) + subst +
                        txtarea.value.substring(endPos, txtarea.value.length);
                txtarea.focus();
                //set new selection
                if (replaced) {
                        var cPos = startPos+(tagOpen.length+myText.length+tagClose.length);
                        txtarea.selectionStart = cPos;
                        txtarea.selectionEnd = cPos;
                } else {
                        txtarea.selectionStart = startPos+tagOpen.length;
                        txtarea.selectionEnd = startPos+tagOpen.length+myText.length;
                }
                txtarea.scrollTop = scrollTop;
        }
}
</SCRIPT>  	
  	
  	
<div id="primer3plus_complete">

<form name="mainForm" action="$machineSettings{URL_FORM_ACTION}" method="post" enctype="multipart/form-data" onReset="initTabs();">
};

$formHTML .= divTopBar("Basic");
$formHTML .= divTaskBar(\%settings);
$formHTML .= divNoJavascript();
$formHTML .= divMessages();


        $formHTML .= qq{  
<div id="menuBar">
        <ul>
        <li id="tab1"><a onclick="showTab('tab1','primer3plus_primer')">Main</a></li>
        <li id="tab2"><a onclick="showTab('tab2','primer3plus_general_primer_picking')">General Settings</a></li>
        <li id="tab3"><a onclick="showTab('tab3','primer3plus_advanced_primer_picking')">Advanced Settings</a></li>
        <li id="tab4"><a onclick="showTab('tab4','primer3plus_Internal_Oligo')">Internal Oligo</a></li>
        <li id="tab5"><a onclick="showTab('tab5','primer3plus_penalties')">Penalty Weights</a></li>
        <li id="tab6"><a onclick="showTab('tab6','primer3plus_advanced_sequence')">Sequence Quality</a></li>
        </ul>
</div>

<div id="primer3plus_primer" class="primer3plus_tab_page">

<div id="primer3plus_name_lib">
   <table class="primer3plus_table_no_border">
     <colgroup>
       <col width="45%">
       <col width="55%">
     </colgroup>
     <tr>
       <td class="primer3plus_cell_no_border">
         <a onmouseover="toolTip('A name to identify your output.');" onmouseout="toolTip();" 
         name="SEQUENCE_ID_INPUT" href="$machineSettings{URL_HELP}#SEQUENCE_ID">Sequence Id:</a>
         <input name="SEQUENCE_ID" value="$settings{SEQUENCE_ID}" type="text">
       </td>
     </tr>
   </table>
</div>

<div id="primer3plus_primer_only" };

	if ($settings{SCRIPT_TASK} ne "Primer_Check")  {
		$formHTML .= qq{style="display: none;" };
	} 	
$formHTML .= qq{>
    <table class="primer3plus_table_no_border">
     <colgroup>
       <col width="32%">
     </colgroup>
     <tr>
       <td class="primer3plus_cell_no_border_bg" valign="top">
         Primer to test:
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border_bg">&nbsp;&nbsp;<input size="30" id="SEQUENCE_PRIMER_SCRIPT" name="SEQUENCE_PRIMER_SCRIPT" 
          value="$settings{SEQUENCE_PRIMER}" type="text" onblur="updateSequence();" onchange="updateSequence();" onkeyup="updateSequence();">
       </td>
     </tr>
  </table>
};

$formHTML .= qq{</div>

<div id="primer3plus_sequence" };

	if ($settings{SCRIPT_TASK} eq "Primer_Check")  {
		$formHTML .= qq{style="display: none;" };
	} 	
my $sequence = $settings{SEQUENCE_TEMPLATE};
$sequence =~ s/(\w{80})/$1\n/g;
$formHTML .= qq{>
   <table class="primer3plus_table_no_border">
     <tr>
       <td class="primer3plus_cell_no_border" valign="bottom">
         <a onmouseover="toolTip('5 -&gt;3 , as ACGTNacgtn -- other letters treated as N -- numbers and blanks ignored FASTA format ok.');"
         onmouseout="toolTip();" name="SEQUENCE_TEMPLATE_INPUT" href="$machineSettings{URL_HELP}#SEQUENCE_TEMPLATE">Paste source sequence below</a>
       </td>
       <td class="primer3plus_cell_no_border" valign="bottom">
         <a name="SCRIPT_SEQUENCE_FILE_INPUT">Or upload sequence file:</a>
         <input name="SCRIPT_SEQUENCE_FILE" type="file">&nbsp;&nbsp;
	 <input name="Upload_File" value="Upload File" type="submit">&nbsp;&nbsp;&nbsp;
       </td>
     </tr>
     <tr>
       <td colspan=2 class="primer3plus_cell_no_border"> <textarea name="SEQUENCE_TEMPLATE" id="sequenceTextarea" rows="12" cols="90">$sequence</textarea>
       </td>
	</tr>
   </table>
   <table class="primer3plus_table_no_border">
	<tr>
       <td class="primer3plus_cell_no_border">
	<table>
	<tr>
       <td class="primer3plus_cell_no_border">
	Mark selected region:
	</td>
       <td class="primer3plus_cell_no_border">
                        <div id="primer3plus_excluded_region_button">
			<input type=button name="excludedRegion" onclick="setRegion('<','>');return false;" value ="&lt; &gt;"
				onmouseover="toolTip('Excluded Region');"  onmouseout="toolTip();">
			</div>
                        <div id="primer3plus_target_region_button">
                        <input type=button name="targetRegion" onclick="setRegion('[',']');return false;" value="[ ]"
				onmouseover="toolTip('Targets Region');"  onmouseout="toolTip();">
			</div>
                        <div id="primer3plus_included_region_button">
                        <input type=button name="includedRegion" onclick="setRegion('{','}');return false;" value="{ }"
				onmouseover="toolTip('Included Region');"  onmouseout="toolTip();">
			</div>
       </td>
       <td class="primer3plus_cell_no_border">
                        <div id="primer3plus_clear_markings_button">
                        <input type=button name="clearMarkings" onclick="clearMarking();return false;" value="Clear">
			</div>
       </td>
	     </tr>
	   </table>
       </td>
       <td class="primer3plus_cell_no_border">
         <input name="Save_Sequence" value="Save Sequence" type="submit">
       </td>
     </tr>
   </table>
  <br>
<div id="primer3plus_excluded_region_box">
  <table class="primer3plus_table_no_border">
     <colgroup>
       <col width="20%">
       <col width="2%">
       <col width="78%">
     </colgroup>
     <tr>
       <td class="primer3plus_cell_no_border">
         <a onmouseover="toolTip('Primer oligos may not overlap any region specified in this tag. The associated value must be a space-separated list of start,length.<br>E.g. 401,7 68,3 forbids selection of primers in the 7 bases starting at 401 and the 3 bases at 68.<br> Or mark the source sequence with &lt; and &gt;:<br> e.g. ...ATCT&amp;lt;CCCC&amp;gt;TCAT.. forbids primers in the central CCCC.');"
         onmouseout="toolTip();" name="SEQUENCE_EXCLUDED_REGION_INPUT" href="$machineSettings{URL_HELP}#SEQUENCE_EXCLUDED_REGION">Excluded Regions:</a>
       </td>
       <td class="primer3plus_cell_no_border">&lt;
       </td>
       <td class="primer3plus_cell_no_border"><input size="40" id="SEQUENCE_EXCLUDED_REGION" name="SEQUENCE_EXCLUDED_REGION" value="$settings{SEQUENCE_EXCLUDED_REGION}" type="text">&nbsp;&gt;
       </td>
     </tr>
  </table>
</div>
<div id="primer3plus_target_region_box">
  <table class="primer3plus_table_no_border">
     <colgroup>
       <col width="20%">
       <col width="2%">
       <col width="78%">
     </colgroup>
     <tr>
       <td class="primer3plus_cell_no_border"><a onmouseover="toolTip('If one or more Targets is specified then a legal primer pair must flank at least one of them. The value should be a space-separated list of start,length pairs.<br>E.g. 50,2 requires primers to surround the 2 bases at positions 50 and 51.<br> Or mark the source sequence with [ and ]: e.g. ...ATCT[CCCC]TCAT..<br> means that primers must flank the central CCCC.');"
         onmouseout="toolTip();" name="SEQUENCE_TARGET_INPUT" href="$machineSettings{URL_HELP}#SEQUENCE_TARGET">Targets:</a>
       </td>
       <td class="primer3plus_cell_no_border">[
       </td>
       <td class="primer3plus_cell_no_border"><input size="40" id="SEQUENCE_TARGET" name="SEQUENCE_TARGET" value="$settings{SEQUENCE_TARGET}" type="text" />&nbsp;]
       </td>
     </tr>
  </table>
</div>
<div id="primer3plus_included_region_box">
  <table class="primer3plus_table_no_border">
     <colgroup>
       <col width="20%">
       <col width="2%">
       <col width="78%">
     </colgroup>
     <tr>
       <td class="primer3plus_cell_no_border"><a onmouseover="toolTip('A sub-region of the given sequence in which to pick primers. For example, often the first dozen or so bases of a sequence are vector, and should be excluded from consideration.<br>The value for this parameter has the form start,length.<br>E.g. 20,400: only pick primers in the 400 base region starting at position 20.<br> Or use { and } in the source sequence to mark the beginning and end of the included<br> region: e.g. in ATC{TTC...TCT}AT the included region is TTC...TCT.');"
         onmouseout="toolTip();"  name="SEQUENCE_INCLUDED_REGION_INPUT" href="$machineSettings{URL_HELP}#SEQUENCE_INCLUDED_REGION">Included Region:</a>
       </td>
       <td class="primer3plus_cell_no_border">{
       </td>
       <td class="primer3plus_cell_no_border"><input size="40" id="SEQUENCE_INCLUDED_REGION" name="SEQUENCE_INCLUDED_REGION" value="$settings{SEQUENCE_INCLUDED_REGION}" type="text">&nbsp;}
       </td>
     </tr>
  </table>
</div>
<br>
<div id="primer3plus_pick_which">
   <table class="primer3plus_table_no_border">
     <colgroup>
       <col width="32%">
       <col width="32%">
       <col width="36%">
     </colgroup>
     <tr>
       <td class="primer3plus_cell_no_border_bg" valign="top">
         <input id="SCRIPT_DETECTION_PICK_LEFT" name="SCRIPT_DETECTION_PICK_LEFT" value="1" };

	$formHTML .= ($settings{SCRIPT_DETECTION_PICK_LEFT}) ? "checked=\"checked\" " : "";
 
	$formHTML .= qq{ type="checkbox">Pick left primer<br>
         or use left primer below.
       </td>
       <td class="primer3plus_cell_no_border_bg" valign="top">
         <input id="SCRIPT_DETECTION_PICK_HYB_PROBE" name="SCRIPT_DETECTION_PICK_HYB_PROBE" value="1" };

	$formHTML .= ($settings{SCRIPT_DETECTION_PICK_HYB_PROBE}) ? "checked=\"checked\" " : "";
 
	$formHTML .= qq{type="checkbox">Pick hybridization probe<br>
         (internal oligo) or use oligo below.
       </td>
       <td class="primer3plus_cell_no_border_bg" valign="top">
         <input id="SCRIPT_DETECTION_PICK_RIGHT" name="SCRIPT_DETECTION_PICK_RIGHT" value="1" };

	$formHTML .= ($settings{SCRIPT_DETECTION_PICK_RIGHT}) ? "checked=\"checked\" " : "";
 
	$formHTML .= qq{ type="checkbox">Pick right primer
         or use right primer<br>
         below (5'-&gt;3' on opposite strand).
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border_bg">&nbsp;&nbsp;<input size="30" id="SEQUENCE_PRIMER" name="SEQUENCE_PRIMER" value="$settings{SEQUENCE_PRIMER}" type="text" onchange="updatePrimer();" onkeyup="updatePrimer();">
       </td>
       <td class="primer3plus_cell_no_border_bg">&nbsp;&nbsp;<input size="30" id="SEQUENCE_INTERNAL_OLIGO" name="SEQUENCE_INTERNAL_OLIGO" value="$settings{SEQUENCE_INTERNAL_OLIGO}"
         type="text">
       </td>
       <td class="primer3plus_cell_no_border_bg">&nbsp;&nbsp;<input size="30" id="SEQUENCE_PRIMER_REVCOMP" name="SEQUENCE_PRIMER_REVCOMP" value="$settings{SEQUENCE_PRIMER_REVCOMP}" type="text">
       </td>
     </tr>
  </table>
</div>
};

$formHTML .= qq{</div>
</div>
<div id="primer3plus_advanced_sequence" style="display: none;" class="primer3plus_tab_page">
   <table class="primer3plus_table_no_border">
    <tr>
       <td class="primer3plus_cell_no_border"> <a name="PRIMER_FIRST_BASE_INDEX_INPUT" href="$machineSettings{URL_HELP}#PRIMER_FIRST_BASE_INDEX">
         First Base Index:</a>
       </td>
       <td class="primer3plus_cell_no_border"> <input size="4" name="PRIMER_FIRST_BASE_INDEX"
         value="$settings{PRIMER_FIRST_BASE_INDEX}" type="text">
       </td>
       <td class="primer3plus_cell_no_border"> <a name="SEQUENCE_QUALITY_INPUT" href="$machineSettings{URL_HELP}#SEQUENCE_QUALITY">
         Sequence Quality:</a>
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="SEQUENCE_START_CODON_POSITION_INPUT" href="$machineSettings{URL_HELP}#SEQUENCE_START_CODON_POSITION">
         Start Codon Position:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="SEQUENCE_START_CODON_POSITION"
         value="$settings{SEQUENCE_START_CODON_POSITION}" type="text">
       </td>
       <td class="primer3plus_cell_no_border" rowspan="5">
         <textarea rows="8" cols="40" name="SEQUENCE_QUALITY">$settings{SEQUENCE_QUALITY}</textarea>
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="PRIMER_MIN_QUALITY_INPUT" href="$machineSettings{URL_HELP}#PRIMER_MIN_QUALITY">
         Min Sequence Quality:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_MIN_QUALITY"
         value="$settings{PRIMER_MIN_QUALITY}" type="text">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="PRIMER_MIN_END_QUALITY_INPUT" href="$machineSettings{URL_HELP}#PRIMER_MIN_END_QUALITY">
         Min End Sequence Quality:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_MIN_END_QUALITY"
         value="$settings{PRIMER_MIN_END_QUALITY}" type="text">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="PRIMER_QUALITY_RANGE_MIN_INPUT" href="$machineSettings{URL_HELP}#PRIMER_QUALITY_RANGE_MIN">
         Sequence Quality Range Min:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_QUALITY_RANGE_MIN"
         value="$settings{PRIMER_QUALITY_RANGE_MIN}" type="text">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="PRIMER_QUALITY_RANGE_MAX_INPUT" href="$machineSettings{URL_HELP}#PRIMER_QUALITY_RANGE_MAX">
         Sequence Quality Range Max:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_QUALITY_RANGE_MAX"
         value="$settings{PRIMER_QUALITY_RANGE_MAX}" type="text">
       </td>
     </tr>
   </table>
};

$formHTML .= qq{</div>

<div id="primer3plus_general_primer_picking" class="primer3plus_tab_page" style="display: none;">
   <table class="primer3plus_table_no_border">
     <tr>
       <td class="primer3plus_cell_no_border">
         <a name="PRIMER_PRODUCT_SIZE_RANGE_INPUT" href="$machineSettings{URL_HELP}#PRIMER_PRODUCT_SIZE_RANGE">
         Product Size Ranges</a>&nbsp;&nbsp;<input size="80" name="PRIMER_PRODUCT_SIZE_RANGE"
         value="$settings{PRIMER_PRODUCT_SIZE_RANGE}" type="text">
       </td>
     </tr>
   </table>
	<br>
  <div class="primer3plus_section">
   <table class="primer3plus_table_no_border">
     <colgroup>
       <col width="18%">
       <col width="14%">
       <col width="14%">
       <col width="14%">
       <col width="40%">
     </colgroup>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="PRIMER_OPT_SIZE_INPUT" href="$machineSettings{URL_HELP}#PRIMER_SIZE">Primer Size</a>
       </td>
       <td class="primer3plus_cell_no_border">Min: <input size="4" name="PRIMER_MIN_SIZE" value="$settings{PRIMER_MIN_SIZE}" type="text">
       </td>
       <td class="primer3plus_cell_no_border">Opt: <input size="4" name="PRIMER_OPT_SIZE" value="$settings{PRIMER_OPT_SIZE}" type="text">
       </td>
       <td class="primer3plus_cell_no_border">Max: <input size="4" name="PRIMER_MAX_SIZE" value="$settings{PRIMER_MAX_SIZE}" type="text">
       </td>
       <td class="primer3plus_cell_no_border">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="PRIMER_OPT_TM_INPUT" href="$machineSettings{URL_HELP}#PRIMER_TM">Primer Tm</a>
       </td>
       <td class="primer3plus_cell_no_border">Min: <input size="4" name="PRIMER_MIN_TM" value="$settings{PRIMER_MIN_TM}" type="text">
       </td>
       <td class="primer3plus_cell_no_border">Opt: <input size="4" name="PRIMER_OPT_TM" value="$settings{PRIMER_OPT_TM}" type="text">
       </td>
       <td class="primer3plus_cell_no_border">Max: <input size="4" name="PRIMER_MAX_TM" value="$settings{PRIMER_MAX_TM}" type="text">
       </td>
       <td class="primer3plus_cell_no_border">&nbsp;&nbsp;&nbsp;&nbsp;
         <a name="PRIMER_PAIR_MAX_DIFF_TM_INPUT" href="$machineSettings{URL_HELP}#PRIMER_PAIR_MAX_DIFF_TM">
         Max Tm Difference:</a> <input size="4" name="PRIMER_PAIR_MAX_DIFF_TM"
         value="$settings{PRIMER_PAIR_MAX_DIFF_TM}" type="text">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="PRIMER_GC_PERCENT_INPUT" href="$machineSettings{URL_HELP}#PRIMER_GC_PERCENT">Primer GC%</a>
       </td>
       <td class="primer3plus_cell_no_border">Min: <input size="4" name="PRIMER_MIN_GC" value="$settings{PRIMER_MIN_GC}" type="text">
       </td>
       <td class="primer3plus_cell_no_border">Opt: <input size="4" name="PRIMER_OPT_GC_PERCENT" value="$settings{PRIMER_OPT_GC_PERCENT}" type="text">
       </td>
       <td class="primer3plus_cell_no_border">Max: <input size="4" name="PRIMER_MAX_GC" value="$settings{PRIMER_MAX_GC}" type="text">
       </td>
       <td class="primer3plus_cell_no_border">&nbsp;&nbsp;&nbsp;&nbsp;<a onmouseover="toolTip('Select which end of the primer is fixed and which end can be extended or shortened by Primer3Plus fo find optimal primers.');"
         onmouseout="toolTip();" name="SCRIPT_FIX_PRIMER_END_INPUT" href="$machineSettings{URL_HELP}#SCRIPT_FIX_PRIMER_END">Fix the</a>
         <input size="2" name="SCRIPT_FIX_PRIMER_END" value="$settings{SCRIPT_FIX_PRIMER_END}" type="text">
         <a href="$machineSettings{URL_HELP}#SCRIPT_FIX_PRIMER_END"> prime end of the primer</a>
       </td>
     </tr>
   </table>
   <table class="primer3plus_table_no_border">
     <colgroup>
       <col width="30%">
       <col width="10%">
       <col width="25%">
       <col width="10%">
       <col width="25%">
     </colgroup>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="PRIMER_SALT_MONOVALENT_INPUT" href="$machineSettings{URL_HELP}#PRIMER_SALT_MONOVALENT">Concentration of monovalent cations:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_SALT_MONOVALENT" value="$settings{PRIMER_SALT_MONOVALENT}" type="text">
       </td>
       <td class="primer3plus_cell_no_border"><a onmouseover="toolTip('Not the concentration of oligos in the reaction mix<br>but of those annealing to template.');"
         onmouseout="toolTip();" name="PRIMER_DNA_CONC_INPUT" href="$machineSettings{URL_HELP}#PRIMER_DNA_CONC">
         Annealing Oligo Concentration:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_DNA_CONC" value="$settings{PRIMER_DNA_CONC}" type="text">
       </td>
       <td class="primer3plus_cell_no_border">&nbsp;
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="PRIMER_SALT_DIVALENT_INPUT" href="$machineSettings{URL_HELP}#PRIMER_SALT_DIVALENT">Concentration of divalent cations:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_SALT_DIVALENT" value="$settings{PRIMER_SALT_DIVALENT}" type="text">
       </td>
       <td class="primer3plus_cell_no_border"><a name="PRIMER_DNTP_CONC_INPUT" href="$machineSettings{URL_HELP}#PRIMER_DNTP_CONC_CONC">Concentration of dNTPs:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_DNTP_CONC" value="$settings{PRIMER_DNTP_CONC}" type="text">
       </td>
       <td class="primer3plus_cell_no_border">&nbsp;
       </td>
     </tr>
   </table>
  </div>
<br>
   <table class="primer3plus_table_no_border">
     <colgroup>
       <col width="100%">
     </colgroup>
      <tbody><tr>
       <td class="primer3plus_cell_no_border">
         <a onmouseover="toolTip('Or N-out undesirable sequence (vector, ALUs, LINEs...)');" onmouseout="toolTip();"
         name="PRIMER_MISPRIMING_LIBRARY_INPUT" href="$machineSettings{URL_HELP}#PRIMER_MISPRIMING_LIBRARY">
         Mispriming/Repeat Library:</a>
         <select name="PRIMER_MISPRIMING_LIBRARY">
};

	my $mishyb1;
	foreach $mishyb1 (@libraryList) {
		my $selectedStatus = "";
		if ($mishyb1 eq $settings{PRIMER_MISPRIMING_LIBRARY} ) {$selectedStatus = " selected=\"selected\"" };
		$formHTML .= "         <option$selectedStatus>$mishyb1</option>\n";
	} 	

        $formHTML .= qq{         </select>
       </td>
     </tr>
   </table>
};

$formHTML .= qq{
<br>
<div id="primer3plus_save_and_load" class="primer3plus_section">
   <b>Load and Save</b>
   <table class="primer3plus_table_no_border">
     <colgroup>
       <col width="100%">
     </colgroup>
      <tbody><tr>
      <td class="primer3plus_cell_no_border">
         <a name="SERVER_PARAMETER_FILE_INPUT" href="$machineSettings{URL_HELP}#SERVER_PARAMETER_FILE">
         Please select special settings here:</a>&nbsp;&nbsp;
         <select name="SERVER_PARAMETER_FILE">
};

        my @ServerParameterFiles = getServerParameterFilesList;
	my $option;
        foreach $option (@ServerParameterFiles) {
                my $selectedStatus = "";
                if ($option eq $settings{SERVER_PARAMETER_FILE} ) {$selectedStatus = " selected=\"selected\"" };
                $formHTML .= "         <option$selectedStatus>$option</option>\n";
        }

        $formHTML .= qq{         </select>&nbsp;(use Activate Settings button to load the selected settings)
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="SCRIPT_SETTINGS_FILE_INPUT">To upload or save a settings file from
         your local computer, choose here:</a>
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><input name="SCRIPT_SETTINGS_FILE" type="file">&nbsp;&nbsp;
             <input name="Activate_Settings" value="Activate Settings" type="submit">&nbsp;&nbsp;&nbsp;
         <input name="Save_Settings" value="Save Settings" type="submit">
       </td>
     </tr>
     </tbody>	
     </table>
</div>

};

$formHTML .= qq{</div>
<div id="primer3plus_advanced_primer_picking" class="primer3plus_tab_page" style="display: none;">
   <table class="primer3plus_table_no_border">
     <colgroup>
       <col width="25%">
       <col width="15%">
       <col width="30%">
       <col width="35%">
     </colgroup>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="PRIMER_MAX_POLY_X_INPUT" href="$machineSettings{URL_HELP}#PRIMER_MAX_POLY_X">Max Poly-X:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_MAX_POLY_X" value="$settings{PRIMER_MAX_POLY_X}" type="text">
       </td>
       <td class="primer3plus_cell_no_border">
         <a name="PRIMER_TM_FORMULA_INPUT" href="$machineSettings{URL_HELP}#PRIMER_TM_FORMULA">
         Table of thermodynamic parameters:</a>
       </td>
       <td class="primer3plus_cell_no_border">         
         <select name="PRIMER_TM_FORMULA">
};
		if ( $settings{PRIMER_TM_FORMULA} == 1 ) {
     		$formHTML .= qq{           <option value="0">Breslauer et al. 1986</option>
           <option selected="selected" value="1">SantaLucia 1998</option>
};
		}
		else {
			$formHTML .= qq{           <option selected="selected" value="0">Breslauer et al. 1986</option>
           <option value="1">SantaLucia 1998</option>
};		
		};

        $formHTML .= qq{         </select>
       </td>         
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="PRIMER_MAX_NS_ACCEPTED_INPUT" href="$machineSettings{URL_HELP}#PRIMER_MAX_NS_ACCEPTED">Max #N's:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_MAX_NS_ACCEPTED" value="$settings{PRIMER_MAX_NS_ACCEPTED}" type="text">
       </td>
       <td class="primer3plus_cell_no_border">
         <a name="PRIMER_SALT_CORRECTIONS" href="$machineSettings{URL_HELP}#PRIMER_SALT_CORRECTIONS">
         Salt correction formula:</a>
       </td>
       <td class="primer3plus_cell_no_border">         
         <select name="PRIMER_SALT_CORRECTIONS">
};
		if ( $settings{PRIMER_SALT_CORRECTIONS} == 1 ) {
     		$formHTML .= qq{                      <option value="0"> Schildkraut and Lifson 1965</option>
           <option selected="selected" value="1">SantaLucia 1998</option>
           <option value="2">Owczarzy et. 2004</option>
};
		}
		elsif ( $settings{PRIMER_SALT_CORRECTIONS} == 2 ) {
     		$formHTML .= qq{                      <option value="0"> Schildkraut and Lifson 1965</option>
           <option value="1">SantaLucia 1998</option>
           <option selected="selected" value="2">Owczarzy et. 2004</option>
};
		}
		else {
			$formHTML .= qq{                      <option selected="selected" value="0"> Schildkraut and Lifson 1965</option>
           <option value="1">SantaLucia 1998</option>
           <option value="2">Owczarzy et. 2004</option>
};		
		};

        $formHTML .= qq{         </select>
       </td>         
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="PRIMER_NUM_RETURN_INPUT" href="$machineSettings{URL_HELP}#PRIMER_NUM_RETURN">Number To Return:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_NUM_RETURN" value="$settings{PRIMER_NUM_RETURN}" type="text">
       </td>
       <td class="primer3plus_cell_no_border"><a name="PRIMER_GC_CLAMP_INPUT" href="$machineSettings{URL_HELP}#PRIMER_GC_CLAMP">CG Clamp:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_GC_CLAMP" value="$settings{PRIMER_GC_CLAMP}" type="text">
       </td>
    </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="PRIMER_MAX_SELF_ANY_INPUT" href="$machineSettings{URL_HELP}#PRIMER_MAX_SELF_ANY">Max Self Complementarity:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_MAX_SELF_ANY" value="$settings{PRIMER_MAX_SELF_ANY}" type="text">
       </td>
       <td class="primer3plus_cell_no_border"><a name="PRIMER_MAX_SELF_END_INPUT" href="$machineSettings{URL_HELP}#PRIMER_MAX_SELF_END">Max 3' Self Complementarity:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_MAX_SELF_END" value="$settings{PRIMER_MAX_SELF_END}" type="text">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"></td>
       <td class="primer3plus_cell_no_border"></td>
       <td class="primer3plus_cell_no_border"><a name="PRIMER_MAX_END_STABILITY_INPUT" href="$machineSettings{URL_HELP}#PRIMER_MAX_END_STABILITY">
         Max 3' Stability:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_MAX_END_STABILITY" value="$settings{PRIMER_MAX_END_STABILITY}" type="text">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"> <a name="PRIMER_MAX_LIBRARY_MISPRIMING_INPUT" href="$machineSettings{URL_HELP}#PRIMER_MAX_LIBRARY_MISPRIMING">Max Repeat Mispriming:</a>
       </td>
       <td class="primer3plus_cell_no_border"> <input size="4" name="PRIMER_MAX_LIBRARY_MISPRIMING" value="$settings{PRIMER_MAX_LIBRARY_MISPRIMING}" type="text">
       </td>
       <td class="primer3plus_cell_no_border"> <a name="PRIMER_PAIR_MAX_LIBRARY_MISPRIMING_INPUT" href="$machineSettings{URL_HELP}#PRIMER_PAIR_MAX_LIBRARY_MISPRIMING">
       Pair Max Repeat Mispriming:</a>
       </td>
       <td class="primer3plus_cell_no_border"> <input size="4" name="PRIMER_PAIR_MAX_LIBRARY_MISPRIMING" value="$settings{PRIMER_PAIR_MAX_LIBRARY_MISPRIMING}" type="text">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"> <a name="PRIMER_MAX_TEMPLATE_MISPRIMING_INPUT" href="$machineSettings{URL_HELP}#PRIMER_MAX_TEMPLATE_MISPRIMING">Max Template Mispriming:</a>
       </td>
       <td class="primer3plus_cell_no_border"> <input size="4" name="PRIMER_MAX_TEMPLATE_MISPRIMING" value="$settings{PRIMER_MAX_TEMPLATE_MISPRIMING}" type="text">
       </td>
       <td class="primer3plus_cell_no_border"> <a name="PRIMER_PAIR_MAX_TEMPLATE_MISPRIMING_INPUT" href="$machineSettings{URL_HELP}#PRIMER_PAIR_MAX_TEMPLATE_MISPRIMING">
       Pair Max Template Mispriming:</a>
       </td>
       <td class="primer3plus_cell_no_border"> <input size="4" name="PRIMER_PAIR_MAX_TEMPLATE_MISPRIMING" value="$settings{PRIMER_PAIR_MAX_TEMPLATE_MISPRIMING}" type="text">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"> <a name="P3P_PRIMER_NAME_ACRONYM_LEFT_INPUT" href="$machineSettings{URL_HELP}#P3P_PRIMER_NAME_ACRONYM_LEFT">
       Left Primer Acronym:</a>
       </td>
       <td class="primer3plus_cell_no_border"> <input size="4" name="P3P_PRIMER_NAME_ACRONYM_LEFT" value="$settings{P3P_PRIMER_NAME_ACRONYM_LEFT}" type="text">
       </td>
       <td class="primer3plus_cell_no_border"> <a name="P3P_PRIMER_NAME_ACRONYM_INTERNAL_OLIGO_INPUT" href="$machineSettings{URL_HELP}#P3P_PRIMER_NAME_ACRONYM_INTERNAL_OLIGO">
       Internal Oligo Acronym:</a>
       </td>
       <td class="primer3plus_cell_no_border"> <input size="4" name="P3P_PRIMER_NAME_ACRONYM_INTERNAL_OLIGO" value="$settings{P3P_PRIMER_NAME_ACRONYM_INTERNAL_OLIGO}" type="text">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"> <a name="P3P_PRIMER_NAME_ACRONYM_RIGHT_INPUT" href="$machineSettings{URL_HELP}#P3P_PRIMER_NAME_ACRONYM_RIGHT">
       Right Primer Acronym:</a>
       </td>
       <td class="primer3plus_cell_no_border"> <input size="4" name="P3P_PRIMER_NAME_ACRONYM_RIGHT" value="$settings{P3P_PRIMER_NAME_ACRONYM_RIGHT}" type="text">
       </td>
       <td class="primer3plus_cell_no_border"> <a name="P3P_PRIMER_NAME_ACRONYM_SPACER_INPUT" href="$machineSettings{URL_HELP}#P3P_PRIMER_NAME_ACRONYM_SPACER">
       Primer Name Spacer:</a>
       </td>
       <td class="primer3plus_cell_no_border"> <input size="4" name="P3P_PRIMER_NAME_ACRONYM_SPACER" value="$settings{P3P_PRIMER_NAME_ACRONYM_SPACER}" type="text">
       </td>
     </tr>
   </table>
   <br>
   <table class="primer3plus_table_no_border">
     <colgroup>
       <col width="23%">
       <col width="16%">
       <col width="16%">
       <col width="16%">
       <col width="29%">
     </colgroup>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="PRIMER_PRODUCT_TM_INPUT" href="$machineSettings{URL_HELP}#PRIMER_PRODUCT_TM">Product Tm</a>
       </td>
       <td class="primer3plus_cell_no_border_right">Min: 
         <input size="6" name="PRIMER_PRODUCT_MIN_TM" value="$settings{PRIMER_PRODUCT_MIN_TM}" type="text">
       </td>
       <td class="primer3plus_cell_no_border_right">Opt: 
         <input size="6" name="PRIMER_PRODUCT_OPT_TM" value="$settings{PRIMER_PRODUCT_OPT_TM}" type="text">
       </td>
       <td class="primer3plus_cell_no_border_right">Max: 
         <input size="6" name="PRIMER_PRODUCT_MAX_TM" value="$settings{PRIMER_PRODUCT_MAX_TM}" type="text">
       </td>
       <td class="primer3plus_cell_no_border">
       </td>
     </tr>
   </table>
   <br>
<div class="primer3plus_section">
   <table class="primer3plus_table_no_border">
     <colgroup>
       <col width="23%">
       <col width="16%">
       <col width="16%">
       <col width="16%">
       <col width="29%">
     </colgroup>
     <tr>
       <td class="primer3plus_cell_no_border" colspan="3">
         <input name="SCRIPT_DETECTION_USE_PRODUCT_SIZE"  value="1" };

	$formHTML .= ($settings{SCRIPT_DETECTION_USE_PRODUCT_SIZE}) ? "checked=\"checked\" " : "";
 
	$formHTML .= qq{type="checkbox">
         <a onmouseover="toolTip('Select box to specify the min, opt, and max product sizes only if you absolutely must!<br>Using them is too slow (and too computationally intensive for our server).');" onmouseout="toolTip();" name="SCRIPT_DETECTION_USE_PRODUCT_SIZE_INPUT" href="$machineSettings{URL_HELP}#REVERSE">
         Use Product Size Input and ignore Product Size Range</a>
       </td>
       <td class="primer3plus_cell_no_border" colspan="2">Warning: slow and expensive!</td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="PRIMER_PRODUCT_SIZE_INPUT" href="primer3plusHelp.cgi#PRIMER_PRODUCT_SIZE">Product Size</a>
       </td>
       <td class="primer3plus_cell_no_border_right">Min: 
         <input size="6" name="SCRIPT_DETECTION_PRODUCT_MIN_SIZE" 
         value="$settings{SCRIPT_DETECTION_PRODUCT_MIN_SIZE}" type="text">
       </td>
       <td class="primer3plus_cell_no_border_right">Opt: 
         <input size="6" name="SCRIPT_DETECTION_PRODUCT_OPT_SIZE" 
         value="$settings{SCRIPT_DETECTION_PRODUCT_OPT_SIZE}" type="text">
       </td>
       <td class="primer3plus_cell_no_border_right">Max: 
         <input size="6" name="SCRIPT_DETECTION_PRODUCT_MAX_SIZE" 
         value="$settings{SCRIPT_DETECTION_PRODUCT_MAX_SIZE}" type="text">
       </td>
       <td class="primer3plus_cell_no_border">
       </td>
     </tr>
   </table>
</div>
   <table class="primer3plus_table_no_border">
     <tr>
       <td class="primer3plus_cell_no_border"><input name="PRIMER_LIBERAL_BASE"  value="1" };

	$formHTML .= ($settings{PRIMER_LIBERAL_BASE}) ? "checked=\"checked\" " : "";
 
	$formHTML .= qq{type="checkbox">
         <a name="PRIMER_LIBERAL_BASE_INPUT" href="$machineSettings{URL_HELP}#PRIMER_LIBERAL_BASE">Liberal Base</a> </td>
       <td class="primer3plus_cell_no_border"><input name="PRIMER_LIB_AMBIGUITY_CODES_CONSENSUS" value="1" };

	$formHTML .= ($settings{PRIMER_LIB_AMBIGUITY_CODES_CONSENSUS}) ? "checked=\"checked\" " : "";
 
	$formHTML .= qq{type="checkbox">Do not treat ambiguity codes in libraries as consensus </td>
       <td class="primer3plus_cell_no_border"><input name="PRIMER_LOWERCASE_MASKING" value="1" };

	$formHTML .= ($settings{PRIMER_LOWERCASE_MASKING}) ? "checked=\"checked\" " : "";
 
	$formHTML .= qq{type="checkbox">Use Lowercase Masking </td>
	    <td class="primer3plus_cell_no_border" valign="top">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
	    &nbsp;&nbsp;&nbsp;
	      <input name="SCRIPT_CONTAINS_JAVA_SCRIPT" value="1" type="hidden">
       </td>

     </tr>
   </table>

<div id="primer3plus_sequencing" class="primer3plus_section">
   <b>Sequencing</b>
   <table class="primer3plus_table_no_border">
     <colgroup>
       <col width="12%">
       <col width="4%">
       <col width="10%">
       <col width="12%">
       <col width="4%">
       <col width="10%">
     </colgroup>
     <tr>
       <td class="primer3plus_cell_no_border"><a onmouseover="toolTip('Space between primer binding site and the start of readable sequencing');" onmouseout="toolTip();" name="SCRIPT_SEQUENCING_LEAD_INPUT" href="$machineSettings{URL_HELP}#SCRIPT_SEQUENCING_LEAD">Lead</a>
       </td>
       <td class="primer3plus_cell_no_border">Bp:
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="SCRIPT_SEQUENCING_LEAD" value="$settings{SCRIPT_SEQUENCING_LEAD}" type="text">
       </td>
       <td class="primer3plus_cell_no_border"><a onmouseover="toolTip('Space between the primers on one DNA strand');" onmouseout="toolTip();" name="SCRIPT_SEQUENCING_SPACING_INPUT" href="$machineSettings{URL_HELP}#SCRIPT_SEQUENCING_SPACING">
         Spacing</a>
       </td>
       <td class="primer3plus_cell_no_border">Bp: </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="SCRIPT_SEQUENCING_SPACING" value="$settings{SCRIPT_SEQUENCING_SPACING}" type="text">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><a onmouseover="toolTip('Space in which Primer3Plus picks the optimal primer');" onmouseout="toolTip();" name="SCRIPT_SEQUENCING_ACCURACY_INPUT"
         href="$machineSettings{URL_HELP}#SCRIPT_SEQUENCING_ACCURACY">Accuracy</a>
       </td>
       <td class="primer3plus_cell_no_border">Bp:
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="SCRIPT_SEQUENCING_ACCURACY" value="$settings{SCRIPT_SEQUENCING_ACCURACY}" type="text">
       </td>
       <td class="primer3plus_cell_no_border"><a onmouseover="toolTip('Space between primers on the forward and the reverse strand');" onmouseout="toolTip();" name="SCRIPT_SEQUENCING_INTERVAL_INPUT" href="$machineSettings{URL_HELP}#SCRIPT_SEQUENCING_INTERVAL">
         Interval</a>
       </td>
       <td class="primer3plus_cell_no_border">Bp:
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="SCRIPT_SEQUENCING_INTERVAL" value="$settings{SCRIPT_SEQUENCING_INTERVAL}" type="text">
       </td>
     </tr> 
     <tr>
       <td class="primer3plus_cell_no_border" colspan="2">
         <a onmouseover="toolTip('Pick primers on the reverse DNA strand as well');" onmouseout="toolTip();" name="SCRIPT_SEQUENCING_REVERSE_INPUT" href="$machineSettings{URL_HELP}#SCRIPT_SEQUENCING_REVERSE">Pick Reverse Primers</a>
	</td>
       <td class="primer3plus_cell_no_border">
	<input name="SCRIPT_SEQUENCING_REVERSE" value="1" };

	$formHTML .= ($settings{SCRIPT_SEQUENCING_REVERSE}) ? "checked=\"checked\" " : "";
 
	$formHTML .= qq{type="checkbox">
       </td>
     </tr>
   </table></div>
</div>
};

$formHTML .= qq{
<div id="primer3plus_Internal_Oligo" class="primer3plus_tab_page" style="display: none;">
  <div class="primer3plus_section">
   <table class="primer3plus_table_no_border">
     <colgroup>
       <col width="32%">
       <col width="68%">
     </colgroup>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="internal_oligo_generic_INPUT" href="$machineSettings{URL_HELP}#internal_oligo_generic">
         Hyb Oligo Excluded Region:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input id="SEQUENCE_INTERNAL_EXCLUDED_REGION" name="SEQUENCE_INTERNAL_EXCLUDED_REGION"
         value="$settings{SEQUENCE_INTERNAL_EXCLUDED_REGION}" type="text">
       </td>
     </tr>
   </table>
  </div>
  <div class="primer3plus_section"> 
   <table class="primer3plus_table_no_border">
     <colgroup>
       <col width="20%">
       <col width="15%">
       <col width="15%">
       <col width="15%">
       <col width="35%">
     </colgroup>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="PRIMER_INTERNAL_OLIGO_SIZE_INPUT" href="$machineSettings{URL_HELP}#PRIMER_SIZE">Hyb Oligo Size:</a>
       </td>
       <td class="primer3plus_cell_no_border">Min: <input size="4" name="PRIMER_INTERNAL_MIN_SIZE"
         value="$settings{PRIMER_INTERNAL_MIN_SIZE}" type="text">
       </td>
       <td class="primer3plus_cell_no_border">Opt: <input size="4" name="PRIMER_INTERNAL_OPT_SIZE"
         value="$settings{PRIMER_INTERNAL_OPT_SIZE}" type="text">
       </td>
       <td class="primer3plus_cell_no_border">Max: <input size="4" name="PRIMER_INTERNAL_MAX_SIZE"
         value="$settings{PRIMER_INTERNAL_MAX_SIZE}" type="text">
       </td>
       <td class="primer3plus_cell_no_border">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="PRIMER_OPT_TM_INPUT" href="$machineSettings{URL_HELP}#PRIMER_TM">Hyb Oligo Tm:</a> 
       </td>
       <td class="primer3plus_cell_no_border">Min: <input size="4" name="PRIMER_INTERNAL_MIN_TM"
         value="$settings{PRIMER_INTERNAL_MIN_TM}" type="text">
       </td>
       <td class="primer3plus_cell_no_border">Opt: <input size="4" name="PRIMER_INTERNAL_OPT_TM"
         value="$settings{PRIMER_INTERNAL_OPT_TM}" type="text"> 
       </td>
       <td class="primer3plus_cell_no_border">Max: <input size="4" name="PRIMER_INTERNAL_MAX_TM"
         value="$settings{PRIMER_INTERNAL_MAX_TM}" type="text">
       </td>
       <td class="primer3plus_cell_no_border">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="PRIMER_INTERNAL_OLIGO_GC_INPUT" href="$machineSettings{URL_HELP}#PRIMER_GC">Hyb Oligo GC%</a>
       </td>
       <td class="primer3plus_cell_no_border">Min: <input size="4" name="PRIMER_INTERNAL_MIN_GC"
         value="$settings{PRIMER_INTERNAL_MIN_GC}" type="text">
       </td>
       <td class="primer3plus_cell_no_border">Opt: <input size="4" name="PRIMER_INTERNAL_OPT_GC_PERCENT"
         value="$settings{PRIMER_INTERNAL_OPT_GC_PERCENT}" type="text">
       </td>
       <td class="primer3plus_cell_no_border">Max: <input size="4" name="PRIMER_INTERNAL_MAX_GC"
         value="$settings{PRIMER_INTERNAL_MAX_GC}" type="text">
       </td>
       <td class="primer3plus_cell_no_border">
       </td>
     </tr>
   </table>

   <table class="primer3plus_table_no_border">
     <colgroup>
       <col width="38%">
       <col width="12%">
       <col width="38%">
       <col width="12%">
     </colgroup>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="internal_oligo_generic_INPUT" href="$machineSettings{URL_HELP}#internal_oligo_generic">
         Hyb Oligo Monovalent Cations Concentration:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_INTERNAL_SALT_MONOVALENT"
         value="$settings{PRIMER_INTERNAL_SALT_MONOVALENT}" type="text">
       </td>
       <td class="primer3plus_cell_no_border"><a name="internal_oligo_generic_INPUT" href="$machineSettings{URL_HELP}#internal_oligo_generic">
         Hyb Oligo DNA Concentration:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_INTERNAL_DNA_CONC"
         value="$settings{PRIMER_INTERNAL_DNA_CONC}" type="text">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="internal_oligo_generic_INPUT" href="$machineSettings{URL_HELP}#internal_oligo_generic">
         Hyb Oligo Divalent Cations Concentration:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_INTERNAL_SALT_DIVALENT"
         value="$settings{PRIMER_INTERNAL_SALT_DIVALENT}" type="text">
       </td>
       <td class="primer3plus_cell_no_border"><a name="internal_oligo_generic_INPUT" href="$machineSettings{URL_HELP}#internal_oligo_generic">
         Hyb Oligo [dNTP] Concentration:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_INTERNAL_DNTP_CONC"
         value="$settings{PRIMER_INTERNAL_DNTP_CONC}" type="text">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="PRIMER_INTERNAL_MAX_NS_ACCEPTED_INPUT" href="$machineSettings{URL_HELP}#internal_oligo_generic">
         Max #Ns:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_INTERNAL_MAX_NS_ACCEPTED"
         value="$settings{PRIMER_INTERNAL_MAX_NS_ACCEPTED}" type="text">
       </td>
       <td class="primer3plus_cell_no_border"><a name="internal_oligo_generic_INPUT" href="$machineSettings{URL_HELP}#internal_oligo_generic">
         Hyb Oligo Max Poly-X:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_INTERNAL_MAX_POLY_X"
         value="$settings{PRIMER_INTERNAL_MAX_POLY_X}" type="text">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="internal_oligo_generic_INPUT" href="$machineSettings{URL_HELP}#internal_oligo_generic">
         Hyb Oligo Self Complementarity:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_INTERNAL_MAX_SELF_ANY"
         value="$settings{PRIMER_INTERNAL_MAX_SELF_ANY}" type="text">
       </td>
       <td class="primer3plus_cell_no_border"><a name="internal_oligo_generic_INPUT" href="$machineSettings{URL_HELP}#internal_oligo_generic">
         Hyb Oligo Max 3' Self Complementarity:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_INTERNAL_MAX_SELF_END"
         value="$settings{PRIMER_INTERNAL_MAX_SELF_END}" type="text">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="internal_oligo_generic_INPUT" href="$machineSettings{URL_HELP}#internal_oligo_generic">
         Hyb Oligo Max Mishyb:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_INTERNAL_MAX_LIBRARY_MISHYB"
         value="$settings{PRIMER_INTERNAL_MAX_LIBRARY_MISHYB}" type="text">
       </td>
       <td class="primer3plus_cell_no_border"><a name="internal_oligo_generic_INPUT" href="$machineSettings{URL_HELP}#internal_oligo_generic">
         Hyb Oligo Min Sequence Quality:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_INTERNAL_MIN_QUALITY"
         value="$settings{PRIMER_INTERNAL_MIN_QUALITY}" type="text">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="internal_oligo_generic_INPUT" href="$machineSettings{URL_HELP}#internal_oligo_generic">
         Hyb Oligo Mishyb Library:</a>
       </td>
       <td class="primer3plus_cell_no_border" colspan="3">
         <select name="PRIMER_INTERNAL_MISHYB_LIBRARY">
};

foreach $mishyb1 (@libraryList) {
	my $selectedStatus = "";
	if ($mishyb1 eq $settings{PRIMER_INTERNAL_MISHYB_LIBRARY} ) {$selectedStatus = " selected=\"selected\"" };
	$formHTML .= "         <option$selectedStatus>$mishyb1</option>\n";
} 	

$formHTML .= qq{         </select>
       </td>
     </tr>
   </table>
  </div>
};

$formHTML .= qq{</div>
<div id="primer3plus_penalties" class="primer3plus_tab_page" style="display: none;">
   <table class="primer3plus_table_penalties">
     <colgroup>
       <col width="33%">
       <col width="34%">
       <col width="33%">
     </colgroup>
     <tr>
       <td class="primer3plus_cell_penalties">
       <h3>For Primers</h3>
       </td>
       <td class="primer3plus_cell_penalties">
       <h3>For Primer Pairs</h3>
       </td>
       <td class="primer3plus_cell_penalties">
       <h3>For Hyb Oligos</h3>
       </td>
     </tr>
   </table>
   <table class="primer3plus_table_penalties">
     <colgroup>
       <col width="10%">
       <col width="3%">
       <col width="8%">
       <col width="3%">
       <col width="9%">
       <col width="11%">
       <col width="3%">
       <col width="8%">
       <col width="3%">
       <col width="9%">
       <col width="10%">
       <col width="3%">
       <col width="8%">
       <col width="3%">
       <col width="9%">
     </colgroup>
     <tr>
       <td class="primer3plus_cell_penalties"><a name="WT_TM_INPUT" href="$machineSettings{URL_HELP}#generic_penalty_weights">Tm</a>
       </td>
       <td class="primer3plus_cell_penalties">Lt:
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_WT_TM_LT"
         value="$settings{PRIMER_WT_TM_LT}" type="text">
       </td>
       <td class="primer3plus_cell_penalties">Gt:
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_WT_TM_GT"
         value="$settings{PRIMER_WT_TM_GT}" type="text">
       </td>
       <td class="primer3plus_cell_penalties"><a name="PAIR_WT_PRODUCT_TM_INPUT" href="$machineSettings{URL_HELP}#generic_penalty_weights">Product Tm</a>
       </td>
       <td class="primer3plus_cell_penalties">Lt: 
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_PAIR_WT_PRODUCT_TM_LT"
         value="$settings{PRIMER_PAIR_WT_PRODUCT_TM_LT}" type="text"> 
       </td>
       <td class="primer3plus_cell_penalties">Gt:
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_PAIR_WT_PRODUCT_TM_GT"
         value="$settings{PRIMER_PAIR_WT_PRODUCT_TM_GT}" type="text">
       </td>
       <td class="primer3plus_cell_penalties"><a name="IO_WT_TM_INPUT" href="$machineSettings{URL_HELP}#generic_penalty_weights">Tm</a>
       </td>
       <td class="primer3plus_cell_penalties">Lt:
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_INTERNAL_WT_TM_LT"
         value="$settings{PRIMER_INTERNAL_WT_TM_LT}" type="text">
       </td>
       <td class="primer3plus_cell_penalties">Gt: 
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_INTERNAL_WT_TM_GT"
         value="$settings{PRIMER_INTERNAL_WT_TM_GT}" type="text">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_penalties"><a name="WT_SIZE_INPUT" href="$machineSettings{URL_HELP}#generic_penalty_weights">Size</a>
       </td>
       <td class="primer3plus_cell_penalties">Lt:
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_WT_SIZE_LT"
         value="$settings{PRIMER_WT_SIZE_LT}" type="text">
       </td>
       <td class="primer3plus_cell_penalties">Gt:
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_WT_SIZE_GT"
         value="$settings{PRIMER_WT_SIZE_GT}" type="text">
       </td>
       <td class="primer3plus_cell_penalties"><a name="PAIR_WT_PRODUCT_SIZE_INPUT" href="$machineSettings{URL_HELP}#generic_penalty_weights">Product Size</a>
       </td>
       <td class="primer3plus_cell_penalties">Lt: 
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_PAIR_WT_PRODUCT_SIZE_LT"
         value="$settings{PRIMER_PAIR_WT_PRODUCT_SIZE_LT}" type="text"> 
       </td>
       <td class="primer3plus_cell_penalties">Gt:
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_PAIR_WT_PRODUCT_SIZE_GT"
         value="$settings{PRIMER_PAIR_WT_PRODUCT_SIZE_GT}" type="text">
       </td>
       <td class="primer3plus_cell_penalties"><a name="IO_WT_SIZE_INPUT" href="$machineSettings{URL_HELP}#generic_penalty_weights">Size</a>
       </td>
       <td class="primer3plus_cell_penalties">Lt:
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_INTERNAL_WT_SIZE_LT"
         value="$settings{PRIMER_INTERNAL_WT_SIZE_LT}" type="text">
       </td>
       <td class="primer3plus_cell_penalties">Gt: 
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_INTERNAL_WT_SIZE_GT"
         value="$settings{PRIMER_INTERNAL_WT_SIZE_GT}" type="text">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_penalties"><a name="WT_GC_PERCENT_INPUT" href="$machineSettings{URL_HELP}#generic_penalty_weights">GC%</a> 
       </td>
       <td class="primer3plus_cell_penalties">Lt:
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_WT_GC_PERCENT_LT"
         value="$settings{PRIMER_WT_GC_PERCENT_LT}" type="text">
       </td>
       <td class="primer3plus_cell_penalties">Gt:
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_WT_GC_PERCENT_GT"
         value="$settings{PRIMER_WT_GC_PERCENT_GT}" type="text">
       </td>
       <td class="primer3plus_cell_penalties">
       </td>
       <td class="primer3plus_cell_penalties"> 
       </td>
       <td class="primer3plus_cell_penalties"> 
       </td>
       <td class="primer3plus_cell_penalties">
       </td>
       <td class="primer3plus_cell_penalties">
       </td>
       <td class="primer3plus_cell_penalties"><a name="IO_WT_GC_PERCENT_INPUT" href="$machineSettings{URL_HELP}#generic_penalty_weights">GC%</a>
       </td>
       <td class="primer3plus_cell_penalties">Lt:
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_INTERNAL_WT_GC_PERCENT_LT"
         value="$settings{PRIMER_INTERNAL_WT_GC_PERCENT_LT}" type="text">
       </td>
       <td class="primer3plus_cell_penalties">Gt: 
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_INTERNAL_WT_GC_PERCENT_GT"
         value="$settings{PRIMER_INTERNAL_WT_GC_PERCENT_GT}" type="text">
       </td>
     </tr>
   </table>
   <table class="primer3plus_table_penalties">
     <colgroup>
       <col width="24%">
       <col width="9%">
       <col width="25%">
       <col width="9%">
       <col width="24%">
       <col width="9%">
     </colgroup>
     <tr>
       <td class="primer3plus_cell_penalties"><a name="WT_REP_SIM_INPUT" href="$machineSettings{URL_HELP}#generic_penalty_weights">Mispriming</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_PAIR_WT_LIBRARY_MISPRIMING"
         value="$settings{PRIMER_PAIR_WT_LIBRARY_MISPRIMING}" type="text">
       </td>
       <td class="primer3plus_cell_penalties"><a name="PAIR_WT_REP_SIM_INPUT" href="$machineSettings{URL_HELP}#generic_penalty_weights">Pair Mispriming</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_PAIR_WT_LIBRARY_MISPRIMING"
         value="$settings{PRIMER_PAIR_WT_LIBRARY_MISPRIMING}" type="text">
       </td>
       <td class="primer3plus_cell_penalties"><a name="IO_WT_REP_SIM_INPUT" href="$machineSettings{URL_HELP}#generic_penalty_weights">Hyb Oligo Mishybing</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_INTERNAL_WT_LIBRARY_MISHYB"
         value="$settings{PRIMER_INTERNAL_WT_LIBRARY_MISHYB}" type="text">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_penalties"><a name="WT_COMPL_ANY_INPUT" href="$machineSettings{URL_HELP}#generic_penalty_weights">Self Complementarity</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_WT_SELF_ANY"
         value="$settings{PRIMER_WT_SELF_ANY}" type="text">
       </td>
       <td class="primer3plus_cell_penalties"><a name="PAIR_WT_COMPL_ANY_INPUT" href="$machineSettings{URL_HELP}#generic_penalty_weights">
         Any Complementarity</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_PAIR_WT_COMPL_ANY"
         value="$settings{PRIMER_PAIR_WT_COMPL_ANY}" type="text">
       </td>
       <td class="primer3plus_cell_penalties"><a name="IO_WT_COMPL_ANY_INPUT" href="$machineSettings{URL_HELP}#generic_penalty_weights">
         Self Complementarity</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_INTERNAL_WT_SELF_ANY"
         value="$settings{PRIMER_INTERNAL_WT_SELF_ANY}" type="text">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_penalties"><a name="WT_COMPL_END_INPUT" href="$machineSettings{URL_HELP}#generic_penalty_weights">3' Self Complementarity</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_WT_SELF_END"
         value="$settings{PRIMER_WT_SELF_END}" type="text">
       </td>
       <td class="primer3plus_cell_penalties"><a name="PAIR_WT_COMPL_END_INPUT" href="$machineSettings{URL_HELP}#generic_penalty_weights">3' Self Complementarity</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_PAIR_WT_COMPL_END"
         value="$settings{PRIMER_PAIR_WT_COMPL_END}" type="text">
       </td>
       <td class="primer3plus_cell_penalties">
       </td>
       <td class="primer3plus_cell_penalties">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_penalties"><a name="PRIMER_WT_TEMPLATE_MISPRIMING_INPUT" href="$machineSettings{URL_HELP}#generic_penalty_weights">Template Mispriming</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_WT_TEMPLATE_MISPRIMING"
         value="$settings{PRIMER_WT_TEMPLATE_MISPRIMING}" type="text">
       </td>
       <td class="primer3plus_cell_penalties"><a name="PRIMER_PAIR_WT_TEMPLATE_MISPRIMING_INPUT" href="$machineSettings{URL_HELP}#generic_penalty_weights">Template Mispriming</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_PAIR_WT_TEMPLATE_MISPRIMING"
         value="$settings{PRIMER_PAIR_WT_TEMPLATE_MISPRIMING}" type="text">
       </td>
       <td class="primer3plus_cell_penalties">
       </td>
       <td class="primer3plus_cell_penalties">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_penalties"><a name="WT_NUM_NS_INPUT" href="$machineSettings{URL_HELP}#generic_penalty_weights">#N's</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_WT_NUM_NS"
         value="$settings{PRIMER_WT_NUM_NS}" type="text">
       </td>
       <td class="primer3plus_cell_penalties">
       </td>
       <td class="primer3plus_cell_penalties">
       </td>
       <td class="primer3plus_cell_penalties"><a name="IO_WT_NUM_NS_INPUT" href="$machineSettings{URL_HELP}#generic_penalty_weights">Hyb Oligo #N's</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_INTERNAL_WT_NUM_NS"
         value="$settings{PRIMER_INTERNAL_WT_NUM_NS}" type="text">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_penalties"><a name="WT_SEQ_QUAL_INPUT" href="$machineSettings{URL_HELP}#generic_penalty_weights">Sequence Quality</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_WT_SEQ_QUAL"
         value="$settings{PRIMER_WT_SEQ_QUAL}" type="text">
       </td>
       <td class="primer3plus_cell_penalties">
       </td>
       <td class="primer3plus_cell_penalties">
       </td>
       <td class="primer3plus_cell_penalties"><a name="IO_WT_SEQ_QUAL_INPUT" href="$machineSettings{URL_HELP}#generic_penalty_weights">Sequence Quality</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_INTERNAL_WT_SEQ_QUAL"
         value="$settings{PRIMER_INTERNAL_WT_SEQ_QUAL}" type="text">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_penalties"><a name="WT_END_QUAL_INPUT" href="$machineSettings{URL_HELP}#generic_penalty_weights">End Sequence Quality</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_WT_END_QUAL"
         value="$settings{PRIMER_WT_END_QUAL}" type="text">
       </td>
       <td class="primer3plus_cell_penalties">
       </td>
       <td class="primer3plus_cell_penalties">
       </td>
       <td class="primer3plus_cell_penalties">
       </td>
       <td class="primer3plus_cell_penalties">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_penalties"><a name="WT_POS_PENALTY_INPUT" href="$machineSettings{URL_HELP}#generic_penalty_weights">Position Penalty</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_WT_POS_PENALTY"
         value="$settings{PRIMER_WT_POS_PENALTY}" type="text">
       </td>
       <td class="primer3plus_cell_penalties"><a name="PAIR_WT_DIFF_TM_INPUT" href="$machineSettings{URL_HELP}#generic_penalty_weights">Tm Difference</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_PAIR_WT_DIFF_TM"
         value="$settings{PRIMER_PAIR_WT_DIFF_TM}" type="text">
       </td>
       <td class="primer3plus_cell_penalties">
       </td>
       <td class="primer3plus_cell_penalties">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_penalties"><a name="WT_END_STABILITY_INPUT" href="$machineSettings{URL_HELP}#generic_penalty_weights">End Stability</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_WT_END_STABILITY"
         value="$settings{PRIMER_WT_END_STABILITY}" type="text">
       </td>
       <td class="primer3plus_cell_penalties"><a name="PAIR_WT_PR_PENALTY_INPUT" href="$machineSettings{URL_HELP}#generic_penalty_weights">
         Primer Penalty Weight</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_PAIR_WT_PR_PENALTY"
         value="$settings{PRIMER_PAIR_WT_PR_PENALTY}" type="text">
       </td>
       <td class="primer3plus_cell_penalties">
       </td>
       <td class="primer3plus_cell_penalties">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_penalties"><a name="PRIMER_INSIDE_PENALTY_INPUT" href="$machineSettings{URL_HELP}#PRIMER_INSIDE_PENALTY">
         Inside Target Penalty:</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_INSIDE_PENALTY"
         value="$settings{PRIMER_INSIDE_PENALTY}" type="text">
       </td>
       <td class="primer3plus_cell_penalties"><a name="PAIR_WT_IO_PENALTY_INPUT" href="$machineSettings{URL_HELP}#generic_penalty_weights">
         Hyb Oligo Penalty Weight</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_PAIR_WT_IO_PENALTY"
         value="$settings{PRIMER_PAIR_WT_IO_PENALTY}" type="text">
       </td>
       <td class="primer3plus_cell_penalties">
       </td>
       <td class="primer3plus_cell_penalties">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_penalties"><a name="PRIMER_OUTSIDE_PENALTY_INPUT" href="$machineSettings{URL_HELP}#PRIMER_OUTSIDE_PENALTY">
         Outside Target Penalty:</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_OUTSIDE_PENALTY"
         value="$settings{PRIMER_OUTSIDE_PENALTY}" type="text">
       </td>
       <td class="primer3plus_cell_penalties">
       </td>
       <td class="primer3plus_cell_penalties">
       </td>
       <td class="primer3plus_cell_penalties">
       </td>
       <td class="primer3plus_cell_penalties">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_penalties" colspan="2"><a name="PRIMER_INSIDE_PENALTY_INPUT" href="$machineSettings{URL_HELP}#PRIMER_INSIDE_PENALTY">
         Set Inside Target Penalty to allow primers inside a target. </a>
       </td>
       <td class="primer3plus_cell_penalties">
       </td>
       <td class="primer3plus_cell_penalties">
       </td>
       <td class="primer3plus_cell_penalties">
       </td>
       <td class="primer3plus_cell_penalties">
       </td>
     </tr>
   </table>
};

my $task = "primer3plus_explain_".$settings{SCRIPT_TASK};
$formHTML .= qq{</div>

</form>

</div>	
<script type="text/javascript">
function initTabs() {
	showTab('tab1','primer3plus_primer');
	showTopic('$task');
}
initTabs();
</script>
};

  my $returnString = $templateText;

  $returnString =~ s/<!-- Primer3plus will include code here -->/$formHTML/;

  return $returnString;
}

################################################################################
# createSelectSequence: Will write an HTML-Form containing sequences to select #
################################################################################

sub createSelectSequence {
  my %settings; 
  %settings = %{(shift)};

  my $sequenceCounter = $settings{SCRIPT_SEQUENCE_COUNTER};
  
  my $templateText = getWrapper();

  my $formHTML = qq{
<div id="primer3plus_complete">

<form action="$machineSettings{URL_FORM_ACTION}" method="post" enctype="multipart/form-data">
};

$formHTML .= divTopBar("Basic");

$formHTML .= divMessages();

$formHTML .= qq{
<div id="primer3plus_select_sequence">

<h2>Please select one of the sequences</h2>

<input id="primer3plus_select_sequence_button" class="primer3plus_action_button"
 name="SelectOneSequence" value="Select Sequence" type="submit"><br>
<br>
<div id="primer3plus_result_sequence_id">
 <table class="primer3plus_table_no_border">
     <colgroup>
       <col width="13%" style="text-align: right;">
       <col width="87%">
     </colgroup>
     <tr>
       <td><input type="radio" name="SCRIPT_SELECTED_SEQUENCE" value="0" checked="checked">
         &nbsp;&nbsp;&nbsp;</td>
       <td>$settings{SEQUENCE_ID}
         </td>
     </tr>
 </table>
 </div>
};

$formHTML .= divHTMLformatSequence($settings{SEQUENCE}, 1);

$formHTML .= qq{<br>
<br>
};

for ( my $i = 1 ; $i < $sequenceCounter ; $i++ ) {
    $formHTML .= qq{<br>
<div id="primer3plus_result_sequence_id">
 <table class="primer3plus_table_no_border">
     <colgroup>
       <col width="13%" style="text-align: right;">
       <col width="87%">
     </colgroup>
     <tr>
       <td><input type="radio" name="SCRIPT_SELECTED_SEQUENCE" value="$i">
         &nbsp;&nbsp;&nbsp;</td>
       <td>$settings{"SEQUENCE_ID_$i"}
         </td>
     </tr>
 </table>
 </div>
 };

	$formHTML .= divHTMLformatSequence($settings{"SEQUENCE_$i"}, 1);
	
	$formHTML .= qq{<br>
<br>};
};

my $HashKeys;
foreach $HashKeys (sort(keys(%settings))){
	if ($HashKeys eq "Pick_Primers") {
	}
	elsif ($HashKeys eq "SCRIPT_SEQUENCE_FILE_CONTENT") {
	}
	elsif ($HashKeys eq "SCRIPT_SEQUENCE_FILE") {
	}
	elsif ($HashKeys eq "SCRIPT_SETTINGS_FILE") {
	}
	elsif ($HashKeys eq "Upload_File") {
	}
    else {
    	$formHTML .= qq{
    <input type="hidden" name="$HashKeys" value="$settings{$HashKeys}">};
	}
};

	$formHTML .= qq{ <input id="primer3plus_select_sequence_button" class="primer3plus_action_button"
   name="SelectOneSequence" value="Select Sequence" type="submit"><br>
 <br>
 </from>
</div>
	};

  my $returnString = $templateText;

  $returnString =~ s/<!-- Primer3plus will include code here -->/$formHTML/;

  return $returnString;
}


###########################################################
# createHelpHTML: Will write an HTML-Form containing Help #
###########################################################

sub createHelpHTML {
  my $templateText = getWrapper();

  my $formHTML = qq{
<div id="primer3plus_complete">

};

$formHTML .= divTopBar("Help");

$formHTML .= divMessages;

$formHTML .= qq{
<div id="primer3plus_help">

<h2><a name="cautions">Cautions</a></h2>
  <p>Some of the most important issues in primer picking can be addressed only before using Primer3. These are sequence
    quality (including making sure the sequence is not vector and not chimeric) and avoiding repetitive elements.<br>
    <br>
    Techniques for avoiding problems include a thorough understanding of possible vector contaminants and cloning
    artifacts coupled with database searches using blast, fasta, or other similarity searching program to screen for
    vector contaminants and possible repeats.  Repbase (J. Jurka, A.F.A. Smit, C. Pethiyagoda, and others, 1995-1996) 
    <a href="ftp://ftp.ncbi.nih.gov/repository/repbase">ftp://ftp.ncbi.nih.gov/repository/repbase</a>
    ) is an excellent source of repeat sequences and pointers to the literature.  Primer3 now allows you to screen
    candidate oligos against a Mispriming Library (or a Mishyb Library in the case of internal oligos).<br>
    <br>
    Sequence quality can be controlled by manual trace viewing and quality clipping or automatic quality clipping
    programs.  Low-quality bases should be changed to N's or can be made part of Excluded Regions. The beginning of
    a sequencing read is often problematic because of primer peaks, and the end of the read often contains many
    low-quality or even meaningless called bases. Therefore when picking primers from single-pass sequence it is
    often best to use the Included Region parameter to ensure that Primer3 chooses primers in the high quality region
    of the read.<br>
    <br>
    In addition, Primer3 takes as input a <a href="#SEQUENCE_QUALITY">Sequence Quality</a> list for use with those
    base calling programs such as Phred that output this information.
  </p>

<h2><a name="SCRIPT_INPUT_PARAMETERS">Script Input Parameters</a></h2>

<h3><a name="SCRIPT_TASK">Task</a></h3>
  <p>
  <a href="#SCRIPT_DETECTION">Detection</a><br>
  <a href="#SCRIPT_CLONING">Cloning</a><br>
  <a href="#SCRIPT_SEQUENCING">Sequencing</a><br>
  <a href="#SCRIPT_PRIMER_LIST">Primer List</a><br>
  <a href="#SCRIPT_PRIMER_CHECK">Primer Check</a>  
  </p>


<h3><a name="SCRIPT_DETECTION">Task: Detection</a></h3>
  <p>The Detection task can be used for designing standard PCR primers or hybridisation oligos to DETECT a given sequence.<br>
  The user can indicate:<br>
  excluded regions - primers are not allowed to bind in this region<br>
  targets - primers must amplify one of the targets<br>
  included region - primers must bind within this region<br>
  <br>
  Primer3Plus will select the primer pair which fits best to all selected parameters. It can be located anywhere in the sequence,
  only limited by the regions and targets described above.
  </p>

<h3><a name="SCRIPT_CLONING">Task: Cloning</a></h3>
  <p>The Cloning task can be used to design primers ending or starting exactly at the boundary of the
  included region.<br>
  To clone for example open reading frames the 5'End of the primers should be fixed. Primer3plus 
  picks primers of various length, all forward primers starting at the same nucleotide (A from ATG)
  and all reverse primers starting at the same nucleotide (G from TAG). To have this functionality 
  the parameter "Fix the x prime end of the primer" in general setting should be set to 5 (default).<br>
  <br>
  To to distinguish between different alleles primers must bind with their 3'End fixed to the varying 
  nucleotides. If the parameter "Fix the x prime end of the primer" in general setting is set to 3, 
  primer3plus picks primers of various length, all primers ending at the same nucleotide.<br>
  <br>
  Primer3Plus picks out of all primers the best pair and orders them by quality.<br>
  <br>
  ATTENTION: Due to the inflexibility of the primer position, only the primer length can be altered. In 
  many cases this leads to primers of low quality. Select the cloning function ONLY if you require 
  your primers to start or to end at a certain nucleotide.
  </p>

<h3><a name="SCRIPT_FIX_PRIMER_END">Fix the x prime end of the primer</a></h3>
  <p>This parameter can be set to 5 (default) or 3. It indicates for Primer3Plus which End of the 
  primer should be fixed and which can be extended or cut.
  </p>

<h3><a name="SCRIPT_SEQUENCING">Task: Sequencing</a></h3>
  <p>The Sequencing task is developed to design a series of primers on both the forward and reverse 
  strands that can be used for custom primer-based (re-)sequencing of clones. Targets can be defined 
  in the sequence which will be sequenced optimally. The pattern how Primer3Plus picks the primers 
  can be modified on the Advanced settings tab:
  </p>

<h3><a name="SCRIPT_SEQUENCING_LEAD">Lead</a></h3>
  <p>Defines the space from the start of the primer to the point were the trace signals are readable 
  (default 50 bp).
  </p>

<h3><a name="SCRIPT_SEQUENCING_SPACING">Spacing</a></h3>
  <p>Defines the space from the start of the primer to the start of the next primer on the same 
  strand (default 500 bp).
  </p>

<h3><a name="SCRIPT_SEQUENCING_INTERVAL">Interval</a></h3>
  <p>Defines the space from the start of the primer to the start of the next primer on the opposite 
  strand (default 250 bp).
  </p>

<h3><a name="SCRIPT_SEQUENCING_ACCURACY">Accuracy</a></h3>
  <p>Defines the size of the area in which primer3plus searches for the best primer (default 20 bp).
  </p>

<h3><a name="SCRIPT_SEQUENCING_REVERSE">Pick Reverse Primers</a></h3>
  <p>Select "Pick Reverse Primers" to pick also primers on the reverse strand (selected by default).
  </p>

<h3><a name="SCRIPT_PRIMER_LIST">Task: Primer List</a></h3>
  <p>With the Primer List task all possible primers that can be designed on the target sequence and 
  meet the current settings will be returned with their corresponding characteristics. This task 
  basically allows manual selection of primers. The run time of the Primer List task can be 
  relatively long, especially when lengthy target sequences are submitted.
  </p>

<h3><a name="SCRIPT_PRIMER_CHECK">Task: Primer Check</a></h3>
  <p>The Primer Check task can be used to obtain information on a specified primer, like its melting 
  temperature or self complementarity. For this task no template sequence is required and only the 
  primer sequence has to be provided.
  </p>

<h3><a name="SERVER_PARAMETER_FILE">Server Parameter File</a></h3>
  <p>A collection of settings for specific applications stored at the server.
  </p>

<h3><a>Naming of Primers</a></h3>
  <p>Primer3Plus will create automatically a name for each primer based on the Sequence ID, the 
  primer number and the primer acronym.
  </p>

<h3><a name="P3P_PRIMER_NAME_ACRONYM_LEFT">Left Primer Acronym</a></h3>
  <p>Acronym for the left primer, by default F
  </p>

<h3><a name="P3P_PRIMER_NAME_ACRONYM_INTERNAL_OLIGO">Internal Oligo Acronym</a></h3>
  <p>Acronym for the internal oligo, by default IN
  </p>

<h3><a name="P3P_PRIMER_NAME_ACRONYM_RIGHT">Right Primer Acronym</a></h3>
  <p>Acronym for the right primer, by default R
  </p>

<h3><a name="P3P_PRIMER_NAME_ACRONYM_SPACER">Primer Name Spacer</a></h3>
  <p>Spacer primer3plus uses between name, number and acronym, by default _
  </p>


<h2><a name="INPUT_PARAMETERS">Input Parameters</a></h2>

<h3><a name="SEQUENCE_TEMPLATE">Source Sequence</a></h3>
  <p>The sequence from which to select primers or hybridization oligos.</p>

<h3><a name="SEQUENCE_ID">Sequence Id</a></h3>
  <p>An identifier that is reproduced in the output to enable you to identify the chosen primers.</p>

<h3><a name="SEQUENCE_TARGET">Targets</a></h3>
  <p>If one or more Targets is specified then a legal primer pair must flank at least one of them.  A Target might
    be a simple sequence repeat site (for example a CA repeat) or a single-base-pair polymorphism.  The value should
    be a space-separated list of<br>
    <pre><tt><i>start</i></tt>,<tt><i>length</i></tt></pre>
    pairs where <tt><i>start</i></tt> is the index of the first base of a Target, and <tt><i>length</i></tt> is its
    length.
  </p>

<h3><a name="SEQUENCE_EXCLUDED_REGION">Excluded Regions</a></h3>
  <p>Primer oligos may not overlap any region specified in this tag. The associated value must be a space-separated list of
    <br>
    <pre><tt><i>start</i></tt>,<tt><i>length</i></tt></pre>
    pairs where <tt><i>start</i></tt> is the index of the first base of the excluded region, and <tt><i>length</i></tt>
    is its length.  This tag is useful for tasks such as excluding regions of low sequence quality or for excluding
    regions containing repetitive elements such as ALUs or LINEs.
  </p>

<h3><a name="PRIMER_PRODUCT_SIZE_RANGE">Product Size Range</a></h3>
  <p>A list of product size ranges, for example
    <br>
    <pre><tt>150-250 100-300 301-400</tt></pre>
    Primer3 first tries to pick primers in the first range.  If that is not possible, it goes to the next range and tries
    again.  It continues in this way until it has either picked all necessary primers or until there are no more ranges.
    For technical reasons this option makes much lighter computational demands than the Product Size option.
  </p>
  
<h3><a name="PRIMER_PRODUCT_SIZE">Product Size</a></h3>
  <p>Minimum, Optimum, and Maximum lengths (in bases) of the PCR product. Primer3 will not generate primers with products
    shorter than Min or longer than Max, and with default arguments Primer3 will attempt to pick primers producing products
    close to the Optimum length. 
  </p>
  
<h3><a name="PRIMER_NUM_RETURN">Number To Return</a></h3>
  <p>The maximum number of primer pairs to return.  Primer pairs returned are sorted by their &quot;quality&quot;, in other
    words by the value of the objective function (where a lower number indicates a better primer pair).  Caution: setting
    this parameter to a large value will increase running time.
  </p>
  
<h3><a name="PRIMER_MAX_END_STABILITY">Max 3' Stability</a></h3>
  <p>The maximum stability for the last five 3' bases of a left or right primer.  Bigger numbers mean more stable 
    3' ends.  The value is the maximum delta G (kcal/mol) for duplex disruption for the five 3' bases as calculated
    using the Nearest-Neighbor parameter values specified by the option of <a href="#PRIMER_TM_FORMULA">'Table of
    thermodynamic parameters'</a>. For example if the table of thermodynamic parameters suggested by 
    <a href="http://dx.doi.org/10.1073/pnas.95.4.1460" target="_blank">SantaLucia 1998, DOI:10.1073/pnas.95.4.1460</a>
    is used the deltaG values for the most stable and for the most labile 5mer duplex are 6.86 kcal/mol (GCGCG)
    and 0.86 kcal/mol (TATAT) respectively. If the table of thermodynamic parameters suggested by 
    <a href="http://dx.doi.org/10.1073/pnas.83.11.3746" target="_blank">Breslauer et al. 1986, 10.1073/pnas.83.11.3746</a>
    is used the deltaG values for the most stable and for the most labile 5mer are 13.4 kcal/mol (GCGCG) and
    4.6 kcal/mol (TATAC) respectively.
  </p>
  
<h3><a name="PRIMER_MAX_LIBRARY_MISPRIMING">Max Mispriming</a></h3>
  <p>The maximum allowed weighted similarity with any sequence in Mispriming Library. Default is 12.
  </p>
  
<h3><a name="PRIMER_MAX_TEMPLATE_MISPRIMING">Max Template Mispriming</a></h3>
  <p>The maximum allowed similarity to ectopic sites in the sequence from which you are designing the primers.
    The scoring system is the same as used for Max Mispriming, except that an ambiguity code is never treated as
    a consensus.
  </p>
  
<h3><a name="PRIMER_PAIR_MAX_LIBRARY_MISPRIMING">Pair Max Mispriming</a></h3>
  <p>The maximum allowed sum of similarities of a primer pair (one similarity for each primer) with any single sequence
    in Mispriming Library. Default is 24. Library sequence weights are not used in computing the sum of similarities.
  </p>
  
<h3><a name="PRIMER_PAIR_MAX_TEMPLATE_MISPRIMING"><strong>Pair Max Template Mispriming</a></h3>
  <p>The maximum allowed summed similarity of both primers to ectopic sites in the sequence from which you are
    designing the primers.  The scoring system is the same as used for Max Mispriming, except that an ambiguity code
    is never treated as a consensus.
  </p>
  
<h3><a name="PRIMER_SIZE">Primer Size</a></h3>
  <p>Minimum, Optimum, and Maximum lengths (in bases) of a primer oligo. Primer3 will not pick primers shorter than Min
    or longer than Max, and with default arguments will attempt to pick primers close with size close to Opt. Min 
    cannot be smaller than 1. Max cannot be larger than 36. (This limit is governed by maximum oligo size for which 
    melting-temperature calculations are valid.) Min cannot be greater than Max.
  </p>

<h3><a name="PRIMER_TM">Primer T<sub>m</sub></a></h3>
  <p>Minimum, Optimum, and Maximum melting temperatures (Celsius) for a primer oligo. Primer3 will not pick oligos with
    temperatures smaller than Min or larger than Max, and with default conditions will try to pick primers with melting
    temperatures close to Opt.<br>
    <br>
    By default Primer3 uses the oligo melting temperature formula and the table of thermodynamic parameters given in
    <a href="http://dx.doi.org/10.1073/pnas.83.11.3746" target="_blank"> Breslauer et al. 1986,
    DOI:10.1073/pnas.83.11.3746</a>~For more information see caption <a href="#PRIMER_TM_FORMULA">
    Table of thermodynamic parameters</a>
  </p>

<h3><a name="PRIMER_PAIR_MAX_DIFF_TM">Maximum T<sub>m</sub> Difference</a></h3>
  <p>Maximum acceptable (unsigned) difference between the melting temperatures of the left and right primers.
  </p>

<h3><a name="PRIMER_TM_FORMULA">Table of thermodynamic parameters</a></h3>
  <p>Option for the table of Nearest-Neighbor thermodynamic parameters and for the method of melting temperature 
    calculation. Two different tables of thermodynamic parameters are available:
    <ol>
    <li><a href="http://dx.doi.org/10.1073/pnas.83.11.3746" target="_blank"> Breslauer et al. 1986, DOI:10.1073/
            pnas.83.11.3746</a> In that case the formula for melting temperature calculation suggested by
        <a href="http://www.pubmedcentral.nih.gov/articlerender.fcgi?tool=pubmed&pubmedid=2243783" target="_blank">
            Rychlik et al. 1990</a> is used (this is used until Primer3 version 1.0.1). This is the default value
            of Primer3 (for backward compatibility).
   </li>
   <li><a href="http://dx.doi.org/10.1073/pnas.95.4.1460" target="_blank">
            SantaLucia 1998, DOI:10.1073/pnas.95.4.1460</a> This is the <i>recommended</i> value.
   </li>
   </ol>
   For specifying the salt correction method for melting temperature calculation see
   <a href="#PRIMER_SALT_CORRECTIONS">Salt correction formula</a>
  </p>

<h3><a name="PRIMER_PRODUCT_TM">Product T<sub>m</sub></a></h3>
  <p>The minimum, optimum, and maximum melting temperature of the amplicon.  Primer3 will not pick a product with melting 
    temperature less than min or greater than max. If Opt is supplied and the
    <a href="#PAIR_WT_PRODUCT_TM">Penalty Weights for Product Size</a>
    are non-0 Primer3 will attempt to pick an amplicon with melting temperature close to Opt.<br>
    <br>
    The maximum allowed melting temperature of the amplicon. Primer3 calculates product T<sub>m</sub> calculated using
    the formula from Bolton and McCarthy, PNAS 84:1390 (1962) as presented in Sambrook, Fritsch and Maniatis, Molecular
    Cloning, p 11.46 (1989, CSHL Press).<br>
    <blockquote>T<sub>m</sub> = 81.5 + 16.6(log<sub>10</sub>([Na+])) + .41*(%GC) - 600/length,</blockquote>
    where [Na+] is the molar sodium concentration, (%GC) is the percent of Gs and Cs in the sequence, and length is the
    length of the sequence.<br>
    <br>
    A similar formula is used by the prime primer selection program in GCG (
    <a href="http://www.gcg.com">http://www.gcg.com</a>
    ), which instead uses 675.0 / length in the last term (after F. Baldino, Jr, M.-F. Chesselet, and M.E. Lewis, Methods
    in Enzymology 168:766 (1989) eqn (1) on page 766 without the mismatch and formamide terms).  The formulas here and in
    Baldino et al. assume Na+ rather than K+.  According to J.G. Wetmur, Critical Reviews in BioChem. and Mol. Bio.
    26:227 (1991) 50 mM K+ should be equivalent in these formulae to .2 M Na+.  Primer3 uses the same salt concentration
    value for calculating both the primer melting temperature and the oligo melting temperature.  If you are planning to
    use the PCR product for hybridization later this behavior will not give you the T<sub>m</sub> under hybridization
    conditions.
  </p>
  
<h3><a name="PRIMER_GC_PERCENT">Primer GC%</a></h3>
  <p>Minimum, Optimum, and Maximum percentage of Gs and Cs in any primer.
  </p>
  
<h3><a name="PRIMER_MAX_SELF_ANY">Max Complementarity</a></h3>
  <p>The maximum allowable local alignment score when testing a single primer for (local) self-complementarity and the
    maximum allowable local alignment score when testing for complementarity between left and right primers.  Local
    self-complementarity is taken to predict the tendency of primers to anneal to each other without necessarily causing
    self-priming in the PCR.  The scoring system gives 1.00 for complementary bases, -0.25 for a match of any base 
    (or N) with an N, -1.00 for a mismatch, and -2.00 for a gap. Only single-base-pair gaps are allowed.  For example,
    the alignment<br>
    <pre>
    5' ATCGNA 3'
       || | |
    3' TA-CGT 5'
    </pre>
    is allowed (and yields a score of 1.75), but the alignment
    <pre>
    5' ATCCGNA 3'
       ||  | |
    3' TA--CGT 5'
    </pre>
    is not considered.  Scores are non-negative, and a score of 0.00 indicates that there is no reasonable local
    alignment between two oligos.
  </p>
  
<h3><a name="PRIMER_MAX_SELF_END">Max 3' Complementarity</a></h3>
  <p>The maximum allowable 3'-anchored global alignment score when testing a single primer for self-complementarity, and
    the maximum allowable 3'-anchored global alignment score when testing for complementarity between left and right
    primers.  The 3'-anchored global alignment score is taken to predict the likelihood of PCR-priming primer-dimers, for
    example<br>
    <pre>
    5' ATGCCCTAGCTTCCGGATG 3'
                 ||| |||||
              3' AAGTCCTACATTTAGCCTAGT 5'
    </pre>
    or
    <pre>
    5` AGGCTATGGGCCTCGCGA 3'
                   ||||||
                3' AGCGCTCCGGGTATCGGA 5'
    </pre>
    The scoring system is as for the Max Complementarity argument.  In the examples above the scores are 7.00 and 
    6.00 respectively.  Scores are non-negative, and a score of 0.00 indicates that there is no reasonable 3'-anchored
    global alignment between two oligos.  In order to estimate 3'-anchored global alignments for candidate primers and
    primer pairs, Primer assumes that the sequence from which to choose primers is presented 5'->3'.  It is nonsensical
    to provide a larger value for this parameter than for the Maximum (local) Complementarity parameter because the
    score of a local alignment will always be at least as great as the score of a global alignment.
  </p>

<h3><a name="PRIMER_MAX_POLY_X">Max Poly-X</a></h3>
  <p>The maximum allowable length of a mononucleotide repeat, for example AAAAAA.
  </p>
  
<h3><a name="SEQUENCE_INCLUDED_REGION">Included Region</a></h3>
  <p>A sub-region of the given sequence in which to pick primers.  For example, often the first dozen or so bases of a
    sequence are vector, and should be excluded from consideration. The value for this parameter has the form<br>
    <pre><tt><i>start</i></tt>,<tt><i>length</i></tt></pre>
    where <tt><i>start</i></tt> is the index of the first base to consider, and <tt><i>length</i></tt> is the number
    of subsequent bases in the primer-picking region.
  </p>
  
<h3><a name="SEQUENCE_START_CODON_POSITION">Start Codon Position</a></h3>
  <p>This parameter should be considered EXPERIMENTAL at this point. Please check the output carefully; some erroneous
    inputs might cause an error in Primer3. Index of the first base of a start codon.  This parameter allows Primer3
    to select primer pairs to create in-frame amplicons e.g. to create a template for a fusion protein.  Primer3 will
    attempt to select an in-frame left primer, ideally starting at or to the left of the start codon, or to the right
    if necessary. Negative values of this parameter are legal if the actual start codon is to the left of available
    sequence. If this parameter is non-negative Primer3 signals an error if the codon at the position specified by
    this parameter is not an ATG.  A value less than or equal to -10^6 indicates that Primer3 should ignore this 
    parameter.<br>
    <br>
    Primer3 selects the position of the right primer by scanning right from the left primer for a stop codon.  Ideally
    the right primer will end at or after the stop codon.
  </p>
  
<h3><a name="PRIMER_MISPRIMING_LIBRARY">Mispriming Library</a></h3>
  <p>This selection indicates what mispriming library (if any) Primer3 should use to screen for interspersed repeats or
    for other sequence to avoid as a location for primers. The human and rodent libraries on the web page are adapted
    from Repbase (J. Jurka, A.F.A. Smit, C. Pethiyagoda, et al., 1995-1996)
    <a href="ftp://ftp.ncbi.nih.gov/repository/repbase">ftp://ftp.ncbi.nih.gov/repository/repbase</a>
    . The human library is humrep.ref concatenated with simple.ref, translated to FASTA format.  There are two rodent
    libraries. One is rodrep.ref translated to FASTA format, and the other is rodrep.ref concatenated with simple.ref,
    translated to FASTA format.<br>
    <br>
    The <i>Drosophila</i> library is the concatenation of two libraries from the 
    <a href="http://www.fruitfly.org">Berkeley Drosophila Genome Project</a>:<br>
    <ol>
    <li> A library of transposable elements
    <a href="http://genomebiology.com/2002/3/12/research/0084"><i>The transposable elements of the Drosophila melanogaster
    euchromatin - a genomics perspective</i> J.S. Kaminker, C.M. Bergman, B. Kronmiller, J. Carlson, R. Svirskas,
    S. Patel, E. Frise, D.A. Wheeler, S.E. Lewis, G.M. Rubin, M. Ashburner and S.E. Celniker Genome Biology (2002)
    3(12):research0084.1-0084.20</a>, 
    <a href="http://www.fruitfly.org/p_disrupt/datasets/ASHBURNER/D_mel_transposon_sequence_set.fasta">
    http://www.fruitfly.org/p_disrupt/datasets/ASHBURNER/D_mel_transposon_sequence_set.fasta<a/><br><br>
    </li>
    <li> A library of repetitive DNA sequences <a href="http://www.fruitfly.org/sequence/sequence_db/na_re.dros">
    http://www.fruitfly.org/sequence/sequence_db/na_re.dros</a>.
    </li>
    </ol>
    Both were downloaded 6/23/04.<br>
    <br>
    The contents of the libraries can be viewed at the following links:
    <ul>
    <li> <a href="cat_humrep_and_simple.cgi">HUMAN</a> (contains microsatellites)
    </li>
    <li> <a href="cat_rodrep_and_simple.cgi">RODENT_AND_SIMPLE</a> (contains microsatellites)
    </li>
    <li> <a href="cat_rodent_ref.cgi">RODENT</a> (does not contain microsatellites)
    </li>
    <li> <a href="cat_drosophila.cgi">DROSOPHILA</a>
    </ul>
  </p>

<h3><a name="PRIMER_GC_CLAMP">CG Clamp</a></h3>
  <p>Require the specified number of consecutive Gs and Cs at the 3' end of both the left and right primer.  (This
    parameter has no effect on the hybridization oligo if one is requested.)
  </p>

<h3><a name="PRIMER_SALT_MONOVALENT">Concentration of monovalent cations</a></h3>
  <p>The millimolar concentration of salt (usually KCl) in the PCR. Primer3 uses this argument to calculate oligo
    melting temperatures.
  </p>

<h3><a name="PRIMER_SALT_DIVALENT">Concentration of divalent cations</a></h3>
  <p>The millimolar concentration of divalent salt cations (usually MgCl<sup>2+</sup> in the PCR). Primer3 converts
    concentration of divalent cations to concentration of monovalent cations using formula suggested in the paper 
    <a href="http://www.clinchem.org/cgi/content/full/47/11/1956" target="blank"> Ahsen et al., 2001</a>
    <br>
    <pre>                     [Monovalent cations] = [Monovalent cations] + 120*(&#8730;([divalent cations] - [dNTP])) </pre>

    According to the formula concentration of desoxynucleotide triphosphate [dNTP] must be smaller than concentration
    of divalent cations. The concentration of dNTPs is included to the formula beacause of some magnesium is bound by
    the dNTP. Attained concentration of monovalent cations is used to calculate oligo/primer melting temperature. See
    <a href="#PRIMER_DNTP_CONC"> Concentration of dNTPs</a> to specify the concentration of dNTPs.
  </p>

<h3><a name="PRIMER_DNTP_CONC">Concentration of dNTPs</a></h3>
  <p>The millimolar concentration of deoxyribonucleotide triphosphate. This argument is considered only if
    <a href="#PRIMER_SALT_DIVALENT">Concentration of divalent cations</a> is specified.
  </p>

<h3><a name="PRIMER_SALT_CORRECTIONS">Salt correction formula</a></h3>
  <p>Option for specifying the salt correction formula for the melting temperature calculation. <br><br>
    <ol>There are three different options available:
    <li><a href="http://dx.doi.org/10.1002/bip.360030207" target="_blank"> Schildkraut and Lifson 1965, DOI:10.1002/bip.360030207</a>
        (this is used until the version 1.0.1 of Primer3).The default value of Primer3 version 1.1.0 (for backward compatibility)</li>
    <li><a href="http://dx.doi.org/10.1073/pnas.95.4.1460" target="_blank">SantaLucia 1998, DOI:10.1073/pnas.95.4.1460</a> 
        This is the <i>recommended</i> value.</li>
    <li><a href="http://dx.doi.org/10.1021/bi034621r" target="_blank">Owczarzy et al. 2004, DOI:10.1021/bi034621r</a></li>
    </ol>
  </p>

<h3><a name="PRIMER_DNA_CONC">Annealing Oligo Concentration</a></h3>
  <p>The nanomolar concentration of annealing oligos in the PCR. Primer3 uses this argument to calculate oligo melting
    temperatures.  The default (50nM) works well with the standard protocol used at the Whitehead/MIT Center for
    Genome Research--0.5 microliters of 20 micromolar concentration for each primer oligo in a 20 microliter reaction
    with 10 nanograms template, 0.025 units/microliter Taq polymerase in 0.1 mM each dNTP, 1.5mM MgCl2, 50mM KCl,
    10mM Tris-HCL (pH 9.3) using 35 cycles with an annealing temperature of 56 degrees Celsius.  This parameter
    corresponds to 'c' in Rychlik, Spencer and Rhoads' equation (ii) (Nucleic Acids Research, vol 18, num 21) where
    a suitable value (for a lower initial concentration of template) is &quot;empirically determined&quot;.  The value
    of this parameter is less than the actual concentration of oligos in the reaction because it is the concentration
    of annealing oligos, which in turn depends on the amount of template (including PCR product) in a given cycle.
    This concentration increases a great deal during a PCR; fortunately PCR seems quite robust for a variety of
    oligo melting temperatures.
  </p>

<h3><a name="PRIMER_MAX_NS_ACCEPTED">Max Ns Accepted</a></h3>
  <p>Maximum number of unknown bases (N) allowable in any primer.
  </p>

<h3><a name="PRIMER_LIBERAL_BASE">Liberal Base</a></h3>
  <p>This parameter provides a quick-and-dirty way to get Primer3 to accept IUB / IUPAC codes for ambiguous bases (i.e.
    by changing all unrecognized bases to N).  If you wish to include an ambiguous base in an oligo, you must set
    <a href=#PRIMER_MAX_NS_ACCEPTED>Max Ns Accepted</a> to a non-0 value. Perhaps '-' and '* ' should be squeezed
    out rather than changed to 'N', but currently they simply get converted to N's.  The authors invite user comments.
  </p>

<h3><a name="PRIMER_FIRST_BASE_INDEX">First Base Index</a></h3>
  <p>The index of the first base in the input sequence.  For input and output using 1-based indexing (such as that
    used in GenBank and to which many users are accustomed) set this parameter to 1.  For input and output using
    0-based indexing set this parameter to 0.  (This parameter also affects the indexes in the contents of the
    files produced when the primer file flag is set.) In the WWW interface this parameter defaults to 1.
  </p>

<h3><a name="PRIMER_INSIDE_PENALTY">Inside Target Penalty</a></h3>
  <p>Non-default values valid only for sequences with 0 or 1 target regions.  If the primer is part of a pair
    that spans a target and overlaps the target, then multiply this value times the number of nucleotide positions
    by which the primer overlaps the (unique) target to get the 'position penalty'.  The effect of this parameter
    is to allow Primer3 to include overlap with the target as a term in the objective function.
  </p>

<h3><a name="PRIMER_OUTSIDE_PENALTY">Outside Target Penalty</a></h3>
  <p>Non-default values valid only for sequences with 0 or 1 target regions.  If the primer is part of a pair that
    spans a target and does not overlap the target, then multiply this value times the number of nucleotide
    positions from the 3' end to the (unique) target to get the 'position penalty'. The effect of this parameter
    is to allow Primer3 to include nearness to the target as a term in the objective function.
  </p>

<h3><a name=SHOW_DEBUGGING>Show Debuging Info</a></h3>
  <p>Include the input to primer3_core as part of the output.
  </p>
  
<h3><a name="PRIMER_LOWERCASE_MASKING">Lowercase masking</a></h3>
  <p>If checked candidate primers having lowercase letter exactly at 3' end are rejected. This option allows to
    design primers overlapping lowercase-masked regions. This property relies on the assumption that masked 
    features (e.g. repeats) can partly overlap primer, but they cannot overlap the 3'-end of the primer. In other
    words, the lowercase letters in other positions are accepted, assuming that the masked features do not influence
    the primer performance if they do not overlap the 3'-end of primer.
  </p>

<h2><a name=SEQUENCE_QUALITY>Sequence Quality</a></h2>

<h3><a name="SEQUENCE_QUALITY">Sequence Quality</a></h3>
  <p>A list of space separated integers. There must be exactly one integer for each base in the Source Sequence if this
    argument is non-empty. High numbers indicate high confidence in the base call at that position and low numbers
    indicate low confidence in the base call at that position.
  </p>

<h3><a name="PRIMER_MIN_QUALITY">Min Sequence Quality</a></h3>
  <p>The minimum sequence quality (as specified by Sequence Quality) allowed within a primer.
  </p>
  
<h3><a name="PRIMER_MIN_END_QUALITY">Min 3' Sequence Quality</a></h3>
  <p>The minimum sequence quality (as specified by Sequence Quality) allowed within the 3' pentamer of a primer.
  </p>
  
<h3><a name="PRIMER_QUALITY_RANGE_MIN">Sequence Quality Range Min</a></h3>
  <p>The minimum legal sequence quality (used for interpreting Min Sequence Quality and Min 3' Sequence Quality).
  </p>
  
<h3><a name="PRIMER_QUALITY_RANGE_MAX">Sequence Quality Range Max</a></h3>
  <p>The maximum legal sequence quality (used for interpreting Min Sequence Quality and Min 3' Sequence Quality).
  </p>


<h2><a name="generic_penalty_weights">Penalty Weights</a></h2>
  <p>This section describes "penalty weights", which allow the user to modify the criteria that Primer3 uses to select
    the "best" primers.  There are two classes of weights: for some parameters there is a 'Lt' (less than) and a
    'Gt' (greater than) weight.  These are the weights that Primer3 uses when the value is less or greater than
    (respectively) the specified optimum. The following parameters have both 'Lt' and 'Gt' weights:
    <ul>
    <li> Product Size </li>
    <li> Primer Size </li>
    <li> Primer T<sub>m</sub> </li>
    <li> Product T<sub>m</sub> </li>
    <li> Primer GC% </li>
    <li> Hyb Oligo Size </li>
    <li> Hyb Oligo T<sub>m</sub> </li>
    <li> Hyb Oligo GC% </li>
    </ul>
    The <a href="#PRIMER_INSIDE_PENALTY">Inside Target Penalty</a> and <a href="#PRIMER_OUTSIDE_PENALTY">Outside
    Target Penalty</a> are similar, except that since they relate to position they do not lend them selves to the
    'Lt' and 'Gt' nomenclature.<br>
    <br>
    For the remaining parameters the optimum is understood and the actual value can only vary in one direction from
    the optimum:<br>
    <br>
    <ul>
    <li>Primer Self Complementarity </li>
    <li>Primer 3' Self Complementarity </li>
    <li>Primer #N's </li>
    <li>Primer Mispriming Similarity </li>
    <li>Primer Sequence Quality </li>
    <li>Primer 3' Sequence Quality </li>
    <li>Primer 3' Stability </li>
    <li>Hyb Oligo Self Complementarity </li>
    <li>Hyb Oligo 3' Self Complementarity </li>
    <li>Hyb Oligo Mispriming Similarity </li>
    <li>Hyb Oligo Sequence Quality </li>
    <li>Hyb Oligo 3' Sequence Quality </li>
    </ul>
    The following are weights are treated specially:<br>
    <br>
    Position Penalty Weight<br>
    &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; Determines the overall weight of the position penalty in calculating 
    the penalty for a primer.<br><br>
    Primer Weight<br>
    &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; Determines the weight of the 2 primer penalties in calculating the
    primer pair penalty.<br><br>
    Hyb Oligo Weight<br>
    &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; Determines the weight of the hyb oligo penalty in calculating the
    penalty of a primer pair plus hyb oligo.<br><br>
    <br>
    The following govern the weight given to various parameters of primer pairs (or primer pairs plus hyb oligo).
    <ul>
    <li>T<sub>m</sub> difference </li>
    <li>Primer-Primer Complementarity </li>
    <li>Primer-Primer 3' Complementarity </li>
    <li>Primer Pair Mispriming Similarity </li>
    </ul>
  </p>


<h2><a name="internal_oligo_generic">Hyb Oligos (Internal Oligos)</a></h2>
  <p>Parameters governing choice of internal oligos are analogous to the parameters governing choice of primer pairs.
    The exception is Max 3' Complementarity which is meaningless when applied to internal oligos used for
    hybridization-based detection, since primer-dimer will not occur.  We recommend that Max 3' Complementarity 
    be set at least as high as Max Complementarity.
  </p>
</div>

<div id="primer3plus_footer">
   <br>
   More about <a href="$machineSettings{URL_ABOUT}">Primer3Plus</a>...

</div>

</div>	
};

  my $returnString = $templateText;

  $returnString =~ s/<!-- Primer3plus will include code here -->/$formHTML/;

  return $returnString;
}

#####################################################################################
# createAboutHTML: Will write an HTML-Form containing information about Primer3plus #
#####################################################################################

sub createAboutHTML {
  my $templateText = getWrapper();

  my $formHTML = qq{
<div id="primer3plus_complete">
};
$formHTML .= divTopBar("About");

$formHTML .= divMessages();

$formHTML .= qq{
<div id="primer3plus_about">

<h1>Primer3Plus is a web-interface for primer3</h1>

<h2>Primer3Plus</h2>
<h3>Primer3Plus - Download Primer3Plus Program and Source Code</h3>
<p>
<a href="http://sourceforge.net/projects/primer3/">
Source code is available at http://sourceforge.net/projects/primer3/.
</a>
</p>

<h3>Primer3Plus - Copyright Notice and Disclaimer</h3>
<p>
Copyright (c) 2006, 2007<br>
by Andreas Untergasser and Harm Nijveen<br>
All rights reserved.<br>
<br>
The Primer3Plus is free software; you can redistribute it and/or modify<br>
it under the terms of the GNU General Public License as published by<br>
the Free Software Foundation; either version 2 of the License, or<br>
(at your option) any later version.<br>
<br>
Primer3Plus is distributed in the hope that it will be useful,<br>
but WITHOUT ANY WARRANTY; without even the implied warranty of<br>
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the<br>
GNU General Public License for more details.<br>
<br>
To received a copy of the GNU General Public License<br>
write to the Free Software Foundation, Inc., 51 Franklin St,<br>
Fifth Floor, Boston, MA  02110-1301  USA<br>
<br>

<h3>Citing Primer3Plus</h3>
<p>
Andreas Untergasser, Harm Nijveen, Xiangyu Rao, Ton Bisseling, Ren&eacute; Geurts, and Jack A.M. Leunissen: 
<b>Primer3Plus, an enhanced web interface to Primer3</b> Nucleic Acids Research 2007 35: W71-W74; doi:10.1093/nar/gkm306
</p>

<h3>Acknowledgments of Primer3Plus</h3>
<p>
We thank Gerben Bijl for extensive beta-testing.
</p>

<h2>Primer3</h2>

<h3>Primer3 - Alternative Web Interface</h3>
<p>
<a href="http://primer3.sourceforge.net/webif.php">http://primer3.sourceforge.net/webif.php</a>
</p>

<h3>Primer3 - Download Primer3 Program and Source Code</h3>
<p>
<a href="http://sourceforge.net/projects/primer3/">
Source code available at http://sourceforge.net/projects/primer3/.
</a>
</p>

<h3>Primer3 - Copyright Notice and Disclaimer</h3>
<p>
Copyright (c) 1996,1997,1998,1999,2000,2001,2004,2006<br>
Whitehead
Institute for Biomedical Research, 
<a href="http://jura.wi.mit.edu/rozen/">Steve Rozen</a>, and Helen Skaletsky<br>
All rights reserved.
</p>
<pre>
Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are
met:

   * Redistributions of source code must retain the above copyright
notice, this list of conditions and the following disclaimer.
   * Redistributions in binary form must reproduce the above
copyright notice, this list of conditions and the following disclaimer
in the documentation and/or other materials provided with the
distribution.
   * Neither the names of the copyright holders nor contributors may
be used to endorse or promote products derived from this software
without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
OWNERS OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
</pre>


<h3>Citing Primer3</h3>
<p>
We request that use of this software be cited in publications as
</p>
<p>
<a href="http://jura.wi.mit.edu/rozen/">Steve Rozen</a>
and Helen J. Skaletsky (2000)
<a href="http://jura.wi.mit.edu/rozen/papers/rozen-and-skaletsky-2000-primer3.pdf">
Primer3 on the WWW for general users and for biologist programmers.
</a>
In: Krawetz S, Misener S (eds)
<i>Bioinformatics Methods and Protocols: Methods in Molecular Biology.</i>
Humana Press, Totowa, NJ, pp 365-386<br>
</p>

<h3>Acknowledgments of Primer3</h3>
<p>
The development of Primer3 and the Primer3
web site was funded by 
Howard Hughes Medical Institute
and by the 
National Institutes of Health,
<a href="http://www.nhgri.nih.gov/">
National Human Genome Research Institute.</a>
under grants R01-HG00257
(to David C. Page) and P50-HG00098 (to Eric S. Lander).
</p>

<p>
We thank
<a href="http://www.centerline.com">
Centerline Software, Inc.,
</a>
for use of their TestCenter memory-error, -leak, and test-coverage checker.
</p>
<p>
Primer3 was a complete re-implementation
of an earlier program:
Primer 0.5 (<em>Steve Lincoln, Mark Daly, and Eric S. Lander</em>).
<em>Lincoln Stein</em> championed the 
idea of making Primer3 a software component suitable for high-throughput
primer design.
</p>

</div>

</div>	
};

  my $returnString = $templateText;

  $returnString =~ s/<!-- Primer3plus will include code here -->/$formHTML/;

  return $returnString;
}


####################################################################################
# createResultsDetection: Will write an HTML-Form based for the detection Function #
####################################################################################
sub createResultsDetection {
  my $completeParameters; 
  my %settings;
  $completeParameters = shift; 
  %settings = %{(shift)};

  my $HashKeys;

  my $templateText = getWrapper();

  if (defined ($settings{PRIMER_ERROR}) and (($settings{PRIMER_ERROR}) ne "")) {
      setMessage("$settings{PRIMER_ERROR}");
  }
  if (defined ($settings{PRIMER_WARNING}) and (($settings{PRIMER_WARNING}) ne "")) {
      setMessage("$settings{PRIMER_WARNING}");
  }

  my $formHTML = qq{
<div id="primer3plus_complete">
};
$formHTML .= divTopBar("Default");

$formHTML .= divMessages();

$formHTML .= qq{
<div id="primer3plus_results">
};

$formHTML .= divReturnToInput($completeParameters);

$formHTML .= qq{
<form action="$machineSettings{URL_PRIMER_MANAGER}" method="post" enctype="multipart/form-data" target="primer3manager">

};

$formHTML .= divPrimerBox(\%settings,"0","1");

$formHTML .= qq{<div class="primer3plus_submit">
<input name="Submit" value="Send to Primer3Manager" type="submit"> <input value="Reset Form" type="reset">
</div>
};

$formHTML .= divHTMLsequence(\%settings, "1");

$formHTML .= qq{ <div class="primer3plus_select_all">
<br>
<input name="SELECT_ALL_PRIMERS" value="1" type="checkbox"> &nbsp; Select all Primers<br>
<br>
</div>
};

for (my $primerCount = 1 ; $primerCount < $settings{"PRIMER_NUM_RETURN"} ; $primerCount++) {
    $formHTML .= divPrimerBox(\%settings,$primerCount,"0");

    $formHTML .= qq{<div class="primer3plus_submit">
<br>
<input name="Submit" value="Send to Primer3Manager" type="submit"> <input value="Reset Form" type="reset">
<br>
<br>
<br>
</div>
};
}

$formHTML .= divStatistics(\%settings);

$formHTML .= qq{<div id="primer3plus_footer">
<br>

More about <a href="$machineSettings{URL_ABOUT}">Primer3Plus</a>...

</div>

</form>

</div>	
};

  my $returnString = $templateText;

  $returnString =~ s/<!-- Primer3plus will include code here -->/$formHTML/;

  return $returnString;
}

###################################################################################
# createResultsPrimerCheck: Will write an HTML-Form for the check Primer Function #
###################################################################################

sub createResultsPrimerCheck {
  my $completeParameters; 
  my %settings;
  $completeParameters = shift; 
  %settings = %{(shift)};

  my $results = \%settings;

  my $HashKeys;

  my $templateText = getWrapper();

  if (defined ($settings{PRIMER_ERROR}) and (($settings{PRIMER_ERROR}) ne "")) {
      setMessage("$settings{PRIMER_ERROR}");
  }
  if (defined ($settings{PRIMER_WARNING}) and (($settings{PRIMER_WARNING}) ne "")) {
      setMessage("$settings{PRIMER_WARNING}");
  }
  
  my $formHTML = qq{
<div id="primer3plus_complete">
};

$formHTML .= divTopBar("Default");

$formHTML .= divMessages();

$formHTML .= qq{
<div id="primer3plus_results">
};

$formHTML .= divReturnToInput($completeParameters);

$formHTML .= qq{
<form action="$machineSettings{URL_PRIMER_MANAGER}" method="post" enctype="multipart/form-data">

};

  my $primerStart;
  my $primerLength;
  my $primerTM;
  my $primerGC;
  my $primerSelf;
  my $primerAny;
  my $primerEnd;
  my $primerStab;
  my $primerNumber = getPrimerNumber();

$formHTML .= qq{  <div class="primer3plus_oligo_box">
  <table class="primer3plus_table_no_border">
     <colgroup>
       <col width="15%">
       <col width="85%">
     </colgroup>
     <tr class="primer3plus_left_primer">
       <td class="primer3plus_cell_no_border"><input name="PRIMER_$primerNumber\_SELECT" value="1" checked="checked" type="checkbox"> &nbsp; Oligo:</td>
       <td class="primer3plus_cell_no_border"><input name="PRIMER_$primerNumber\_NAME" value="$results->{"PRIMER_LEFT_0_NAME"}" size="40"></td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border">Sequence:</td>
       <td class="primer3plus_cell_no_border"><input name="PRIMER_$primerNumber\_SEQUENCE" value="$results->{"PRIMER_LEFT_0_SEQUENCE"}" size="90"></td>
     </tr>
};

  ($primerStart, $primerLength) = split "," , $results->{"PRIMER_LEFT_0"};
  $primerTM = sprintf ("%.1f",($results->{"PRIMER_LEFT_0_TM"}));
  $primerGC = sprintf ("%.1f",($results->{"PRIMER_LEFT_0_GC_PERCENT"}));
  $primerSelf = sprintf ("%.1f",($results->{"PRIMER_LEFT_0_SELF_ANY"}));
  $primerAny = sprintf ("%.1f",($results->{"PRIMER_LEFT_0_SELF_END"}));
  $primerStab = sprintf ("%.1f",($results->{"PRIMER_LEFT_0_END_STABILITY"}));

$formHTML .= qq{     <tr>
       <td class="primer3plus_cell_no_border">Length:</td>
       <td class="primer3plus_cell_no_border">$primerLength bp</td>
     <tr>
     </tr>
       <td class="primer3plus_cell_no_border">Tm:</td>
       <td class="primer3plus_cell_no_border">$primerTM &deg;C </td>
     <tr>
     </tr>
       <td class="primer3plus_cell_no_border">GC:</td>
       <td class="primer3plus_cell_no_border">$primerGC %</td>
     <tr>
     </tr>
       <td class="primer3plus_cell_no_border">ANY:</td>
       <td class="primer3plus_cell_no_border">$primerSelf</td>
     <tr>
     </tr>
       <td class="primer3plus_cell_no_border">SELF:</td>
       <td class="primer3plus_cell_no_border">$primerAny</td>
     </tr>
     </tr>
       <td class="primer3plus_cell_no_border">3' Stability:</td>
       <td class="primer3plus_cell_no_border">$primerStab &Delta;G</td>
     </tr>
};

if (defined ($results->{"PRIMER_LEFT_0_MISPRIMING_SCORE"}) 
		and (($results->{"PRIMER_LEFT_0_MISPRIMING_SCORE"}) ne "")) {

$formHTML .= qq{     <tr>
       <td class="primer3plus_cell_no_border">Mispriming:</td>
       <td class="primer3plus_cell_no_border">$results->{"PRIMER_LEFT_0_MISPRIMING_SCORE"}</td>
     </tr>
};
}

$formHTML .= qq{  </table>
  </div>
};


$formHTML .= qq{<div class="primer3plus_submit">
<br>
<input name="Submit" value="Send to Primer3Manager" type="submit"> <input value="Reset Form" type="reset">
</div>
};

$formHTML .= qq{<br>
</div>


</form>

</div>	
};

  my $returnString = $templateText;

  $returnString =~ s/<!-- Primer3plus will include code here -->/$formHTML/;

  return $returnString;
}

############################################################
# divReturnToInput: Create a return to Input screen Button #
############################################################
sub divReturnToInput {
  my %settings; 
  %settings = %{(shift)};

  my $HashKeys;

  my $formHTML = qq{
<div id="primer3plus_return_to_input_button">
<form action="$machineSettings{URL_FORM_ACTION}" method="post" enctype="multipart/form-data">
};

foreach $HashKeys (sort(keys(%settings))){
	if ($HashKeys ne "Pick_Primers") {
    	$formHTML .= qq{
    <input type="hidden" name="$HashKeys" value="$settings{$HashKeys}">};

	};
};

$formHTML .= qq{
<input id="primer3plus_return_to_pick_primers_button" class="primer3plus_action_button" name="Return_To_Pick_Primers" value="< Back" type="submit">
</form>

</div>	
};

  return $formHTML;
}

####################################################################################
# createResultsList: Will write an HTML-Form for the Parameters in the Result Hash #
####################################################################################
sub createResultsList {
  my %settings; 
  %settings = %{(shift)};

  my $results = \%settings;

  my $HashKeys;

  my $templateText = getWrapper();

  if (defined ($settings{PRIMER_ERROR}) and (($settings{PRIMER_ERROR}) ne "")) {
      setMessage("$settings{PRIMER_ERROR}");
  }
  if (defined ($settings{PRIMER_WARNING}) and (($settings{PRIMER_WARNING}) ne "")) {
      setMessage("$settings{PRIMER_WARNING}");
  }

  my $formHTML = qq{
<div id="primer3plus_complete">

<form action="$machineSettings{URL_PRIMER_MANAGER}" method="post" enctype="multipart/form-data">
};
$formHTML .= divTopBar("Default");

$formHTML .= divMessages();

$formHTML .= qq{
<div id="primer3plus_results">
<table class="primer3plus_table_no_border">
      <colgroup>
        <col width="40%">
        <col width="60%">
      </colgroup>
    <tr>
      <td class="primer3plus_cell_no_border">Parameter</td>
      <td class="primer3plus_cell_no_border">Value</td>
    <tr>
};

foreach $HashKeys (sort(keys(%settings))){
    $formHTML .= qq{
     <tr>
       <td class="primer3plus_cell_no_border">$HashKeys</td>
       <td class="primer3plus_cell_no_border">$settings{$HashKeys}</td>
     </tr>};
};
$formHTML .= qq{
   </table>
</div>

<div id="primer3plus_footer">
<br>

More about <a href="$machineSettings{URL_ABOUT}">Primer3Plus</a>...

</div>

</form>

</div>	
};

  my $returnString = $templateText;

  $returnString =~ s/<!-- Primer3plus will include code here -->/$formHTML/;

  return $returnString;
}

################################################################################
# createResultsPrimerList: Will write an Tabels all Primers in the Result Hash #
################################################################################
sub createResultsPrimerList {
  my ($completeParameters, %settings, $sortedInput) ; 
  $completeParameters = shift; 
  %settings = %{(shift)};
  $sortedInput = shift;

  my $templateText = getWrapper();

  if (defined ($settings{PRIMER_ERROR}) and (($settings{PRIMER_ERROR}) ne "")) {
      setMessage("$settings{PRIMER_ERROR}");
  }
  if (defined ($settings{PRIMER_WARNING}) and (($settings{PRIMER_WARNING}) ne "")) {
      setMessage("$settings{PRIMER_WARNING}");
  }

  my $formHTML = qq{
<div id="primer3plus_complete">
};
$formHTML .= divTopBar("Default");

$formHTML .= divMessages();

$formHTML .= qq{<div id="primer3plus_results">
};

$formHTML .= divReturnToInput($completeParameters);

$formHTML .= qq{
<form action="$machineSettings{URL_PRIMER_MANAGER}" method="post" enctype="multipart/form-data" target="primer3manager">
};

if ($sortedInput == 0){
   $formHTML .= divHTMLsequence(\%settings, "0");
}
else {
   $formHTML .= divHTMLsequence(\%settings, "-1");
}

$formHTML .= qq{   <div class="primer3plus_select_all">
   <input id="SELECT_ALL_PRIMERS" name="SELECT_ALL_PRIMERS" value="1" type="checkbox"> &nbsp; Select all Primers &nbsp;
   </div>
   <div class="primer3plus_submit">
   &nbsp;<input name="Submit" value="Send to Primer3Manager" type="submit"> <input value="Reset Form" type="reset">
   <br>
   <br>
   </div>
};

 if (defined ($settings{PRIMER_LEFT_0_SEQUENCE})) {
     $formHTML .= qq{<h2 class="primer3plus_left_primer">Left Primers:</h2>
};
     $formHTML .= divLongList(\%settings,"LEFT",$sortedInput);

     $formHTML .= qq{<br>
};

     $formHTML .= qq{<div class="primer3plus_submit">
<br>
<input name="Submit" value="Send to Primer3Manager" type="submit"> <input value="Reset Form" type="reset">
<br>
<br>
<br>
</div>
};  }

 if (defined ($settings{PRIMER_INTERNAL_OLIGO_0_SEQUENCE})) {
     $formHTML .= qq{<h2 class="primer3plus_internal_oligo">Internal Oligos:</h2>
};
     $formHTML .= divLongList(\%settings,"INTERNAL_OLIGO",$sortedInput);

     $formHTML .= qq{<br>
};

     $formHTML .= qq{<div class="primer3plus_submit">
<br>
<input name="Submit" value="Send to Primer3Manager" type="submit"> <input value="Reset Form" type="reset">
<br>
<br>
<br>
</div>
};
  }
 
 if (defined ($settings{PRIMER_RIGHT_0_SEQUENCE})) {
     $formHTML .= qq{<h2 class="primer3plus_right_primer">Right Primers:</h2>
};
     $formHTML .= divLongList(\%settings,"RIGHT",$sortedInput);

     $formHTML .= qq{<br>
};

     $formHTML .= qq{<div class="primer3plus_submit">
<br>
<input name="Submit" value="Send to Primer3Manager" type="submit"> <input value="Reset Form" type="reset">
<br>
<br>
<br>
</div>
};
  }

$formHTML .= qq{<div id="primer3plus_footer">
<br>

More about <a href="$machineSettings{URL_ABOUT}">Primer3Plus</a>...

</div>

</form>

</div>	
};

  my $returnString = $templateText;

  $returnString =~ s/<!-- Primer3plus will include code here -->/$formHTML/;

  return $returnString;
}

sub divLongList {
  my ($formHTML, $results, $primerType, $sortedInput);
  $results = shift;
  $primerType = shift;
  $sortedInput = shift;


  $formHTML = qq{
  <div class="primer3plus_long_list">
   <table class="primer3plus_long_list_table">
     <colgroup>
       <col style="width:20%">
       <col style="width:38%">
       <col style="width:6%; text-align:right">
       <col style="width:8%; text-align:right">
       <col style="width:7%; text-align:right">
       <col style="width:7%; text-align:right">
       <col style="width:7%; text-align:right">
       <col style="width:7%; text-align:right">
     </colgroup>
     <tr>
       <td class="primer3plus_cell_long_list">&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; Name</td>
       <td class="primer3plus_cell_long_list">Sequence</td>
       <td class="primer3plus_cell_long_list">Start</td>
       <td class="primer3plus_cell_long_list">Length</td>
       <td class="primer3plus_cell_long_list">Tm</td>
       <td class="primer3plus_cell_long_list">GC %</td>
       <td class="primer3plus_cell_long_list">ANY</td>
       <td class="primer3plus_cell_long_list">END</td>
     <tr>
};

  my $primerStart;
  my $primerLength;
  my $primerTM;
  my $primerGC;
  my $primerSelf;
  my $primerEnd;
  my $stopLoop;
  my $primerNumber;

  my $counter = 0;
  for ($stopLoop = 0 ; $stopLoop ne 1 ; ) {
      ($primerStart, $primerLength) = split "," , $results->{"PRIMER_$primerType\_$counter"};
      $primerTM = sprintf ("%.1f",($results->{"PRIMER_$primerType\_$counter\_TM"}));
      $primerGC = sprintf ("%.1f",($results->{"PRIMER_$primerType\_$counter\_GC_PERCENT"}));
      $primerSelf = sprintf ("%.1f",($results->{"PRIMER_$primerType\_$counter\_SELF_ANY"}));
      $primerEnd = sprintf ("%.1f",($results->{"PRIMER_$primerType\_$counter\_SELF_END"}));
      $primerNumber = getPrimerNumber();

      $formHTML .= qq{     <tr>
       <td class="primer3plus_cell_long_list"><input id="PRIMER_$primerNumber\_SELECT" name="PRIMER_$primerNumber\_SELECT" value="1" type="checkbox">
       &nbsp; &nbsp;<input id="PRIMER_$primerNumber\_NAME" name="PRIMER_$primerNumber\_NAME"
           value="$results->{"PRIMER_$primerType\_$counter\_NAME"}" size="12"></td>
       <td class="primer3plus_cell_long_list"><input id="PRIMER_$primerNumber\_SEQUENCE" name="PRIMER_$primerNumber\_SEQUENCE"
         value="$results->{"PRIMER_$primerType\_$counter\_SEQUENCE"}" size="35"></td>
       <td class="primer3plus_cell_long_list">$primerStart</td>
       <td class="primer3plus_cell_long_list">$primerLength</td>
       <td class="primer3plus_cell_long_list">$primerTM</td>
       <td class="primer3plus_cell_long_list">$primerGC</td>
       <td class="primer3plus_cell_long_list">$primerSelf</td>
       <td class="primer3plus_cell_long_list">$primerEnd</td>
     </tr>
};
      $counter++;
      
      if (!(defined ($results->{"PRIMER_$primerType\_$counter\_SEQUENCE"}))) {
          $stopLoop = 1;
      }

      if ($counter eq 10000) {
          $stopLoop = 1;
      }
  }

$formHTML .= qq{
   </table>
  </div>
};

  return $formHTML;
}

####################################################
# divPrimerBox: Creates a box with one primer pair #
####################################################
sub divPrimerBox {
  my ($results, $counter, $selection, $checked) ; 
  $results = shift;
  $counter = shift;
  $checked = shift;

  $selection = $counter + 1;

  my $primerAny;
  my $primerEnd;
  my $primerTM;

  my $formHTML = qq{  <div class="primer3plus_primer_pair_box">
  <table class="primer3plus_table_primer_pair_box">
     <colgroup>
       <col width="16%">
       <col width="16%">
       <col width="16%">
       <col width="16%">
       <col width="16%">
       <col width="16%">
     </colgroup>
     <tr>
       <td class="primer3plus_cell_primer_pair_box">Pair $selection:</td>
       <td class="primer3plus_cell_primer_pair_box"></td>
       <td class="primer3plus_cell_primer_pair_box"></td>
       <td class="primer3plus_cell_primer_pair_box"></td>
       <td class="primer3plus_cell_primer_pair_box"></td>
       <td class="primer3plus_cell_primer_pair_box"></td>
     </tr>
};

$formHTML .= partPrimerData( $results, $counter, "LEFT", $checked);

$formHTML .= partPrimerData( $results, $counter, "INTERNAL_OLIGO", $checked);

$formHTML .= partPrimerData( $results, $counter, "RIGHT", $checked);

if ((defined ($results->{"PRIMER_PAIR\_$counter\_COMPL_ANY"})) 
		and (($results->{"PRIMER_PAIR\_$counter\_COMPL_ANY"}) ne "")
		and (defined ($results->{"PRIMER_PAIR\_$counter\_COMPL_END"}))
		and (($results->{"PRIMER_PAIR\_$counter\_COMPL_END"}) ne "")) {

$primerAny = sprintf ("%.1f",($results->{"PRIMER_PAIR\_$counter\_COMPL_ANY"}));
$primerEnd = sprintf ("%.1f",($results->{"PRIMER_PAIR\_$counter\_COMPL_END"}));

$formHTML .= qq{     <tr class="primer3plus_primer_pair">
       <td colspan="2" class="primer3plus_cell_primer_pair_box">Product Size: &nbsp; $results->{"PRIMER_PRODUCT_SIZE\_$counter"} bp</td>
       <td class="primer3plus_cell_primer_pair_box">Pair Any: $primerAny</td>
       <td class="primer3plus_cell_primer_pair_box">Pair End: $primerEnd</td>
       <td class="primer3plus_cell_primer_pair_box">};
}
else {
$formHTML .= qq{     <tr class="primer3plus_primer_pair">
       <td colspan="2" class="primer3plus_cell_primer_pair_box">Product Size: &nbsp; $results->{"PRIMER_PRODUCT_SIZE\_$counter"} bp</td>
       <td class="primer3plus_cell_primer_pair_box"></td>
       <td class="primer3plus_cell_primer_pair_box"></td>
       <td class="primer3plus_cell_primer_pair_box">};
}
if (defined ($results->{"PRIMER_PRODUCT_TM\_$counter"}) 
		and (($results->{"PRIMER_PRODUCT_TM\_$counter"}) ne "")) {
    $primerTM = sprintf ("%.1f",($results->{"PRIMER_PRODUCT_TM\_$counter"}));
    $formHTML .= qq{Product TM:<br>&nbsp; &nbsp; $primerTM &deg;C};
}
$formHTML .= qq{</td>
       <td class="primer3plus_cell_primer_pair_box">};

if (defined ($results->{"PRIMER_PRODUCT_TM_OLIGO_TM_DIFF\_$counter"}) 
		and (($results->{"PRIMER_PRODUCT_TM_OLIGO_TM_DIFF\_$counter"}) ne "")) {
    $primerTM = sprintf ("%.1f",($results->{"PRIMER_PRODUCT_TM_OLIGO_TM_DIFF\_$counter"}));
    $formHTML .= qq{Product - Tm:<br>&nbsp; &nbsp;&nbsp; $primerTM &deg;C};
}

$formHTML .= qq{</td>
     </tr>
};

if (defined ($results->{"PRIMER_PAIR\_$counter\_MISPRIMING_SCORE"}) 
		and (($results->{"PRIMER_PAIR\_$counter\_MISPRIMING_SCORE"}) ne "")) {

$formHTML .= qq{     <tr class="primer3plus_primer_pair">
       <td class="primer3plus_cell_primer_pair_box">Pair Mispriming:</td>
       <td colspan="5" class="primer3plus_cell_primer_pair_box">$results->{"PRIMER_PAIR\_$counter\_MISPRIMING_SCORE"}</td>
     </tr>
};
}   

$formHTML .= qq{  </table>
  </div>
};
  
  return $formHTML;
}

sub partPrimerData {
  my ($results, $counter, $type, $checked, $selection) ; 
  $results = shift;
  $counter = shift;
  $type    = shift;
  $checked = shift;
  
  $selection = $counter + 1;
    
  my $primerStart;
  my $primerLength;
  my $primerTM;
  my $primerGC;
  my $primerSelf;
  my $primerAny;
  my $primerEnd;
  my $primerNumber;
  
  my $cssName;
  my $writeName;
  
  if ($type eq "LEFT") {
		$cssName = "left_primer";
		$writeName = "Left Primer";
  }
  elsif ($type eq "INTERNAL_OLIGO") {
		$cssName = "internal_oligo";
		$writeName = "Internal Oligo";
  }
  elsif ($type eq "RIGHT") {
		$cssName = "right_primer";
		$writeName = "Right Primer";
  }
 
  my $formHTML = "";
  

if (defined ($results->{"PRIMER_$type\_$counter\_SEQUENCE"})
		and (($results->{"PRIMER_$type\_$counter\_SEQUENCE"}) ne "")) {

$primerNumber = getPrimerNumber();

$formHTML .= qq{     <tr class="primer3plus_$cssName">
       <td colspan="6" class="primer3plus_cell_primer_pair_box"><input id="PRIMER_$primerNumber\_SELECT" name="PRIMER_$primerNumber\_SELECT" value="1" };

$formHTML .= ($checked) ? "checked=\"checked\" " : "";
 
$formHTML .= qq{type="checkbox"> 
         &nbsp;$writeName $selection: &nbsp; &nbsp;
         <input id="PRIMER_$primerNumber\_NAME" name="PRIMER_$primerNumber\_NAME" value="$results->{"PRIMER_$type\_$counter\_NAME"}" size="40"></td>
     </tr>
     <tr>
       <td class="primer3plus_cell_primer_pair_box">Sequence:</td>
       <td colspan="5" class="primer3plus_cell_primer_pair_box"><input id="PRIMER_$primerNumber\_SEQUENCE" name="PRIMER_$primerNumber\_SEQUENCE"
         value="$results->{"PRIMER_$type\_$counter\_SEQUENCE"}" size="90"></td>
     </tr>
};

  ($primerStart, $primerLength) = split "," , $results->{"PRIMER_$type\_$counter"};
  $primerTM = sprintf ("%.1f",($results->{"PRIMER_$type\_$counter\_TM"}));
  $primerGC = sprintf ("%.1f",($results->{"PRIMER_$type\_$counter\_GC_PERCENT"}));
  $primerSelf = sprintf ("%.1f",($results->{"PRIMER_$type\_$counter\_SELF_ANY"}));
  $primerAny = sprintf ("%.1f",($results->{"PRIMER_$type\_$counter\_SELF_END"}));

$formHTML .= qq{     <tr>
       <td class="primer3plus_cell_primer_pair_box">Start: &nbsp; $primerStart</td>
       <td class="primer3plus_cell_primer_pair_box">Length: &nbsp; $primerLength bp</td>
       <td class="primer3plus_cell_primer_pair_box">Tm: &nbsp; $primerTM &deg;C </td>
       <td class="primer3plus_cell_primer_pair_box">GC: &nbsp; $primerGC %</td>
       <td class="primer3plus_cell_primer_pair_box">ANY: &nbsp; $primerSelf</td>
       <td class="primer3plus_cell_primer_pair_box">SELF: &nbsp; $primerAny</td>
     </tr>
};

if (defined ($results->{"PRIMER_$type\_$counter\_MISPRIMING_SCORE"}) 
		and (($results->{"PRIMER_$type\_$counter\_MISPRIMING_SCORE"}) ne "")) {

$formHTML .= qq{     <tr>
       <td class="primer3plus_cell_primer_pair_box">Mispriming:</td>
       <td colspan="5" class="primer3plus_cell_primer_pair_box">$results->{"PRIMER_$type\_$counter\_MISPRIMING_SCORE"}</td>
     </tr>
};
}
if (defined ($results->{"PRIMER_$type\_$counter\_WARNING"}) 
		and (($results->{"PRIMER_$type\_$counter\_WARNING"}) ne "")) {
my $warningMessage = $results->{"PRIMER_$type\_$counter\_WARNING"};
$warningMessage =~ s/^Left primer/$writeName/;
$formHTML .= qq{     <tr>
       <td class="primer3plus_warning" colspan="6">$warningMessage</td>
     </tr>
};
}
if (defined ($results->{"PRIMER_$type\_$counter\_ERROR"}) 
		and (($results->{"PRIMER_$type\_$counter\_ERROR"}) ne "")) {
my $errorMessage = $results->{"PRIMER_$type\_$counter\_ERROR"};
$errorMessage =~ s/^Left primer/$writeName/;
$formHTML .= qq{     <tr>
       <td class="primer3plus_warning" colspan="6">$errorMessage</td>
    </tr>
};
}
if (defined ($results->{"PRIMER_$type\_$counter\_MESSAGE"}) 
		and (($results->{"PRIMER_$type\_$counter\_MESSAGE"}) ne "")) {
my $infoMessage = $results->{"PRIMER_$type\_$counter\_MESSAGE"};
$infoMessage =~ s/^Left primer/$writeName/;
$formHTML .= qq{     <tr>
       <td class="primer3plus_warning" colspan="6">$infoMessage</td>
     </tr>
};
}
$formHTML .= qq{	<tr><td class="primer3plus_cell_primer_pair_box" colspan="6"></td></tr>}
}
else {
	$formHTML = "";
}

	return $formHTML;
}

###################################################
# divHTMLsequence: Prints out the sequence nicely # 
###################################################
sub divHTMLsequence {
  my ($results, $sequence, $seqLength, $firstBase);
  my ($base, $count, $preCount, $postCount, $printBase) ;
  my ($format, $baseFormat, $preFormat, $firstPair);
  my (@targets, $region, $run, $counter);
  my $formHTML;
   
  $results = shift;
  $firstPair = shift;

  $sequence = $results->{"SEQUENCE_TEMPLATE"};
  $format = $sequence;
  $format =~ s/\w/N/g;

  $seqLength = length ($sequence);
  $firstBase = $results->{"PRIMER_FIRST_BASE_INDEX"};
  
  if ((defined $results->{"SEQUENCE_TEMPLATE"})and ($results->{"SEQUENCE_TEMPLATE"} ne "")) {

  if (defined ($results->{"SEQUENCE_EXCLUDED_REGION"}) and (($results->{"SEQUENCE_EXCLUDED_REGION"}) ne "")) {
      @targets = split ' ', $results->{"SEQUENCE_EXCLUDED_REGION"};
      foreach $region (@targets) {
          $format = addRegion($format,$region,$firstBase,"E");
      }
  }
  if (defined ($results->{"SEQUENCE_TARGET"}) and (($results->{"SEQUENCE_TARGET"}) ne "")) {
      @targets = split ' ', $results->{"SEQUENCE_TARGET"};
      foreach $region (@targets) {
          $format = addRegion($format,$region,$firstBase,"T");
      }
  }
  if (defined ($results->{"SEQUENCE_INCLUDED_REGION"}) and (($results->{"SEQUENCE_INCLUDED_REGION"}) ne "")) {
      $format = addRegion($format,$results->{"SEQUENCE_INCLUDED_REGION"},$firstBase,"I");
  }
  
  if ($firstPair eq 1) {
      if (defined ($results->{"PRIMER_LEFT_0"}) and (($results->{"PRIMER_LEFT_0"}) ne "")) {
           $format = addRegion($format,$results->{"PRIMER_LEFT_0"},$firstBase,"F");
      }
      if (defined ($results->{"PRIMER_INTERNAL_OLIGO_0"}) and (($results->{"PRIMER_INTERNAL_OLIGO_0"}) ne "")) {
     	   $format = addRegion($format,$results->{"PRIMER_INTERNAL_OLIGO_0"},$firstBase,"O");
      }
      if (defined ($results->{"PRIMER_RIGHT_0"}) and (($results->{"PRIMER_RIGHT_0"}) ne "")) {
           $format = addRegion($format,$results->{"PRIMER_RIGHT_0"},$firstBase,"R");
      }
  }
  elsif ($firstPair eq -1) {
      
  }
  else {
      $run = 1;
      for (my $counter = 0 ; $run eq 1 ; $counter++ ) {
           if (!defined ($results->{"PRIMER_LEFT_$counter"}))  {
                 $run = 0;
	    }
	    else {
                 $format = addRegion($format,$results->{"PRIMER_LEFT_$counter"},$firstBase,"F");
            }
      }
      $run = 1;
      for (my $counter = 0 ; $run eq 1 ; $counter++ ) {
            if (!defined ($results->{"PRIMER_RIGHT_$counter"}))  {
                 $run = 0;
	    }
	    else {
                 $format = addRegion($format,$results->{"PRIMER_RIGHT_$counter"},$firstBase,"R");
            }
      }
  }

  ## Handy for testing:
#  $sequence = $format;

  $formHTML = qq{  <div id="primer3plus_result_sequence" class="primer3plus_tab_page_no_border">
  <table class="primer3plus_table_no_border">
     <colgroup>
       <col width="13%" style="text-align: right;">
       <col width="87%">
     </colgroup>
};
  $preFormat = "N";
  for (my $i=0; $i<$seqLength; $i++) {
     $count = $i;
     $preCount = $i - 1;
     $postCount = $i + 1;
     $base = substr($sequence,$i,1);
     $baseFormat = substr($format,$i,1);

     if (($count % 50) eq 0) {
         $printBase = $i + $firstBase;
         $formHTML .= qq{     <tr>
       <td>$printBase&nbsp;&nbsp;</td>
       <td>};
     }

     if ($preFormat ne $baseFormat) {
         if ($preFormat ne "J") {
             $formHTML .= qq{</a>};
         }
         if ($baseFormat eq "N") {
             $formHTML .= qq{<a>};
         }
         if ($baseFormat eq "E") {
             $formHTML .= qq{<a class="primer3plus_excluded_region">};
         }
         if ($baseFormat eq "T") {
             $formHTML .= qq{<a class="primer3plus_target">};
         }
         if ($baseFormat eq "I") {
             $formHTML .= qq{<a class="primer3plus_included_region">};
         }
         if ($baseFormat eq "F") {
             $formHTML .= qq{<a class="primer3plus_left_primer">};
         }
         if ($baseFormat eq "O") {
             $formHTML .= qq{<a class="primer3plus_internal_oligo">};
         }
         if ($baseFormat eq "R") {
             $formHTML .= qq{<a class="primer3plus_right_primer">};
         }
         if ($baseFormat eq "B") {
             $formHTML .= qq{<a class="primer3plus_left_right_primer">};
         }

     }

     if ((($count % 10) eq 0) and !(($count % 50) eq 0)) {
         $formHTML .= qq{&nbsp;&nbsp;};
     }

     $formHTML .= qq{$base};

     if (($postCount % 50) eq 0) {
         $formHTML .= qq{</a></td>
     </tr>
};
         $baseFormat = "J";
     }
     $preFormat = $baseFormat;
  }

  if (($postCount % 50) ne 0) {
      $formHTML .= qq{</a></td>
     </tr>
};
  }

  $formHTML .= qq{  </table>
  </div>
};
}
else {
    $formHTML = "";
}

  return $formHTML;
}

sub addRegion {
  my ($formatString, $region, $firstBase, $letter);
  my ($regionStart, $regionLength, $regionEnd);
  my ($stingStart, $stringRegion, $stringEnd, $stringLength);
  $formatString = shift;
  $region = shift;
  $firstBase = shift;
  $letter = shift;
  ($regionStart, $regionLength) = split "," , $region;
  $regionStart =~ s/\s//g;
  $regionLength =~ s/\s//g;
  $regionStart = $regionStart - $firstBase;
  if ($regionStart < 0) {
      $regionStart = 0;
  }
  if ($letter eq "R") {
  $regionStart = $regionStart - $regionLength + 1;  
  }
  $regionEnd = $regionStart + $regionLength;
  $stringLength = length $formatString;
  if ($regionEnd > $stringLength) {
      $regionEnd = $stringLength;
  }
  $stingStart = substr($formatString,0,$regionStart);
  $stringRegion = substr($formatString,$regionStart,$regionLength);
  $stringEnd = substr($formatString,$regionEnd,$stringLength);
  if (($letter ne "F") and ($letter ne "R")) {
      $stringRegion =~ s/\w/$letter/g;
  }
  if ($letter eq "F") {
      $stringRegion =~ tr/NETIFROB/FFFFFBFB/;
  }
  if  ($letter eq "R") {
      $stringRegion =~ tr/NETIFROB/RRRRBRRB/;
  }
  $formatString = $stingStart;
  $formatString .= $stringRegion;
  $formatString .= $stringEnd;

  return $formatString;
}

sub divHTMLformatSequence {
  my ($sequence, $firstPair, $firstBase, $seqLength);
  my ($base, $count, $preCount, $postCount, $printBase) ;
  my (@targets, $region, $run, $counter);
  my $formHTML;
   
  $sequence = shift;
  $firstPair = shift;

  $seqLength = length ($sequence);
  
  $formHTML = qq{  <div id="primer3plus_result_sequence" class="primer3plus_tab_page_no_border">
  <table class="primer3plus_table_no_border">
     <colgroup>
       <col width="13%" style="text-align: right;">
       <col width="87%">
     </colgroup>
};
  for (my $i=0; $i<$seqLength; $i++) {
     $count = $i;
     $preCount = $i - 1;
     $postCount = $i + 1;
     $base = substr($sequence,$i,1);

     if (($count % 50) eq 0) {
         $printBase = $i + $firstBase;
         $formHTML .= qq{     <tr>
       <td>$printBase&nbsp;&nbsp;</td>
       <td>};
     }

     if ((($count % 10) eq 0) and !(($count % 50) eq 0)) {
         $formHTML .= qq{&nbsp;&nbsp;};
     }

     $formHTML .= qq{$base};

     if (($postCount % 50) eq 0) {
         $formHTML .= qq{</a></td>
     </tr>
};
     }
  }

  if (($postCount % 50) ne 0) {
      $formHTML .= qq{</a></td>
     </tr>
};
  }

  $formHTML .= qq{  </table>
  </div>
};

  return $formHTML;
}

#####################
# Form Manager HTML #
#####################
sub createManagerHTML {
  my (@sequences, @names, @toOrder, @date) ;
  @sequences = @{(shift)};
  @names = @{(shift)};
  @toOrder = @{(shift)};
  @date = @{(shift)};
  $primerNumber = -1;

  my $templateText = getWrapper();

  my $formHTML = qq{
<div id="primer3plus_complete">

<form action="$machineSettings{URL_PRIMER_MANAGER}" method="post" enctype="multipart/form-data">
};
$formHTML .= divTopBar("Manager");

$formHTML .= divMessages();

$formHTML .= qq{
<div id="primer3plus_manager">
   <input type="hidden" id="HTML_MANAGER" name="HTML_MANAGER" value="HTML_MANAGER">
   <input name="Submit" value="Order selected Primers" type="submit">&nbsp;
   <input name="Submit" value="Refresh" type="submit">&nbsp;
   <input value="Reset Form" type="reset">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
   <input name="Submit" value="Delete selected Primers" type="submit">
   <br>
   <br>
   <table class="primer3plus_table_no_border">
     <colgroup>
       <col width="100%">
     </colgroup>
      <tr>
       <td class="primer3plus_cell_no_border"><a id="MANAGER_FILE_INPUT" name="MANAGER_FILE_INPUT">To upload or save a primer file from
         your local computer, choose here:</a>
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><input id="DATABASE_FILE" name="DATABASE_FILE" type="file">&nbsp;&nbsp;
	 <input name="Submit" value="Upload File" type="submit">&nbsp;&nbsp;&nbsp;
         <input name="Submit" value="Save File" type="submit">
       </td>
     </tr>
   </table>
   <br>
   <table class="primer3plus_table_no_border">
     <colgroup>
       <col width="7%">
       <col width="25%">
       <col width="45%">
       <col width="15%">
       <col width="4%">
       <col width="4%">
     </colgroup>
     <tr>
       <td class="primer3plus_cell_no_border">Select</td>
       <td class="primer3plus_cell_no_border">&nbsp;Name</td>
       <td class="primer3plus_cell_no_border">&nbsp;Sequence</td>
       <td class="primer3plus_cell_no_border">&nbsp;Designed on</td>
       <td class="primer3plus_cell_no_border">&nbsp;Check!</td>
       <td class="primer3plus_cell_no_border">&nbsp;BLAST!</td>
     </tr>
};
my ($cgiName, $blastLinkUse);
my $blastLink = getMachineSetting("URL_BLAST");

for (my $counter=0 ; $counter <= $#sequences ; $counter++) {
$primerNumber = getPrimerNumber();
$cgiName = $names[$counter];
$cgiName =~ tr/ /+/;
#QUERY=&amp;
$blastLinkUse = $blastLink;
$blastLinkUse =~ s/;QUERY=/;QUERY=$sequences[$counter]/;

$formHTML .= qq{     <tr>
       <td class="primer3plus_cell_no_border">&nbsp;&nbsp;<input id="PRIMER_$primerNumber\_SELECT" name="PRIMER_$primerNumber\_SELECT" value="1" };

$formHTML .= ($toOrder[$counter] eq 1) ? "checked=\"checked\" " : "";
 
$formHTML .= qq{type="checkbox"></td>
       <td class="primer3plus_cell_no_border"><input id="PRIMER_$primerNumber\_NAME" name="PRIMER_$primerNumber\_NAME" value="$names[$counter]" size="20"></td>
       <td class="primer3plus_cell_no_border"><input id="PRIMER_$primerNumber\_SEQUENCE" name="PRIMER_$primerNumber\_SEQUENCE" value="$sequences[$counter]" size="44"></td>
       <td class="primer3plus_cell_no_border"><input id="PRIMER_$primerNumber\_DATE" name="PRIMER_$primerNumber\_DATE" value="$date[$counter]" size="9"></td>
       <td class="primer3plus_cell_no_border">&nbsp;<a href="$machineSettings{URL_FORM_ACTION}?SEQUENCE_ID=$cgiName&SEQUENCE_PRIMER=$sequences[$counter]&SCRIPT_TASK=Primer_Check">Check!</a></td>
       <td class="primer3plus_cell_no_border">&nbsp;$blastLinkUse</td>
     </tr>
};

};

$formHTML .= qq{   </table>
   <br>
   <input name="Submit" value="Order selected Primers" type="submit">&nbsp;
   <input name="Submit" value="Refresh" type="submit">&nbsp;
   <input value="Reset Form" type="reset">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
   <input name="Submit" value="Delete selected Primers" type="submit">
   <br>
   <br>
 </div>
</form>
</div>
};

  my $returnString = $templateText;

  $returnString =~ s/<!-- Primer3plus will include code here -->/$formHTML/;

  return $returnString;
}

