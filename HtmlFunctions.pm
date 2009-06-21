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
@EXPORT = qw(&mainStartUpHTML &createHelpHTML &createAboutHTML 
             &createPackageHTML &mainResultsHTML &createManagerHTML 
             &getWrapper &createSelectSequence);
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

function updateSequence() {
    document.getElementById("SEQUENCE_PRIMER").value = document.getElementById("SEQUENCE_PRIMER_SCRIPT").value;  
}

function updatePrimer() {
    document.getElementById("SEQUENCE_PRIMER_SCRIPT").value = document.getElementById("SEQUENCE_PRIMER").value;  
}
};

my $primerSelected = 1;

if ( $settings{PRIMER_TASK} eq "Primer_Check" ) {
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
	
<input name="SCRIPT_RADIO_BUTTONS_FIX" id="SCRIPT_RADIO_BUTTONS_FIX" value="SCRIPT_CONTAINS_JAVA_SCRIPT,PRIMER_PICK_LEFT_PRIMER,PRIMER_PICK_INTERNAL_OLIGO,PRIMER_PICK_RIGHT_PRIMER,SCRIPT_SEQUENCING_REVERSE,P3P_DETECTION_USE_PRODUCT_SIZE,PRIMER_LIBERAL_BASE,SCRIPT_PRINT_INPUT,PRIMER_LIB_AMBIGUITY_CODES_CONSENSUS" type="hidden">

         <a name="SERVER_PARAMETER_FILE_INPUT" href="$machineSettings{URL_HELP}#SERVER_PARAMETER_FILE">
         Load server settings:</a>&nbsp;&nbsp;
         <select name="SERVER_PARAMETER_FILE">
};

        my @ServerParameterFiles = getServerParameterFilesList;
	my $option;
        foreach $option (@ServerParameterFiles) {
                my $selectedStatus = "";
                if ($option eq $settings{SERVER_PARAMETER_FILE} ) {$selectedStatus = " selected=\"selected\"" };
                $formHTML .= "         <option$selectedStatus>$option</option>\n";
        }

        $formHTML .= qq{         </select>&nbsp;
       <input name="Activate_Settings" value="Activate Settings" type="submit"><br>
             <a id="PRIMER_TASK_INPUT" name="PRIMER_TASK_INPUT" href="$machineSettings{URL_HELP}#PRIMER_TASK">
         Task:</a>&nbsp;
        <select id="PRIMER_TASK" name="PRIMER_TASK" class="primer3plus_task" onchange="showSelection(this);" onkeyup="showSelection(this)">
};

        my $option;
        foreach $option (@scriptTask) {
                my $selectedStatus = "";
                if ($option eq $settings{PRIMER_TASK} ) {$selectedStatus = " selected=\"selected\"" };
                $formHTML .= "         <option class=\"primer3plus_task\"$selectedStatus>$option</option>\n";
        }

        $formHTML .= qq{         </select>
       </td>};

        $formHTML .= qq{
        <td class="primer3plus_cell_no_border_explain">
   <div id="primer3plus_explain_Detection"
        };

        if ($settings{PRIMER_TASK} ne "Detection")  {
                $formHTML .= qq{style="display: none;" };
        }
$formHTML .= qq{>
     <a>Select primer pairs to detect the given template sequence. Optionally targets and included/excluded regions can be specified.</a>
   </div>
   <div id="primer3plus_explain_Cloning" };

        if ($settings{PRIMER_TASK} ne "Cloning")  {
                $formHTML .= qq{style="display: none;" };
        }
$formHTML .= qq{>
     <a>Mark an included region to pick primers fixed at its the boundaries. The quality of the primers might be low.</a>
   </div>
   <div id="primer3plus_explain_Sequencing" };

        if ($settings{PRIMER_TASK} ne "Sequencing")  {
                $formHTML .= qq{style="display: none;" };
        }
$formHTML .= qq{>
     <a>Pick a series of primers on both strands for sequencing. Optionally the regions of interest can be marked using targets.</a>
   </div>
   <div id="primer3plus_explain_Primer_List" };

        if ($settings{PRIMER_TASK} ne "Primer_List")  {
                $formHTML .= qq{style="display: none;" };
        }
$formHTML .= qq{>
     <a>Returns a list of all possible primers the can be designed on the template sequence. Optionally targets and included/exlcuded regions can be specified.</a>
   </div>
   <div id="primer3plus_explain_Primer_Check" };

        if ($settings{PRIMER_TASK} ne "Primer_Check")  {
                $formHTML .= qq{style="display: none;" };
        }
$formHTML .= qq{>
     <a>Evaluate a primer of known sequence with the given settings.</a>
   </div>
         </td><td class="primer3plus_cell_no_border" align="right">};

