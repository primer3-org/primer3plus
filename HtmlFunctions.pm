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
package HtmlFunctions;
use Carp;
#use CGI::Carp qw(fatalsToBrowser);
use Exporter;
use settings;
our (@ISA, @EXPORT, @EXPORT_OK, $VERSION);

@ISA = qw(Exporter);
@EXPORT = qw(&mainStartUpHTML &createHelpHTML &createAboutHTML &createResultsPrefoldHTML
             &createPackageHTML &mainResultsHTML &createManagerDisplayHTML 
             &createCompareFileHTML &createResultCompareFileHTML &createPrefoldHTML
             &getWrapper &createSelectSequence &createStatisticsHTML &geneBroHTML);
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

#############################################
# divTopBar: Writes the TopBar for the Form #    
#############################################
sub divTopBar {
	my $title = shift;
	my $explain = shift;
	my $help = shift;
	
	if ($title eq "0") {
		$title = "Primer3Plus";
	}
	if ($explain eq "0") {
		$explain = "pick primers from a DNA sequence";
	}
	if ($explain eq "1") {
		$explain = qq{<a class="primer3plus_top_bar_link" href="$machineSettings{URL_HELP}">Help</a>};
	}
	if ($help eq "0") {
		$help = qq{<a class="primer3plus_top_bar_link" href="$machineSettings{URL_HELP}">Help</a>};
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
       <td class="primer3plus_top_bar_cell"><a class="primer3plus_top_bar_link" href="primer3plusPackage.cgi">More...</a>
       </td>
       <td class="primer3plus_top_bar_cell"><a class="primer3plus_top_bar_link" href="http://sourceforge.net/projects/primer3/">Source Code</a>
       </td>
     </tr>
     <tr>
       <td class="primer3plus_top_bar_cell">$help
       </td>
       <td class="primer3plus_top_bar_cell"><a class="primer3plus_top_bar_link" href="primer3plusAbout.cgi">About</a>
       </td>
     </tr>
   </table>
</div>

};
	return $formHTML;
}

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

################################################################################################
# createStartUpUseScript: Will write an HTML-Form based on the parameters in the Hash supplied #
################################################################################################
sub mainStartUpHTML {
  my %settings; 
  %settings = %{(shift)};

  my $templateText = getWrapper();

  my $formHTML = qq{

<DIV id=toolTipLayer style="VISIBILITY: hidden; POSITION: absolute; z-index: 1">will be replace by tooltip text
</DIV>
};

################################
# Script for Tab functionality #
################################
$formHTML .= qq{
<SCRIPT language=JavaScript>
var prevTabPage = "primer3plus_main_tab";
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

function hideTabs() {
        document.getElementById('primer3plus_general_primer_picking').style.display="none";
        document.getElementById('primer3plus_advanced_primer_picking').style.display="none";
        document.getElementById('primer3plus_internal_oligo').style.display="none";
        document.getElementById('primer3plus_penalties').style.display="none";
        document.getElementById('primer3plus_advanced_sequence').style.display="none";
    
}
};

########################################
# Script for hiding useless parameters #
########################################
$formHTML .= qq{
var prevSelectedid = "primer3plus_explain_" + "$settings{PRIMER_TASK}";

function showSelection(selector) {
        x = selector.selectedIndex;
        id = "primer3plus_explain_" + selector.options[x].text;
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

        if (id == "primer3plus_explain_check_primers") {
			setSelection("none","none","none","none","none","inline")
			document.getElementById("primer3plus_pick_primers_button").value = "Check Primer";             
        } else if (id == "primer3plus_explain_generic") {
             setSelection("inline","inline","inline","inline","inline","inline");
        } else if (id == "primer3plus_explain_pick_sequencing_primers") {
             setSelection("none","inline","none","none","none","none");
        } else if (id == "primer3plus_explain_pick_cloning_primers") {
             setSelection("none","none","inline","none","none","none");
        } else if (id == "primer3plus_explain_pick_discriminative_primers") {
             setSelection("none","inline","none","none","none","none");
        } else if (id == "primer3plus_explain_pick_primer_list") {
             setSelection("inline","inline","inline","inline","inline","none");
        }
    }
}

function setSelection(excludedState,targetState,includedState,regionState,okPairState,pickwhichState) {
        document.getElementById("primer3plus_excluded_region_box").style.display=excludedState;
        document.getElementById("primer3plus_excluded_region_button").style.display=excludedState;
        document.getElementById("primer3plus_target_region_box").style.display=targetState;
        document.getElementById("primer3plus_target_region_button").style.display=targetState;
        document.getElementById("primer3plus_included_region_box").style.display=includedState;
        document.getElementById("primer3plus_included_region_button").style.display=includedState;
        document.getElementById("primer3plus_primer_overlap_pos_box").style.display=regionState;
        document.getElementById("primer3plus_pair_ok_reg_box").style.display=okPairState;
        document.getElementById("primer3plus_pick_which").style.display=pickwhichState;
}
};

########################################
# Script for ???? #
########################################
$formHTML .= qq{
var prevSequence = 0;
var prevSequencing = 0;

function selectSequencing() {
        var seqId = -1;
        var selector = document.getElementById('PRIMER_TASK');
        for (var i = 0; i < selector.length; i++) {
                if (selector.options[i].text == 'Sequencing') {
                        seqId = i;
                }
        }
        if (seqId > -1) {
                document.getElementById('PRIMER_TASK').options[seqId].selected='true';
                showSelection(document.getElementById('PRIMER_TASK'));
        }
}
};

###########################
# Script for the Tooltips #
###########################
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
};

##########################################
# Script for marking within the sequence #
##########################################
$formHTML .= qq{
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

<form name="mainForm" action="$machineSettings{URL_FORM_ACTION}" method="post" enctype="multipart/form-data" onReset="initPage();">
};

######################
# Insert the Top Bar #
######################
$formHTML .= divTopBar(0,0,0);

################################################################
# Create the always visible Settings/Task and pick primers bar #
################################################################
$formHTML .= qq{
<div id="primer3plus_task_bar">
   <table class="primer3plus_table_no_border">
     <colgroup>
       <col width="50%">
       <col width="30%">

       <col width="20%">
     </colgroup>
	<tr>
	<td class="primer3plus_cell_no_border">
	
<input name="SCRIPT_RADIO_BUTTONS_FIX" id="SCRIPT_RADIO_BUTTONS_FIX" value="PRIMER_PICK_LEFT_PRIMER,PRIMER_PICK_INTERNAL_OLIGO,PRIMER_PICK_RIGHT_PRIMER,PRIMER_PICK_ANYWAY,PRIMER_LIBERAL_BASE,PRIMER_LOWERCASE_MASKING,PRIMER_LIB_AMBIGUITY_CODES_CONSENSUS,PRIMER_THERMODYNAMIC_OLIGO_ALIGNMENT,PRIMER_THERMODYNAMIC_TEMPLATE_ALIGNMENT,SCRIPT_DISPLAY_DEBUG_INFORMATION" type="hidden">

	<input id="GENBRO_RETURN_PATH" name="GENBRO_RETURN_PATH" value="$settings{GENBRO_RETURN_PATH}" type="hidden">
        <input id="GENBRO_DB" name="GENBRO_DB" value="$settings{GENBRO_DB}" type="hidden">
        <input id="GENBRO_POSITION" name="GENBRO_POSITION" value="$settings{GENBRO_POSITION}" type="hidden">
        <input id="GENBRO_FILE" name="GENBRO_FILE" value="" type="hidden">


         <a name="SCRIPT_SERVER_PARAMETER_FILE_INPUT" href="$machineSettings{URL_HELP}#SCRIPT_SERVER_PARAMETER_FILE">
         Load server settings:</a>&nbsp;&nbsp;
         <select name="SCRIPT_SERVER_PARAMETER_FILE">
};

        my @ServerParameterFiles = getServerParameterFilesList;
	    my $option;
        foreach $option (@ServerParameterFiles) {
                my $selectedStatus = "";
                if ($option eq $settings{SCRIPT_SERVER_PARAMETER_FILE} ) {$selectedStatus = " selected=\"selected\"" };
                $formHTML .= "         <option$selectedStatus>$option</option>\n";
        }

        $formHTML .= qq{         </select>&nbsp;
       <input name="Activate_Settings" value="Activate Settings" type="submit"><br>
             <a id="PRIMER_TASK_INPUT" name="PRIMER_TASK_INPUT" href="$machineSettings{URL_HELP}#PRIMER_TASK">
         Task:</a>&nbsp;
        <select id="PRIMER_TASK" name="PRIMER_TASK" class="primer3plus_task" onchange="showSelection(this);" onkeyup="showSelection(this)">
};

        foreach $option (@scriptTask) {
                my $selectedStatus = "";
                if ($option eq $settings{PRIMER_TASK} ) {$selectedStatus = " selected=\"selected\"" };
                $formHTML .= "         <option class=\"primer3plus_task\"$selectedStatus>$option</option>\n";
        }

        $formHTML .= qq{         </select>
       </td>

        <td class="primer3plus_cell_no_border_explain">
   <div id="primer3plus_explain_generic" style="display: none;">
     <a>Select primer pairs to detect the given template sequence. Optionally targets and included/excluded regions can be specified.</a>
   </div>
   <div id="primer3plus_explain_pick_cloning_primers" style="display: none;">
     <a>Mark an included region to pick primers 5' fixed at its the boundaries. The quality of the primers might be low.</a>
   </div>
   <div id="primer3plus_explain_pick_discriminative_primers" style="display: none;">
     <a>Mark an target to pick primers 3' fixed at its the boundaries. The quality of the primers might be low.</a>
   </div>
   <div id="primer3plus_explain_pick_sequencing_primers" style="display: none;">
     <a>Pick a series of primers on both strands for sequencing. Optionally the regions of interest can be marked using targets.</a>
   </div>
   <div id="primer3plus_explain_pick_primer_list" style="display: none;">
     <a>Returns a list of all possible primers the can be designed on the template sequence. Optionally targets and included/exlcuded regions can be specified.</a>
   </div>
   <div id="primer3plus_explain_check_primers"  style="display: none;">
     <a>Evaluate a primer of known sequence with the given settings.</a>
   </div>
         </td><td class="primer3plus_cell_no_border" align="right">

	<table><tr>
	<td><input id="primer3plus_pick_primers_button" class="primer3plus_action_button" name="Pick_Primers" value="Pick Primers" type="submit" style="background: #83db7b;"></td>
	<td><input class="primer3plus_action_button" name="Default_Settings" value="Reset Form" type="submit"></td>
	</tr></table>
        </td>
        </tr>
   </tbody></table>
</div>
};

###########################
# Write a Javascript hint #
###########################
$formHTML .= qq{
<script type="text/javascript">
	document.write("<style type=\\"text/css\\">div#primer3plus_no_javascript { display: none; }</style>");
</script>

<div id="primer3plus_no_javascript">
   <table class="primer3plus_table_no_border">
     <tr>
       <td class="primer3plus_note">
       		JavaScript is not enabled, please enable JavaScript and refresh the browser.</a>.
       </td>
     </tr>
   </table>
</div>
};

##################################
# Insert possible Error Messages #
##################################
$formHTML .= divMessages();

#######################
# Create the Tab line #
#######################
$formHTML .= qq{  
<div id="menuBar">
        <ul>
        <li id="tab1"><a onclick="showTab('tab1','primer3plus_main_tab')">Main</a></li>
        <li id="tab2"><a onclick="showTab('tab2','primer3plus_general_primer_picking')">General Settings</a></li>
        <li id="tab3"><a onclick="showTab('tab3','primer3plus_advanced_primer_picking')">Advanced Settings</a></li>
        <li id="tab4"><a onclick="showTab('tab4','primer3plus_internal_oligo')">Internal Oligo</a></li>
        <li id="tab5"><a onclick="showTab('tab5','primer3plus_penalties')">Penalty Weights</a></li>
        <li id="tab6"><a onclick="showTab('tab6','primer3plus_advanced_sequence')">Advanced Sequence</a></li>
        </ul>
</div>};

#######################
# Create the MAIN tab #
#######################
$formHTML .= qq{
<div id="primer3plus_main_tab" class="primer3plus_tab_page">

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

<div id="primer3plus_sequence">
   <table class="primer3plus_table_no_border">
     <tr>
       <td class="primer3plus_cell_no_border" valign="bottom">
         <a onmouseover="toolTip('5 -&gt;3 , as ACGTNacgtn -- other letters treated as N -- numbers and blanks ignored FASTA format ok.');"
         onmouseout="toolTip();" name="SEQUENCE_TEMPLATE_INPUT" href="$machineSettings{URL_HELP}#SEQUENCE_TEMPLATE">Paste template sequence below</a>
       </td>
       <td class="primer3plus_cell_no_border" valign="bottom">
         <a name="SCRIPT_SEQUENCE_FILE_INPUT">Or upload sequence file:</a>
         <input name="SCRIPT_SEQUENCE_FILE" type="file">&nbsp;&nbsp;
	 <input name="Upload_File" value="Upload File" type="submit">&nbsp;&nbsp;&nbsp;
       </td>
     </tr>};

my $sequence = $settings{SEQUENCE_TEMPLATE};
$sequence =~ s/(\w{80})/$1\n/g;
$formHTML .= qq{
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
         <a onmouseover="toolTip('Primer oligos may not overlap any region specified in this tag. The associated value must be a space-separated list of start,length.<br>E.g. 401,7 68,3 forbids selection of primers in the 7 bases starting at 401 and the 3 bases at 68.<br> Or mark the template sequence with &lt; and &gt;:<br> e.g. ...ATCT&amp;lt;CCCC&amp;gt;TCAT.. forbids primers in the central CCCC.');"
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
       <td class="primer3plus_cell_no_border"><a onmouseover="toolTip('If one or more Targets is specified then a legal primer pair must flank at least one of them. The value should be a space-separated list of start,length pairs.<br>E.g. 50,2 requires primers to surround the 2 bases at positions 50 and 51.<br> Or mark the template sequence with [ and ]: e.g. ...ATCT[CCCC]TCAT..<br> means that primers must flank the central CCCC.');"
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
       <td class="primer3plus_cell_no_border"><a onmouseover="toolTip('A sub-region of the given sequence in which to pick primers. For example, often the first dozen or so bases of a sequence are vector, and should be excluded from consideration.<br>The value for this parameter has the form start,length.<br>E.g. 20,400: only pick primers in the 400 base region starting at position 20.<br> Or use { and } in the template sequence to mark the beginning and end of the included<br> region: e.g. in ATC{TTC...TCT}AT the included region is TTC...TCT.');"
         onmouseout="toolTip();"  name="SEQUENCE_INCLUDED_REGION_INPUT" href="$machineSettings{URL_HELP}#SEQUENCE_INCLUDED_REGION">Included Region:</a>
       </td>
       <td class="primer3plus_cell_no_border">{
       </td>
       <td class="primer3plus_cell_no_border"><input size="40" id="SEQUENCE_INCLUDED_REGION" name="SEQUENCE_INCLUDED_REGION" value="$settings{SEQUENCE_INCLUDED_REGION}" type="text">&nbsp;}
       </td>
     </tr>
  </table>
</div>
<div id="primer3plus_primer_overlap_pos_box">
  <table class="primer3plus_table_no_border">
     <colgroup>
       <col width="20%">
       <col width="2%">
       <col width="78%">
     </colgroup>
     <tr>
       <td class="primer3plus_cell_no_border"><a onmouseover="toolTip('A list of positions in the given sequence. The value for this parameter has the form position.<br>E.g. 120: only pick primers overlaping the position 120.<br> Or use - in the template sequence to mark the position.<br>Primer3 tries to pick primer pairs were the forward or the reverse primer overlaps one of these positions.');"
         onmouseout="toolTip();"  name="SEQUENCE_OVERLAP_JUNCTION_LIST_INPUT" href="$machineSettings{URL_HELP}#SEQUENCE_OVERLAP_JUNCTION_LIST">Primer overlap positions:</a>
       </td>
       <td class="primer3plus_cell_no_border">-
       </td>
       <td class="primer3plus_cell_no_border"><input size="40" id="SEQUENCE_OVERLAP_JUNCTION_LIST" name="SEQUENCE_OVERLAP_JUNCTION_LIST" value="$settings{SEQUENCE_OVERLAP_JUNCTION_LIST}" type="text">
       </td>
     </tr>
  </table>
</div>
<div id="primer3plus_pair_ok_reg_box">
  <table class="primer3plus_table_no_border">
     <colgroup>
       <col width="20%">
       <col width="2%">
       <col width="78%">
     </colgroup>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="SEQUENCE_PRIMER_PAIR_OK_REGION_LIST_INPUT" href="$machineSettings{URL_HELP}#SEQUENCE_PRIMER_PAIR_OK_REGION_LIST">Pair OK Region List:</a>
       </td>
       <td class="primer3plus_cell_no_border">
       </td>
       <td class="primer3plus_cell_no_border"><input size="40" id="SEQUENCE_PRIMER_PAIR_OK_REGION_LIST" name="SEQUENCE_PRIMER_PAIR_OK_REGION_LIST" value="$settings{SEQUENCE_PRIMER_PAIR_OK_REGION_LIST}" type="text">
       </td>
     </tr>
  </table>
</div>
<br>
<div id="primer3plus_primer_selection">
   <table class="primer3plus_table_no_border">
     <colgroup>
       <col width="32%">
       <col width="32%">
       <col width="36%">
     </colgroup>
     <tr>
       <td class="primer3plus_cell_no_border_bg" valign="top">
         <input id="PRIMER_PICK_LEFT_PRIMER" name="PRIMER_PICK_LEFT_PRIMER" value="1" };

	$formHTML .= ($settings{PRIMER_PICK_LEFT_PRIMER}) ? "checked=\"checked\" " : "";
 
	$formHTML .= qq{ type="checkbox"><a href="$machineSettings{URL_HELP}#PRIMER_PICK_LEFT_PRIMER">Pick left primer</a>
       </td>
       <td class="primer3plus_cell_no_border_bg" valign="top">
         <input id="PRIMER_PICK_INTERNAL_OLIGO" name="PRIMER_PICK_INTERNAL_OLIGO" value="1" };

	$formHTML .= ($settings{PRIMER_PICK_INTERNAL_OLIGO}) ? "checked=\"checked\" " : "";
 
	$formHTML .= qq{type="checkbox"><a href="$machineSettings{URL_HELP}#PRIMER_PICK_INTERNAL_OLIGO">Pick hybridization probe</a><br>
       </td>
       <td class="primer3plus_cell_no_border_bg" valign="top">
         <input id="PRIMER_PICK_RIGHT_PRIMER" name="PRIMER_PICK_RIGHT_PRIMER" value="1" };

	$formHTML .= ($settings{PRIMER_PICK_RIGHT_PRIMER}) ? "checked=\"checked\" " : "";
 
	$formHTML .= qq{ type="checkbox"><a href="$machineSettings{URL_HELP}#PRIMER_PICK_RIGHT_PRIMER">Pick right primer</a>
       </td>
     </tr>
  </table>
</div>
<div id="primer3plus_pick_which">
   <table class="primer3plus_table_no_border">
     <colgroup>
       <col width="32%">
       <col width="32%">
       <col width="36%">
     </colgroup>
     <tr>
       <td class="primer3plus_cell_no_border_bg" valign="top">
         or use <a href="$machineSettings{URL_HELP}#SEQUENCE_PRIMER">left primer</a> below.
       </td>
       <td class="primer3plus_cell_no_border_bg" valign="top">
         (internal oligo) or use <a href="$machineSettings{URL_HELP}#SEQUENCE_INTERNAL_OLIGO">oligo</a> below.
       </td>
       <td class="primer3plus_cell_no_border_bg" valign="top">
         or use <a href="$machineSettings{URL_HELP}#SEQUENCE_PRIMER_REVCOMP">right primer</a><br>
         below (5'-&gt;3' on opposite strand).
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border_bg">&nbsp;&nbsp;<input size="30" id="SEQUENCE_PRIMER" name="SEQUENCE_PRIMER" value="$settings{SEQUENCE_PRIMER}" type="text">
       </td>
       <td class="primer3plus_cell_no_border_bg">&nbsp;&nbsp;<input size="30" id="SEQUENCE_INTERNAL_OLIGO" name="SEQUENCE_INTERNAL_OLIGO" value="$settings{SEQUENCE_INTERNAL_OLIGO}"
         type="text">
       </td>
       <td class="primer3plus_cell_no_border_bg">&nbsp;&nbsp;<input size="30" id="SEQUENCE_PRIMER_REVCOMP" name="SEQUENCE_PRIMER_REVCOMP" value="$settings{SEQUENCE_PRIMER_REVCOMP}" type="text">
       </td>
     </tr>
  </table>
</div>
</div>
</div>
};

####################################
# Create the ADVANCED SEQUENCE tab #
####################################
$formHTML .= qq{<div id="primer3plus_advanced_sequence" class="primer3plus_tab_page">
   <table class="primer3plus_table_no_border">
     <colgroup>
       <col width="30%">
       <col width="10%">
       <col width="30%">
       <col width="10%">
       <col width="20%">
     </colgroup>
    <tr>
       <td class="primer3plus_cell_no_border"><a href="$machineSettings{URL_HELP}#SEQUENCE_FORCE_LEFT_START">
         Force Left Primer Start:</a>
       </td>
       <td class="primer3plus_cell_no_border"> <input size="6" name="SEQUENCE_FORCE_LEFT_START"
         value="$settings{SEQUENCE_FORCE_LEFT_START}" type="text">
       </td>
       <td class="primer3plus_cell_no_border"><a href="$machineSettings{URL_HELP}#SEQUENCE_FORCE_RIGHT_START">
         Force Right Primer Start:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="6" name="SEQUENCE_FORCE_RIGHT_START"
         value="$settings{SEQUENCE_FORCE_RIGHT_START}" type="text">
       </td>
       <td class="primer3plus_cell_no_border"> 
       </td>
     </tr>
    <tr>
       <td class="primer3plus_cell_no_border"><a href="$machineSettings{URL_HELP}#SEQUENCE_FORCE_LEFT_END">
         Force Left Primer End:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="6" name="SEQUENCE_FORCE_LEFT_END"
         value="$settings{SEQUENCE_FORCE_LEFT_END}" type="text">
       </td>
       <td class="primer3plus_cell_no_border"><a href="$machineSettings{URL_HELP}#SEQUENCE_FORCE_RIGHT_END">
         Force Right Primer End:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="6" name="SEQUENCE_FORCE_RIGHT_END"
         value="$settings{SEQUENCE_FORCE_RIGHT_END}" type="text">
       </td>
       <td class="primer3plus_cell_no_border"> 
       </td>
     </tr>
    <tr>
       <td class="primer3plus_cell_no_border"> <a name="PRIMER_FIRST_BASE_INDEX_INPUT" href="$machineSettings{URL_HELP}#PRIMER_FIRST_BASE_INDEX">
         First Base Index:</a>
       </td>
       <td class="primer3plus_cell_no_border"> <input size="4" name="PRIMER_FIRST_BASE_INDEX"
         value="$settings{PRIMER_FIRST_BASE_INDEX}" type="text">
       </td>
       <td colspan="3" class="primer3plus_cell_no_border"> <a name="SEQUENCE_QUALITY_INPUT" href="$machineSettings{URL_HELP}#SEQUENCE_QUALITY">
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
       <td class="primer3plus_cell_no_border" rowspan="5" colspan="3">
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
};

