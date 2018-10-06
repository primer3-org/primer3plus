const API_URL = process.env.API_URL
const HELP_LINK_URL = process.env.HELP_LINK_URL

// The default Settings loded from the server
var defSet;
// "TAG":["default setting","data type"]

// The old tags which need to be replaced by new tags
var repOld;
// "OLD TAG":"NEW TAG"

// The available server settings files
var server_setting_files;

// The available misspriming library files
var misspriming_lib_files;

var debug = 1;

var p3p_errors = [];
var p3p_warnings = [];
var p3p_messages = [];

document.addEventListener("DOMContentLoaded", function() {
  // Send different data to avoid caching
  var dt = new Date();
  var utcDate = dt.toUTCString();
  const formData = new FormData();
  formData.append('stufferData', utcDate);
  axios
    .post(`${API_URL}/defaultsettings`, formData)
    .then(res => {
        if (res.status === 200) {
          defSet = res.data["def"];
          repOld = res.data["replace"];
          server_setting_files = res.data["server_setting_files"];
          misspriming_lib_files = res.data["misspriming_lib_files"];
          setHTMLParameters(defSet);
          initElements();
      }
    })
    .catch(err => {
      let errorMessage = err
  //    if (err.response) {
  //      errorMessage = err.response.data.errors
  //      .map(error => error.title)
   //     .join('; ')
  //    }
      add_message("err","Error loading default settings from server: " + errorMessage);
    })
});

function loadSetFileFromServer() {
  del_all_messages ();
  // Send different data to avoid caching
  var fileName = getHtmlTagValue("P3P_SERVER_SETTINGS_FILE");
  if ((fileName == "Default") || (fileName == "")) {
    setHTMLParameters(defSet);
    add_message("mess","Default settings loaded!");
    return;	  
  }
  const formData = new FormData();
  formData.append('P3P_SERVER_SETTINGS_FILE', fileName);
  axios
    .post(`${API_URL}/settingsFile`, formData)
    .then(res => {
        if (res.status === 200) {
          loadP3File("seq",res.data);
      }
    })
    .catch(err => {
      let errorMessage = err
  //    if (err.response) {
  //      errorMessage = err.response.data.errors
  //      .map(error => error.title)
   //     .join('; ')
  //    }
      add_message("err","Error loading server settings file " + fileName + ": " + errorMessage);
    })
}

function del_all_messages () {
  del_message("err");
  del_message("warn");
  del_message("mess");
}
function del_message(level) {
  if (level == "err") {
    p3p_errors = [];
  }
  if (level == "warn") {
    p3p_warnings = [];
  }
  if (level == "mess") {
    p3p_messages = [];
  }
  refresh_message(level);
}
function add_message(level,message) {
  var arr = get_message_arr(level);
  if (arr == null) {
    return;
  }
  arr.push(message);
  refresh_message(level);
}
function get_message_arr(level) {
  if (level == "err") {
    return p3p_errors;
  }
  if (level == "warn") {
    return p3p_warnings;
  }
  if (level == "mess") {
    return p3p_messages;
  }
  return null;
}

function refresh_message(level) {
  var el = null;
  if (level == "err") {
    el = document.getElementById('P3P_TOP_MESSAGE_ERROR');
  }
  if (level == "warn") {
    el = document.getElementById('P3P_TOP_MESSAGE_WARNING');
  }
  if (level == "mess") {
    el = document.getElementById('P3P_TOP_MESSAGE_MESSAGE');
  }
  var arr = get_message_arr(level);
  if ((arr === null) || (el == null)) {
    return;
  }
  if (arr.length == 0) {
    el.innerHTML = "\n";
    el.style.display="none";
  } else {
    var txt = "";
    for (var i = 0; i < arr.length; i++) {
      txt += arr[i] + "<br />";
    }
    el.innerHTML = txt;
    el.style.display="inline";
  }
}

function initElements(){
  addServerFiles();
  linkHelpTags();
  initTabFunctionality();
  initResetDefautl();
  initTaskFunctionality();
  initLoadSeqFile();
  initSaveFile();
  initLoadExample();
  initExplainSeqRegions();
  initLoadSetFile();
}

function linkHelpTags() {
  var linkRoot = `${HELP_LINK_URL}#`;
  for (var tag in defSet) {
    if (defSet.hasOwnProperty(tag)) {
      var pageElement = document.getElementById(tag + '_HELP');
      if (pageElement !== null) {
        pageElement.href = linkRoot + tag;
        pageElement.target = "p3p_help";
      }
    }
  }
//  targetGenomes.innerHTML = rhtml
}