$formHTML .= qq{   
	<table><tr>
	<td><input id="primer3plus_pick_primers_button" class="primer3plus_action_button" name="Pick_Primers" value="Pick Primers" type="submit" style="background: #83db7b;"></td>
	<td><input class="primer3plus_action_button" name="Default_Settings" value="Reset Form" type="submit"></td>
	</tr></table>
};

$formHTML .= qq{
        </td>
        </tr>
   </tbody></table>
</div>
};

my $urlFormAction = getMachineSetting("URL_FORM_ACTION");
$urlFormAction .= "?SCRIPT_CONTAINS_JAVA_SCRIPT=0";
$formHTML .= qq{
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

<div id="primer3plus_primer_only" };

	if ($settings{PRIMER_TASK} ne "Primer_Check")  {
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

	if ($settings{PRIMER_TASK} eq "Primer_Check")  {
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
<div id="primer3plus_primer_overlap_pos_box">
  <table class="primer3plus_table_no_border">
     <colgroup>
       <col width="20%">
       <col width="2%">
       <col width="78%">
     </colgroup>
     <tr>
       <td class="primer3plus_cell_no_border"><a onmouseover="toolTip('A list of positions in the given sequence. The value for this parameter has the form position.<br>E.g. 120: only pick primers overlaping the position 120.<br> Or use ? in the source sequence to mark the position.<br>Primer3 tries to pick primer pairs were the forward or the reverse primer overlaps one of these positions.');"
         onmouseout="toolTip();"  name="SEQUENCE_PRIMER_OVERLAP_POS_INPUT" href="$machineSettings{URL_HELP}#SEQUENCE_PRIMER_OVERLAP_POS">Primer overlap positions:</a>
       </td>
       <td class="primer3plus_cell_no_border">?
       </td>
       <td class="primer3plus_cell_no_border"><input size="40" id="SEQUENCE_PRIMER_OVERLAP_POS" name="SEQUENCE_PRIMER_OVERLAP_POS" value="$settings{SEQUENCE_PRIMER_OVERLAP_POS}" type="text">
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
         <input id="PRIMER_PICK_LEFT_PRIMER" name="PRIMER_PICK_LEFT_PRIMER" value="1" };

	$formHTML .= ($settings{PRIMER_PICK_LEFT_PRIMER}) ? "checked=\"checked\" " : "";
 
	$formHTML .= qq{ type="checkbox"><a href="$machineSettings{URL_HELP}#PRIMER_PICK_LEFT_PRIMER">Pick left primer</a><br>
         or use <a href="$machineSettings{URL_HELP}#SEQUENCE_PRIMER">left primer</a> below.
       </td>
       <td class="primer3plus_cell_no_border_bg" valign="top">
         <input id="PRIMER_PICK_INTERNAL_OLIGO" name="PRIMER_PICK_INTERNAL_OLIGO" value="1" };

	$formHTML .= ($settings{PRIMER_PICK_INTERNAL_OLIGO}) ? "checked=\"checked\" " : "";
 
	$formHTML .= qq{type="checkbox"><a href="$machineSettings{URL_HELP}#PRIMER_PICK_INTERNAL_OLIGO">Pick hybridization probe</a><br>
         (internal oligo) or use <a href="$machineSettings{URL_HELP}#SEQUENCE_INTERNAL_OLIGO">oligo</a> below.
       </td>
       <td class="primer3plus_cell_no_border_bg" valign="top">
         <input id="PRIMER_PICK_RIGHT_PRIMER" name="PRIMER_PICK_RIGHT_PRIMER" value="1" };

	$formHTML .= ($settings{PRIMER_PICK_RIGHT_PRIMER}) ? "checked=\"checked\" " : "";
 
	$formHTML .= qq{ type="checkbox"><a href="$machineSettings{URL_HELP}#PRIMER_PICK_RIGHT_PRIMER">Pick right primer</a>
         or use <a href="$machineSettings{URL_HELP}#SEQUENCE_PRIMER_REVCOMP">right primer</a><br>
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
     <tr>
       <td class="primer3plus_cell_no_border_bg"><a href="$machineSettings{URL_HELP}#SEQUENCE_FORCE_LEFT_START">Force start:</a>&nbsp;&nbsp;
         <input size="6" name="SEQUENCE_FORCE_LEFT_START" value="$settings{SEQUENCE_FORCE_LEFT_START}" type="text">
       </td>
       <td class="primer3plus_cell_no_border_bg">&nbsp;&nbsp;
       </td>
       <td class="primer3plus_cell_no_border_bg"><a href="$machineSettings{URL_HELP}#SEQUENCE_FORCE_RIGHT_START">Force start:</a>&nbsp;&nbsp;
         <input size="6" name="SEQUENCE_FORCE_RIGHT_START" value="$settings{SEQUENCE_FORCE_RIGHT_START}" type="text">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border_bg"><a href="$machineSettings{URL_HELP}#SEQUENCE_FORCE_LEFT_END">Force end:</a>&nbsp;&nbsp;&nbsp;
         <input size="6" name="SEQUENCE_FORCE_LEFT_END" value="$settings{SEQUENCE_FORCE_LEFT_END}" type="text">
       </td>
       <td class="primer3plus_cell_no_border_bg">&nbsp;&nbsp;
       </td>
       <td class="primer3plus_cell_no_border_bg"><a href="$machineSettings{URL_HELP}#SEQUENCE_FORCE_RIGHT_END">Force end:</a>&nbsp;&nbsp;&nbsp;
         <input size="6" name="SEQUENCE_FORCE_RIGHT_END" value="$settings{SEQUENCE_FORCE_RIGHT_END}" type="text">
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
$formHTML .= qq{<div id="primer3plus_advanced_sequence" style="display: none;" class="primer3plus_tab_page">
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
};

###################################
# Create the GENERAL SETTINGS tab #
###################################
$formHTML .= qq{
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
         <input name="P3P_DETECTION_USE_PRODUCT_SIZE"  value="1" };

	$formHTML .= ($settings{P3P_DETECTION_USE_PRODUCT_SIZE}) ? "checked=\"checked\" " : "";
 
	$formHTML .= qq{type="checkbox">
         <a onmouseover="toolTip('Select box to specify the min, opt, and max product sizes only if you absolutely must!<br>Using them is too slow (and too computationally intensive for our server).');" onmouseout="toolTip();" name="P3P_DETECTION_USE_PRODUCT_SIZE_INPUT" href="$machineSettings{URL_HELP}#REVERSE">
         Use Product Size Input and ignore Product Size Range</a>
       </td>
       <td class="primer3plus_cell_no_border" colspan="2">Warning: slow and expensive!</td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><a name="PRIMER_PRODUCT_SIZE_INPUT" href="primer3plusHelp.cgi#PRIMER_PRODUCT_SIZE">Product Size</a>
       </td>
       <td class="primer3plus_cell_no_border_right">Min: 
         <input size="6" name="P3P_DETECTION_PRODUCT_MIN_SIZE" 
         value="$settings{P3P_DETECTION_PRODUCT_MIN_SIZE}" type="text">
       </td>
       <td class="primer3plus_cell_no_border_right">Opt: 
         <input size="6" name="P3P_DETECTION_PRODUCT_OPT_SIZE" 
         value="$settings{P3P_DETECTION_PRODUCT_OPT_SIZE}" type="text">
       </td>
       <td class="primer3plus_cell_no_border_right">Max: 
         <input size="6" name="P3P_DETECTION_PRODUCT_MAX_SIZE" 
         value="$settings{P3P_DETECTION_PRODUCT_MAX_SIZE}" type="text">
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
       <td class="primer3plus_cell_no_border"><a onmouseover="toolTip('Space between primer binding site and the start of readable sequencing');" onmouseout="toolTip();" name="PRIMER_SEQUENCING_LEAD_INPUT" href="$machineSettings{URL_HELP}#PRIMER_SEQUENCING_LEAD">Lead</a>
       </td>
       <td class="primer3plus_cell_no_border">Bp:
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_SEQUENCING_LEAD" value="$settings{PRIMER_SEQUENCING_LEAD}" type="text">
       </td>
       <td class="primer3plus_cell_no_border"><a onmouseover="toolTip('Space between the primers on one DNA strand');" onmouseout="toolTip();" name="PRIMER_SEQUENCING_SPACING_INPUT" href="$machineSettings{URL_HELP}#PRIMER_SEQUENCING_SPACING">
         Spacing</a>
       </td>
       <td class="primer3plus_cell_no_border">Bp: </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_SEQUENCING_SPACING" value="$settings{PRIMER_SEQUENCING_SPACING}" type="text">
       </td>
     </tr>
     <tr>
       <td class="primer3plus_cell_no_border"><a onmouseover="toolTip('Space in which Primer3Plus picks the optimal primer');" onmouseout="toolTip();" name="PRIMER_SEQUENCING_ACCURACY_INPUT"
         href="$machineSettings{URL_HELP}#PRIMER_SEQUENCING_ACCURACY">Accuracy</a>
       </td>
       <td class="primer3plus_cell_no_border">Bp:
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_SEQUENCING_ACCURACY" value="$settings{PRIMER_SEQUENCING_ACCURACY}" type="text">
       </td>
       <td class="primer3plus_cell_no_border"><a onmouseover="toolTip('Space between primers on the forward and the reverse strand');" onmouseout="toolTip();" name="PRIMER_SEQUENCING_INTERVAL_INPUT" href="$machineSettings{URL_HELP}#PRIMER_SEQUENCING_INTERVAL">
         Interval</a>
       </td>
       <td class="primer3plus_cell_no_border">Bp:
       </td>
       <td class="primer3plus_cell_no_border"><input size="4" name="PRIMER_SEQUENCING_INTERVAL" value="$settings{PRIMER_SEQUENCING_INTERVAL}" type="text">
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
<div id="primer3plus_internal_oligo" class="primer3plus_tab_page" style="display: none;">
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

my $task = "primer3plus_explain_".$settings{PRIMER_TASK};
$formHTML .= qq{</div>

</form>

</div>	
<script type="text/javascript">
function initTabs() {
	showTab('tab1','primer3plus_main_tab');
	showTopic('$task');
}
initTabs();
</script>
};

  my $returnString = $templateText;

  $returnString =~ s/<!-- Primer3plus will include code here -->/$formHTML/;

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
  my $task = $results->{"PRIMER_TASK"};
  my $pair_count = 0;
  my $primer_count = 0;

  # To be sure primer3 run well and provided results  
  if (defined $results->{"PRIMER_PAIR_NUM_RETURNED"}){
      $pair_count = $results->{"PRIMER_PAIR_NUM_RETURNED"};
      $primer_count = $results->{"PRIMER_LEFT_NUM_RETURNED"};
      $primer_count += $results->{"PRIMER_INTERNAL_NUM_RETURNED"};
      $primer_count += $results->{"PRIMER_RIGHT_NUM_RETURNED"};
  } else {
      $returnString = createResultsNoPrimers($completeParameters, $results);       
  }


  if (($task eq "pick_detection_primers") 
       || ($task eq "pick_cloning_primers")
       || ($task eq "pick_discriminative_primers")
       || ($task eq "pick_sequencing_primers")
       || ($task eq "pick_primer_list")
       || ($task eq "check_primers")) {
      if ($pair_count != 0) {
          $returnString = createResultsDetection($completeParameters, $results);
      } elsif ($task eq "pick_sequencing_primers") {
          $returnString = createResultsPrimerList($completeParameters, $results, "0");
      } else {
          $returnString = createResultsPrimerList($completeParameters, $results, "1");
      }
  }
  elsif ($task eq "Detection") {
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


###########################################################
# createHelpHTML: Will write an HTML-Form containing Help #
###########################################################

sub createHelpHTML {
  my $helpHTML = shift;
  my $templateText = getWrapper();

  my $formHTML = qq{
<div id="primer3plus_complete">

};

$formHTML .= divTopBar("Primer3Plus - Help",0,"");

$formHTML .= divMessages;

$formHTML .= $helpHTML;

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
$formHTML .= divTopBar("Primer3Plus - About",0,0);

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
<div id="primer3plus_help">

<h2><a name="primer3plus" href="primer3plus.cgi">Primer3Plus</a></h2>
  <p>Primer3Plus is the module which runs primer3 to pick primers.
  </p>

<h2><a name="primer3manager" href="primer3manager.cgi">Primer3Manager</a></h2>
  <p>Primer3Manager allows to manage selected primers and to save them.
  </p>


</div>

</div>	
};

  my $returnString = $templateText;

  $returnString =~ s/<!-- Primer3plus will include code here -->/$formHTML/;

  return $returnString;
}

##################################################################################
# createResultsNoPrimers: Will write an HTML-Form based if no primers were found #
##################################################################################
sub createResultsNoPrimers {
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
$formHTML .= divTopBar(0,0,0);

$formHTML .= divMessages();

$formHTML .= qq{
<div id="primer3plus_results">
};

$formHTML .= divReturnToInput($completeParameters);

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
$formHTML .= divTopBar(0,0,0);

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

$formHTML .= divTopBar(0,0,0);

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
$formHTML .= divTopBar(0,0,0);

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
$formHTML .= divTopBar(0,0,0);

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

$formHTML .= partPrimerData( $results, $counter, "INTERNAL", $checked);

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
      if (defined ($results->{"PRIMER_INTERNAL_0"}) and (($results->{"PRIMER_INTERNAL_0"}) ne "")) {
     	   $format = addRegion($format,$results->{"PRIMER_INTERNAL_0"},$firstBase,"O");
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
$formHTML .= divTopBar("Primer3Manager", "manage your primer library",0);

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
       <td class="primer3plus_cell_no_border">&nbsp;<a href="$machineSettings{URL_FORM_ACTION}?SEQUENCE_ID=$cgiName&SEQUENCE_PRIMER=$sequences[$counter]&PRIMER_TASK=Primer_Check">Check!</a></td>
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

1;