###################################
# Create the GENERAL SETTINGS tab #
###################################
$formHTML .= qq{
<div id="primer3plus_general_primer_picking" class="primer3plus_tab_page">
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
       <td class="primer3plus_cell_no_border"><a name="PRIMER_OPT_SIZE_INPUT">Primer Size</a>
       </td>
       <td class="primer3plus_cell_no_border"><a href="$machineSettings{URL_HELP}#PRIMER_MIN_SIZE">Min:</a>
       <input size="4" name="PRIMER_MIN_SIZE" value="$settings{PRIMER_MIN_SIZE}" type="text">
       </td>
       <td class="primer3plus_cell_no_border"><a href="$machineSettings{URL_HELP}#PRIMER_OPT_SIZE">Opt:</a>
       <input size="4" name="PRIMER_OPT_SIZE" value="$settings{PRIMER_OPT_SIZE}" type="text">
       </td>
       <td class="primer3plus_cell_no_border"><a href="$machineSettings{URL_HELP}#PRIMER_MAX_SIZE">Max:</a> 
       <input size="4" name="PRIMER_MAX_SIZE" value="$settings{PRIMER_MAX_SIZE}" type="text">
       </td>
       <td class="primer3plus_cell_no_border">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="PRIMER_OPT_TM_INPUT">Primer Tm</a>
       </td>
       <td class="primer3plus_cell_no_border"><a href="$machineSettings{URL_HELP}#PRIMER_MIN_TM">Min:</a>
         <input size="4" name="PRIMER_MIN_TM" value="$settings{PRIMER_MIN_TM}" type="text">
       </td>
       <td class="primer3plus_cell_no_border"><a href="$machineSettings{URL_HELP}#PRIMER_OPT_TM">Opt:</a>
         <input size="4" name="PRIMER_OPT_TM" value="$settings{PRIMER_OPT_TM}" type="text">
       </td>
       <td class="primer3plus_cell_no_border"><a href="$machineSettings{URL_HELP}#PRIMER_MAX_TM">Max:</a>
         <input size="4" name="PRIMER_MAX_TM" value="$settings{PRIMER_MAX_TM}" type="text">
       </td>
       <td class="primer3plus_cell_no_border">&nbsp;&nbsp;&nbsp;
         <a name="PRIMER_PAIR_MAX_DIFF_TM_INPUT" href="$machineSettings{URL_HELP}#PRIMER_PAIR_MAX_DIFF_TM">
         Max Tm Difference:</a> <input size="4" name="PRIMER_PAIR_MAX_DIFF_TM"
         value="$settings{PRIMER_PAIR_MAX_DIFF_TM}" type="text">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="PRIMER_GC_PERCENT_INPUT">Primer GC%</a>
       </td>
       <td class="primer3plus_cell_no_border"><a href="$machineSettings{URL_HELP}#PRIMER_MIN_GC">Min:</a>
          <input size="4" name="PRIMER_MIN_GC" value="$settings{PRIMER_MIN_GC}" type="text">
       </td>
       <td class="primer3plus_cell_no_border"><a href="$machineSettings{URL_HELP}#PRIMER_OPT_GC_PERCENT">Opt:</a>
         <input size="4" name="PRIMER_OPT_GC_PERCENT" value="$settings{PRIMER_OPT_GC_PERCENT}" type="text">
       </td>
       <td class="primer3plus_cell_no_border"><a href="$machineSettings{URL_HELP}#PRIMER_MAX_GC">Max:</a>
         <input size="4" name="PRIMER_MAX_GC" value="$settings{PRIMER_MAX_GC}" type="text">
       </td>
       <td class="primer3plus_cell_no_border">
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
       <td class="primer3plus_cell_no_border"><a name="PRIMER_DNTP_CONC_INPUT" href="$machineSettings{URL_HELP}#PRIMER_DNTP_CONC">Concentration of dNTPs:</a>
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
       <td class="primer3plus_cell_no_border"><a name="SCRIPT_SETTINGS_FILE_INPUT">To upload or save a settings file from
         your local computer, choose here:</a>
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><input name="SCRIPT_SETTINGS_FILE" type="file">&nbsp;&nbsp;
             <input name="Load_Settings" value="Load Settings" type="submit">&nbsp;&nbsp;&nbsp;
         <input name="Save_Settings" value="Save Settings" type="submit">
       </td>
     </tr>
     </tbody>	
     </table>
</div>

};

$formHTML .= qq{</div>
<div id="primer3plus_advanced_primer_picking" class="primer3plus_tab_page">
   <table class="primer3plus_table_no_border">
     <colgroup>
       <col width="25%">
       <col width="10%">
       <col width="33%">
       <col width="32%">
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
       <td class="primer3plus_cell_no_border"><a name="PRIMER_GC_CLAMP_INPUT" href="$machineSettings{URL_HELP}#PRIMER_GC_CLAMP">CG Clamp:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_GC_CLAMP" value="$settings{PRIMER_GC_CLAMP}" type="text">
       </td>
       <td class="primer3plus_cell_no_border_th"><a name="PRIMER_THERMODYNAMIC_OLIGO_ALIGNMENT_INPUT" href="$machineSettings{URL_HELP}#PRIMER_THERMODYNAMIC_OLIGO_ALIGNMENT">
       Use Thermodynamic Primer Alignment:</a>
       </td>
       <td class="primer3plus_cell_no_border_th"><input name="PRIMER_THERMODYNAMIC_OLIGO_ALIGNMENT"  value="1" };

	$formHTML .= ($settings{PRIMER_THERMODYNAMIC_OLIGO_ALIGNMENT}) ? "checked=\"checked\" " : "";
 
	$formHTML .= qq{type="checkbox"><a>&nbsp;&nbsp;Activates Settings Starting with TH:</a>
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="PRIMER_MAX_END_GC_INPUT" href="$machineSettings{URL_HELP}#PRIMER_MAX_END_GC">Max End GC:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_MAX_END_GC" value="$settings{PRIMER_MAX_END_GC}" type="text">
       </td>
       <td class="primer3plus_cell_no_border_th"><a name="PRIMER_THERMODYNAMIC_TEMPLATE_ALIGNMENT_INPUT" href="$machineSettings{URL_HELP}#PRIMER_THERMODYNAMIC_TEMPLATE_ALIGNMENT">
       Use Thermodynamic Template Alignment:</a>
       </td>
       <td class="primer3plus_cell_no_border_th"><input name="PRIMER_THERMODYNAMIC_TEMPLATE_ALIGNMENT"  value="1" };

	$formHTML .= ($settings{PRIMER_THERMODYNAMIC_TEMPLATE_ALIGNMENT}) ? "checked=\"checked\" " : "";
 
	$formHTML .= qq{type="checkbox"><a>&nbsp;&nbsp;Activates TH: Settings-VERY SLOW</a>
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="PRIMER_NUM_RETURN_INPUT" href="$machineSettings{URL_HELP}#PRIMER_NUM_RETURN">Number To Return:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_NUM_RETURN" value="$settings{PRIMER_NUM_RETURN}" type="text">
       </td>
       <td class="primer3plus_cell_no_border"><a name="PRIMER_MAX_END_STABILITY_INPUT" href="$machineSettings{URL_HELP}#PRIMER_MAX_END_STABILITY">
         Max End Stability:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_MAX_END_STABILITY" value="$settings{PRIMER_MAX_END_STABILITY}" type="text">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="PRIMER_MIN_5_PRIME_OVERLAP_OF_JUNCTION_INPUT" href="$machineSettings{URL_HELP}#PRIMER_MIN_5_PRIME_OVERLAP_OF_JUNCTION">
         5 Prime Junction Overlap: </a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_MIN_5_PRIME_OVERLAP_OF_JUNCTION" value="$settings{PRIMER_MIN_5_PRIME_OVERLAP_OF_JUNCTION}" type="text">
       </td>
       <td class="primer3plus_cell_no_border"><a name="PRIMER_MIN_3_PRIME_OVERLAP_OF_JUNCTION_INPUT" href="$machineSettings{URL_HELP}#PRIMER_MIN_3_PRIME_OVERLAP_OF_JUNCTIONT">
         3 Prime Junction Overlap: </a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_MIN_3_PRIME_OVERLAP_OF_JUNCTION" value="$settings{PRIMER_MIN_3_PRIME_OVERLAP_OF_JUNCTION}" type="text">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="PRIMER_MIN_LEFT_THREE_PRIME_DISTANCE_INPUT" href="$machineSettings{URL_HELP}#PRIMER_MIN_LEFT_THREE_PRIME_DISTANCE">
         Min Left Primer End Distance:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_MIN_LEFT_THREE_PRIME_DISTANCE" value="$settings{PRIMER_MIN_LEFT_THREE_PRIME_DISTANCE}" type="text">
       </td>
       <td class="primer3plus_cell_no_border"><a name="PRIMER_MIN_RIGHT_THREE_PRIME_DISTANCE_INPUT" href="$machineSettings{URL_HELP}#PRIMER_MIN_RIGHT_THREE_PRIME_DISTANCE">
         Min Right Primer End Distance:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_MIN_RIGHT_THREE_PRIME_DISTANCE" value="$settings{PRIMER_MIN_RIGHT_THREE_PRIME_DISTANCE}" type="text">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="PRIMER_MAX_SELF_ANY_INPUT" href="$machineSettings{URL_HELP}#PRIMER_MAX_SELF_ANY">Max Self Complementarity:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_MAX_SELF_ANY" value="$settings{PRIMER_MAX_SELF_ANY}" type="text">
       </td>
       <td class="primer3plus_cell_no_border"><a name="PRIMER_PAIR_MAX_COMPL_ANY_INPUT" href="$machineSettings{URL_HELP}#PRIMER_PAIR_MAX_COMPL_ANY">Max Pair Complementarity:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_PAIR_MAX_COMPL_ANY" value="$settings{PRIMER_PAIR_MAX_COMPL_ANY}" type="text">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border_th"><a name="PRIMER_MAX_SELF_ANY_TH_INPUT" href="$machineSettings{URL_HELP}#PRIMER_MAX_SELF_ANY_TH">TH: Max Self Complementarity:</a>
       </td>
       <td class="primer3plus_cell_no_border_th"><input size="4" name="PRIMER_MAX_SELF_ANY_TH" value="$settings{PRIMER_MAX_SELF_ANY_TH}" type="text">
       </td>
       <td class="primer3plus_cell_no_border_th"><a name="PRIMER_PAIR_MAX_COMPL_ANY_TH_INPUT" href="$machineSettings{URL_HELP}#PRIMER_PAIR_MAX_COMPL_ANY_TH">TH: Max Pair Complementarity:</a>
       </td>
       <td class="primer3plus_cell_no_border_th"><input size="4" name="PRIMER_PAIR_MAX_COMPL_ANY_TH" value="$settings{PRIMER_PAIR_MAX_COMPL_ANY_TH}" type="text">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="PRIMER_MAX_SELF_END_INPUT" href="$machineSettings{URL_HELP}#PRIMER_MAX_SELF_END">Max End Self Complementarity:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_MAX_SELF_END" value="$settings{PRIMER_MAX_SELF_END}" type="text">
       </td>
       <td class="primer3plus_cell_no_border"><a name="PRIMER_PAIR_MAX_COMPL_END_INPUT" href="$machineSettings{URL_HELP}#PRIMER_PAIR_MAX_COMPL_END">Max Pair End Complementarity:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_PAIR_MAX_COMPL_END" value="$settings{PRIMER_PAIR_MAX_COMPL_END}" type="text">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border_th"><a name="PRIMER_MAX_SELF_END_TH_INPUT" href="$machineSettings{URL_HELP}#PRIMER_MAX_SELF_END_TH">TH: Max End Self Compl.:</a>
       </td>
       <td class="primer3plus_cell_no_border_th"><input size="4" name="PRIMER_MAX_SELF_END_TH" value="$settings{PRIMER_MAX_SELF_END_TH}" type="text">
       </td>
       <td class="primer3plus_cell_no_border_th"><a name="PRIMER_PAIR_MAX_COMPL_END_TH_INPUT" href="$machineSettings{URL_HELP}#PRIMER_PAIR_MAX_COMPL_END_TH">TH: Max Pair End Complementarity:</a>
       </td>
       <td class="primer3plus_cell_no_border_th"><input size="4" name="PRIMER_PAIR_MAX_COMPL_END_TH" value="$settings{PRIMER_PAIR_MAX_COMPL_END_TH}" type="text">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border_th"><a name="PRIMER_MAX_HAIRPIN_TH_INPUT" href="$machineSettings{URL_HELP}#PRIMER_MAX_HAIRPIN_TH">TH: Max Hairpin:</a>
       </td>
       <td class="primer3plus_cell_no_border_th"><input size="4" name="PRIMER_MAX_HAIRPIN_TH" value="$settings{PRIMER_MAX_HAIRPIN_TH}" type="text">
       </td>
       <td class="primer3plus_cell_no_border">
       </td>
       <td class="primer3plus_cell_no_border">
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
       <td class="primer3plus_cell_no_border_th"><a name="PRIMER_MAX_TEMPLATE_MISPRIMING_TH_INPUT" href="$machineSettings{URL_HELP}#PRIMER_MAX_TEMPLATE_MISPRIMING_TH">
       TH: Max Template Mispriming:</a>
       </td>
       <td class="primer3plus_cell_no_border_th"><input size="4" name="PRIMER_MAX_TEMPLATE_MISPRIMING_TH" value="$settings{PRIMER_MAX_TEMPLATE_MISPRIMING_TH}" type="text">
       </td>
       <td class="primer3plus_cell_no_border_th"><a name="PRIMER_PAIR_MAX_TEMPLATE_MISPRIMING_TH_INPUT" href="$machineSettings{URL_HELP}#PRIMER_PAIR_MAX_TEMPLATE_MISPRIMING_TH">
       TH: Pair Max Template Mispriming:</a>
       </td>
       <td class="primer3plus_cell_no_border_th"><input size="4" name="PRIMER_PAIR_MAX_TEMPLATE_MISPRIMING_TH" value="$settings{PRIMER_PAIR_MAX_TEMPLATE_MISPRIMING_TH}" type="text">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"> <a name="PRIMER_MAX_LIBRARY_MISPRIMING_INPUT" href="$machineSettings{URL_HELP}#PRIMER_MAX_LIBRARY_MISPRIMING">Max Library Mispriming:</a>
       </td>
       <td class="primer3plus_cell_no_border"> <input size="4" name="PRIMER_MAX_LIBRARY_MISPRIMING" value="$settings{PRIMER_MAX_LIBRARY_MISPRIMING}" type="text">
       </td>
       <td class="primer3plus_cell_no_border"> <a name="PRIMER_PAIR_MAX_LIBRARY_MISPRIMING_INPUT" href="$machineSettings{URL_HELP}#PRIMER_PAIR_MAX_LIBRARY_MISPRIMING">
       Pair Max Library Mispriming:</a>
       </td>
       <td class="primer3plus_cell_no_border"> <input size="4" name="PRIMER_PAIR_MAX_LIBRARY_MISPRIMING" value="$settings{PRIMER_PAIR_MAX_LIBRARY_MISPRIMING}" type="text">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"> <a name="PRIMER_MUST_MATCH_FIVE_PRIME_INPUT" href="$machineSettings{URL_HELP}#PRIMER_MUST_MATCH_FIVE_PRIME">
       Primer Must Match 5 Prime:</a>
       </td>
       <td class="primer3plus_cell_no_border"> <input size="4" name="PRIMER_MUST_MATCH_FIVE_PRIME" value="$settings{PRIMER_MUST_MATCH_FIVE_PRIME}" type="text">
       </td>
       <td class="primer3plus_cell_no_border"> <a name="PRIMER_INTERNAL_MUST_MATCH_FIVE_PRIME_INPUT" href="$machineSettings{URL_HELP}#PRIMER_INTERNAL_MUST_MATCH_FIVE_PRIME">
       Internal Must Match 5 Prime:</a>
       </td>
       <td class="primer3plus_cell_no_border"> <input size="4" name="PRIMER_INTERNAL_MUST_MATCH_FIVE_PRIME" value="$settings{PRIMER_INTERNAL_MUST_MATCH_FIVE_PRIME}" type="text">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"> <a name="PRIMER_MUST_MATCH_THREE_PRIME_INPUT" href="$machineSettings{URL_HELP}#PRIMER_MUST_MATCH_THREE_PRIME">
       Primer Must Match 3 Prime:</a>
       </td>
       <td class="primer3plus_cell_no_border"> <input size="4" name="PRIMER_MUST_MATCH_THREE_PRIME" value="$settings{PRIMER_MUST_MATCH_THREE_PRIME}" type="text">
       </td>
       <td class="primer3plus_cell_no_border"> <a name="PRIMER_INTERNAL_MUST_MATCH_THREE_PRIME_INPUT" href="$machineSettings{URL_HELP}#PRIMER_INTERNAL_MUST_MATCH_THREE_PRIME">
       Internal Must Match 3 Prime:</a>
       </td>
       <td class="primer3plus_cell_no_border"> <input size="4" name="PRIMER_INTERNAL_MUST_MATCH_THREE_PRIME" value="$settings{PRIMER_INTERNAL_MUST_MATCH_THREE_PRIME}" type="text">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"> <a name="P3P_PRIMER_NAME_ACRONYM_LEFT_INPUT" href="$machineSettings{URL_HELP}#P3P_PRIMER_NAME_ACRONYM_LEFT">
       Left Primer Acronym:</a>
       </td>
       <td class="primer3plus_cell_no_border"> <input size="4" name="P3P_PRIMER_NAME_ACRONYM_LEFT" value="$settings{P3P_PRIMER_NAME_ACRONYM_LEFT}" type="text">
       </td>
       <td class="primer3plus_cell_no_border"> <a name="P3P_PRIMER_NAME_ACRONYM_INTERNAL_INPUT" href="$machineSettings{URL_HELP}#P3P_PRIMER_NAME_ACRONYM_INTERNAL">
       Internal Oligo Acronym:</a>
       </td>
       <td class="primer3plus_cell_no_border"> <input size="4" name="P3P_PRIMER_NAME_ACRONYM_INTERNAL" value="$settings{P3P_PRIMER_NAME_ACRONYM_INTERNAL}" type="text">
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
       <col width="17%">
       <col width="15%">
       <col width="15%">
       <col width="15%">
       <col width="38%">
     </colgroup>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="PRIMER_PRODUCT_TM_INPUT">Product Tm</a>
       </td>
       <td class="primer3plus_cell_no_border_right"><a href="$machineSettings{URL_HELP}#PRIMER_PRODUCT_MIN_TM">Min:</a>
         <input size="6" name="PRIMER_PRODUCT_MIN_TM" value="$settings{PRIMER_PRODUCT_MIN_TM}" type="text">
       </td>
       <td class="primer3plus_cell_no_border_right"><a href="$machineSettings{URL_HELP}#PRIMER_PRODUCT_OPT_TM">Opt:</a>
         <input size="6" name="PRIMER_PRODUCT_OPT_TM" value="$settings{PRIMER_PRODUCT_OPT_TM}" type="text">
       </td>
       <td class="primer3plus_cell_no_border_right"><a href="$machineSettings{URL_HELP}#PRIMER_PRODUCT_MAX_TM">Max:</a>
         <input size="6" name="PRIMER_PRODUCT_MAX_TM" value="$settings{PRIMER_PRODUCT_MAX_TM}" type="text">
       </td>
       <td class="primer3plus_cell_no_border">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="PRIMER_PRODUCT_SIZE_INPUT" href="$machineSettings{URL_HELP}#PRIMER_PRODUCT_OPT_SIZE">Product Size</a>
       </td>
       <td class="primer3plus_cell_no_border_right">Min: 
         <input size="6" name="SCRIPT_PRODUCT_MIN_SIZE" 
         value="$settings{SCRIPT_PRODUCT_MIN_SIZE}" type="text">
       </td>
       <td class="primer3plus_cell_no_border_right"><a href="$machineSettings{URL_HELP}#PRIMER_PRODUCT_OPT_SIZE">Opt:</a> 
         <input size="6" name="PRIMER_PRODUCT_OPT_SIZE" 
         value="$settings{PRIMER_PRODUCT_OPT_SIZE}" type="text">
       </td>
       <td class="primer3plus_cell_no_border_right">Max: 
         <input size="6" name="SCRIPT_PRODUCT_MAX_SIZE" 
         value="$settings{SCRIPT_PRODUCT_MAX_SIZE}" type="text">
       </td>
       <td class="primer3plus_cell_no_border">&nbsp;&nbsp;&nbsp;<input name="SCRIPT_DISPLAY_DEBUG_INFORMATION"  value="1" };

	$formHTML .= ($settings{SCRIPT_DISPLAY_DEBUG_INFORMATION}) ? "checked=\"checked\" " : "";
 
	$formHTML .= qq{type="checkbox">
         <a name="SCRIPT_DISPLAY_DEBUG_INFORMATION_INPUT" href="$machineSettings{URL_HELP}#SCRIPT_DISPLAY_DEBUG_INFORMATION">Debug Information</a>
       </td>
     </tr>
   </table>
   <table class="primer3plus_table_no_border">
     <tr>
       <td class="primer3plus_cell_no_border"><input name="PRIMER_PICK_ANYWAY"  value="1" };

	$formHTML .= ($settings{PRIMER_PICK_ANYWAY}) ? "checked=\"checked\" " : "";
 
	$formHTML .= qq{type="checkbox">
         <a name="PRIMER_PICK_ANYWAY_INPUT" href="$machineSettings{URL_HELP}#PRIMER_PICK_ANYWAY">Pick Anyway</a>
         &nbsp;&nbsp;&nbsp;
         <input name="PRIMER_LIBERAL_BASE"  value="1" };

	$formHTML .= ($settings{PRIMER_LIBERAL_BASE}) ? "checked=\"checked\" " : "";
 
	$formHTML .= qq{type="checkbox">
         <a name="PRIMER_LIBERAL_BASE_INPUT" href="$machineSettings{URL_HELP}#PRIMER_LIBERAL_BASE">Liberal Base</a>
         &nbsp;&nbsp;&nbsp;
         <input name="PRIMER_LIB_AMBIGUITY_CODES_CONSENSUS" value="1" };

	$formHTML .= ($settings{PRIMER_LIB_AMBIGUITY_CODES_CONSENSUS}) ? "checked=\"checked\" " : "";
 
	$formHTML .= qq{type="checkbox">
	     <a name="PRIMER_LIB_AMBIGUITY_CODES_CONSENSUS_INPUT" href="$machineSettings{URL_HELP}#PRIMER_LIB_AMBIGUITY_CODES_CONSENSUS">Do not treat ambiguity codes in libraries as consensus</a>
         &nbsp;&nbsp;&nbsp;
         <input name="PRIMER_LOWERCASE_MASKING" value="1" };

	$formHTML .= ($settings{PRIMER_LOWERCASE_MASKING}) ? "checked=\"checked\" " : "";
 
	$formHTML .= qq{type="checkbox">
		<a name="PRIMER_LOWERCASE_MASKING_INPUT" href="$machineSettings{URL_HELP}#PRIMER_LOWERCASE_MASKING">Use Lowercase Masking</a>
       </td>
     </tr>
   </table>

<div id="primer3plus_sequencing" class="primer3plus_section">
   <b>Sequencing</b>
   <table class="primer3plus_table_no_border">
     <colgroup>
       <col width="25%">
       <col width="15%">
       <col width="27%">
       <col width="33%">
     </colgroup>
     <tr>
       <td class="primer3plus_cell_no_border"><a onmouseover="toolTip('Space between primer binding site and the start of readable sequencing');" onmouseout="toolTip();" name="PRIMER_SEQUENCING_LEAD_INPUT" href="$machineSettings{URL_HELP}#PRIMER_SEQUENCING_LEAD">Lead</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_SEQUENCING_LEAD" value="$settings{PRIMER_SEQUENCING_LEAD}" type="text">
       </td>
       <td class="primer3plus_cell_no_border"><a onmouseover="toolTip('Space between the primers on one DNA strand');" onmouseout="toolTip();" name="PRIMER_SEQUENCING_SPACING_INPUT" href="$machineSettings{URL_HELP}#PRIMER_SEQUENCING_SPACING">
         Spacing</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_SEQUENCING_SPACING" value="$settings{PRIMER_SEQUENCING_SPACING}" type="text">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><a onmouseover="toolTip('Space in which Primer3Plus picks the optimal primer');" onmouseout="toolTip();" name="PRIMER_SEQUENCING_ACCURACY_INPUT"
         href="$machineSettings{URL_HELP}#PRIMER_SEQUENCING_ACCURACY">Accuracy</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_SEQUENCING_ACCURACY" value="$settings{PRIMER_SEQUENCING_ACCURACY}" type="text">
       </td>
       <td class="primer3plus_cell_no_border"><a onmouseover="toolTip('Space between primers on the forward and the reverse strand');" onmouseout="toolTip();" name="PRIMER_SEQUENCING_INTERVAL_INPUT" href="$machineSettings{URL_HELP}#PRIMER_SEQUENCING_INTERVAL">
         Interval</a>
       </td>
      <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_SEQUENCING_INTERVAL" value="$settings{PRIMER_SEQUENCING_INTERVAL}" type="text">
       </td>
     </tr> 
   </table></div>
</div>
};