function addServerFiles() {
  var mis = document.getElementById('PRIMER_MISPRIMING_LIBRARY');
  if (mis !== null) {
    for (var i = 0; i < misspriming_lib_files.length; i++) {
      var option = document.createElement("option");
      option.text = misspriming_lib_files[i].name;
      option.value = misspriming_lib_files[i].file;
      mis.add(option);
    }	  
  }
  var misOl = document.getElementById('PRIMER_INTERNAL_MISHYB_LIBRARY');
  if (misOl !== null) {
    for (var i = 0; i < misspriming_lib_files.length; i++) {
      var option = document.createElement("option");
      option.text = misspriming_lib_files[i].name;
      option.value = misspriming_lib_files[i].file;
      misOl.add(option);
    }     
  }
  var set = document.getElementById('P3P_SERVER_SETTINGS_FILE');
  if (set !== null) {
    for (var i = 0; i < server_setting_files.length; i++) {
      var option = document.createElement("option");
      option.text = server_setting_files[i].name;
      option.value = server_setting_files[i].file;
      set.add(option);
    } 
  }
  var btn = document.getElementById('P3P_ACTION_SERVER_SETTINGS');
  if (btn !== null) {
    btn.addEventListener('click', loadSetFileFromServer);
  }
}

async function blaParameters() {
//  console.log(defSet)
  var alles = "";
  for (var tag in defSet) {
    if (defSet.hasOwnProperty(tag)) {
      var  value = getHtmlTagValue(tag);
      if (value !== null) {
	if (value == defSet[tag][0]) {
//           console.log("EQUAL: " + tag );
	} else {
           alles += "Difference: " + tag + "\n      HP:" + value + "\n    JSON:" + defSet[tag][0] + "\n";
	}
      } else {
           alles += "ABSENT: " + tag + "\n";
      }

    }
  }
  var out = document.getElementById('sequenceTextarea');  
  out.innerHTML = alles;
}

function getHtmlTagValue(tag) {
  var pageElement = document.getElementById(tag);
  if (pageElement !== null) {
    var tagName = pageElement.tagName.toLowerCase();
    if (tagName === 'textarea') {
      return pageElement.value;
    }
    if (tagName === 'select') {
      return pageElement.options[pageElement.selectedIndex].value;
    }
    if (tagName === 'input') {
      var type = pageElement.getAttribute('type').toLowerCase();
      if (type == 'checkbox') {
        if (pageElement.checked == true) {
          return "1";
        } else {
          return "0";
        }
      }
      if ((type == 'text') || (type == 'hidden')) {
        return pageElement.value;
      }
//    alert("Unknown Type by " + tag + ": " + pageElement.getAttribute('type'));
    }
  }
  return null;
}

async function setHTMLParameters(para) {
  for (var tag in para) {
    if (para.hasOwnProperty(tag)) {
      setHtmlTagValue(tag, para[tag][0]);	     
    }
  }
}

function setHtmlTagValue(tag, value) {
  var pageElement = document.getElementById(tag);
  value = value.replace(/\s*$/, "");
  if (pageElement !== null) {
    var tagName = pageElement.tagName.toLowerCase();
    if (tagName === 'textarea') {
      pageElement.value = value;
    }
    if (tagName === 'select') {
      if (value == "") {
        pageElement.selectedIndex = 0;
	return true;
      } else {
        for (var i = 0; i < pageElement.options.length; i++) {
          if (pageElement.options[i].value == value) {
            pageElement.selectedIndex = i;
            return true;
          }
        }
      }
      return false;
    }
    if (tagName === 'input') {
      var type = pageElement.getAttribute('type').toLowerCase();
      if (type == 'checkbox') {
        var uVal = parseInt(value);
        if (uVal != 0) {
          pageElement.checked = true;
          return true;
        } else {
          pageElement.checked = false;
          return true;
        }
      }
      if ((type == 'text') || (type == 'hidden')) {
          pageElement.value = value;
          return true;
      }
//    alert("Unknown Type by " + tag + ": " + pageElement.getAttribute('type'));
    }
  }
  return false;
}

function detectBorwser() {
    var browser = window.navigator.userAgent.toLowerCase();
    if (browser.indexOf("edge") != -1) {
        return "edge";
    }
    if (browser.indexOf("firefox") != -1) {
        return "firefox";
    }
    if (browser.indexOf("chrome") != -1) {
        return "chrome";
    }
    if (browser.indexOf("safari") != -1) {
        return "safari";
    }
    add_message("warn","Unknown Browser: Functionality may be impaired!\n\n" +browser);
    return browser;
}
function saveFile(fileName,content) {
    var a = document.createElement("a");
    document.body.appendChild(a);
    a.style.display = "none";
    var blob = new Blob([content], {type: "text/plain"});
    var browser = detectBorwser();
    if (browser != "edge") {
            var url = window.URL.createObjectURL(blob);
            a.href = url;
            a.download = fileName;
            a.click();
            window.URL.revokeObjectURL(url);
    } else {
        window.navigator.msSaveBlob(blob, fileName);
    }
    return;
};