$formHTML .= qq{
<div id="primer3plus_internal_oligo" class="primer3plus_tab_page">
  <div class="primer3plus_section">
   <table class="primer3plus_table_no_border">
     <colgroup>
       <col width="32%">
       <col width="68%">
     </colgroup>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="internal_oligo_generic_INPUT" href="$machineSettings{URL_HELP}#SEQUENCE_INTERNAL_EXCLUDED_REGION">
         Excluded Region:</a>
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
       <td class="primer3plus_cell_no_border"><a name="PRIMER_INTERNAL_OLIGO_SIZE_INPUT">Hyb Oligo Size:</a>
       </td>
       <td class="primer3plus_cell_no_border"><a href="$machineSettings{URL_HELP}#PRIMER_INTERNAL_MIN_SIZE">Min:</a>
         <input size="4" name="PRIMER_INTERNAL_MIN_SIZE" value="$settings{PRIMER_INTERNAL_MIN_SIZE}" type="text">
       </td>
       <td class="primer3plus_cell_no_border"><a href="$machineSettings{URL_HELP}#PRIMER_INTERNAL_OPT_SIZE">Opt:</a>
         <input size="4" name="PRIMER_INTERNAL_OPT_SIZE" value="$settings{PRIMER_INTERNAL_OPT_SIZE}" type="text">
       </td>
       <td class="primer3plus_cell_no_border"><a href="$machineSettings{URL_HELP}#PRIMER_INTERNAL_MAX_SIZE">Max:</a>
         <input size="4" name="PRIMER_INTERNAL_MAX_SIZE" value="$settings{PRIMER_INTERNAL_MAX_SIZE}" type="text">
       </td>
       <td class="primer3plus_cell_no_border">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="PRIMER_OPT_TM_INPUT">Hyb Oligo Tm:</a> 
       </td>
       <td class="primer3plus_cell_no_border"><a href="$machineSettings{URL_HELP}#PRIMER_INTERNAL_MIN_TM">Min:</a>
         <input size="4" name="PRIMER_INTERNAL_MIN_TM" value="$settings{PRIMER_INTERNAL_MIN_TM}" type="text">
       </td>
       <td class="primer3plus_cell_no_border"><a href="$machineSettings{URL_HELP}#PRIMER_INTERNAL_OPT_TM">Opt:</a>
         <input size="4" name="PRIMER_INTERNAL_OPT_TM" value="$settings{PRIMER_INTERNAL_OPT_TM}" type="text"> 
       </td>
       <td class="primer3plus_cell_no_border"><a href="$machineSettings{URL_HELP}#PRIMER_INTERNAL_MAX_TM">Max:</a>
         <input size="4" name="PRIMER_INTERNAL_MAX_TM" value="$settings{PRIMER_INTERNAL_MAX_TM}" type="text">
       </td>
       <td class="primer3plus_cell_no_border">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="PRIMER_INTERNAL_OLIGO_GC_INPUT">Hyb Oligo GC%</a>
       </td>
       <td class="primer3plus_cell_no_border"><a href="$machineSettings{URL_HELP}#PRIMER_INTERNAL_MIN_GC">Min:</a>
         <input size="4" name="PRIMER_INTERNAL_MIN_GC" value="$settings{PRIMER_INTERNAL_MIN_GC}" type="text">
       </td>
       <td class="primer3plus_cell_no_border"><a href="$machineSettings{URL_HELP}#PRIMER_INTERNAL_OPT_GC_PERCENT">Opt:</a>
         <input size="4" name="PRIMER_INTERNAL_OPT_GC_PERCENT" value="$settings{PRIMER_INTERNAL_OPT_GC_PERCENT}" type="text">
       </td>
       <td class="primer3plus_cell_no_border"><a href="$machineSettings{URL_HELP}#PRIMER_INTERNAL_MAX_GC">Max:</a>
         <input size="4" name="PRIMER_INTERNAL_MAX_GC" value="$settings{PRIMER_INTERNAL_MAX_GC}" type="text">
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
       <td class="primer3plus_cell_no_border"><a name="PRIMER_INTERNAL_SALT_MONOVALENT_INPUT" href="$machineSettings{URL_HELP}#PRIMER_INTERNAL_SALT_MONOVALENT">
         Hyb Oligo Monovalent Cations Concentration:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_INTERNAL_SALT_MONOVALENT"
         value="$settings{PRIMER_INTERNAL_SALT_MONOVALENT}" type="text">
       </td>
       <td class="primer3plus_cell_no_border"><a name="PRIMER_INTERNAL_DNA_CONC_INPUT" href="$machineSettings{URL_HELP}#PRIMER_INTERNAL_DNA_CONC">
         Hyb Oligo DNA Concentration:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_INTERNAL_DNA_CONC"
         value="$settings{PRIMER_INTERNAL_DNA_CONC}" type="text">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="PRIMER_INTERNAL_SALT_DIVALENT_INPUT" href="$machineSettings{URL_HELP}#PRIMER_INTERNAL_SALT_DIVALENT">
         Hyb Oligo Divalent Cations Concentration:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_INTERNAL_SALT_DIVALENT"
         value="$settings{PRIMER_INTERNAL_SALT_DIVALENT}" type="text">
       </td>
       <td class="primer3plus_cell_no_border"><a name="PRIMER_INTERNAL_DNTP_CONC_INPUT" href="$machineSettings{URL_HELP}#PRIMER_INTERNAL_DNTP_CONC">
         Hyb Oligo dNTP Concentration:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_INTERNAL_DNTP_CONC"
         value="$settings{PRIMER_INTERNAL_DNTP_CONC}" type="text">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="PRIMER_INTERNAL_MAX_NS_ACCEPTED_INPUT" href="$machineSettings{URL_HELP}#PRIMER_INTERNAL_MAX_NS_ACCEPTED">
         Max #Ns:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_INTERNAL_MAX_NS_ACCEPTED"
         value="$settings{PRIMER_INTERNAL_MAX_NS_ACCEPTED}" type="text">
       </td>
       <td class="primer3plus_cell_no_border"><a name="PRIMER_INTERNAL_MAX_POLY_X_INPUT" href="$machineSettings{URL_HELP}#PRIMER_INTERNAL_MAX_POLY_X">
         Hyb Oligo Max Poly-X:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_INTERNAL_MAX_POLY_X"
         value="$settings{PRIMER_INTERNAL_MAX_POLY_X}" type="text">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="PRIMER_INTERNAL_MAX_SELF_ANY_INPUT" href="$machineSettings{URL_HELP}#PRIMER_INTERNAL_MAX_SELF_ANY">
         Hyb Oligo Self Complementarity:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_INTERNAL_MAX_SELF_ANY"
         value="$settings{PRIMER_INTERNAL_MAX_SELF_ANY}" type="text">
       </td>
       <td class="primer3plus_cell_no_border"><a name="PRIMER_INTERNAL_MAX_SELF_END_INPUT" href="$machineSettings{URL_HELP}#PRIMER_INTERNAL_MAX_SELF_END">
         Hyb Oligo Max End Self Complementarity:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_INTERNAL_MAX_SELF_END"
         value="$settings{PRIMER_INTERNAL_MAX_SELF_END}" type="text">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border_th"><a name="PRIMER_INTERNAL_MAX_SELF_ANY_TH_INPUT" href="$machineSettings{URL_HELP}#PRIMER_INTERNAL_MAX_SELF_ANY_TH">
         TH: Hyb Oligo Self Complementarity:</a>
       </td>
       <td class="primer3plus_cell_no_border_th"><input size="4" name="PRIMER_INTERNAL_MAX_SELF_ANY_TH"
         value="$settings{PRIMER_INTERNAL_MAX_SELF_ANY_TH}" type="text">
       </td>
       <td class="primer3plus_cell_no_border_th"><a name="PRIMER_INTERNAL_MAX_SELF_END_TH_INPUT" href="$machineSettings{URL_HELP}#PRIMER_INTERNAL_MAX_SELF_END_TH">
         TH: Hyb Oligo Max End Self Complementarity:</a>
       </td>
       <td class="primer3plus_cell_no_border_th"><input size="4" name="PRIMER_INTERNAL_MAX_SELF_END_TH"
         value="$settings{PRIMER_INTERNAL_MAX_SELF_END_TH}" type="text">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border_th"><a name="PRIMER_INTERNAL_MAX_HAIRPIN_TH_INPUT" href="$machineSettings{URL_HELP}#PRIMER_INTERNAL_MAX_HAIRPIN_TH">
         TH: Hyb Oligo Max Hairpin:</a>
       </td>
       <td class="primer3plus_cell_no_border_th"><input size="4" name="PRIMER_INTERNAL_MAX_HAIRPIN_TH"
         value="$settings{PRIMER_INTERNAL_MAX_HAIRPIN_TH}" type="text">
       </td>
       <td class="primer3plus_cell_no_border"><a name="PRIMER_INTERNAL_MAX_LIBRARY_MISHYB_INPUT" href="$machineSettings{URL_HELP}#PRIMER_INTERNAL_MAX_LIBRARY_MISHYB">
         Max Library Mishyb:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_INTERNAL_MAX_LIBRARY_MISHYB"
         value="$settings{PRIMER_INTERNAL_MAX_LIBRARY_MISHYB}" type="text">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="PRIMER_INTERNAL_MISHYB_LIBRARY_INPUT" href="$machineSettings{URL_HELP}#PRIMER_INTERNAL_MISHYB_LIBRARY">
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
     <tr>
       <td class="primer3plus_cell_no_border"><a name="PRIMER_INTERNAL_MIN_QUALITY_INPUT" href="$machineSettings{URL_HELP}#PRIMER_INTERNAL_MIN_QUALITY">
         Hyb Oligo Min Sequence Quality:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_INTERNAL_MIN_QUALITY"
         value="$settings{PRIMER_INTERNAL_MIN_QUALITY}" type="text">
       </td>
       <td class="primer3plus_cell_no_border">
       </td>
       <td class="primer3plus_cell_no_border">
       </td>
     </tr>
   </table>
  </div>
</div>
};

##################################
# Create the PENALTY WEIGHTS tab #
##################################
$formHTML .= qq{
<div id="primer3plus_penalties" class="primer3plus_tab_page">
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
       <h3>For Internal Oligos</h3>
       </td>
       <td class="primer3plus_cell_penalties">
       <h3>For Primer Pairs</h3>
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
       <td class="primer3plus_cell_penalties"><a name="PRIMER_WT_SIZE_INPUT">Size</a>
       </td>
       <td class="primer3plus_cell_penalties"><a href="$machineSettings{URL_HELP}#PRIMER_WT_SIZE_LT">Lt:</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_WT_SIZE_LT"
         value="$settings{PRIMER_WT_SIZE_LT}" type="text">
       </td>
       <td class="primer3plus_cell_penalties"><a href="$machineSettings{URL_HELP}#PRIMER_WT_SIZE_GT">Gt:</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_WT_SIZE_GT"
         value="$settings{PRIMER_WT_SIZE_GT}" type="text">
       </td>
       <td class="primer3plus_cell_penalties"><a name="PRIMER_INTERNAL_WT_SIZE_INPUT">Size</a>
       </td>
       <td class="primer3plus_cell_penalties"><a href="$machineSettings{URL_HELP}#PRIMER_INTERNAL_WT_SIZE_LT">Lt:</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_INTERNAL_WT_SIZE_LT"
         value="$settings{PRIMER_INTERNAL_WT_SIZE_LT}" type="text">
       </td>
       <td class="primer3plus_cell_penalties"><a href="$machineSettings{URL_HELP}#PRIMER_INTERNAL_WT_SIZE_GT">Gt:</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_INTERNAL_WT_SIZE_GT"
         value="$settings{PRIMER_INTERNAL_WT_SIZE_GT}" type="text">
       </td>
       <td class="primer3plus_cell_penalties"><a name="PAIR_WT_PRODUCT_SIZE_INPUT">Product Size</a>
       </td>
       <td class="primer3plus_cell_penalties"><a href="$machineSettings{URL_HELP}#PRIMER_PAIR_WT_PRODUCT_SIZE_LT">Lt:</a> 
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_PAIR_WT_PRODUCT_SIZE_LT"
         value="$settings{PRIMER_PAIR_WT_PRODUCT_SIZE_LT}" type="text"> 
       </td>
       <td class="primer3plus_cell_penalties"><a href="$machineSettings{URL_HELP}#PRIMER_PAIR_WT_PRODUCT_SIZE_GT">Gt:</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_PAIR_WT_PRODUCT_SIZE_GT"
         value="$settings{PRIMER_PAIR_WT_PRODUCT_SIZE_GT}" type="text">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_penalties"><a name="PRIMER_WT_TM_INPUT">Tm</a>
       </td>
       <td class="primer3plus_cell_penalties"><a href="$machineSettings{URL_HELP}#PRIMER_WT_TM_LT">Lt:</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_WT_TM_LT"
         value="$settings{PRIMER_WT_TM_LT}" type="text">
       </td>
       <td class="primer3plus_cell_penalties"><a href="$machineSettings{URL_HELP}#PRIMER_WT_TM_GT">Gt:</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_WT_TM_GT"
         value="$settings{PRIMER_WT_TM_GT}" type="text">
       </td>
       <td class="primer3plus_cell_penalties"><a name="PRIMER_INTERNAL_WT_TM_INPUT">Tm</a>
       </td>
       <td class="primer3plus_cell_penalties"><a href="$machineSettings{URL_HELP}#PRIMER_INTERNAL_WT_TM_LT">Lt:</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_INTERNAL_WT_TM_LT"
         value="$settings{PRIMER_INTERNAL_WT_TM_LT}" type="text">
       </td>
       <td class="primer3plus_cell_penalties"><a href="$machineSettings{URL_HELP}#PRIMER_INTERNAL_WT_TM_GT">Gt:</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_INTERNAL_WT_TM_GT"
         value="$settings{PRIMER_INTERNAL_WT_TM_GT}" type="text">
       </td>
       <td class="primer3plus_cell_penalties"><a name="PAIR_WT_DIFF_TM_INPUT" href="$machineSettings{URL_HELP}#PRIMER_PAIR_WT_DIFF_TM">Tm Difference</a>
       </td>
       <td class="primer3plus_cell_penalties"> 
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
       <td class="primer3plus_cell_penalties"><a name="PRIMER_WT_GC_PERCENT_INPUT">GC%</a> 
       </td>
       <td class="primer3plus_cell_penalties"><a href="$machineSettings{URL_HELP}#PRIMER_WT_GC_PERCENT_LT">Lt:</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_WT_GC_PERCENT_LT"
         value="$settings{PRIMER_WT_GC_PERCENT_LT}" type="text">
       </td>
       <td class="primer3plus_cell_penalties"><a href="$machineSettings{URL_HELP}#PRIMER_WT_GC_PERCENT_GT">Gt:</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_WT_GC_PERCENT_GT"
         value="$settings{PRIMER_WT_GC_PERCENT_GT}" type="text">
       </td>
       <td class="primer3plus_cell_penalties"><a name="PRIMER_INTERNAL_WT_GC_PERCENT_INPUT">GC%</a>
       </td>
       <td class="primer3plus_cell_penalties"><a href="$machineSettings{URL_HELP}#PRIMER_INTERNAL_WT_GC_PERCENT_LT">Lt:</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_INTERNAL_WT_GC_PERCENT_LT"
         value="$settings{PRIMER_INTERNAL_WT_GC_PERCENT_LT}" type="text">
       </td>
       <td class="primer3plus_cell_penalties"><a href="$machineSettings{URL_HELP}#PRIMER_INTERNAL_WT_GC_PERCENT_GT">Gt:</a> 
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_INTERNAL_WT_GC_PERCENT_GT"
         value="$settings{PRIMER_INTERNAL_WT_GC_PERCENT_GT}" type="text">
       </td>
       <td class="primer3plus_cell_penalties"><a name="PAIR_WT_PRODUCT_TM_INPUT">Product Tm</a>
       </td>
       <td class="primer3plus_cell_penalties"><a href="$machineSettings{URL_HELP}#PRIMER_PAIR_WT_PRODUCT_TM_LT">Lt:</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_PAIR_WT_PRODUCT_TM_LT"
         value="$settings{PRIMER_PAIR_WT_PRODUCT_TM_LT}" type="text"> 
       </td>
       <td class="primer3plus_cell_penalties"><a href="$machineSettings{URL_HELP}#PRIMER_PAIR_WT_PRODUCT_TM_GT">Gt:</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_PAIR_WT_PRODUCT_TM_GT"
         value="$settings{PRIMER_PAIR_WT_PRODUCT_TM_GT}" type="text">
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
       <td class="primer3plus_cell_penalties"><a name="PRIMER_WT_TEMPLATE_MISPRIMING_INPUT" href="$machineSettings{URL_HELP}#PRIMER_WT_TEMPLATE_MISPRIMING">Template Mispriming</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_WT_TEMPLATE_MISPRIMING"
         value="$settings{PRIMER_WT_TEMPLATE_MISPRIMING}" type="text">
       </td>
       <td class="primer3plus_cell_penalties">
       </td>
       <td class="primer3plus_cell_penalties">
       </td>
       <td class="primer3plus_cell_penalties"><a name="PRIMER_PAIR_WT_TEMPLATE_MISPRIMING_INPUT" href="$machineSettings{URL_HELP}#PRIMER_PAIR_WT_TEMPLATE_MISPRIMING">Template Mispriming</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_PAIR_WT_TEMPLATE_MISPRIMING"
         value="$settings{PRIMER_PAIR_WT_TEMPLATE_MISPRIMING}" type="text">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_penalties_th"><a name="PRIMER_WT_TEMPLATE_MISPRIMING_TH_INPUT" href="$machineSettings{URL_HELP}#PRIMER_WT_TEMPLATE_MISPRIMING_TH">TH: Template Mispriming</a>
       </td>
       <td class="primer3plus_cell_penalties_th"><input size="4" name="PRIMER_WT_TEMPLATE_MISPRIMING_TH"
         value="$settings{PRIMER_WT_TEMPLATE_MISPRIMING_TH}" type="text">
       </td>
       <td class="primer3plus_cell_penalties">
       </td>
       <td class="primer3plus_cell_penalties">
       </td>
       <td class="primer3plus_cell_penalties_th"><a name="PRIMER_PAIR_WT_TEMPLATE_MISPRIMING_TH_INPUT" href="$machineSettings{URL_HELP}#PRIMER_PAIR_WT_TEMPLATE_MISPRIMING_TH">TH: Template Mispriming</a>
       </td>
       <td class="primer3plus_cell_penalties_th"><input size="4" name="PRIMER_PAIR_WT_TEMPLATE_MISPRIMING_TH"
         value="$settings{PRIMER_PAIR_WT_TEMPLATE_MISPRIMING_TH}" type="text">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_penalties"><a name="PRIMER_WT_LIBRARY_MISPRIMING_INPUT" href="$machineSettings{URL_HELP}#PRIMER_WT_LIBRARY_MISPRIMING">Library Mispriming</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_WT_LIBRARY_MISPRIMING"
         value="$settings{PRIMER_WT_LIBRARY_MISPRIMING}" type="text">
       </td>
       <td class="primer3plus_cell_penalties"><a name="PRIMER_INTERNAL_WT_LIBRARY_MISHYB_INPUT" href="$machineSettings{URL_HELP}#PRIMER_INTERNAL_WT_LIBRARY_MISHYB">Library Mishyb</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_INTERNAL_WT_LIBRARY_MISHYB"
         value="$settings{PRIMER_INTERNAL_WT_LIBRARY_MISHYB}" type="text">
       </td>
       <td class="primer3plus_cell_penalties"><a name="PRIMER_PAIR_WT_LIBRARY_MISPRIMING_INPUT" href="$machineSettings{URL_HELP}#PRIMER_PAIR_WT_LIBRARY_MISPRIMING">Library Mispriming</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_PAIR_WT_LIBRARY_MISPRIMING"
         value="$settings{PRIMER_PAIR_WT_LIBRARY_MISPRIMING}" type="text">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_penalties"><a name="PRIMER_WT_SELF_ANY_INPUT" href="$machineSettings{URL_HELP}#PRIMER_WT_SELF_ANY">Self Complementarity</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_WT_SELF_ANY"
         value="$settings{PRIMER_WT_SELF_ANY}" type="text">
       </td>
       <td class="primer3plus_cell_penalties"><a name="PRIMER_INTERNAL_WT_SELF_ANY_INPUT" href="$machineSettings{URL_HELP}#PRIMER_INTERNAL_WT_SELF_ANY">
         Self Complementarity</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_INTERNAL_WT_SELF_ANY"
         value="$settings{PRIMER_INTERNAL_WT_SELF_ANY}" type="text">
       </td>
       <td class="primer3plus_cell_penalties"><a name="PRIMER_PAIR_WT_COMPL_ANY_INPUT" href="$machineSettings{URL_HELP}#PRIMER_PAIR_WT_COMPL_ANY">
         Pair Complementarity</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_PAIR_WT_COMPL_ANY"
         value="$settings{PRIMER_PAIR_WT_COMPL_ANY}" type="text">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_penalties_th"><a name="PRIMER_WT_SELF_ANY_TH_INPUT" href="$machineSettings{URL_HELP}#PRIMER_WT_SELF_ANY_TH">
         TH: Self Complementarity</a>
       </td>
       <td class="primer3plus_cell_penalties_th"><input size="4" name="PRIMER_WT_SELF_ANY_TH"
         value="$settings{PRIMER_WT_SELF_ANY_TH}" type="text">
       </td>
       <td class="primer3plus_cell_penalties_th"><a name="PRIMER_INTERNAL_WT_SELF_ANY_TH_INPUT" href="$machineSettings{URL_HELP}#PRIMER_INTERNAL_WT_SELF_ANY_TH">
         TH: Self Complementarity</a>
       </td>
       <td class="primer3plus_cell_penalties_th"><input size="4" name="PRIMER_INTERNAL_WT_SELF_ANY_TH"
         value="$settings{PRIMER_INTERNAL_WT_SELF_ANY_TH}" type="text">
       </td>
       <td class="primer3plus_cell_penalties_th"><a name="PRIMER_PAIR_WT_COMPL_ANY_TH_INPUT" href="$machineSettings{URL_HELP}#PRIMER_PAIR_WT_COMPL_ANY_TH">
         TH: Pair Complementarity</a>
       </td>
       <td class="primer3plus_cell_penalties_th"><input size="4" name="PRIMER_PAIR_WT_COMPL_ANY_TH"
         value="$settings{PRIMER_PAIR_WT_COMPL_ANY_TH}" type="text">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_penalties"><a name="PRIMER_WT_SELF_END_INPUT" href="$machineSettings{URL_HELP}#PRIMER_WT_SELF_END">End Self Complementarity</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_WT_SELF_END"
         value="$settings{PRIMER_WT_SELF_END}" type="text">
       </td>
       <td class="primer3plus_cell_penalties"><a name="PRIMER_INTERNAL_WT_SELF_END_INPUT" href="$machineSettings{URL_HELP}#PRIMER_INTERNAL_WT_SELF_END">End Self Complementarity</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_INTERNAL_WT_SELF_END"
         value="$settings{PRIMER_INTERNAL_WT_SELF_END}" type="text">
       </td>
       <td class="primer3plus_cell_penalties"><a name="PRIMER_PAIR_WT_COMPL_END_INPUT" href="$machineSettings{URL_HELP}#PRIMER_PAIR_WT_COMPL_END">Pair End Complementarity</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_PAIR_WT_COMPL_END"
         value="$settings{PRIMER_PAIR_WT_COMPL_END}" type="text">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_penalties_th"><a name="PRIMER_WT_SELF_END_TH_INPUT" href="$machineSettings{URL_HELP}#PRIMER_WT_SELF_END_TH">
         TH: End Self Complementarity</a>
       </td>
       <td class="primer3plus_cell_penalties_th"><input size="4" name="PRIMER_WT_SELF_END_TH"
         value="$settings{PRIMER_WT_SELF_END_TH}" type="text">
       </td>
       <td class="primer3plus_cell_penalties_th"><a name="PRIMER_INTERNAL_WT_SELF_END_TH_INPUT" href="$machineSettings{URL_HELP}#PRIMER_INTERNAL_WT_SELF_END_TH">
         TH: End Self Complementarity</a>
       </td>
       <td class="primer3plus_cell_penalties_th"><input size="4" name="PRIMER_INTERNAL_WT_SELF_END_TH"
         value="$settings{PRIMER_INTERNAL_WT_SELF_END_TH}" type="text">
       </td>
       <td class="primer3plus_cell_penalties_th"><a name="PRIMER_PAIR_WT_COMPL_END_TH_INPUT" href="$machineSettings{URL_HELP}#PRIMER_PAIR_WT_COMPL_END_TH">
         TH: Pair End Complementarity</a>
       </td>
       <td class="primer3plus_cell_penalties_th"><input size="4" name="PRIMER_PAIR_WT_COMPL_END_TH"
         value="$settings{PRIMER_PAIR_WT_COMPL_END_TH}" type="text">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_penalties_th"><a name="PRIMER_WT_HAIRPIN_TH_INPUT" href="$machineSettings{URL_HELP}#PRIMER_WT_HAIRPIN_TH">
         TH: Hairpin</a>
       </td>
       <td class="primer3plus_cell_penalties_th"><input size="4" name="PRIMER_WT_HAIRPIN_TH"
         value="$settings{PRIMER_WT_HAIRPIN_TH}" type="text">
       </td>
       <td class="primer3plus_cell_penalties_th"><a name="PRIMER_INTERNAL_WT_HAIRPIN_TH_INPUT" href="$machineSettings{URL_HELP}#PRIMER_INTERNAL_WT_HAIRPIN_TH">
         TH: Hairpin</a>
       </td>
       <td class="primer3plus_cell_penalties_th"><input size="4" name="PRIMER_INTERNAL_WT_HAIRPIN_TH"
         value="$settings{PRIMER_INTERNAL_WT_HAIRPIN_TH}" type="text">
       </td>
       <td class="primer3plus_cell_penalties_th">
       </td>
       <td class="primer3plus_cell_penalties_th">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_penalties"><a name="PRIMER_WT_NUM_NS_INPUT" href="$machineSettings{URL_HELP}#PRIMER_WT_NUM_NS">#N's</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_WT_NUM_NS"
         value="$settings{PRIMER_WT_NUM_NS}" type="text">
       </td>
       <td class="primer3plus_cell_penalties"><a name="PRIMER_INTERNAL_WT_NUM_NS_INPUT" href="$machineSettings{URL_HELP}#PRIMER_INTERNAL_WT_NUM_NS">Hyb Oligo #N's</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_INTERNAL_WT_NUM_NS"
         value="$settings{PRIMER_INTERNAL_WT_NUM_NS}" type="text">
       </td>
       <td class="primer3plus_cell_penalties">
       </td>
       <td class="primer3plus_cell_penalties">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_penalties"><a name="PRIMER_WT_SEQ_QUAL_INPUT" href="$machineSettings{URL_HELP}#PRIMER_WT_SEQ_QUAL">Sequence Quality</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_WT_SEQ_QUAL"
         value="$settings{PRIMER_WT_SEQ_QUAL}" type="text">
       </td>
       <td class="primer3plus_cell_penalties"><a name="PRIMER_INTERNAL_WT_SEQ_QUAL_INPUT" href="$machineSettings{URL_HELP}#PRIMER_INTERNAL_WT_SEQ_QUAL">Sequence Quality</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_INTERNAL_WT_SEQ_QUAL"
         value="$settings{PRIMER_INTERNAL_WT_SEQ_QUAL}" type="text">
       </td>
       <td class="primer3plus_cell_penalties">
       </td>
       <td class="primer3plus_cell_penalties">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_penalties"><a name="PRIMER_WT_END_QUAL_INPUT" href="$machineSettings{URL_HELP}#PRIMER_WT_END_QUAL">End Sequence Quality</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_WT_END_QUAL"
         value="$settings{PRIMER_WT_END_QUAL}" type="text">
       </td>
       <td class="primer3plus_cell_penalties"><a name="PRIMER_INTERNAL_WT_END_QUAL_INPUT" href="$machineSettings{URL_HELP}#PRIMER_INTERNAL_WT_END_QUAL">End Sequence Quality</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_INTERNAL_WT_END_QUAL"
         value="$settings{PRIMER_INTERNAL_WT_END_QUAL}" type="text">
       </td>
       <td class="primer3plus_cell_penalties">
       </td>
       <td class="primer3plus_cell_penalties">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_penalties"><a name="PRIMER_WT_POS_PENALTY_INPUT" href="$machineSettings{URL_HELP}#PRIMER_WT_POS_PENALTY">Position Penalty</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_WT_POS_PENALTY"
         value="$settings{PRIMER_WT_POS_PENALTY}" type="text">
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
       <td class="primer3plus_cell_penalties"><a name="PRIMER_WT_END_STABILITY_INPUT" href="$machineSettings{URL_HELP}#PRIMER_WT_END_STABILITY">End Stability</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_WT_END_STABILITY"
         value="$settings{PRIMER_WT_END_STABILITY}" type="text">
       </td>
       <td class="primer3plus_cell_penalties">
       </td>
       <td class="primer3plus_cell_penalties">
       </td>
       <td class="primer3plus_cell_penalties"><a name="PRIMER_PAIR_WT_PR_PENALTY_INPUT" href="$machineSettings{URL_HELP}#PRIMER_PAIR_WT_PR_PENALTY">
         Primer Penalty Weight</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_PAIR_WT_PR_PENALTY"
         value="$settings{PRIMER_PAIR_WT_PR_PENALTY}" type="text">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_penalties"><a name="PRIMER_INSIDE_PENALTY_INPUT" href="$machineSettings{URL_HELP}#PRIMER_INSIDE_PENALTY">
         Inside Target Penalty:</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_INSIDE_PENALTY"
         value="$settings{PRIMER_INSIDE_PENALTY}" type="text">
       </td>
       <td class="primer3plus_cell_penalties">
       </td>
       <td class="primer3plus_cell_penalties">
       </td>
       <td class="primer3plus_cell_penalties"><a name="PRIMER_PAIR_WT_IO_PENALTY_INPUT" href="$machineSettings{URL_HELP}#PRIMER_PAIR_WT_IO_PENALTY">
         Hyb Oligo Penalty Weight</a>
       </td>
       <td class="primer3plus_cell_penalties"><input size="4" name="PRIMER_PAIR_WT_IO_PENALTY"
         value="$settings{PRIMER_PAIR_WT_IO_PENALTY}" type="text">
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

</form>

</div>	
<script type="text/javascript">
function initPage() {
    hideTabs();
	showTab('tab1','primer3plus_main_tab');
    id = "primer3plus_explain_" + "$settings{PRIMER_TASK}";
    showTopic(id);
}
initPage();
</script>
};

  my $returnString = $templateText;
  
  my $canon = qq{  <link rel=canonical href="https://primer3plus.com/cgi-bin/dev/primer3plus.cgi" />
</head>};

  $returnString =~ s/<\/head>/$canon/;

  $returnString =~ s/<title>Primer3Plus<\/title>/<title>Primer3Plus - Pick Primers<\/title>/;

  my $metaDesc = qq{<meta name="description" content="Primer3Plus picks primers from a DNA sequence using Primer3. This is the latest version straight from the developers with all the new features.">};
  $returnString =~ s/<meta name="description" content=".+?">/$metaDesc/;

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

$formHTML .= divTopBar(0,0,0);

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

#######################################################
# geneBroHTML: Writes the jump page to genome Browser #
#######################################################
sub geneBroHTML {
  my ($completeParameters, $results); 
  $completeParameters = shift;

  my $jumpPath = "";
  $jumpPath .= $completeParameters->{GENBRO_RETURN_PATH};
  $jumpPath .= "?db=";
  $jumpPath .= $completeParameters->{GENBRO_DB};
  $jumpPath .= "&position=";
  $jumpPath .= $completeParameters->{GENBRO_POSITION};
  $jumpPath .= "&hgct_customText=";
  $jumpPath .= $completeParameters->{GENBRO_FILE};

  my $returnHTML = qq{<html>
<head>
   <meta http-equiv="refresh"
   content="0; url=$jumpPath">
</head>
<body>
   <p>You are being redirected to Genome Browser:
   <a href="$jumpPath">$jumpPath</a></p>
</body>
</html>};

  return $returnHTML;
}



##################################################################
# mainResultsHTML: Will select the function to write a HTML-Form #
##################################################################
sub mainResultsHTML {
  my ($completeParameters, $results); 
  $completeParameters = shift;
  $results = shift;

  my $task = $results->{"PRIMER_TASK"};
  my $pair_count = 0;
  my $primer_count = 0;
  my $returnHTML = "";

  # Get the frame for the webpage
  my $templateText = getWrapper();

  # Push all errors to the messages array
  if (defined ($results->{PRIMER_ERROR}) and (($results->{PRIMER_ERROR}) ne "")) {
      divErrorsWarning($results->{PRIMER_ERROR});
  }
  if (defined ($results->{PRIMER_WARNING}) and (($results->{PRIMER_WARNING}) ne "")) {
      divErrorsWarning($results->{PRIMER_WARNING});
  }

  # Figure out if any primers were returned and
  # write a helping page if no primers are returned  
  if (defined $results->{"PRIMER_PAIR_NUM_RETURNED"}){
      $pair_count = $results->{"PRIMER_PAIR_NUM_RETURNED"};
  }
  if (defined $results->{"PRIMER_LEFT_NUM_RETURNED"}){
      $primer_count = $results->{"PRIMER_LEFT_NUM_RETURNED"};
  }
  if (defined $results->{"PRIMER_INTERNAL_NUM_RETURNED"}){
      $primer_count += $results->{"PRIMER_INTERNAL_NUM_RETURNED"};
  }
  if (defined $results->{"PRIMER_RIGHT_NUM_RETURNED"}){
      $primer_count += $results->{"PRIMER_RIGHT_NUM_RETURNED"};
  }

  
  # Now work out the HTML code
  #---------------------------
  
  $returnHTML = qq{
<div id="primer3plus_complete">
};
  # Write the top bar
  $returnHTML .= divTopBar(0,0,0);
  # Write the error messages
  $returnHTML .= divMessages();
  # Start the primer3plus results section
  $returnHTML .= qq{
<div id="primer3plus_results">
};
  # Write the back button
  $returnHTML .= divReturnToInput($completeParameters);

  # Link to Genome Browser if possible
  if ($completeParameters->{"GENBRO_RETURN_PATH"} ne "") {
      $returnHTML .= divGenomeBrowser($completeParameters); 
  }
 
  # Display debug information
  if ((defined $results->{"SCRIPT_DISPLAY_DEBUG_INFORMATION"}) and ($results->{"SCRIPT_DISPLAY_DEBUG_INFORMATION"} eq 1)){
      $returnHTML .= printDebugInfo($results, "The Primer3Plus results hash", 1);
  }

  # Write some help if no primers found
  if ($primer_count == 0){
      $returnHTML .= createResultsNoPrimers($results);       
  } 
  # If only one primer was found we write the results different
  elsif ($primer_count == 1) {
      $returnHTML .= createResultsPrimerCheck($results);
  }
  # Print out pair boxes
  elsif ($pair_count != 0) {
      $returnHTML .= createResultsDetection($results);
  } 
  # Sequencing needs a different sequenceprint
  elsif ($task eq "pick_sequencing_primers") {
      $returnHTML .= createResultsPrimerList($completeParameters, $results, "0");
  } 
  # The regular output
  else {
      $returnHTML .= createResultsPrimerList($completeParameters, $results, "1");
  } 

# This should never happen - it prints the hash
#  else {
#      $returnHTML .= createResultsList($results);
#  }

# Close the complete and the results div
$returnHTML .= qq{
</div>
</div>
};

  # Embedd the created HTML code into the loaded template file
  my $returnString = $templateText;
  $returnString =~ s/<!-- Primer3plus will include code here -->/$returnHTML/;

  return $returnString;
}

###########################################################################
# createResultsPrefoldHTML: Will select the function to write a HTML-Form #
###########################################################################
sub createResultsPrefoldHTML {
  my ($completeParameters, $results); 
  $completeParameters = shift;
  $results = shift;

  my $returnHTML = "";

  # Get the frame for the webpage
  my $templateText = getWrapper();

  # Now work out the HTML code
  #---------------------------
  
  $returnHTML = qq{
<div id="primer3plus_complete">
};
  # Write the top bar
  $returnHTML .= divTopBar("Primer3Prefold","avoid secondary structures",0);
  # Write the error messages
  $returnHTML .= divMessages();

  # Start the primer3plus results section
  $returnHTML .= qq{
<div id="primer3plus_results">
};
  # Display debug information
  if ((defined $results->{"SCRIPT_DISPLAY_DEBUG_INFORMATION"}) and ($results->{"SCRIPT_DISPLAY_DEBUG_INFORMATION"} eq 1)){
      $returnHTML .= printDebugInfo($results, "The Primer3Plus results hash", 1);
  }

$returnHTML .= qq{
<form action="$machineSettings{URL_FORM_ACTION}" method="post" enctype="multipart/form-data">

<input type="hidden" name="SEQUENCE_ID" value="$results->{"SEQUENCE_ID"}">
<input type="hidden" name="SEQUENCE_TEMPLATE" value="$results->{"SEQUENCE_TEMPLATE"}">
<input type="hidden" name="PRIMER_FIRST_BASE_INDEX" value="$results->{"PRIMER_FIRST_BASE_INDEX"}">
<input type="hidden" name="PRIMER_SALT_MONOVALENT" value="$results->{"PRIMER_SALT_MONOVALENT"}">
<input type="hidden" name="PRIMER_SALT_DIVALENT" value="$results->{"PRIMER_SALT_DIVALENT"}">
<input type="hidden" name="PRIMER_OPT_TM" value="$results->{"PRIMER_OPT_TM"}">
<input type="hidden" name="SEQUENCE_EXCLUDED_REGION" value="$results->{"SEQUENCE_EXCLUDED_REGION"}">
<input type="hidden" name="SCRIPT_DISPLAY_DEBUG_INFORMATION" value="$results->{"SCRIPT_DISPLAY_DEBUG_INFORMATION"}">

<h2>Regions with secondary structures are displayed red:</h2>

<div class="primer3plus_submit">
<input name="Submit" value="Send to Primer3Plus" type="submit">
</div>

<br /><br /><br />
};

$returnHTML .= divHTMLsequence($results, "-1");

# Close the complete and the results div
$returnHTML .= qq{

<div class="primer3plus_submit">
<br /><br />
<input name="Submit" value="Send to Primer3Plus" type="submit">
</div>
	
</form>

</div>
</div>
};

  # Embedd the created HTML code into the loaded template file
  my $returnString = $templateText;

  $returnString =~ s/<!-- Primer3plus will include code here -->/$returnHTML/;

  return $returnString;
}