// Functions to load the sequence and settings files
function initLoadSeqFile() {
  var pButton = document.getElementById('P3P_SELECT_SEQ_FILE');
  if (pButton !== null) {
    pButton.addEventListener('change', runLoadSeqFile, false);
  }
}
function runLoadSeqFile(f) {
  var file = f.target.files[0];
  if (file) { // && file.type.match("text/*")) {
    var reader = new FileReader();
    reader.onload = function(event) {
      var txt = event.target.result;
      loadSeqFile(txt);
    }
    reader.readAsText(file);
    document.getElementById("P3P_SELECT_SEQ_FILE").value = "";
  } else {
    add_message("err","Error opening file");
  }
}
function loadSeqFile(txt) {
  txt = txt.replace(/\r\n/g, "\n");
  txt = txt.replace(/\r/g, "\n");
  txt = txt.replace(/^\s*/, "");
  var fileLines = txt.split('\n');
  var id = "";
  var seq = "";
  var message = "Primer3Plus loaded ";

  if (txt.match(/^>/) != null) {
    // Read Fasta
    id = fileLines[0].replace(/^>/, "");
    var add = true;
    for (var i = 1; i < fileLines.length; i++) {
      if ((fileLines[i].match(/^>/) == null) && (add == true)){
        seq += fileLines[i];
      } else {
        add = false;
      }
    }
    message += "Fasta file!";
  } else if (txt.match(/^\^\^/) != null) {
    // Read SeqEdit (not tested!)
    seq = txt.replace(/^\^\^/, "");
    message += "SeqEdit file!";
  } else if ((txt.match(/ORIGIN/) != null) && (txt.match(/LOCUS/) != null)) {
    // Read GeneBank
    var add = false;
    for (var i = 0; i < fileLines.length; i++) {
      if (fileLines[i].match(/^DEFINITION/) != null) {
        id = fileLines[i].replace(/^DEFINITION/, "");
      } else if (fileLines[i].match(/^ORIGIN/) != null) {
        add = true;
      } else if (fileLines[i].match(/^\/\//) != null) {
        add = false;
      } else if (add == true) {
        seq += fileLines[i].replace(/\d+/g, "");
      }
    }
    message += "GeneBank file!";
  } else if ((txt.match(/Sequence/) != null) && (txt.match(/SQ/) != null)) {
    // Read EMBL
    var add = false;
    for (var i = 0; i < fileLines.length; i++) {
      if (fileLines[i].match(/^DE/) != null) {
        id = fileLines[i].replace(/^DE/, "");
      } else if (fileLines[i].match(/^SQ/) != null) {
        add = true;
      } else if (fileLines[i].match(/^\/\//) != null) {
        add = false; 
      } else if (add == true) {
        seq += fileLines[i].replace(/\d+/g, "");
      }
    }
    message += "EMBL file!";
  } else if ((txt.match(/Primer3 File/) != null) || (txt.match(/\n=\n/) != null)) {
    // Read Primer3Plus and Primer3
    loadP3File("file",txt);
    return;
  } else {
    // Read file plain txt
    seq = txt;
    message += "file as plain text!";
  }
  // cleanup input
  id = id.replace(/^\s+/g, "");
  setHtmlTagValue("SEQUENCE_ID",id);
  seq = seq.replace(/\d+/g, "");
  seq = seq.replace(/\W+/g, "");
  setHtmlTagValue("SEQUENCE_TEMPLATE", seq);
  del_all_messages();
  add_message("mess",message);
}
function initLoadSetFile() {
  var pButton = document.getElementById('P3P_SELECT_SETTINGS_FILE');
  if (pButton !== null) {
    pButton.addEventListener('change', runLoadSetFile, false);
  }
}
function runLoadSetFile(f) {
  var file = f.target.files[0];
  if (file) { // && file.type.match("text/*")) {
    var reader = new FileReader();
    reader.onload = function(event) {
      var txt = event.target.result;
      loadP3File("set", txt);
    }
    reader.readAsText(file);
    document.getElementById("P3P_SELECT_SETTINGS_FILE").value = "";
  } else {
    add_message("err","Error opening file");
  }
}
function loadP3File(limit,txt) {
  txt = txt.replace(/\r\n/g, "\n");
  txt = txt.replace(/\r/g, "\n");
  txt = txt.replace(/^\s*/, "");
  var fileLines = txt.split('\n');
  var sel;
  var message = "Primer3Plus loaded ";
  if (limit == "file") {
    if (txt.match(/P3_FILE_TYPE=sequence/) != null) {
      sel = "seq";
      message += "sequence information from Primer3Plus file";    
    } else if (txt.match(/P3_FILE_TYPE=settings/) != null) {
      sel = "set";
      message += "settings information from Primer3Plus file";
    } else {
      sel = "all";
      message += "all information from Primer3Plus file";
    }
  } else {
    sel = limit;
  }
  var fileId = "";
  for (var i = 0; i < fileLines.length; i++) {
    if ((fileLines[i].match(/=/) != null) && (fileLines[i] != "") && (fileLines[i] != "=")) {
      var pair = fileLines[i].split('=');
      if ((pair.length > 1) && (defSet.hasOwnProperty(pair[0]))){
        if (pair[0].startsWith('P3_FILE_ID')) {
          fileId = pair[1];
        }
        if (sel == "seq") {
          if (pair[0].startsWith("SEQUENCE_")) {
            setHtmlTagValue(pair[0], pair[1]);
          }
        } else if (sel == "set") {
          if (pair[0].startsWith("PRIMER_") || pair[0].startsWith("P3P_")) {
            setHtmlTagValue(pair[0], pair[1]);
          }
        } else {
          setHtmlTagValue(pair[0], pair[1]);
        }
      } else {
	if (!(pair[0].startsWith('P3_FILE_TYPE'))) {
          add_message("warn","Primer3Plus is unable to load: " + fileLines[i]);
        }
      }
    }
  }
  if (fileId != "") {
    message += ": " + fileId + "!";
  } else {
    message += "!";
  }
  del_all_messages();
  add_message("mess",message);
}
// Functions to load the sequence and settings files
function initSaveFile() {
  var pButtonSeq = document.getElementById('P3P_ACTION_SEQUENCE_SAVE');
  if (pButtonSeq !== null) {
    pButtonSeq.addEventListener('click', function(){runSaveFile('seq','Primer3plus_Sequence.txt');});
  }
  var pButtonSet = document.getElementById('P3P_ACTION_SETTINGS_SAVE');
  if (pButtonSet !== null) {
    pButtonSet.addEventListener('click', function(){runSaveFile('set','Primer3plus_Settings.txt');});
  }
  var pButtonAll = document.getElementById('P3P_ACTION_ALL_SAVE');
  if (pButtonAll !== null) {
    pButtonAll.addEventListener('click', function(){runSaveFile('all','Primer3plus_Complete.txt');});
  }
  var pButtonP3 = document.getElementById('P3P_ACTION_ALL_P3_SAVE');
  if (pButtonP3 !== null) {
    pButtonP3.addEventListener('click', function(){runSaveFile('primer3','Primer3_Input.txt');});
  }
}

function runSaveFile(sel, fileName) {
  var con = createSaveFileString(sel);
  saveFile(fileName,con);
}

// This function creates the files to save 
// and the Primer3 input file!!
function createSaveFileString(sel) {
  var usedTags = [];
  var wValues = {};
  var ret = "";
  // Extract the used tags with values
  for (var tag in defSet) {
    if (defSet.hasOwnProperty(tag)) {
      var val = getHtmlTagValue(tag);
      if (val != null) {
	if (((sel == "seq") && tag.startsWith("SEQUENCE_")) ||
	    ((sel == "set") && tag.startsWith("PRIMER_")) ||
            ((sel == "set") && tag.startsWith("P3P_")) ||
            ((sel == "all")) ||
            ((sel == "primer3") && !(tag.startsWith("P3P_")))) {
          usedTags.push(tag);
          wValues[tag] = val;
        }
      }
    }
  }
  // Write the headers
  if (sel != "primer3") {
    ret += "Primer3 File - http://primer3.org\n";
  }  
  if (sel == "seq") {
    ret += "P3_FILE_TYPE=sequence\n\nP3_FILE_ID=User sequence\n";
  }  
  if (sel == "set") {
    ret += "P3_FILE_TYPE=settings\n\nP3_FILE_ID=User settings\n";
  }  
  if (sel == "all") {
    ret += "P3_FILE_TYPE=all\nP3_FILE_ID=User data\n";
  }  

  //Print the array data
  usedTags.sort();
  for (var i = 0; i < usedTags.length; i++) {
    ret += usedTags[i] + "=" + wValues[usedTags[i]] + "\n"; 
  }

  // Add the lonley "=" for Primer3
  if (sel == "primer3") {
    ret += "=\n";
  }
  return ret;
}

// Explain sequence Regions help functionality
function initExplainSeqRegions() { 
  var btExcluded = document.getElementById('P3P_ACTION_SEL_EXCLUDED');
  if (btExcluded === null) {
    return;
  }
  var btTarget = document.getElementById('P3P_ACTION_SEL_TARGET');
  if (btTarget === null) {
    return;
  }
  var btIncluded = document.getElementById('P3P_ACTION_SEL_INCLUDED');
  if (btIncluded === null) {
    return;
  }
  var hlpExcluded = document.getElementById('SEQUENCE_EXCLUDED_REGION_HELP');
  if (hlpExcluded === null) {
    return;
  }
  var hlpTarget = document.getElementById('SEQUENCE_TARGET_HELP');
  if (hlpTarget === null) {
    return;
  }
  var hlpIncluded = document.getElementById('SEQUENCE_INCLUDED_REGION_HELP');
  if (hlpIncluded === null) {
    return;
  }
  var hlpOverlap = document.getElementById('SEQUENCE_OVERLAP_JUNCTION_LIST_HELP');
  if (hlpOverlap === null) {
    return;
  }
  var hlpOkList = document.getElementById('SEQUENCE_PRIMER_PAIR_OK_REGION_LIST_HELP');
  if (hlpOkList === null) {
    return;
  }
  var exExcluded = document.getElementById('P3P_SEQ_EXPLAIN_EXCLUDED');
  if (exExcluded === null) {
    return;
  }
  var exTarget = document.getElementById('P3P_SEQ_EXPLAIN_TARGET');
  if (exTarget === null) {
    return;
  }
  var exIncluded = document.getElementById('P3P_SEQ_EXPLAIN_INCLUDED');
  if (exIncluded === null) {
    return;
  }
  var exOverlap = document.getElementById('P3P_SEQ_EXPLAIN_OVERLAP');
  if (exOverlap === null) {
    return;
  }
  var exOkList = document.getElementById('P3P_SEQ_EXPLAIN_OK_LIST');
  if (exOkList === null) {
    return;
  }
  btExcluded.addEventListener('mouseover', function(){showExplainSeqRegions(exExcluded)});
  btExcluded.addEventListener('mouseout', function(){hideExplainSeqRegions()});
  hlpExcluded.addEventListener('mouseover', function(){showExplainSeqRegions(exExcluded)});
  hlpExcluded.addEventListener('mouseout', function(){hideExplainSeqRegions()});
  btTarget.addEventListener('mouseover', function(){showExplainSeqRegions(exTarget)});
  btTarget.addEventListener('mouseout', function(){hideExplainSeqRegions()});
  hlpTarget.addEventListener('mouseover', function(){showExplainSeqRegions(exTarget)});
  hlpTarget.addEventListener('mouseout', function(){hideExplainSeqRegions()});
  btIncluded.addEventListener('mouseover', function(){showExplainSeqRegions(exIncluded)});
  btIncluded.addEventListener('mouseout', function(){hideExplainSeqRegions()});
  hlpIncluded.addEventListener('mouseover', function(){showExplainSeqRegions(exIncluded)});
  hlpIncluded.addEventListener('mouseout', function(){hideExplainSeqRegions()});
  hlpOverlap.addEventListener('mouseover', function(){showExplainSeqRegions(exOverlap)});
  hlpOverlap.addEventListener('mouseout', function(){hideExplainSeqRegions()});
  hlpOkList.addEventListener('mouseover', function(){showExplainSeqRegions(exOkList)});
  hlpOkList.addEventListener('mouseout', function(){hideExplainSeqRegions()});
}
function showExplainSeqRegions(elem) {
  hideExplainSeqRegions();
  elem.style.display = "inline";
}
function hideExplainSeqRegions() {
  document.getElementById('P3P_SEQ_EXPLAIN_EXCLUDED').style.display = "none";
  document.getElementById('P3P_SEQ_EXPLAIN_TARGET').style.display = "none";
  document.getElementById('P3P_SEQ_EXPLAIN_INCLUDED').style.display = "none";
  document.getElementById('P3P_SEQ_EXPLAIN_OVERLAP').style.display = "none";
  document.getElementById('P3P_SEQ_EXPLAIN_OK_LIST').style.display = "none";
}

// Functions for tab functionality
function initTabFunctionality() {
  var btMain = document.getElementById('P3P_SEL_TAB_MAIN');
  if (btMain === null) {
    return;
  }
  var btGeneralSet = document.getElementById('P3P_SEL_TAB_GENERAL_SETTINGS');
  if (btGeneralSet === null) {
    return;
  }
  var btAdvanced = document.getElementById('P3P_SEL_TAB_ADVANCED_PRI');
  if (btAdvanced === null) {
    return;
  }
  var btInternal = document.getElementById('P3P_SEL_TAB_INTERNAL');
  if (btInternal === null) {
    return;
  }
  var btPenalties = document.getElementById('P3P_SEL_TAB_PENALTIES');
  if (btPenalties === null) {
    return;
  }
  var btAdvancedSeq = document.getElementById('P3P_SEL_TAB_ADVANCED_SEQ');
  if (btAdvancedSeq === null) {
    return;
  }
  var btResults = document.getElementById('P3P_SEL_TAB_RESULTS');
  if (btResults === null) {
    return;
  }
  var tabMain = document.getElementById('P3P_TAB_MAIN');
  if (tabMain === null) {
    return;
  }
  var tabGeneralSet = document.getElementById('P3P_TAB_GENERAL_SETTINGS');
  if (tabGeneralSet === null) {
    return;
  }
  var tabAdvanced = document.getElementById('P3P_TAB_ADVANCED_PRI');
  if (tabAdvanced === null) {
    return;
  }
  var tabInternal = document.getElementById('P3P_TAB_INTERNAL_OLIGO');
  if (tabInternal === null) {
    return;
  }
  var tabPenalties = document.getElementById('P3P_TAB_PENALTIES');
  if (tabPenalties === null) {
    return;
  }
  var tabAdvancedSeq = document.getElementById('P3P_TAB_ADVANCED_SEQUENCE');
  if (tabAdvancedSeq === null) {
    return;
  }
  var tabResults = document.getElementById('P3P_TAB_RESULTS');
  if (tabResults === null) {
    return;
  }
  btMain.addEventListener('click', function(){browseTabFunctionality('P3P_TAB_MAIN');});
  btGeneralSet.addEventListener('click', function(){browseTabFunctionality('P3P_TAB_GENERAL_SETTINGS');});
  btAdvanced.addEventListener('click', function(){browseTabFunctionality('P3P_TAB_ADVANCED_PRI');});
  btInternal.addEventListener('click', function(){browseTabFunctionality('P3P_TAB_INTERNAL_OLIGO');});
  btPenalties.addEventListener('click', function(){browseTabFunctionality('P3P_TAB_PENALTIES');});
  btAdvancedSeq.addEventListener('click', function(){browseTabFunctionality('P3P_TAB_ADVANCED_SEQUENCE');});
  btResults.addEventListener('click', function(){browseTabFunctionality('P3P_TAB_RESULTS');});
	
  browseTabFunctionality('P3P_TAB_MAIN');
}
function browseTabFunctionality(tab) {
  browseTabSelect(tab,'P3P_SEL_TAB_MAIN','P3P_TAB_MAIN');
  browseTabSelect(tab,'P3P_SEL_TAB_GENERAL_SETTINGS','P3P_TAB_GENERAL_SETTINGS');
  browseTabSelect(tab,'P3P_SEL_TAB_ADVANCED_PRI','P3P_TAB_ADVANCED_PRI');
  browseTabSelect(tab,'P3P_SEL_TAB_INTERNAL','P3P_TAB_INTERNAL_OLIGO');
  browseTabSelect(tab,'P3P_SEL_TAB_PENALTIES','P3P_TAB_PENALTIES');
  browseTabSelect(tab,'P3P_SEL_TAB_ADVANCED_SEQ','P3P_TAB_ADVANCED_SEQUENCE');
  browseTabSelect(tab,'P3P_SEL_TAB_RESULTS','P3P_TAB_RESULTS');
}
function browseTabSelect(sel,btn,tab) {
  var button = document.getElementById(btn);
  var tabField = document.getElementById(tab);
  if (sel == tab) {
    button.style.background="rgb(255, 255, 230)";
    button.style.position="relative";
    button.style.top="2px";
    button.style.zIndex="1";
    tabField.style.display="inline";
  } else {
    button.style.background="white";
//    button.style.position="relative";
    button.style.top="0";
    button.style.zIndex="0";
    tabField.style.display="none";
  }
}

// Get the task selection right
function initTaskFunctionality() {
  var task = document.getElementById('PRIMER_TASK');
  if (task === null) {
    return;
  }
  var btn = document.getElementById('P3P_SEL_REG_ALL_BT');
  if (btn === null) {
    return;
  }
  var inp = document.getElementById('P3P_SEL_REG_ALL_IN');
  if (inp === null) {
    return;
  }
  task.addEventListener('change', showTaskSelection);
  task.addEventListener('keyup', showTaskSelection);
  showTaskSelection();
}
var prevSelectedTab = "";
function showTaskSelection() {
  var task = document.getElementById('PRIMER_TASK');
  var x = task.selectedIndex;
  var id = "P3P_EXPLAIN_TASK_" + task.options[x].text.toUpperCase();
  if (prevSelectedTab != "" && document.getElementById(prevSelectedTab)) {
    document.getElementById(prevSelectedTab).style.display="none"; 
  }
  if (id != "" && document.getElementById(id)) {
    prevSelectedTab = id;
    document.getElementById(id).style.display="inline";
    document.getElementById("P3P_ACTION_RUN_PRIMER3").value = "Pick Primers";	  
    if (id == "P3P_EXPLAIN_TASK_CHECK_PRIMERS") {
      setTaskSelection(false,false,false,false,false,false,true);
      document.getElementById("P3P_ACTION_RUN_PRIMER3").value = "Check Primer";
    } else if (id == "P3P_EXPLAIN_TASK_GENERIC") {
      setTaskSelection(true,true,true,true,true,true,true);
    } else if (id == "P3P_EXPLAIN_TASK_PICK_SEQUENCING_PRIMERS") {
      setTaskSelection(true,false,true,false,false,false,false);
    } else if (id == "P3P_EXPLAIN_TASK_PICK_CLONING_PRIMERS") {
      setTaskSelection(true,false,false,true,false,false,false);
    } else if (id == "P3P_EXPLAIN_TASK_PICK_DISCRIMINATIVE_PRIMERS") {
      setTaskSelection(true,false,true,false,false,false,false);
    } else if (id == "P3P_EXPLAIN_TASK_PICK_PRIMER_LIST") {
      setTaskSelection(true,true,true,true,true,true,false);
    }
  }
}
//                            1          2            3            4            5           6           7
function setTaskSelection(allState,excludedState,targetState,includedState,overlapState,okPairState,pickwhichState) {
  if(allState) {
    document.getElementById("P3P_SEL_REG_ALL_BT").style.display="table";
    document.getElementById("P3P_SEL_REG_ALL_IN").style.display="table";
  } else {
    document.getElementById("P3P_SEL_REG_ALL_BT").style.display="none";
    document.getElementById("P3P_SEL_REG_ALL_IN").style.display="none";
  }
  if(excludedState) {
    document.getElementById("P3P_ACTION_SEL_EXCLUDED").style.visibility="visible";
    document.getElementById("P3P_VIS_EXCLUDED_BOX").style.visibility="visible";
  } else {
    document.getElementById("P3P_ACTION_SEL_EXCLUDED").style.visibility="hidden";
    document.getElementById("P3P_VIS_EXCLUDED_BOX").style.visibility="hidden";
  }
  if(targetState) {
    document.getElementById("P3P_ACTION_SEL_TARGET").style.visibility="visible";
    document.getElementById("P3P_VIS_TARGET_BOX").style.visibility="visible";
  } else {
    document.getElementById("P3P_ACTION_SEL_TARGET").style.visibility="hidden";
    document.getElementById("P3P_VIS_TARGET_BOX").style.visibility="hidden";
  }
  if(includedState) {
    document.getElementById("P3P_ACTION_SEL_INCLUDED").style.visibility="visible";
    document.getElementById("P3P_VIS_INCLUDED_BOX").style.visibility="visible";
  } else {
    document.getElementById("P3P_ACTION_SEL_INCLUDED").style.visibility="hidden";
    document.getElementById("P3P_VIS_INCLUDED_BOX").style.visibility="hidden";
  }
  if(overlapState) {
    document.getElementById("P3P_VIS_OVERLAP_BOX").style.visibility="visible";
  } else {
    document.getElementById("P3P_VIS_OVERLAP_BOX").style.visibility="hidden";
  }
  if(okPairState) {
    document.getElementById("P3P_VIS_PAIR_OK_BOX").style.visibility="visible";
  } else {
    document.getElementById("P3P_VIS_PAIR_OK_BOX").style.visibility="hidden";
  }
  if(pickwhichState){
    document.getElementById("P3P_VIS_PRIMER_EXPLAIN").style.display="table-row";
    document.getElementById("P3P_VIS_PRIMER_BOXES").style.display="table-row";
  } else {
    document.getElementById("P3P_VIS_PRIMER_EXPLAIN").style.display="none";
    document.getElementById("P3P_VIS_PRIMER_BOXES").style.display="none";
  }
}

function initResetDefautl() { 
  var pButton = document.getElementById('P3P_ACTION_RESET_DEFAULT');
  if (pButton !== null) {
    pButton.addEventListener('click', buttonResetDefault);
  }
}
function buttonResetDefault() {
  del_all_messages ();	
  setHTMLParameters(defSet);
  add_message("mess","Default settings loaded!");
}

function initLoadExample() {
  var pButton = document.getElementById('P3P_ACTION_LOAD_EXAMPLE');
  if (pButton !== null) {
    pButton.addEventListener('click', runLoadExample);
  }
}
function runLoadExample() {
  var seq = 'acaatattgtattggtgagatcatataagatttgatgtcaacatcttcgtaaaggtctcagatt' +
    'cgattctccccggtatcaatttaagtgagctaatttagcttcttaaaaaataaaatcaaacaacttttacataaactca' +
    'gtgaaaacttggatataaagtatccttatactactctttagtcttgattagtctctgcaaagatatttatatgtacttt' +
    'gtattatcataagaacattcattgacattttaagttaatgaattactaacatgtcaactcttattctagccaacagtta' +
    'ctttgttccctccacattctctttgaaatagtcaaacgtatccaatcatgcatgtctgttctgatcataacagcaaaag' +
    'catgtgtatagaaaattgatagttgaattagagtcattttccataaaaaaatattcaataagtgtgacattatttttcg' +
    'tatgaattaatccattttttgctgatttgagattctttctttctttgcttcttgctttccttcatcagccatttttttt' +
    'gttttctctttctctctctcttcttgattcaatgaatctcaaaaatggattactattgttcattctgtttctggattgt' +
    'gtttttttcaaagttgaatccaaatgtgtaaaagggtgtgatgtagctttagcttcctactatattataccatcaattc' +
    'aactcagaaatatatcaaactttatgcaatcaaagattgttcttaccaattcctttgatgttataatgagctacaatag' +
    'agacgtagtattcgataaatctggtcttatttcctatactagaatcaacgttccgttcccatgtgaatgtattggaggt' +
    'gaatttctaggacatgtgtttgaatatacaacaaaagaaggagacgattatgatttaattgcaaatacttattacgcaa' +
    'gtttgacaactgttgagttattgaaaaagttcaacagctatgatccaaatcatatacctgttaaggctaagattaatgt' +
    'cactgtaatttgttcatgtgggaatagccagatttcaaaagattatggcttgtttgttacctatccactcaggtctgat' +
    'gatactcttgcgaaaattgcgaccaaagctggtcttgatgaagggttgatacaaaatttcaatcaagatgccaatttca' +
    'gcataggaagtgggatagtgttcattccaggaagaggtatgtattttctcattttctgccaactgtggttggcacagat' +
    'ggtttgaacttctgtcacatccgttgtaactttgataagtctgaaattccgcagtttgtagattactggtaaattccat' +
    'tataaatgtttaatgtgatttggtgattcttatcaaaagtacttgtataagtatgcgagttagataaaaaaaattatga' +
    'ccatcttgttctcgtggaaatggactctgataattcataaagtctagccagtgattgtaacaaccaggctttgaacttg' +
    'gtacttccaatcaacttgaccttcaccagacctcattgaccacttgagtcgaaccctttaatttcagttagagtatatt' +
    'taaatgctaagttactctattatttttcaaagtatatacatggtataaattttgaagttttatgtagttattgtttact' +
    'ttgcagatcaaaatggacatttttttcctttgtattctaggtaagtaacattgattatctcaattttcatttttgaatg' +
    'atttatagaagaagtaaatattgcttcatataatttggttatatttttctaactttcattttctttttatttttccatt' +
    'cttgcagaacaggtttgtcttttgctattaagatgattatttgttagcttgttcacaaaaatatgagaatggacaaaag' +
    'gtcaatgcttcctgtgagcttaaatttggttcaatataagcaggtattgctaagggttcagctgttggtatagctatgg' +
    'caggaatatttggacttctattatttgttatctatatatatgccaaatacttccaaaagaaggaagaagagaaaactaa' +
    'acttccacaaacttctagggcattttcaactcaagatggtaatatttttaaacattcatattctaagttcttattaaaa' +
    'atatttcttttaacctatcttatgatataagtatttatttcagtatttgagagagcttgcgaaaatagcttataacatg' +
    'tttgtttcattaaactgtatttatttcattaaatagtttatacttgctgatttttgtttatgttattggtgaagcctca' +
    'ggtagtgcagaatatgaaacttcaggatccagtgggcatgctactggtagtgctgccggccttacaggcattatggtgg' +
    'caaagtcgacagagtttacgtatcaagaattagccaaggcgacaaataatttcagcttggataataaaattggtcaagg' +
    'tggatttggagctgtctattatgcagaacttagaggcgaggtacgaaactacatgaatttgtttaatagagtgtacttt' +
    'gattttagttttgaacaagttctataaaatattttcaaaaaacttttattttttgtcataacttggaaagaaagtaaag' +
    'ccatttttttttccttcacgttttcattgatttcctctcatgcaacttattgtatgcagaaaacagcaattaagaagat' +
    'ggatgtacaagcatcgtccgaatttctctgtgagttgaaggtcttaacacatgttcatcacttgaatctggtataccat' +
    'ccttttaaaaatcttaagccatatataatatatttaggagatataatcatttatttttatatatggtttgaagaatcat' +
    'cgtttaactacaaagcaaataaccagtgttagttttgagaacataagaactctataactatcaagcaaaacataatctg' +
    'tagtagctgtttacaattatctgtcctacacagttagcgaataatttgaaacacactgcagaacattatttgtatgtac' +
    'ttcttgattttgtacatgtttgtatactttttgtataatcagttttgtatttgttctagatattactctgaatttgcct' +
    'aaattttatgaacaatgtaggtgcggttgattggatattgcgttgaagggtcacttttcctcgtatatgaacatattga' +
    'caatggaaacttgggtcaatatttacatggtataggtaagattaacaaaaatgtgctaatatttttatgtgattttaca' +
    'atattgtcaaacagtcattaatgatggttagatgatttcaggtacagaaccattaccatggtctagtagagtgcagatt' +
    'gctctagattcagccagaggcctagaatacattcatgaacacactgtgcctgtttatatccatcgcgacgtaaaatcag' +
    'caaatatattgatagacaaaaatttgcgtggaaaggttgcaatttgaccaatcttaatgatctatattataaattttaa' +
    'tttatcacttcttcttttacattaattaactctatgaatggttttgaattcaggttgctgattttggcttgaccaaact' +
    'tattgaagttggaaactcgacacttcacactcgtcttgtgggaacatttggatacatgccaccagagtatgattcgttt' +
    'gtattaaattttgagtttaatattagtacaaaaagtacaacaaaaattcagtgattcattcacatttcacaatacatat' +
    'gtcactttgttatattataaaatgggatatgaccagatgattgtacaattttttttataacaaatgatatttgtataac' +
    'ccttttagtatgtccatggattataaactatcttcaactttcttaattgtagaaaacatgtttgtttattagctgtttt' +
    'ttttctctgttgcagatatgctcaatatggcgatgtttctccaaaaatagatgtatatgcttttggcgttgttctttat' +
    'gaacttattactgcaaagaatgctgtcctgaagacaggtgaatctgttgcagaatcaaagggtcttgtacaattggtag' +
    'gtctagataccatatttattaagaaaacactcatttcatgtatatttttagtaaaatatttttaagttagtaattatgt' +
    'acattttaaattcagtaaactgaatgcattcacttaaaccagaacaaaagttatccttgattattttgtattgcagttt' +
    'gaagaagcacttcatcgaatggatcctttagaaggtcttcgaaaattggtggatcctaggcttaaagaaaactatccca' +
    'ttgattctgttctcaaggtgggaagcattttttcttagcaaaaaattgaatgttatttctttttcttctcaatttgcat' +
    'tatataccaacaaaaaaaaaatgcatatttatgtggtatagcctttcaaatcattgtagtacataagcaaagttcatgt' +
    'tattaaaatataattaaatgtatgcaaaagtgtatagtttgtaaagttactaaactcatttgttttagcactagatttt' +
    'gtcattgaacataacttaagatatgtgaatatttgaattgcagatggctcaacttgggagagcatgtacgagagacaat' +
    'ccgctactacgcccaagcatgagatctatagttgttgctcttatgacactttcatcaccaactgaagattgtgatgatg' +
    'actcttcatatgaaaatcaatctctcataaatctgttgtcaactagatgaagattttgtgtgacaaattgaattgtgtt' +
    'tgttaaaacatgtagaaagcatacaacaaatggtttgtactttacttgtatatgaaatattgcagttggagagttttta' +
    'cttttcttacctcaattatccatcttgaacattgttttgtatgtggcaagagttcaaacactggtgtactcattgaaaa' +
    'gttatggtgagaaaatcactgatcagatgattcttgagaaagataatgagaactctgtcacc';
  setHTMLParameters(defSet);
  setHtmlTagValue("SEQUENCE_ID", "Medicago Lyk3");
  setHtmlTagValue("SEQUENCE_TEMPLATE", seq);
}