#########################################################################
# divErrorsWarning: Writes the Errors and warnings in the message array #   
#########################################################################
sub divErrorsWarning {
    my $errorString = shift;
    my @messages;
    my $mess;
    
    @messages = split ';', $errorString;
    
    foreach $mess (@messages) {
        setMessage("Error: $mess");
    }
    
    return 0;
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
if (defined ($settings{"PRIMER_INTERNAL_EXPLAIN"}) and (($settings{"PRIMER_INTERNAL_EXPLAIN"}) ne "")) {
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

##################################################################################
# createResultsNoPrimers: Will write an HTML-Form based if no primers were found #
##################################################################################
sub createResultsNoPrimers {
  my $settings = shift;

  my $formHTML =  qq{
<br>
Primer3plus could not pick any primers. Try less strict settings.<br>
<br>
};

$formHTML .= divStatistics($settings);

  return $formHTML;
}

###################################################################################
# createResultsPrimerCheck: Will write an HTML-Form for the check Primer Function #
###################################################################################

sub createResultsPrimerCheck {
  my $results = shift;
  my $type;
  my $formHTML = "";

  my $primerStart;
  my $primerLength;
  my $primerTM;
  my $primerGC;
  my $primerSelf;
  my $primerAny;
  my $primerEnd;
  my $primerHairpin;
  my $primerStab;
  my $primerPenalty;
  
  my $thAdd = "";
  if (($results->{"PRIMER_THERMODYNAMIC_OLIGO_ALIGNMENT"}) eq "1") {
  	  $thAdd = "_TH";
  }
  my $thTmAdd = "";
  if (($results->{"PRIMER_THERMODYNAMIC_TEMPLATE_ALIGNMENT"}) eq "1") {
  	  $thTmAdd = "_TH";
  }

  ## Figure out which primer to return
  ## This function will be only run if only one primer was found
  if (defined ($results->{"PRIMER_LEFT_0_SEQUENCE"})) {
      $type = "LEFT";
  }
  if (defined ($results->{"PRIMER_RIGHT_0_SEQUENCE"})) {
      $type = "RIGHT";
  }
  if (defined ($results->{"PRIMER_INTERNAL_0_SEQUENCE"})) {
      $type = "INTERNAL";
  }

  ## Format the information
  ($primerStart, $primerLength) = split "," , $results->{"PRIMER_$type\_0"};
  $primerTM = sprintf ("%.1f",($results->{"PRIMER_$type\_0_TM"}));
  $primerGC = sprintf ("%.1f",($results->{"PRIMER_$type\_0_GC_PERCENT"}));
  $primerSelf = sprintf ("%.1f",($results->{"PRIMER_$type\_0_SELF_ANY$thAdd"}));
  $primerAny = sprintf ("%.1f",($results->{"PRIMER_$type\_0_SELF_END$thAdd"}));
  $primerStab = sprintf ("%.1f",($results->{"PRIMER_$type\_0_END_STABILITY"}));
  $primerPenalty = sprintf ("%.3f",($results->{"PRIMER_$type\_0_PENALTY"}));

  $formHTML .= qq{
<form action="$machineSettings{URL_PRIMER_MANAGER}" method="post" enctype="multipart/form-data">
};

$formHTML .= partHiddenManagerFields($results);

$formHTML .= qq{
  <div class="primer3plus_oligo_box">
  <table class="primer3plus_table_no_border">
     <colgroup>
       <col width="17%">
       <col width="83%">
     </colgroup>
     <tr class="primer3plus_left_primer">
       <td class="primer3plus_cell_no_border"><input name="PRIMER_$type\0_SELECT" value="1" checked="checked" type="checkbox"> &nbsp; Oligo:</td>
       <td class="primer3plus_cell_no_border"><input name="PRIMER_$type\0_NAME" value="$results->{"PRIMER_$type\_0_NAME"}" size="40"></td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><a href="$machineSettings{URL_HELP}#PRIMER_RIGHT_4_SEQUENCE">Sequence:</a></td>
       <td class="primer3plus_cell_no_border"><input name="PRIMER_$type\0_SEQUENCE" value="$results->{"PRIMER_$type\_0_SEQUENCE"}" size="90"></td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><a href="$machineSettings{URL_HELP}#PRIMER_RIGHT_4">Length:</a></td>
       <td class="primer3plus_cell_no_border">$primerLength bp</td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><a href="$machineSettings{URL_HELP}#PRIMER_RIGHT_4_TM">Tm:</a></td>
       <td class="primer3plus_cell_no_border">$primerTM C </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><a href="$machineSettings{URL_HELP}#PRIMER_RIGHT_4_GC_PERCENT">GC:</a></td>
       <td class="primer3plus_cell_no_border">$primerGC %</td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><a href="$machineSettings{URL_HELP}#PRIMER_RIGHT_4_SELF_ANY$thAdd">Any Dimer:</a></td>
       <td class="primer3plus_cell_no_border">$primerSelf</td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><a href="$machineSettings{URL_HELP}#PRIMER_RIGHT_4_SELF_END$thAdd">End Dimer:</a></td>
       <td class="primer3plus_cell_no_border">$primerAny</td>
     </tr>};

  if (defined ($results->{"PRIMER_$type\_0_TEMPLATE_MISPRIMING$thTmAdd"}) 
        and (($results->{"PRIMER_$type\_0_TEMPLATE_MISPRIMING$thTmAdd"}) ne "")) {
      my   $primerTempMispr = sprintf ("%.1f",($results->{"PRIMER_$type\_0_TEMPLATE_MISPRIMING$thTmAdd"}));

      $formHTML .= qq{     <tr>
       <td class="primer3plus_cell_no_border"><a href="$machineSettings{URL_HELP}#PRIMER_RIGHT_4_TEMPLATE_MISPRIMING$thTmAdd">Template Mispriming:</a></td>
       <td class="primer3plus_cell_no_border">$primerTempMispr</td>
     </tr>
};
  }

  if (($results->{"PRIMER_THERMODYNAMIC_OLIGO_ALIGNMENT"}) eq "1") {
      $primerHairpin = sprintf ("%.1f",($results->{"PRIMER_$type\_0_HAIRPIN_TH"}));
      
      $formHTML .= qq{     <tr>
       <td class="primer3plus_cell_no_border"><a href="$machineSettings{URL_HELP}#PRIMER_RIGHT_4_HAIRPIN_TH">Hairpin:</a></td>
       <td class="primer3plus_cell_no_border">$primerHairpin</td>
     </tr>
};
  }

$formHTML .= qq{     
     <tr>
       <td class="primer3plus_cell_no_border"><a href="$machineSettings{URL_HELP}#PRIMER_RIGHT_4_END_STABILITY">3' Stability:</a></td>
       <td class="primer3plus_cell_no_border">$primerStab &Delta;G</td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><a href="$machineSettings{URL_HELP}#PRIMER_RIGHT_4_PENALTY">Penalty:</a></td>
       <td class="primer3plus_cell_no_border">$primerPenalty</td>
     </tr>
  };
  # Now the optional fields
  if (defined ($results->{"PRIMER_$type\_0_POSITION_PENALTY"}) 
        and (($results->{"PRIMER_$type\_0_POSITION_PENALTY"}) ne "")) {
     my   $primerPosPenalty = sprintf ("%.3f",($results->{"PRIMER_$type\_0_POSITION_PENALTY"}));

$formHTML .= qq{     <tr>
       <td class="primer3plus_cell_no_border"><a href="$machineSettings{URL_HELP}#PRIMER_RIGHT_4_POSITION_PENALTY">Position Penalty:</a></td>
       <td class="primer3plus_cell_no_border">$primerPosPenalty</td>
     </tr>
};
  }

  if (defined ($results->{"PRIMER_$type\_0_LIBRARY_MISPRIMING"}) 
        and (($results->{"PRIMER_$type\_0_LIBRARY_MISPRIMING"}) ne "")) {

$formHTML .= qq{     <tr>
       <td class="primer3plus_cell_no_border"><a href="$machineSettings{URL_HELP}#PRIMER_RIGHT_4_LIBRARY_MISPRIMING">Library Mispriming:</a></td>
       <td class="primer3plus_cell_no_border">$results->{"PRIMER_$type\_0_LIBRARY_MISPRIMING"}</td>
     </tr>
};
  }

  if (defined ($results->{"PRIMER_$type\_0_LIBRARY_MISHYB"}) 
        and (($results->{"PRIMER_$type\_0_LIBRARY_MISHYB"}) ne "")) {

$formHTML .= qq{     <tr>
       <td class="primer3plus_cell_no_border"><a href="$machineSettings{URL_HELP}#PRIMER_INTERNAL_4_LIBRARY_MISHYB">Library Mishyb:</a></td>
       <td class="primer3plus_cell_no_border">$results->{"PRIMER_$type\_0_LIBRARY_MISHYB"}</td>
     </tr>
};
  }

  if (defined ($results->{"PRIMER_$type\_0_MIN_SEQ_QUALITY"}) 
        and (($results->{"PRIMER_$type\_0_MIN_SEQ_QUALITY"}) ne "")) {

$formHTML .= qq{     <tr>
       <td class="primer3plus_cell_no_border"><a href="$machineSettings{URL_HELP}#PRIMER_RIGHT_4_MIN_SEQ_QUALITY">Min Seq Quality:</a></td>
       <td class="primer3plus_cell_no_border">$results->{"PRIMER_$type\_0_MIN_SEQ_QUALITY"}</td>
     </tr>
};
  }

  if (defined ($results->{"PRIMER_$type\_0_PROBLEMS"}) 
        and (($results->{"PRIMER_$type\_0_PROBLEMS"}) ne "")) {

$formHTML .= qq{     <tr>
       <td class="primer3plus_cell_no_border_problem"><a href="$machineSettings{URL_HELP}#PRIMER_RIGHT_4_PROBLEMS">Problems:</a></td>
       <td class="primer3plus_cell_no_border_problem">$results->{"PRIMER_$type\_0_PROBLEMS"}</td>
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

</form>
};

  return $formHTML;
}

####################################################################################
# createResultsDetection: Will write an HTML-Form based for the detection Function #
####################################################################################
sub createResultsDetection {
  my $settings = shift;

my $formHTML .= qq{
<form action="$machineSettings{URL_PRIMER_MANAGER}" method="post" enctype="multipart/form-data" target="primer3manager">
};

$formHTML .= partHiddenManagerFields($settings);

$formHTML .= divPrimerBox($settings,"0","1");

$formHTML .= qq{<div class="primer3plus_submit">
<input name="Submit" value="Send to Primer3Manager" type="submit"> <input value="Reset Form" type="reset">
</div>
};

$formHTML .= divHTMLsequence($settings, "1");

$formHTML .= qq{ <div class="primer3plus_select_all">
<br>
<input name="SELECT_ALL_PRIMERS" value="1" type="checkbox"> &nbsp; Select all Primers<br>
<br>
</div>
};

for (my $primerCount = 1 ; $primerCount < $settings->{"PRIMER_PAIR_NUM_RETURNED"} ; $primerCount++) {
    $formHTML .= divPrimerBox($settings,$primerCount,"0");

    $formHTML .= qq{<div class="primer3plus_submit">
<br>
<input name="Submit" value="Send to Primer3Manager" type="submit"> <input value="Reset Form" type="reset">
<br>
<br>
<br>
</div>
};
}

$formHTML .= divStatistics($settings);

$formHTML .= qq{
</form>

};

  return $formHTML;
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

#####################################################################
# divGenomeBrowser: Create a return to Genome Browser screen Button #
#####################################################################
sub divGenomeBrowser {
  my %settings;
  %settings = %{(shift)};

  my $formHTML = qq{
<div id="primer3plus_return_to_input_button">
<form action="$machineSettings{URL_GENE_BRO_ACTION}" method="post" enctype="multipart/form-data" target="genomeBrowser">
<input id="GENBRO_RETURN_PATH" name="GENBRO_RETURN_PATH" value="$settings{GENBRO_RETURN_PATH}" type="hidden">
<input id="GENBRO_DB" name="GENBRO_DB" value="$settings{GENBRO_DB}" type="hidden">
<input id="GENBRO_POSITION" name="GENBRO_POSITION" value="$settings{GENBRO_POSITION}" type="hidden">
<input id="GENBRO_FILE" name="GENBRO_FILE" value="$settings{GENBRO_FILE}" type="hidden">
<input id="primer3plus_return_to_genome_browser_button" class="primer3plus_action_button" name="Return_To_Genome_Browser" value="Return to Genome Browser" type="submit">
<input id="primer3plus_return_to_genome_browser_button" class="primer3plus_action_button" name="Save_BED" value="Save BED File" type="submit">
</form>
</div>
};

  return $formHTML;
}

#################################################################################
# printDebugInfo: Will write an HTML-Form for the Parameters in the Result Hash #
#################################################################################
sub printDebugInfo {
  my %settings;
  my $p3input;
  my $hashText;
  %settings = %{(shift)};
  $hashText = shift;
  $p3input = shift;
  my $HashKeys;
  my $HashContent;
  
  foreach $HashKeys (sort(keys(%settings))){
  	if (($HashKeys ne "") && ($HashKeys ne "SCRIPT_DEBUG_INPUT") && ($HashKeys ne "SCRIPT_DEBUG_OUTPUT")) {
    	$HashContent .= qq{$HashKeys = $settings{$HashKeys}\n};
  	}
  };

  my $formHTML = qq{
   <p>$hashText:<br>
     <textarea name="SCRIPT_DEBUG_P3P_HASH" cols="100" rows="7">$HashContent</textarea>
   </p>
};

  if ($p3input != 0 ) {
    $formHTML .= qq{   <p>Input provided to Primer3_core:<br>
     <textarea name="SCRIPT_DEBUG_P3_INPUT" cols="100" rows="7">$settings{"SCRIPT_DEBUG_INPUT"}</textarea>
   </p>
   <p>Output provided by Primer3core:<br>
     <textarea name="SCRIPT_DEBUG_P3_OUTPUT" cols="100" rows="7">$settings{"SCRIPT_DEBUG_OUTPUT"}</textarea>
   </p>
};
  }
  
  return $formHTML;
}

################################################################################
# createResultsPrimerList: Will write an Tabels all Primers in the Result Hash #
################################################################################
sub createResultsPrimerList {
  my ($completeParameters, $settings, $sortedInput) ; 
  $completeParameters = shift; 
  $settings = shift;
  $sortedInput = shift;

  my $formHTML = "";

$formHTML .= qq{
<form action="$machineSettings{URL_PRIMER_MANAGER}" method="post" enctype="multipart/form-data" target="primer3manager">
};

$formHTML .= partHiddenManagerFields($settings);

if ($sortedInput == 0){
   $formHTML .= divHTMLsequence($settings, "0");
}
else {
   $formHTML .= divHTMLsequence($settings, "-1");
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

 if (defined ($settings->{PRIMER_LEFT_0_SEQUENCE})) {
     $formHTML .= qq{<h2 class="primer3plus_left_primer">Left Primers:</h2>
};
     $formHTML .= divLongList($settings,"LEFT",$sortedInput);

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

 if (defined ($settings->{PRIMER_INTERNAL_OLIGO_0_SEQUENCE})) {
     $formHTML .= qq{<h2 class="primer3plus_internal_oligo">Internal Oligos:</h2>
};
     $formHTML .= divLongList($settings,"INTERNAL_OLIGO",$sortedInput);

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
 
 if (defined ($settings->{PRIMER_RIGHT_0_SEQUENCE})) {
     $formHTML .= qq{<h2 class="primer3plus_right_primer">Right Primers:</h2>
};
     $formHTML .= divLongList($settings,"RIGHT",$sortedInput);

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

$formHTML .= qq{
</form>
};

  return $formHTML;
}

sub divLongList {
  my ($formHTML, $results, $primerType, $sortedInput);
  $results = shift;
  $primerType = shift;
  $sortedInput = shift;


  my $primerStart;
  my $primerLength;
  my $primerTM;
  my $primerGC;
  my $primerSelf;
  my $primerEnd;
  my $primerTemplateBinding;
  my $primerEndStability;
  my $primerPenalty;
  my $stopLoop;
  
  my $thAdd = "";
  if (($results->{"PRIMER_THERMODYNAMIC_OLIGO_ALIGNMENT"}) eq "1") {
  	  $thAdd = "_TH";
  }
  my $thTmAdd = "";
  if (($results->{"PRIMER_THERMODYNAMIC_TEMPLATE_ALIGNMENT"}) eq "1") {
  	  $thTmAdd = "_TH";
  }
  
  $formHTML = qq{
  <div class="primer3plus_long_list">
   <table class="primer3plus_long_list_table">
     <colgroup>
       <col style="width:16%">
       <col style="width:28%">
       <col style="width:6.5%; text-align:right">
       <col style="width:6.5%; text-align:right">
       <col style="width:6%; text-align:right">
       <col style="width:6.5%; text-align:right">
       <col style="width:5.5%; text-align:right">
       <col style="width:5.5%; text-align:right">
       <col style="width:6.5%; text-align:right">
       <col style="width:6.5%; text-align:right">
       <col style="width:7.5%; text-align:right">
     </colgroup>
     <tr>
       <td class="primer3plus_cell_long_list">&nbsp; &nbsp; &nbsp; &nbsp; Name</td>
       <td class="primer3plus_cell_long_list">Sequence</td>
       <td class="primer3plus_cell_long_list"><a href="$machineSettings{URL_HELP}#PRIMER_RIGHT_4">Start</a></td>
       <td class="primer3plus_cell_long_list"><a href="$machineSettings{URL_HELP}#PRIMER_RIGHT_4">Length</a></td>
       <td class="primer3plus_cell_long_list"><a href="$machineSettings{URL_HELP}#PRIMER_RIGHT_4_TM">Tm</a></td>
       <td class="primer3plus_cell_long_list"><a href="$machineSettings{URL_HELP}#PRIMER_RIGHT_4_GC_PERCENT">GC %</a></td>
       <td class="primer3plus_cell_long_list"><a href="$machineSettings{URL_HELP}#PRIMER_RIGHT_4_SELF_ANY$thAdd">Any</a></td>
       <td class="primer3plus_cell_long_list"><a href="$machineSettings{URL_HELP}#PRIMER_RIGHT_4_SELF_END$thAdd">End</a></td>
       <td class="primer3plus_cell_long_list"><a href="$machineSettings{URL_HELP}#PRIMER_RIGHT_4_TEMPLATE_MISPRIMING$thAdd">TB</a></td>
       <td class="primer3plus_cell_long_list"><a href="$machineSettings{URL_HELP}#PRIMER_RIGHT_4_END_STABILITY">3' Stab</a></td>
       <td class="primer3plus_cell_long_list"><a href="$machineSettings{URL_HELP}#PRIMER_RIGHT_4_PENALTY">Penalty</a></td>
     </tr>
};

  my $counter = 0;
  for ($stopLoop = 0 ; $stopLoop ne 1 ; ) {
      ($primerStart, $primerLength) = split "," , $results->{"PRIMER_$primerType\_$counter"};
      $primerTM = sprintf ("%.1f",($results->{"PRIMER_$primerType\_$counter\_TM"}));
      $primerGC = sprintf ("%.1f",($results->{"PRIMER_$primerType\_$counter\_GC_PERCENT"}));
      $primerSelf = sprintf ("%.1f",($results->{"PRIMER_$primerType\_$counter\_SELF_ANY$thAdd"}));
      $primerEnd = sprintf ("%.1f",($results->{"PRIMER_$primerType\_$counter\_SELF_END$thAdd"}));
      if (defined $results->{"PRIMER_$primerType\_$counter\_TEMPLATE_MISPRIMING$thTmAdd"}) {
          $primerTemplateBinding = sprintf ("%.1f",($results->{"PRIMER_$primerType\_$counter\_TEMPLATE_MISPRIMING$thTmAdd"}));
      } else {
          $primerTemplateBinding = "";
      }   
      $primerEndStability = sprintf ("%.1f",($results->{"PRIMER_$primerType\_$counter\_END_STABILITY"}));
      $primerPenalty = sprintf ("%.3f",($results->{"PRIMER_$primerType\_$counter\_PENALTY"}));

  $formHTML .= qq{     <tr>
       <td class="primer3plus_cell_long_list"><input id="PRIMER_$primerType\_$counter\_SELECT" name="PRIMER_$primerType\_$counter\_SELECT" value="1" type="checkbox">
       &nbsp; <input id="PRIMER_$primerType\_$counter\_NAME" name="PRIMER_$primerType\_$counter\_NAME"
           value="$results->{"PRIMER_$primerType\_$counter\_NAME"}" size="12"></td>
       <td class="primer3plus_cell_long_list"><input id="PRIMER_$primerType\_$counter\_SEQUENCE" name="PRIMER_$primerType\_$counter\_SEQUENCE"
         value="$results->{"PRIMER_$primerType\_$counter\_SEQUENCE"}" size="35"></td>
       <td class="primer3plus_cell_long_list">$primerStart</td>
       <td class="primer3plus_cell_long_list">$primerLength</td>
       <td class="primer3plus_cell_long_list">$primerTM</td>
       <td class="primer3plus_cell_long_list">$primerGC</td>
       <td class="primer3plus_cell_long_list">$primerSelf</td>
       <td class="primer3plus_cell_long_list">$primerEnd</td>
       <td class="primer3plus_cell_long_list">$primerTemplateBinding</td>
       <td class="primer3plus_cell_long_list">$primerEndStability</td>
       <td class="primer3plus_cell_long_list">$primerPenalty</td>
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

############################################################################
# partHiddenManagerFields: Will write the hidden fields for primer3Manager #
############################################################################
sub partHiddenManagerFields {
  my $settings; 
  $settings = shift;

  my $formHTML = qq{
<input type="hidden" name="PRIMER_LEFT_NUM_RETURNED" value="$settings->{"PRIMER_LEFT_NUM_RETURNED"}">
<input type="hidden" name="PRIMER_INTERNAL_NUM_RETURNED" value="$settings->{"PRIMER_INTERNAL_NUM_RETURNED"}">
<input type="hidden" name="PRIMER_RIGHT_NUM_RETURNED" value="$settings->{"PRIMER_RIGHT_NUM_RETURNED"}">
<input type="hidden" name="PRIMER_PAIR_NUM_RETURNED" value="$settings->{"PRIMER_PAIR_NUM_RETURNED"}">

<input type="hidden" name="SCRIPT_DISPLAY_DEBUG_INFORMATION" value="$settings->{"SCRIPT_DISPLAY_DEBUG_INFORMATION"}">
<input type="hidden" name="P3P_PRIMER_NAME_ACRONYM_LEFT" value="$settings->{"P3P_PRIMER_NAME_ACRONYM_LEFT"}">
<input type="hidden" name="P3P_PRIMER_NAME_ACRONYM_INTERNAL" value="$settings->{"P3P_PRIMER_NAME_ACRONYM_INTERNAL"}">
<input type="hidden" name="P3P_PRIMER_NAME_ACRONYM_RIGHT" value="$settings->{"P3P_PRIMER_NAME_ACRONYM_RIGHT"}">
<input type="hidden" name="P3P_PRIMER_NAME_ACRONYM_SPACER" value="$settings->{"P3P_PRIMER_NAME_ACRONYM_SPACER"}">

<input type="hidden" name="SCRIPT_PRIMER_MANAGER" value="PRIMER3PLUS">
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

  my $primerAny = "";
  my $primerEnd = "";
  my $productTM = "";
  my $productOligDiff = "";
  my $pairPenalty = "";
  my $productMispriming = "";
  my $productToA = "";
  
  if (defined ($results->{"PRIMER_PAIR_$counter\_PRODUCT_TM"}) 
        and (($results->{"PRIMER_PAIR_$counter\_PRODUCT_TM"}) ne "")) {
      $productTM .= qq{<a href="$machineSettings{URL_HELP}#PRIMER_PAIR_4_PRODUCT_TM">Tm:</a> };
      $productTM .= sprintf ("%.1f",($results->{"PRIMER_PAIR_$counter\_PRODUCT_TM"}));
      $productTM .= qq{ C};
  }
  if (defined ($results->{"PRIMER_PAIR_$counter\_PRODUCT_TM_OLIGO_TM_DIFF"}) 
        and (($results->{"PRIMER_PAIR_$counter\_PRODUCT_TM_OLIGO_TM_DIFF"}) ne "")) {
      $productOligDiff .= qq{<a href="$machineSettings{URL_HELP}#PRIMER_PAIR_4_PRODUCT_TM_OLIGO_TM_DIFF">dT:</a> };
      $productOligDiff .= sprintf ("%.1f",($results->{"PRIMER_PAIR_$counter\_PRODUCT_TM_OLIGO_TM_DIFF"}));
      $productOligDiff .= qq{ C};
  }
  if ((defined ($results->{"PRIMER_PAIR\_$counter\_COMPL_ANY"})) 
        and (($results->{"PRIMER_PAIR\_$counter\_COMPL_ANY"}) ne "")) {
      $primerAny .= qq{<a href="$machineSettings{URL_HELP}#PRIMER_PAIR_4_COMPL_ANY">Any:</a> };
      $primerAny .= sprintf ("%.1f",($results->{"PRIMER_PAIR\_$counter\_COMPL_ANY"}));
  } elsif ((defined ($results->{"PRIMER_PAIR\_$counter\_COMPL_ANY_TH"})) 
        and (($results->{"PRIMER_PAIR\_$counter\_COMPL_ANY_TH"}) ne "")) {
      $primerAny .= qq{<a href="$machineSettings{URL_HELP}#PRIMER_PAIR_4_COMPL_ANY_TH">Any:</a> };
      $primerAny .= sprintf ("%.1f",($results->{"PRIMER_PAIR\_$counter\_COMPL_ANY_TH"}));
  }
  if ((defined ($results->{"PRIMER_PAIR\_$counter\_COMPL_END"}))
        and (($results->{"PRIMER_PAIR\_$counter\_COMPL_END"}) ne "")) {
      $primerEnd .= qq{<a href="$machineSettings{URL_HELP}#PRIMER_PAIR_4_COMPL_END">End:</a> };
      $primerEnd .= sprintf ("%.1f",($results->{"PRIMER_PAIR\_$counter\_COMPL_END"}));
  } elsif ((defined ($results->{"PRIMER_PAIR\_$counter\_COMPL_END_TH"}))
        and (($results->{"PRIMER_PAIR\_$counter\_COMPL_END_TH"}) ne "")) {
      $primerEnd .= qq{<a href="$machineSettings{URL_HELP}#PRIMER_PAIR_4_COMPL_END_TH">End:</a> };
      $primerEnd .= sprintf ("%.1f",($results->{"PRIMER_PAIR\_$counter\_COMPL_END_TH"}));
  }
  if ((defined ($results->{"PRIMER_PAIR\_$counter\_TEMPLATE_MISPRIMING"}))
        and (($results->{"PRIMER_PAIR\_$counter\_TEMPLATE_MISPRIMING"}) ne "")) {
      $productMispriming .= qq{<a href="$machineSettings{URL_HELP}#PRIMER_PAIR_4_TEMPLATE_MISPRIMING">TB:</a> };
      $productMispriming .= sprintf ("%.1f",($results->{"PRIMER_PAIR\_$counter\_TEMPLATE_MISPRIMING"}));
  } elsif ((defined ($results->{"PRIMER_PAIR\_$counter\_TEMPLATE_MISPRIMING_TH"}))
        and (($results->{"PRIMER_PAIR\_$counter\_TEMPLATE_MISPRIMING_TH"}) ne "")) {
      $productMispriming .= qq{<a href="$machineSettings{URL_HELP}#PRIMER_PAIR_4_TEMPLATE_MISPRIMING_TH">TB:</a> };
      $productMispriming .= sprintf ("%.1f",($results->{"PRIMER_PAIR\_$counter\_TEMPLATE_MISPRIMING_TH"}));
  }
  if (defined ($results->{"PRIMER_PAIR_$counter\_T_OPT_A"}) 
        and (($results->{"PRIMER_PAIR_$counter\_T_OPT_A"}) ne "")) {
      $productToA .= qq{<a href="$machineSettings{URL_HELP}#PRIMER_PAIR_4_T_OPT_A">T opt A:</a> };
      $productToA .= sprintf ("%.1f",($results->{"PRIMER_PAIR_$counter\_T_OPT_A"}));
  }
  if ((defined ($results->{"PRIMER_PAIR\_$counter\_PENALTY"}))
        and (($results->{"PRIMER_PAIR\_$counter\_PENALTY"}) ne "")) {
      $pairPenalty .= qq{<a href="$machineSettings{URL_HELP}#PRIMER_PAIR_4_PENALTY">Penalty:</a> };
      $pairPenalty .= sprintf ("%.3f",($results->{"PRIMER_PAIR\_$counter\_PENALTY"}));
  }

  my $formHTML = qq{  <div class="primer3plus_primer_pair_box">
  <table class="primer3plus_table_primer_pair_box">
     <colgroup>
       <col width="12.0%">
       <col width="2.0%">
       <col width="10.0%">
       <col width="10.0%">
       <col width="10.0%">
       <col width="8.0%">
       <col width="8.0%">
       <col width="8.5%">
       <col width="8.0%">
       <col width="10.5%">
       <col width="13.0%">
     </colgroup>
     <tr>
       <td colspan="11" class="primer3plus_cell_primer_pair_box"><input id="PRIMER_PAIR\_$counter\_SELECT" name="PRIMER_PAIR\_$counter\_SELECT" value="1" };

$formHTML .= ($checked) ? "checked=\"checked\" " : "";
 
$formHTML .= qq{type="checkbox">&nbsp;Pair $selection:
       <input id="PRIMER_PAIR_$counter\_NAME" name="PRIMER_PAIR_$counter\_NAME" value="$results->{"PRIMER_PAIR_$counter\_NAME"}" size="40">
};

  if ((defined ($results->{"PRIMER_PAIR_$counter\_AMPLICON"}))
        and (($results->{"PRIMER_PAIR_$counter\_AMPLICON"}) ne "")) {
  $formHTML .= qq{<input type="hidden" name="PRIMER_PAIR_$counter\_AMPLICON" value="$results->{"PRIMER_PAIR_$counter\_AMPLICON"}">
};
  }
  
  $formHTML .= qq{       </td>
     </tr>
};
  

$formHTML .= partPrimerData( $results, $counter, "LEFT", $checked);

$formHTML .= partPrimerData( $results, $counter, "INTERNAL", $checked);

$formHTML .= partPrimerData( $results, $counter, "RIGHT", $checked);

$formHTML .= qq{     <tr class="primer3plus_primer_pair">
       <td colspan="3" class="primer3plus_cell_primer_pair_box"><strong>Pair:</strong>&nbsp;&nbsp;&nbsp;
         <a href="$machineSettings{URL_HELP}#PRIMER_PAIR_4_PRODUCT_SIZE">Product Size:</a>&nbsp;
         &nbsp;$results->{"PRIMER_PAIR_$counter\_PRODUCT_SIZE"} bp</td>
       <td class="primer3plus_cell_primer_pair_box">$productTM</td>
       <td class="primer3plus_cell_primer_pair_box">$productOligDiff</td>
       <td class="primer3plus_cell_primer_pair_box">$primerAny</td>
       <td class="primer3plus_cell_primer_pair_box">$primerEnd</td>
       <td class="primer3plus_cell_primer_pair_box">$productMispriming</td>
       <td class="primer3plus_cell_primer_pair_box">$productToA</td>
       <td class="primer3plus_cell_primer_pair_box"></td>
       <td class="primer3plus_cell_primer_pair_box">$pairPenalty</td>
     </tr>
};

if (defined ($results->{"PRIMER_PAIR_$counter\_LIBRARY_MISPRIMING"}) 
		and (($results->{"PRIMER_PAIR_$counter\_LIBRARY_MISPRIMING"}) ne "")) {

$formHTML .= qq{     <tr class="primer3plus_primer_pair">
       <td colspan="3" class="primer3plus_cell_primer_pair_box">
         <a href="$machineSettings{URL_HELP}#PRIMER_PAIR_4_LIBRARY_MISPRIMING">Library Mispriming:</a></td>
       <td colspan="8" class="primer3plus_cell_primer_pair_box">$results->{"PRIMER_PAIR_$counter\_LIBRARY_MISPRIMING"}</td>
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
    
  my ($primerStart, $primerLength, $primerTM, $primerGC, $primerAny, $primerHairpin);
  my ($primerEnd, $primerEndStability, $primerTemplateBinding, $primerPenalty);
  my $cssName;
  my $writeName;
  
  my $thAdd = "";
  if (($results->{"PRIMER_THERMODYNAMIC_OLIGO_ALIGNMENT"}) eq "1") {
  	  $thAdd = "_TH";
  }
  my $thTmAdd = "";
  if (($results->{"PRIMER_THERMODYNAMIC_TEMPLATE_ALIGNMENT"}) eq "1") {
  	  $thTmAdd = "_TH";
  }

  if ($type eq "LEFT") {
		$cssName = "left_primer";
		$writeName = "Left Primer";
  }
  elsif ($type eq "INTERNAL") {
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

  ($primerStart, $primerLength) = split "," , $results->{"PRIMER_$type\_$counter"};
  $primerTM = sprintf ("%.1f",($results->{"PRIMER_$type\_$counter\_TM"}));
  $primerGC = sprintf ("%.1f",($results->{"PRIMER_$type\_$counter\_GC_PERCENT"}));
  $primerAny = sprintf ("%.1f",($results->{"PRIMER_$type\_$counter\_SELF_ANY$thAdd"}));
  $primerEnd = sprintf ("%.1f",($results->{"PRIMER_$type\_$counter\_SELF_END$thAdd"}));
  if (defined $results->{"PRIMER_$type\_$counter\_TEMPLATE_MISPRIMING$thTmAdd"}) {
      $primerTemplateBinding = sprintf ("%.1f",($results->{"PRIMER_$type\_$counter\_TEMPLATE_MISPRIMING$thTmAdd"}));
  } else {
      $primerTemplateBinding = "";
  }
  if (($results->{"PRIMER_THERMODYNAMIC_OLIGO_ALIGNMENT"}) eq "1") {
      $primerHairpin = sprintf ("%.1f",($results->{"PRIMER_$type\_$counter\_HAIRPIN_TH"}));
  }
  $primerEndStability = sprintf ("%.1f",($results->{"PRIMER_$type\_$counter\_END_STABILITY"}));
  $primerPenalty = sprintf ("%.3f",($results->{"PRIMER_$type\_$counter\_PENALTY"}));

$formHTML .= qq{     <tr class="primer3plus_$cssName">
       <td colspan="2" class="primer3plus_cell_primer_pair_box"> 
         &nbsp;$writeName $selection:
       </td>
       <td colspan="9" class="primer3plus_cell_primer_pair_box"> 
         <input id="PRIMER_$type\_$counter\_SEQUENCE" name="PRIMER_$type\_$counter\_SEQUENCE"
         value="$results->{"PRIMER_$type\_$counter\_SEQUENCE"}" size="90"></td>
     </tr>
     <tr>
       <td class="primer3plus_cell_primer_pair_box"><a href="$machineSettings{URL_HELP}#PRIMER_RIGHT_4">Start:</a> $primerStart</td>
       <td colspan="2" class="primer3plus_cell_primer_pair_box"><a href="$machineSettings{URL_HELP}#PRIMER_RIGHT_4">Length:</a> $primerLength bp</td>
       <td class="primer3plus_cell_primer_pair_box"><a href="$machineSettings{URL_HELP}#PRIMER_RIGHT_4_TM">Tm:</a> $primerTM C </td>
       <td class="primer3plus_cell_primer_pair_box"><a href="$machineSettings{URL_HELP}#PRIMER_RIGHT_4_GC_PERCENT">GC:</a> $primerGC %</td>
       <td class="primer3plus_cell_primer_pair_box"><a href="$machineSettings{URL_HELP}#PRIMER_RIGHT_4_SELF_ANY$thAdd">Any:</a> $primerAny</td>
       <td class="primer3plus_cell_primer_pair_box"><a href="$machineSettings{URL_HELP}#PRIMER_RIGHT_4_SELF_END$thAdd">End:</a> $primerEnd</td>
       <td class="primer3plus_cell_primer_pair_box"><a href="$machineSettings{URL_HELP}#PRIMER_RIGHT_4_TEMPLATE_MISPRIMING$thTmAdd">TB:</a> $primerTemplateBinding</td>
       <td class="primer3plus_cell_primer_pair_box">};
       
if (($results->{"PRIMER_THERMODYNAMIC_OLIGO_ALIGNMENT"}) eq "1") {
       $formHTML .= qq{<a href="$machineSettings{URL_HELP}#PRIMER_RIGHT_4_HAIRPIN_TH">HP:</a> $primerHairpin};
}

$formHTML .= qq{</td>
       <td class="primer3plus_cell_primer_pair_box"><a href="$machineSettings{URL_HELP}#PRIMER_RIGHT_4_END_STABILITY">3' Stab:</a> $primerEndStability</td>
       <td class="primer3plus_cell_primer_pair_box"><a href="$machineSettings{URL_HELP}#PRIMER_RIGHT_4_PENALTY">Penalty:</a> $primerPenalty</td>
     </tr>
};

  if ((defined ($results->{"PRIMER_$type\_$counter\_POSITION_PENALTY"}) 
        and (($results->{"PRIMER_$type\_$counter\_POSITION_PENALTY"}) ne ""))
        or (defined ($results->{"PRIMER_$type\_$counter\_MIN_SEQ_QUALITY"}) 
        and (($results->{"PRIMER_$type\_$counter\_MIN_SEQ_QUALITY"}) ne ""))) {
    my $primerPosPen = "";
    my $primerMinSeqQual = "";
    if (defined ($results->{"PRIMER_$type\_$counter\_POSITION_PENALTY"}) 
        and (($results->{"PRIMER_$type\_$counter\_POSITION_PENALTY"}) ne "")) {
        $primerPosPen = qq{<a href="$machineSettings{URL_HELP}#PRIMER_RIGHT_4_POSITION_PENALTY">Position Penalty:</a>&nbsp;&nbsp;};
        $primerPosPen .= $results->{"PRIMER_$type\_$counter\_POSITION_PENALTY"};
    }
    if (defined ($results->{"PRIMER_$type\_$counter\_MIN_SEQ_QUALITY"}) 
        and (($results->{"PRIMER_$type\_$counter\_MIN_SEQ_QUALITY"}) ne "")) {
        $primerMinSeqQual = qq{<a href="$machineSettings{URL_HELP}#PRIMER_RIGHT_4_MIN_SEQ_QUALITY">Min Seq Quality:</a>&nbsp;&nbsp;};
        $primerMinSeqQual .= $results->{"PRIMER_$type\_$counter\_MIN_SEQ_QUALITY"};
    }
            
    $formHTML .= qq{     <tr>
       <td colspan="3" class="primer3plus_cell_primer_pair_box">$primerPosPen</td>
       <td colspan="2" class="primer3plus_cell_primer_pair_box">$primerMinSeqQual</td>
       <td class="primer3plus_cell_primer_pair_box"></td>
       <td class="primer3plus_cell_primer_pair_box"></td>
       <td class="primer3plus_cell_primer_pair_box"></td>
       <td class="primer3plus_cell_primer_pair_box"></td>
       <td class="primer3plus_cell_primer_pair_box"></td>
       <td class="primer3plus_cell_primer_pair_box"></td>
     </tr>
};
  }
  
  if (defined ($results->{"PRIMER_$type\_$counter\_LIBRARY_MISPRIMING"}) 
        and (($results->{"PRIMER_$type\_$counter\_LIBRARY_MISPRIMING"}) ne "")) {
    $formHTML .= qq{     <tr>
       <td colspan="11" class="primer3plus_cell_primer_pair_box">
         <a href="$machineSettings{URL_HELP}#PRIMER_RIGHT_4_LIBRARY_MISPRIMING">Library Mispriming:</a>&nbsp;
         $results->{"PRIMER_$type\_$counter\_LIBRARY_MISPRIMING"}</td>
     </tr>
};
  }

  if (defined ($results->{"PRIMER_$type\_$counter\_LIBRARY_MISHYB"}) 
        and (($results->{"PRIMER_$type\_$counter\_LIBRARY_MISHYB"}) ne "")) {
    $formHTML .= qq{     <tr>
       <td colspan="11" class="primer3plus_cell_primer_pair_box">
         <a href="$machineSettings{URL_HELP}#PRIMER_INTERNAL_4_LIBRARY_MISHYB">Library Mishyb:</a>&nbsp;
         $results->{"PRIMER_$type\_$counter\_LIBRARY_MISHYB"}</td>
     </tr>
};
  }
  if (defined ($results->{"PRIMER_$type\_$counter\_PROBLEMS"}) 
		and (($results->{"PRIMER_$type\_$counter\_PROBLEMS"}) ne "")) {
    $formHTML .= qq{     <tr>
       <td class="primer3plus_cell_no_border_problem" colspan="2"><a href="$machineSettings{URL_HELP}#PRIMER_RIGHT_4_PROBLEMS">Problems:</a></td>
       <td class="primer3plus_cell_no_border_problem" colspan="9">$results->{"PRIMER_$type\_$counter\_PROBLEMS"}</td>
     </tr>
};
}
  $formHTML .= qq{     <tr>
       <td class="primer3plus_cell_no_border" colspan="11"></td>
     </tr>
};
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
  my (@targets, $region, $run, $counter, $madeRegion);
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
  
  # Add only the first primer pair e.g. Detection
  if ($firstPair eq 1) {
      if (defined ($results->{"PRIMER_LEFT_0"}) and (($results->{"PRIMER_LEFT_0"}) ne "")) {
           $format = addRegion($format,$results->{"PRIMER_LEFT_0"},$firstBase,"F");
      }
      if (defined ($results->{"PRIMER_INTERNAL_0"}) and (($results->{"PRIMER_INTERNAL_0"}) ne "")) {
     	   $format = addRegion($format,$results->{"PRIMER_INTERNAL_0"},$firstBase,"O");
      }
      if (defined ($results->{"PRIMER_RIGHT_0"}) and (($results->{"PRIMER_RIGHT_0"}) ne "")) {
           $format = addRegion($format,$results->{"PRIMER_RIGHT_0"},$firstBase,"R");
      }
  }
  # Mark no primers on the sequence e.g. Primer list
  elsif ($firstPair eq -1) {
      
  }
  # Mark all primers on the sequence e.g. Sequencing
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
  if (defined ($results->{"SEQUENCE_OVERLAP_JUNCTION_LIST"}) and (($results->{"SEQUENCE_OVERLAP_JUNCTION_LIST"}) ne "")) {
      @targets = split ' ', $results->{"SEQUENCE_OVERLAP_JUNCTION_LIST"};
      foreach $region (@targets) {
          $madeRegion = $region - 1;
          $madeRegion .= ",2";
          $format = addRegion($format,$madeRegion,$firstBase,"-");
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
         if ($baseFormat eq "-") {
             $formHTML .= qq{<a class="primer3plus_primer_overlap_pos">};
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

###########################################################
# createHelpHTML: Will write an HTML-Form containing Help #
###########################################################
sub createHelpHTML ($) {
  my $helpHTML = shift;
  my $templateText = getWrapper();

  my $formHTML = qq{
<div id="primer3plus_complete">

};

$formHTML .= divTopBar("Primer3Plus - Help",0,"");

$formHTML .= divMessages;

$formHTML .= $helpHTML;

  my $returnString = $templateText;
  
  my $canon = qq{  <link rel=canonical href="https://primer3plus.com/cgi-bin/dev/primer3plusHelp.cgi" />
</head>};

  $returnString =~ s/<\/head>/$canon/;

  $returnString =~ s/<title>Primer3Plus<\/title>/<title>Primer3Plus - Help<\/title>/;

  my $metaDesc = qq{<meta name="description" content="The Help section explains all Primer3 and Primer3Plus tags and provides information on the primer selection behind the scenes.">};
  $returnString =~ s/<meta name="description" content=".+?">/$metaDesc/;

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
$formHTML .= divTopBar("Primer3Plus - About",0,0);

$formHTML .= divMessages();

my $p3p_version = getMachineSetting("P3P_VERSION");
my $p3_version = getPrimer3Version();

$formHTML .= qq{
<div id="primer3plus_about">

<h2>Primer3Plus is a web-interface for primer3</h2>

<h2>Versions</h2>
<p>Primer3Plus Version: $p3p_version <br>
   <br>
   Primer3 Version : $p3_version<br>
   <br>
</p>

<h2>Download Program and Source Code</h2>
<p>
<a href="http://sourceforge.net/projects/primer3/">
Source code is available at http://sourceforge.net/projects/primer3/.
</a>
</p>

<h2>Citing Primer3 and Primer3Plus</h2>

<p>We request but do not require that use of this software be cited in
publications as<br>
<br>
Untergasser A, Cutcutache I, Koressaar T, Ye J, Faircloth BC, Remm M and Rozen SG.<br>
Primer3--new capabilities and interfaces.<br>
Nucleic Acids Res. 2012 Aug 1;40(15):e115. 
<br>
<br>
The paper is available at
<a href="http://www.ncbi.nlm.nih.gov/pmc/articles/PMC3424584/">http://www.ncbi.nlm.nih.gov/pmc/articles/PMC3424584/</a><br>
<br>	
Source code available at <a href="http://sourceforge.net/projects/primer3/">http://sourceforge.net/projects/primer3/</a>.</p>

<h2>Fair use of Primer3 and Primer3Plus</h2>

<p>
The development of primer3 is promoted by a small group of 
enthusiastic scientists mainly in their free time.They do not gain 
any financial profit with primer3.<br>
<br>
There are two groups of primer3 users: end users, who run 
primer3 to pick their primers and programmers, who use primer3 
in their scripts or software packages. We encourage both to use 
primer3.
<br>
<br>
If you are an end user, we request but do not
require that use of this software be cited in publications
as listed above under CITING PRIMER3.
<br>
<br>
If you are a programmer, you  will see that primer3 is now 
distributed under the GNU  General Public License, version 2 or 
(at  your option) any later version of the License (GPL2). 

As we understand it, if you include parts of the primer3 source 
code in your source code or link to primer3 binary libraries in 
your executable, you have to release your software also under 
GPL2. If you only call primer3 from your software and interpret 
its output, you can use any license you want for your software. 
If you modify primer3 and then release your modified software, 
you have to release your modifications in source code under 
GPL2 as well.
<br>
<br>
We chose GPL2 because we wanted primer3 to evolve and for the 
improvements to find their way back into the main distribution. 

If you are programming a new web interface which runs primer3, 
please include in the about page of the tool the sentence 
"&lt;your software name&gt; uses primer3 version ...". 
Please consider releasing your software under GPL2 as well, 
especially if you do not want to maintain it in the future. 
<br>
<br>
There is no need to ask us for permission to include primer3 
in your tools.


<h2>Acknowledgments</h2>

<p>Initial development of Primer3 was funded by Howard Hughes Medical
Institute and by the National Institutes of Health, National Human
Genome Research Institute under grants R01-HG00257 (to David C. Page)
and P50-HG00098 (to Eric S. Lander),
but ongoing development and maintenance are not currently funded.
<br>
<br>
Primer3 was originally written by Helen J. Skaletsky (Howard Hughes
Medical Institute, Whitehead Institute) and Steve Rozen (Duke-NUS
Graduate Medical School Singapore, formerly at Whitehead Institute)
based on the design of earlier versions, notably Primer 0.5
(Steve Lincoln, Mark Daly, and Eric S. Lander).
The original web interface was designed by Richard Resnick.  Lincoln
Stein designed the Boulder-IO format in the days before XML and RDF, and
championed the idea of making primer3 a software component, which
has been key to its wide utility.<br>
<br>
In addition, among others, Ernst Molitor, Carl Foeller, and James Bonfield
contributed to the early
design of primer3. Brant Faircloth has helped with 
ensuring that primer3 runs on Windows and MacOS and with the
primer3 web site. 
Triinu Koressaar and Maido Remm modernized the melting 
temperature calculations in 2008.  
Triinu Koressaar added secondary structure, 
primer-dimer, and template mispriming based on a thermodynamic
model in 2.2.0.
Ioana Cutcutache is responsible for most of the 
remaining improvements
in 2.2.0, including performance enhancements, modern
command line arguments, and new input tags to 
control primer location (with the "overlap junction"
tags initially implemented by Andreas Untergasser).
Jian Ye patiently provided new requirements.<br>
<br>
Harm Nijveen and Andreas Untergasser developed the webinterface 
Primer3Plus in 2006-2009. Currently Primer3Plus is maintained by 
Andreas Untergasser.
<br>
<br>
Primer3 is an open software development project hosted
on SourceForge: <a href="http://sourceforge.net/projects/primer3/">http://sourceforge.net/projects/primer3/</a>
.</p>

<h2>COPYRIGHT AND LICENSE</h2>

<pre>Copyright (c) 1996,1997,1998,1999,2000,2001,2004,2006,2007,2008,2009,2010
              2011,2012
Whitehead Institute for Biomedical Research, Steve Rozen
(<a href="http://purl.com/STEVEROZEN/">http://purl.com/STEVEROZEN/</a>), Andreas Untergasser and Helen Skaletsky. All rights
reserved.

    This file is part of the primer3 suite and libraries.

    The primer3 suite and libraries are free software;
    you can redistribute them and/or modify them under the terms
    of the GNU General Public License as published by the Free
    Software Foundation; either version 2 of the License, or (at
    your option) any later version.

    This software is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this software (file gpl-2.0.txt in the source
    distribution); if not, write to the Free Software
    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA

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

</div>

</div>  
};

  my $returnString = $templateText;

  my $canon = qq{  <link rel=canonical href="https://primer3plus.com/cgi-bin/dev/primer3plusAbout.cgi" />
</head>};

  $returnString =~ s/<\/head>/$canon/;

  $returnString =~ s/<title>Primer3Plus<\/title>/<title>Primer3Plus - About<\/title>/;

  my $metaDesc = qq{<meta name="description" content="Find out about the fair usage and citing Primer3Plus. The licence information is available here.">};
  $returnString =~ s/<meta name="description" content=".+?">/$metaDesc/;

  $returnString =~ s/<!-- Primer3plus will include code here -->/$formHTML/;

  return $returnString;
}

###########################################################
# getPrimer3Version: get version information from primer3 #
###########################################################
sub getPrimer3Version () {
    my @readTheLine;
    my $readLine;
    my $returnLine;
    my $primer3BIN = getMachineSetting("PRIMER_BIN");
    my $callPrimer3 = $primer3BIN . getMachineSetting("PRIMER_RUNTIME");

###### Check if Primer3 can be run
    if ( !( -e $primer3BIN ) ) {
        return("Configuration Error: $primer3BIN ".
                   "can not be found!");
    }
    if ( !( -x $primer3BIN ) ) {
        return("Configuration Error: $primer3BIN ".
                   "is not executable!");
    }

###### Really run primer3
    open PRIMER3OUTPUT, "$callPrimer3 -about 2>&1 |"
        or return "";
    while (<PRIMER3OUTPUT>) {
        push @readTheLine, $_;
    }
    close PRIMER3OUTPUT;
#   unlink $inputFile;

###### Interprete the output
    foreach $readLine (@readTheLine) {
        $returnLine .= $readLine;
    }
  
    return $returnLine;
}

################################################################
# createPackageHTML: Creates an HTML-Page with all p3p modules #
################################################################

sub createPackageHTML {
  my $templateText = getWrapper();

  my $formHTML = qq{
<div id="primer3plus_complete">

};

$formHTML .= divTopBar(0,0,0);

$formHTML .= divMessages;

$formHTML .= qq{
<div id="primer3plus_results">

<h2><a name="primer3plus" href="primer3plus.cgi">Primer3Plus</a></h2>
  <p>Primer3Plus is the module which runs primer3 to pick primers.
  </p>

<h2><a name="primer3manager" href="primer3manager.cgi">Primer3Manager</a></h2>
  <p>Primer3Manager allows to manage selected primers and to save them.
  </p>

<h2><a name="primer3prefold" href="primer3prefold.cgi">Primer3Prefold</a></h2>
  <p>Primer3Prefold allows to fold a sequence before primer selection to 
     exclude regions with a secondary structure.
  </p>

<h2><a name="primer3compareFiles" href="primer3compareFiles.cgi">Primer3ComareFiles</a></h2>
  <p>Primer3ComareFiles allows to compare files with each other and the 
     default values to identify differences.
  </p>

<h2><a name="primer3statistics" href="primer3statistics.cgi">Primer3Statistics</a></h2>
  <p>Primer3Statistics prints statistics about primer3plus usage.
  </p>


</div>

</div>  
};

  my $returnString = $templateText;

  my $canon = qq{  <link rel=canonical href="https://primer3plus.com/cgi-bin/dev/primer3plusPackage.cgi" />
</head>};

  $returnString =~ s/<\/head>/$canon/;

  $returnString =~ s/<title>Primer3Plus<\/title>/<title>Primer3Plus - More...<\/title>/;

  my $metaDesc = qq{<meta name="description" content="Primer3Plus is not only primer selection - Primer3Manager organizes primers and Primer3Prefold avoids secondary structures in the DNA template.">};
  $returnString =~ s/<meta name="description" content=".+?">/$metaDesc/;

  $returnString =~ s/<!-- Primer3plus will include code here -->/$formHTML/;

  return $returnString;
}

##############################################################
# createStatisticsHTML: Creates an HTML-Page with Statistics #
##############################################################
sub createStatisticsHTML {
  my %startUps = %{(shift)};
  my %primer3Runs = %{(shift)};
  my %managerRuns = %{(shift)};
  my %prefoldStartUps = %{(shift)};
  my %prefoldRuns = %{(shift)};
  my %staticticsViews = %{(shift)};
  my $printStats = shift;

  my $templateText = getWrapper();
  my $theKey;
  my $monthKey;
  my $startUpsVal;
  my $primer3RunsVal;
  my $managerRunsVal;
  my $prefoldStartUpsVal;
  my $prefoldRunsVal;
  my $staticticsViewsVal;
  my %startUpsMonth;
  my %primer3RunsMonth;
  my %managerRunsMonth;
  my %prefoldStartUpsMonth;
  my %prefoldRunsMonth;
  my %staticticsViewsMonth;
  my %allDates;
  my %allMonth;

  # Collect all the dates and the Month usage:
  foreach $theKey (keys(%startUps)) {
      $allDates{$theKey} = 1;
      # Add to the month
      $monthKey = $theKey;
      $monthKey =~ s/\.\d+$// ;
      if (defined $startUpsMonth{$monthKey}) {
          $startUpsMonth{$monthKey} += $startUps{$theKey};
      } else {
          $startUpsMonth{$monthKey} = $startUps{$theKey};
          $allMonth{$monthKey} = 1;
      }
  }
  foreach $theKey (keys(%primer3Runs)) {
      $allDates{$theKey} = 1;
      # Add to the month
      $monthKey = $theKey;
      $monthKey =~ s/\.\d+$// ;
      if (defined $primer3RunsMonth{$monthKey}) {
          $primer3RunsMonth{$monthKey} += $primer3Runs{$theKey};
      } else {
          $primer3RunsMonth{$monthKey} = $primer3Runs{$theKey};
          $allMonth{$monthKey} = 1;
      }
  }
  foreach $theKey (keys(%managerRuns)) {
      $allDates{$theKey} = 1;
      # Add to the month
      $monthKey = $theKey;
      $monthKey =~ s/\.\d+$// ;
      if (defined $managerRunsMonth{$monthKey}) {
          $managerRunsMonth{$monthKey} += $managerRuns{$theKey};
      } else {
          $managerRunsMonth{$monthKey} = $managerRuns{$theKey};
          $allMonth{$monthKey} = 1;
      }
  }
  foreach $theKey (keys(%prefoldStartUps)) {
      $allDates{$theKey} = 1;
      # Add to the month
      $monthKey = $theKey;
      $monthKey =~ s/\.\d+$// ;
      if (defined $prefoldStartUpsMonth{$monthKey}) {
          $prefoldStartUpsMonth{$monthKey} += $prefoldStartUps{$theKey};
      } else {
          $prefoldStartUpsMonth{$monthKey} = $prefoldStartUps{$theKey};
          $allMonth{$monthKey} = 1;
      }
  }
  foreach $theKey (keys(%prefoldRuns)) {
      $allDates{$theKey} = 1;
      # Add to the month
      $monthKey = $theKey;
      $monthKey =~ s/\.\d+$// ;
      if (defined $prefoldRunsMonth{$monthKey}) {
          $prefoldRunsMonth{$monthKey} += $prefoldRuns{$theKey};
      } else {
          $prefoldRunsMonth{$monthKey} = $prefoldRuns{$theKey};
          $allMonth{$monthKey} = 1;
      }
  }
  foreach $theKey (keys(%staticticsViews)) {
      $allDates{$theKey} = 1;
      # Add to the month
      $monthKey = $theKey;
      $monthKey =~ s/\.\d+$// ;
      if (defined $staticticsViewsMonth{$monthKey}) {
          $staticticsViewsMonth{$monthKey} += $staticticsViews{$theKey};
      } else {
          $staticticsViewsMonth{$monthKey} = $staticticsViews{$theKey};
          $allMonth{$monthKey} = 1;
      }
  }


  my $formHTML = qq{
<div id="primer3plus_complete">
};

$formHTML .= divTopBar("Primer3Statistics","watch the server glow",0);

$formHTML .= divMessages;

if ($printStats eq "Y") { 
    $formHTML .= qq{
<div id="primer3plus_results">

<h2>Usage per month:</h2>
  <table class="primer3plus_table_with_border">
     <colgroup>
       <col width="15%">
       <col width="14%">
       <col width="14%">
       <col width="14%">
       <col width="14%">
       <col width="14%">
       <col width="15%">
     </colgroup>
     <tr>
       <td><strong>Date</strong></td>
       <td><strong>P3Plus</strong></td>
       <td><strong>Primer3 runs</strong></td>
       <td><strong>P3Manager</strong></td>
       <td><strong>P3Prefold</strong></td>
       <td><strong>UNAFold runs</strong></td>
       <td><strong>P3Statistics</strong></td>
     </tr>
};

  foreach $theKey (reverse sort(keys(%allMonth))) {
      if (defined $startUpsMonth{$theKey}) {
          $startUpsVal = $startUpsMonth{$theKey};
      } else {
          $startUpsVal = "---";
      }
      if (defined $primer3RunsMonth{$theKey}) {
          $primer3RunsVal = $primer3RunsMonth{$theKey};
      } else {
          $primer3RunsVal = "---";
      }
      if (defined $managerRunsMonth{$theKey}) {
          $managerRunsVal = $managerRunsMonth{$theKey};
      } else {
          $managerRunsVal = "---";
      }
      if (defined $prefoldStartUpsMonth{$theKey}) {
          $prefoldStartUpsVal = $prefoldStartUpsMonth{$theKey};
      } else {
          $prefoldStartUpsVal = "---";
      }
      if (defined $prefoldRunsMonth{$theKey}) {
          $prefoldRunsVal = $prefoldRunsMonth{$theKey};
      } else {
          $prefoldRunsVal = "---";
      }
      if (defined $staticticsViewsMonth{$theKey}) {
          $staticticsViewsVal = $staticticsViewsMonth{$theKey};
      } else {
          $staticticsViewsVal = "---";
      }
      $theKey =~ s/\./-/g;
      $formHTML .= qq{    <tr>
       <td>$theKey</td>
       <td>$startUpsVal</td>
       <td>$primer3RunsVal</td>
       <td>$managerRunsVal</td>
       <td>$prefoldStartUpsVal</td>
       <td>$prefoldRunsVal</td>
       <td>$staticticsViewsVal</td>
     </tr>
};
  }

$formHTML .= qq{
  </table>
<h2>Usage per day:</h2>
  <table class="primer3plus_table_with_border">
     <colgroup>
       <col width="15%">
       <col width="14%">
       <col width="14%">
       <col width="14%">
       <col width="14%">
       <col width="14%">
       <col width="15%">
     </colgroup>
     <tr>
       <td><strong>Date</strong></td>
       <td><strong>P3Plus</strong></td>
       <td><strong>Primer3 runs</strong></td>
       <td><strong>P3Manager</strong></td>
       <td><strong>P3Prefold</strong></td>
       <td><strong>UNAFold runs</strong></td>
       <td><strong>P3Statistics</strong></td>
     </tr>
};

  foreach $theKey (reverse sort(keys(%allDates))) {
      if (defined $startUps{$theKey}) {
          $startUpsVal = $startUps{$theKey};
      } else {
          $startUpsVal = "---";
      }
      if (defined $primer3Runs{$theKey}) {
          $primer3RunsVal = $primer3Runs{$theKey};
      } else {
          $primer3RunsVal = "---";
      }
      if (defined $managerRuns{$theKey}) {
          $managerRunsVal = $managerRuns{$theKey};
      } else {
          $managerRunsVal = "---";
      }
      if (defined $prefoldStartUps{$theKey}) {
          $prefoldStartUpsVal = $prefoldStartUps{$theKey};
      } else {
          $prefoldStartUpsVal = "---";
      }
      if (defined $prefoldRuns{$theKey}) {
          $prefoldRunsVal = $prefoldRuns{$theKey};
      } else {
          $prefoldRunsVal = "---";
      }
      if (defined $staticticsViews{$theKey}) {
          $staticticsViewsVal = $staticticsViews{$theKey};
      } else {
          $staticticsViewsVal = "---";
      }
      $theKey =~ s/\./-/g;
      $formHTML .= qq{    <tr>
       <td>$theKey</td>
       <td>$startUpsVal</td>
       <td>$primer3RunsVal</td>
       <td>$managerRunsVal</td>
       <td>$prefoldStartUpsVal</td>
       <td>$prefoldRunsVal</td>
       <td>$staticticsViewsVal</td>
     </tr>
};
  }

$formHTML .= qq{
  </table></div>

</div>  
};
  } else {
    $formHTML .= qq{
<div id="primer3plus_results">

<h2>Display of statistics is not supported on this server!</h2>
</div>

</div>  
};
}

  my $returnString = $templateText;

  my $canon = qq{  <link rel=canonical href="https://primer3plus.com/cgi-bin/dev/primer3statistics.cgi" />
</head>};

  $returnString =~ s/<\/head>/$canon/;

  $returnString =~ s/<title>Primer3Plus<\/title>/<title>Primer3Plus - Statistics<\/title>/;

  my $metaDesc = qq{<meta name="description" content="The statistics page allows you to see Primer3Plus usage. Watch our servers glow...">};
  $returnString =~ s/<meta name="description" content=".+?">/$metaDesc/;

  $returnString =~ s/<!-- Primer3plus will include code here -->/$formHTML/;

  return $returnString;
}

####################################################
# createCompareFileHTML: Compares the stored files #
####################################################
sub createCompareFileHTML () {
  my $templateText = getWrapper();

  my $formHTML = qq{
<div id="primer3plus_complete">

};

  $formHTML .= divTopBar("Primer3CompareFiles","find the difference",0);

  $formHTML .= divMessages;

  $formHTML .= qq{
<div id="primer3plus_results">

  <p>&nbsp;&nbsp;Primer3ComareFiles allows to compare files with each other and the 
     default values to identify differences.<br>
     <br>
     <form name="mainForm" action="$machineSettings{URL_COMPARE_FILE}" method="post" enctype="multipart/form-data">
     &nbsp;&nbsp;<a name="SCRIPT_SEQUENCE_FILE_INPUT">File 1:</a>
     <input name="SCRIPT_SEQUENCE_FILE" type="file"><br>
     <br>
     &nbsp;&nbsp;<a name="SCRIPT_SEQUENCE_FILE_INPUT">File 2:</a>
     <input name="SCRIPT_SETTINGS_FILE" type="file"><br>
     <br>
     &nbsp;&nbsp;<a name="SCRIPT_SERVER_PARAMETER_FILE_INPUT">
     Server settings:</a>&nbsp;&nbsp;
     <select name="SCRIPT_SERVER_PARAMETER_FILE">
     <option>None</option>
};

  my @ServerParameterFiles = getServerParameterFilesList;
  my $option;
  foreach $option (@ServerParameterFiles) {
      my $selectedStatus = "";
      if ($option eq "Default" ) {
          $selectedStatus = " selected=\"selected\"" 
      };
      $formHTML .= "     <option$selectedStatus>$option</option>\n";
  }
  $formHTML .= qq{     </select>&nbsp;
     <br>
     <br>
     &nbsp;&nbsp;<input name="Compare_Files" value="Compare Files" type="submit">
     </form>
  </p>


</div>

</div>  
};

  my $returnString = $templateText;

  my $canon = qq{  <link rel=canonical href="https://primer3plus.com/cgi-bin/dev/primer3compareFiles.cgi" />
</head>};

  $returnString =~ s/<\/head>/$canon/;

  $returnString =~ s/<title>Primer3Plus<\/title>/<title>Primer3Plus - Compare Files<\/title>/;

  my $metaDesc = qq{<meta name="description" content="The Compare Files tool analyzes Primer3 settings files for differences.">};
  $returnString =~ s/<meta name="description" content=".+?">/$metaDesc/;

  $returnString =~ s/<!-- Primer3plus will include code here -->/$formHTML/;

  return $returnString;
}

##########################################################################
# createResultCompareFileHTML: Creates an HTML-Page with the differences #
##########################################################################
sub createResultCompareFileHTML {
  my $fileOne = shift;
  my $fileTwo = shift;
  my $serverFile = shift;
  my %resEqualServer = %{(shift)};
  my %resDiffServer = %{(shift)};
  my %resEqualFiles = %{(shift)};
  my %resDiffFiles = %{(shift)};

  my $templateText = getWrapper();
  my $theKey;
  
  my $tableStartA = qq{
  <table class="primer3plus_table_with_border">
     <colgroup>
       <col width="46%">
       <col width="18%">
       <col width="18%">
       <col width="18%">
     </colgroup>
     <tr>
       <td colspan="4"><strong>};

  my $tableStartB = qq{</strong></td>
     </tr>
     <tr>
       <td><strong>Parameter</strong></td>
       <td><strong>File 1</strong></td>
       <td><strong>File 2</strong></td>
       <td><strong>Server file</strong></td>
     </tr>
};


  my $formHTML = qq{
<div id="primer3plus_complete">
};

  $formHTML .= divTopBar("Primer3CompareFiles","find the difference",0);

  $formHTML .= divMessages;

  $formHTML .= qq{
<div id="primer3plus_results">

};
  $formHTML .= $tableStartA;
  $formHTML .= "Parameters in the files different to the Server file";
  $formHTML .= $tableStartB;
  
  foreach $theKey (sort(keys(%resDiffServer))) {
      if (!(($fileOne->{$theKey} eq "Not defined") 
          || ($fileTwo->{$theKey} eq "Not defined")
          || ($serverFile->{$theKey} eq "Not defined"))) {
      $formHTML .= qq{     <tr>
       <td>$theKey</td>
       <td>$fileOne->{$theKey}</td>
       <td>$fileTwo->{$theKey}</td>
       <td>$serverFile->{$theKey}</td>
     </tr>
};
     };
  }

  foreach $theKey (sort(keys(%resDiffServer))) {
      if (($fileOne->{$theKey} eq "Not defined") 
          || ($fileTwo->{$theKey} eq "Not defined")
          || ($serverFile->{$theKey} eq "Not defined")) {
      $formHTML .= qq{     <tr>
       <td>$theKey</td>
       <td>$fileOne->{$theKey}</td>
       <td>$fileTwo->{$theKey}</td>
       <td>$serverFile->{$theKey}</td>
     </tr>
};
     };
  }

  $formHTML .= qq{</table>
<br>
};
  $formHTML .= $tableStartA;
  $formHTML .= "Parameters different between the files";
  $formHTML .= $tableStartB;

  foreach $theKey (sort(keys(%resDiffFiles))) {
      if (!(($fileOne->{$theKey} eq "Not defined") 
          || ($fileTwo->{$theKey} eq "Not defined")
          || ($serverFile->{$theKey} eq "Not defined"))) {
      $formHTML .= qq{     <tr>
       <td>$theKey</td>
       <td>$fileOne->{$theKey}</td>
       <td>$fileTwo->{$theKey}</td>
       <td>$serverFile->{$theKey}</td>
     </tr>
};
     };
  }

  foreach $theKey (sort(keys(%resDiffFiles))) {
      if (($fileOne->{$theKey} eq "Not defined") 
          || ($fileTwo->{$theKey} eq "Not defined")
          || ($serverFile->{$theKey} eq "Not defined")) {
      $formHTML .= qq{     <tr>
       <td>$theKey</td>
       <td>$fileOne->{$theKey}</td>
       <td>$fileTwo->{$theKey}</td>
       <td>$serverFile->{$theKey}</td>
     </tr>
};
     };
  }

  $formHTML .= qq{</table>
<br>
};
  $formHTML .= $tableStartA;
  $formHTML .= "Parameters only equal in the files";
  $formHTML .= $tableStartB;

  foreach $theKey (sort(keys(%resEqualFiles))) {
      if (!(($fileOne->{$theKey} eq "Not defined") 
          || ($fileTwo->{$theKey} eq "Not defined"))) {
      $formHTML .= qq{     <tr>
       <td>$theKey</td>
       <td>$fileOne->{$theKey}</td>
       <td>$fileTwo->{$theKey}</td>
       <td></td>
     </tr>
};
     };
  }

  foreach $theKey (sort(keys(%resEqualFiles))) {
      if (($fileOne->{$theKey} eq "Not defined") 
          || ($fileTwo->{$theKey} eq "Not defined")) {
      $formHTML .= qq{     <tr>
       <td>$theKey</td>
       <td>$fileOne->{$theKey}</td>
       <td>$fileTwo->{$theKey}</td>
       <td></td>
     </tr>
};
     };
  }

  $formHTML .= qq{</table>
<br>
};
  $formHTML .= $tableStartA;
  $formHTML .= "Parameters equal in the files and the Server file";
  $formHTML .= $tableStartB;

  foreach $theKey (sort(keys(%resEqualServer))) {
      if (!(($fileOne->{$theKey} eq "Not defined") 
          || ($fileTwo->{$theKey} eq "Not defined")
          || ($serverFile->{$theKey} eq "Not defined"))) {
      $formHTML .= qq{     <tr>
       <td>$theKey</td>
       <td>$fileOne->{$theKey}</td>
       <td>$fileTwo->{$theKey}</td>
       <td>$serverFile->{$theKey}</td>
     </tr>
};
     };
  }

  foreach $theKey (sort(keys(%resEqualServer))) {
      if (($fileOne->{$theKey} eq "Not defined") 
          || ($fileTwo->{$theKey} eq "Not defined")
          || ($serverFile->{$theKey} eq "Not defined")) {
      $formHTML .= qq{     <tr>
       <td>$theKey</td>
       <td>$fileOne->{$theKey}</td>
       <td>$fileTwo->{$theKey}</td>
       <td>$serverFile->{$theKey}</td>
     </tr>
};
     };
  }

  $formHTML .= qq{</table>
<br>
</div>

</div>  
};

  my $returnString = $templateText;

  $returnString =~ s/<!-- Primer3plus will include code here -->/$formHTML/;

  return $returnString;
}

#####################
# Form Manager HTML #
#####################
sub createManagerDisplayHTML {
  my ($hash, $cgiInput, $counter) ;
  $hash = shift;
  $cgiInput = shift;

  my ($cgiName, $blastLinkUse, $blastSeq, $blastName);
  
  my $templateText = getWrapper();
  my $blastLink = getMachineSetting("URL_BLAST");

  my $formHTML = qq{
<SCRIPT language=JavaScript>
var prevTabPage = "primer3plus_main_tab";
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

function hideTabs() {
        document.getElementById('primer3plus_load_and_save').style.display="none";
        document.getElementById('primer3plus_settings').style.display="none";
}
</SCRIPT> 	
 	
<div id="primer3plus_complete">

<form action="$machineSettings{URL_PRIMER_MANAGER}" method="post" enctype="multipart/form-data">
<input type="hidden" name="SCRIPT_PRIMER_MANAGER" value="$hash->{"SCRIPT_PRIMER_MANAGER"}">
<input type="hidden" name="PRIMER_PAIR_NUM_RETURNED" value="$hash->{"PRIMER_PAIR_NUM_RETURNED"}">
};
  $formHTML .= divTopBar("Primer3Manager", "manage your primer library",0);

  $formHTML .= divMessages();
  
  # Display debug information
  if ($hash->{"SCRIPT_DISPLAY_DEBUG_INFORMATION"} eq 1){
  	  $formHTML .= qq{
  <div id="primer3plus_manager">
};
  	
      $formHTML .= printDebugInfo($cgiInput, "Provided input on CGI", 0);
      $formHTML .= printDebugInfo($hash, "Merged Information", 0);
  	  $formHTML .= qq{
  </div>
};
  }

  $formHTML .= qq{
  <div id="menuBar">
    <ul>
      <li id="tab1"><a onclick="showTab('tab1','primer3plus_main_tab')">Main</a></li>
      <li id="tab2"><a onclick="showTab('tab2','primer3plus_load_and_save')">Load and Save</a></li>
      <li id="tab3"><a onclick="showTab('tab3','primer3plus_settings')">Settings</a></li>
    </ul>
  </div>

  <div id="primer3plus_main_tab" class="primer3plus_tab_page">
};
     
     if ($hash->{"SCRIPT_PRIMER_MANAGER"} eq "PRIMER3MANAGER_DISPLAYMODE" ){
         $formHTML .= qq{   <input name="Submit" value="Order selected Primers" type="submit" style="background: #83db7b;">&nbsp;
   <input name="Submit" value="Refresh" type="submit">&nbsp;
   <input value="Reset Form" type="reset">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
   <input name="Submit" value="Delete Mode" type="submit">};
     } else {
     	 $formHTML .= qq{   <input name="Submit" value="Delete selected Primers" type="submit" style="background: #FF8040;">&nbsp;
   <input name="Submit" value="Refresh" type="submit">&nbsp;
   <input value="Reset Form" type="reset">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
   <input name="Submit" value="Order Mode" type="submit">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
   <input name="Submit" value="Delete all Primers" type="submit" style="background: #FF8040;">};
     }
     $formHTML .= qq{
   <br>
   <table class="primer3plus_table_no_border">
     <colgroup>
       <col width="10%">
       <col width="40%">
       <col width="10%">
       <col width="40%">
     </colgroup>
};

  for($counter = 0; $counter <= $hash->{"PRIMER_PAIR_NUM_RETURNED"}; $counter++) {

      $formHTML .= qq{     <tr>
       <td class="primer3plus_cell_no_border">&nbsp;&nbsp;<input id="PRIMER_PAIR_$counter\_SELECT" name="PRIMER_PAIR_$counter\_SELECT" value="1" };

      if ($hash->{"PRIMER_PAIR_$counter\_SELECT"} == 1) {
          if (!($hash->{"SCRIPT_PRIMER_MANAGER"} eq "PRIMER3MANAGER_DELETEMODE")) {
              $formHTML .= "checked=\"checked\" ";          	
          }
      } else {
          if ($hash->{"SCRIPT_PRIMER_MANAGER"} eq "PRIMER3MANAGER_DELETEMODE") {
              $formHTML .= "checked=\"checked\" ";          	
          }
      }
      
      #QUERY=&amp;
      $blastLinkUse = $blastLink;
      $blastSeq = blastSequences($hash, $counter);
      $blastLinkUse =~ s/;QUERY=/;QUERY=$blastSeq/;

      $formHTML .= qq{type="checkbox">&nbsp;&nbsp; Name: 
       </td>
       <td class="primer3plus_cell_no_border"><input id="PRIMER_PAIR_$counter\_NAME" name="PRIMER_PAIR_$counter\_NAME" value="$hash->{"PRIMER_PAIR_$counter\_NAME"}" size="25">
       </td>
       <td class="primer3plus_cell_no_border">Designed on</td>
       <td class="primer3plus_cell_no_border"><input id="PRIMER_PAIR_$counter\_DATE" name="PRIMER_PAIR_$counter\_DATE" value="$hash->{"PRIMER_PAIR_$counter\_DATE"}" size="10">
         &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
         <a href="$machineSettings{URL_FORM_ACTION}?SEQUENCE_ID=$hash->{"PRIMER_PAIR_$counter\_NAME"}&SEQUENCE_PRIMER=$hash->{"PRIMER_LEFT_$counter\_SEQUENCE"}&SEQUENCE_INTERNAL_OLIGO=$hash->{"PRIMER_INTERNAL_$counter\_SEQUENCE"}&SEQUENCE_PRIMER_REVCOMP=$hash->{"PRIMER_RIGHT_$counter\_SEQUENCE"}&SEQUENCE_TEMPLATE=$hash->{"PRIMER_PAIR_$counter\_AMPLICON"}">Check!</a>
         &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
         $blastLinkUse</td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border">Left:</td>
       <td class="primer3plus_cell_no_border"><input id="PRIMER_LEFT_$counter\_SEQUENCE" name="PRIMER_LEFT_$counter\_SEQUENCE" value="$hash->{"PRIMER_LEFT_$counter\_SEQUENCE"}" size="40"></td>
       <td class="primer3plus_cell_no_border">Right:</td>
       <td class="primer3plus_cell_no_border"><input id="PRIMER_RIGHT_$counter\_SEQUENCE" name="PRIMER_RIGHT_$counter\_SEQUENCE" value="$hash->{"PRIMER_RIGHT_$counter\_SEQUENCE"}" size="40"></td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border">Internal:</td>
       <td class="primer3plus_cell_no_border"><input id="PRIMER_INTERNAL_$counter\_SEQUENCE" name="PRIMER_INTERNAL_$counter\_SEQUENCE" value="$hash->{"PRIMER_INTERNAL_$counter\_SEQUENCE"}" size="40"></td>
       <td class="primer3plus_cell_no_border"></td>
       <td class="primer3plus_cell_no_border"></td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border">Amplicon: </td>
       <td colspan="3" class="primer3plus_cell_no_border"><textarea name="PRIMER_PAIR_$counter\_AMPLICON" id="PRIMER_PAIR_$counter\_AMPLICON" rows="4" cols="85">$hash->{"PRIMER_PAIR_$counter\_AMPLICON"}</textarea>
       </td>
     </tr>
     <tr>
       <td colspan="4" class="primer3plus_cell_no_border">&nbsp;&nbsp;&nbsp;</td>
     </tr>};

  };

$formHTML .= qq{   </table>
   <br>
};
  
     if ($hash->{"SCRIPT_PRIMER_MANAGER"} eq "PRIMER3MANAGER_DISPLAYMODE" ){
         $formHTML .= qq{   <input name="Submit" value="Order selected Primers" type="submit" style="background: #83db7b;">&nbsp;
   <input name="Submit" value="Refresh" type="submit">&nbsp;
   <input value="Reset Form" type="reset">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
   <input name="Submit" value="Delete Mode" type="submit">};
     } else {
     	 $formHTML .= qq{   <input name="Submit" value="Delete selected Primers" type="submit" style="background: #FF8040;">&nbsp;
   <input name="Submit" value="Refresh" type="submit">&nbsp;
   <input value="Reset Form" type="reset">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
   <input name="Submit" value="Order Mode" type="submit">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
   <input name="Submit" value="Delete all Primers" type="submit" style="background: #FF8040;">};
     }
     $formHTML .= qq{
   <br>
   <br>
  </div>

  <div id="primer3plus_load_and_save" class="primer3plus_tab_page">

   <table class="primer3plus_table_no_border">
     <colgroup>
       <col width="100%">
     </colgroup>
     <tr>
       <td class="primer3plus_cell_no_border"><a id="SCRIPT_SAVE_FILE_INPUT" name="SCRIPT_SAVE_FILE_INPUT">To save a RDML file or
         export as fasta on your local computer, choose here:</a>
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border">
         <input name="Submit" value="Save RDML File" type="submit">&nbsp;&nbsp;
         <input name="Submit" value="Export as Fasta" type="submit">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border">&nbsp;&nbsp;&nbsp;
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><a id="SCRIPT_SEQUENCE_FILE_INPUT" name="SCRIPT_SEQUENCE_FILE_INPUT">To upload a RDML primer file from
         your local computer, choose here:</a>
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><input id="SCRIPT_SEQUENCE_FILE" name="SCRIPT_SEQUENCE_FILE" type="file">&nbsp;&nbsp;
	     <input name="Submit" value="Upload File" type="submit">&nbsp;&nbsp;&nbsp;
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border">&nbsp;&nbsp;&nbsp;
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><a id="SCRIPT_SETTINGS_FILE_INPUT" name="SCRIPT_SETTINGS_FILE_INPUT">To import a fasta primer file created by 
         Primer3Plus up to version 2.1 from your local computer, choose here:</a>
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><input id="SCRIPT_SETTINGS_FILE" name="SCRIPT_SETTINGS_FILE" type="file">&nbsp;&nbsp;
	     <input name="Submit" value="Upload File" type="submit">&nbsp;&nbsp;&nbsp;
       </td>
     </tr>
   </table>
  </div>


  <div id="primer3plus_settings" class="primer3plus_tab_page">

   <table class="primer3plus_table_no_border">
     <colgroup>
       <col width="25%">
       <col width="15%">
       <col width="27%">
       <col width="33%">
     </colgroup>
     <tr>
       <td class="primer3plus_cell_no_border"> <a name="P3P_PRIMER_NAME_ACRONYM_LEFT_INPUT">
       RDML Version:</a>
       </td>
       <td class="primer3plus_cell_no_border">
         <select name="P3P_RDML_VERSION">
};
		if ( $hash->{P3P_RDML_VERSION} == 1.1 ) {
     		$formHTML .= qq{           <option value="1.0">1.0</option>
           <option selected="selected" value="1.1">1.1</option>
};
		}
		else {
			$formHTML .= qq{           <option selected="selected" value="1.0">1.0</option>
           <option value="1.1">1.1</option>
};		
		};

        $formHTML .= qq{         </select>
       </td>
       <td class="primer3plus_cell_no_border">
       </td>
       <td class="primer3plus_cell_no_border">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"> <a name="P3P_PRIMER_NAME_ACRONYM_LEFT_INPUT" href="$machineSettings{URL_HELP}#P3P_PRIMER_NAME_ACRONYM_LEFT">
       Left Primer Acronym:</a>
       </td>
       <td class="primer3plus_cell_no_border"> <input size="4" name="P3P_PRIMER_NAME_ACRONYM_LEFT" value="$hash->{P3P_PRIMER_NAME_ACRONYM_LEFT}" type="text">
       </td>
       <td class="primer3plus_cell_no_border"> <a name="P3P_PRIMER_NAME_ACRONYM_INTERNAL_INPUT" href="$machineSettings{URL_HELP}#P3P_PRIMER_NAME_ACRONYM_INTERNAL">
       Internal Oligo Acronym:</a>
       </td>
       <td class="primer3plus_cell_no_border"> <input size="4" name="P3P_PRIMER_NAME_ACRONYM_INTERNAL" value="$hash->{P3P_PRIMER_NAME_ACRONYM_INTERNAL}" type="text">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"> <a name="P3P_PRIMER_NAME_ACRONYM_RIGHT_INPUT" href="$machineSettings{URL_HELP}#P3P_PRIMER_NAME_ACRONYM_RIGHT">
       Right Primer Acronym:</a>
       </td>
       <td class="primer3plus_cell_no_border"> <input size="4" name="P3P_PRIMER_NAME_ACRONYM_RIGHT" value="$hash->{P3P_PRIMER_NAME_ACRONYM_RIGHT}" type="text">
       </td>
       <td class="primer3plus_cell_no_border"> <a name="P3P_PRIMER_NAME_ACRONYM_SPACER_INPUT" href="$machineSettings{URL_HELP}#P3P_PRIMER_NAME_ACRONYM_SPACER">
       Primer Name Spacer:</a>
       </td>
       <td class="primer3plus_cell_no_border"> <input size="4" name="P3P_PRIMER_NAME_ACRONYM_SPACER" value="$hash->{P3P_PRIMER_NAME_ACRONYM_SPACER}" type="text">
       </td>
     </tr>
   </table>
  </div>

 
</form>
</div>
<script type="text/javascript">
  hideTabs();
  showTab('tab1','primer3plus_main_tab');
</script>
};

  my $returnString = $templateText;

  my $canon = qq{  <link rel=canonical href="https://primer3plus.com/cgi-bin/dev/primer3manager.cgi" />
</head>};

  $returnString =~ s/<\/head>/$canon/;

  $returnString =~ s/<title>Primer3Plus<\/title>/<title>Primer3Plus - Primer3Manager<\/title>/;

  my $metaDesc = qq{<meta name="description" content="Primer3Manager organizes primer collections and exports them in the RDML format.">};
  $returnString =~ s/<meta name="description" content=".+?">/$metaDesc/;

  $returnString =~ s/<!-- Primer3plus will include code here -->/$formHTML/;

  return $returnString;
}

#####################
# Form Prefold HTML #
#####################
sub createPrefoldHTML {
  my ($hash, $cgiInput) ;
  $hash = shift;
  $cgiInput = shift;

  my $templateText = getWrapper();

  my $formHTML = qq{
<SCRIPT language=JavaScript>
function clearMarking() {
        var txtarea = document.mainForm.sequenceTextarea;
        txtarea.value = txtarea.value.replace(/[{}<>[\\]]/g,"");
        document.getElementById("SEQUENCE_INCLUDED_REGION").value="";
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

<form name="mainForm" action="$machineSettings{URL_PREFOLD}" method="post" enctype="multipart/form-data">
};
  $formHTML .= divTopBar("Primer3Prefold", "avoid secondary structures",0);

  $formHTML .= divMessages();
  
  # Display debug information
  if ($hash->{"SCRIPT_DISPLAY_DEBUG_INFORMATION"} eq 1){
  	  $formHTML .= qq{
  <div id="primer3plus_manager">
};
  	
      $formHTML .= printDebugInfo($cgiInput, "Provided input on CGI", 0);
      $formHTML .= printDebugInfo($hash, "Merged Information", 0);
  	  $formHTML .= qq{
  </div>
};
  }

  $formHTML .= qq{
<div id="primer3plus_results">
   <table class="primer3plus_table_no_border">
     <tr>
       <td colspan="2" class="primer3plus_cell_no_border">
         <a name="SEQUENCE_ID_INPUT" href="$machineSettings{URL_HELP}#SEQUENCE_ID">Sequence Id:</a>
         <input name="SEQUENCE_ID" value="$hash->{SEQUENCE_ID}" type="text">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border" valign="bottom">
         <a name="SEQUENCE_TEMPLATE_INPUT" href="$machineSettings{URL_HELP}#SEQUENCE_TEMPLATE">Paste template sequence below</a>
       </td>
       <td class="primer3plus_cell_no_border" valign="bottom">
         <a name="SCRIPT_SEQUENCE_FILE_INPUT">Or upload sequence file:</a>
         <input name="SCRIPT_SEQUENCE_FILE" type="file">&nbsp;&nbsp;
         <input name="Upload_File" value="Upload File" type="submit">&nbsp;&nbsp;&nbsp;
       </td>
     </tr>};

    my $sequence = $hash->{SEQUENCE_TEMPLATE};
    $sequence =~ s/(\w{80})/$1\n/g;

$formHTML .= qq{
     <tr>
       <td colspan="2" class="primer3plus_cell_no_border"> <textarea name="SEQUENCE_TEMPLATE" id="sequenceTextarea" rows="12" cols="90">$sequence</textarea>
       </td>
	</tr>
     <tr>
       <td colspan="2" class="primer3plus_cell_no_border">
         Due to performance reasons a sequence can be maximally $machineSettings{MAX_PREFOLD_SEQUENCE} bp long. If the 
         submitted sequence is bigger, select an included region < $machineSettings{MAX_PREFOLD_SEQUENCE} bp. 
       </td>
	</tr>
     <tr>
       <td colspan="2" class="primer3plus_cell_no_border">
         <a name="SEQUENCE_INCLUDED_REGION_INPUT" href="$machineSettings{URL_HELP}#SEQUENCE_INCLUDED_REGION">Included Region (start,length):</a>
         &nbsp;{&nbsp;<input size="40" id="SEQUENCE_INCLUDED_REGION" name="SEQUENCE_INCLUDED_REGION" value="$hash->{SEQUENCE_INCLUDED_REGION}" type="text">&nbsp;}
         &nbsp;&nbsp;<input type=button name="includedRegion" onclick="setRegion('{','}');return false;" value="{ }">
         <input type=button name="clearMarkings" onclick="clearMarking();return false;" value="Clear">
       </td>
	</tr>
     <tr>
       <td colspan="2" class="primer3plus_cell_no_border">
         &nbsp;
       </td>
	</tr>
     <tr>
       <td colspan="2" class="primer3plus_cell_no_border">
         &nbsp;<input name="Prefold_Sequence" value="Prefold Sequence" type="submit" style="background: #83db7b;">&nbsp;
         <input name="Submit" value="Refresh" type="submit">&nbsp;
         <input class="primer3plus_action_button" name="Default_Settings" value="Reset Form" type="submit">
       </td>
	</tr>
     <tr>
       <td colspan="2" class="primer3plus_cell_no_border">
         &nbsp;
       </td>
	</tr>
   </table>

  <div class="primer3plus_section">
   <table class="primer3plus_table_no_border">
     <colgroup>
       <col width="30%">
       <col width="10%">
       <col width="15%">
       <col width="10%">
       <col width="35%">
     </colgroup>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="PRIMER_SALT_MONOVALENT_INPUT" href="$machineSettings{URL_HELP}#PRIMER_SALT_MONOVALENT">Concentration of monovalent cations:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_SALT_MONOVALENT" value="$hash->{PRIMER_SALT_MONOVALENT}" type="text">
       </td>
       <td class="primer3plus_cell_no_border"><a href="$machineSettings{URL_HELP}#PRIMER_OPT_TM">Opt Primer Tm:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_OPT_TM" value="$hash->{PRIMER_OPT_TM}" type="text">
       </td>
       <td class="primer3plus_cell_no_border">&nbsp;
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="PRIMER_SALT_DIVALENT_INPUT" href="$machineSettings{URL_HELP}#PRIMER_SALT_DIVALENT">Concentration of divalent cations:</a>
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_SALT_DIVALENT" value="$hash->{PRIMER_SALT_DIVALENT}" type="text">
       </td>
       <td class="primer3plus_cell_no_border">&nbsp;
       </td>
       <td class="primer3plus_cell_no_border">&nbsp;
       </td>
       <td class="primer3plus_cell_no_border">&nbsp;
       </td>
     </tr>
   </table>
  </div>

  <table class="primer3plus_table_no_border">
    <tr>
       <td class="primer3plus_cell_no_border">
         Please visit <a class="primer3plus_top_bar_link" href="primer3plusAbout.cgi">About</a> for
         Primer3 and Primer3Plus citation requests.<br /><br />
         Primer3Prefold uses for folding the software UNAFold, a successor of mfold. 
         License conditions require that you cite the following article if you use Primer3Prefold:
         <br /><br />
         Markham, N. R. &amp; Zuker, M. (2008) UNAFold: software for nucleic acid folding and hybriziation.
         In Keith, J. M., editor, <i>Bioinformatics, Volume II. Structure, Function and Applications</i>, 
         number 453 in <i>Methods in Molecular Biology</i>, chapter 1, pages 3&ndash;31.  
         Humana Press, Totowa, NJ.  ISBN 978-1-60327-428-9.
         <a href="http://www.springerprotocols.com/Abstract/doi/10.1007/978-1-60327-429-6_1">[Abstract]</a> 
         <a href="http://www.springerprotocols.com/Full/doi/10.1007/978-1-60327-429-6_1?encCode=RklCOjFfNi05MjQtNzIzMDYtMS04Nzk=">[Full Text]</a>
         <a href="http://www.springerprotocols.com/Pdf/doi/10.1007/978-1-60327-429-6_1?encCode=RklCOjFfNi05MjQtNzIzMDYtMS04Nzk=">[PDF]</a>         
       </td>
     </tr>
   </table>
  
</div>

</form>

</div>  
};

  my $returnString = $templateText;

  my $canon = qq{  <link rel=canonical href="https://primer3plus.com/cgi-bin/dev/primer3prefold.cgi" />
</head>};

  $returnString =~ s/<\/head>/$canon/;

  $returnString =~ s/<title>Primer3Plus<\/title>/<title>Primer3Plus - Primer3Prefold<\/title>/;

  my $metaDesc = qq{<meta name="description" content="Primer3Prefold uses UNAFold to find stable secondary structures in template DNA and avoids them in Primer3Plus.">};
  $returnString =~ s/<meta name="description" content=".+?">/$metaDesc/;

  $returnString =~ s/<!-- Primer3plus will include code here -->/$formHTML/;

  return $returnString;
}

sub blastSequences {
    my ($hash, $counter);
    $hash = shift;
    $counter = shift;
    
    my ($fullName, $formHTML, $name);
	
    $name = "%3E" . $hash->{"PRIMER_PAIR_$counter\_NAME"};

    if ($hash->{"PRIMER_LEFT_$counter\_SEQUENCE"} ne "") {
        $fullName = $name . $hash->{"P3P_PRIMER_NAME_ACRONYM_SPACER"} . $hash->{"P3P_PRIMER_NAME_ACRONYM_LEFT"};
        $formHTML .= qq{$fullName};
        $formHTML .= "%0D%0A". qq{$hash->{"PRIMER_LEFT_$counter\_SEQUENCE"}};
        $formHTML .= "%0D%0A";
    }
    if ($hash->{"PRIMER_RIGHT_$counter\_SEQUENCE"} ne "") {
        $fullName = $name . $hash->{"P3P_PRIMER_NAME_ACRONYM_SPACER"} . $hash->{"P3P_PRIMER_NAME_ACRONYM_RIGHT"};
        $formHTML .= qq{$fullName};
        $formHTML .= "%0D%0A". qq{$hash->{"PRIMER_RIGHT_$counter\_SEQUENCE"}};
        $formHTML .= "%0D%0A";;
    }
    if ($hash->{"PRIMER_INTERNAL_$counter\_SEQUENCE"} ne "") {
        $fullName = $name . $hash->{"P3P_PRIMER_NAME_ACRONYM_SPACER"} . $hash->{"P3P_PRIMER_NAME_ACRONYM_INTERNAL"};
        $formHTML .= qq{$fullName};
        $formHTML .= "%0D%0A" . qq{$hash->{"PRIMER_INTERNAL_$counter\_SEQUENCE"}};
        $formHTML .= "%0D%0A";
    }       

	return $formHTML;
}


1;
