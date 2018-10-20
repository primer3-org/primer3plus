const HELP_LINK_URL = ""; //process.env.HELP_LINK_URL

var p3p_errors = [];
var p3p_warnings = [];
var p3p_messages = [];

var primerData;

var showPrimer = 0;

var prevSelectedTab = "";

var sett = {
  "P3P_RDML_VERSION": "1.1",
  "P3P_PRIMER_NAME_ACRONYM_INTERNAL": "IN",
  "P3P_PRIMER_NAME_ACRONYM_LEFT": "F",
  "P3P_PRIMER_NAME_ACRONYM_RIGHT": "R",
  "P3P_PRIMER_NAME_ACRONYM_SPACER": "_"
};

var debugMode = 2;

document.addEventListener("DOMContentLoaded", function() {
  init_message_buttons();
  initTabFunctionality();
  initSettings();
  var clData = localStorage.getItem("P3M_ALL_DATA");
  if (clData === null) {
    primerData = [];
  } else {
    primerData = JSON.parse(clData);
  }
  updateList();
});

function saveToLocalStorage() {
  localStorage.setItem("P3M_ALL_DATA", JSON.stringify(primerData));
}

window.clearLocalStorage = clearLocalStorage;
function clearLocalStorage() {
  localStorage.clear();
  primerData = [];
  showPrimer = 0;
  updateList();
  browseTabFunctionality('P3P_TAB_MAIN');
}

window.movePairUp = movePairUp;
function movePairUp() {
  if (showPrimer > 0) {
    var ele = primerData[showPrimer - 1];
    primerData[showPrimer - 1] = primerData[showPrimer];
    primerData[showPrimer] = ele;
    showPrimer--;
    updateList();
    saveToLocalStorage();
  }
}

window.movePairDown = movePairDown;
function movePairDown() {
  if (showPrimer < primerData.length - 1) {
    var ele = primerData[showPrimer + 1];
    primerData[showPrimer + 1] = primerData[showPrimer];
    primerData[showPrimer] = ele;
    showPrimer++;
    updateList();
    saveToLocalStorage();
  }
}

window.deletePair = deletePair;
function deletePair() {
  if (primerData.length > 0) {
    primerData.splice(showPrimer, 1);
    if(showPrimer > 0) {
      showPrimer--;
    }
    updateList();
    saveToLocalStorage();
  }
}

function init_message_buttons() {
  var err = document.getElementById('P3P_ACTION_RESET_ERROR');
  if (err !== null) {
    err.addEventListener('click', function(){
      del_message("err");
      refresh_message("err");
    });
  }
  var warn = document.getElementById('P3P_ACTION_RESET_WARNING');
  if (warn !== null) {
    warn.addEventListener('click', function(){
      del_message("warn");
      refresh_message("warn");
    });
  }
  var mess = document.getElementById('P3P_ACTION_RESET_MESSAGE');
  if (mess !== null) {
    mess.addEventListener('click', function(){
      del_message("mess");
      refresh_message("mess");
    });
  }
}
function del_all_messages() {
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
  var arr = null;
  if (level == "err") {
    arr = p3p_errors;
  }
  if (level == "warn") {
    arr = p3p_warnings;
  }
  if (level == "mess") {
    arr = p3p_messages;
  }
  if (arr == null) {
    return;
  }
  arr.push(message);
  refresh_message(level);
}
function refresh_message(level) {
  var el = null;
  var box = null;
  var arr = null;
  if (level == "err") {
    el = document.getElementById('P3P_TOP_MESSAGE_ERROR');
    box = document.getElementById('P3P_TOP_MESSAGE_ERROR_BOX');
    arr = p3p_errors;
  }
  if (level == "warn") {
    el = document.getElementById('P3P_TOP_MESSAGE_WARNING');
    box = document.getElementById('P3P_TOP_MESSAGE_WARNING_BOX');
    arr = p3p_warnings;  
  }
  if (level == "mess") {
    el = document.getElementById('P3P_TOP_MESSAGE_MESSAGE');
    box = document.getElementById('P3P_TOP_MESSAGE_MESSAGE_BOX');
    arr = p3p_messages;	  
  }
  if ((arr === null) || (box == null) || (el == null)) {
    return;
  }
  if (arr.length == 0) {
    box.innerHTML = "\n";
    el.style.display="none";
  } else {
    var txt = "";
    for (var i = 0; i < arr.length; i++) {
      txt += arr[i] + "<br />";
    }
    box.innerHTML = txt;
    el.style.display="inline";
  }
}

// Functions for tab functionality
function initTabFunctionality() {
  var btMain = document.getElementById('P3P_SEL_TAB_MAIN');
  if (btMain === null) {
    return;
  }
  var btOrder = document.getElementById('P3P_SEL_TAB_ORDER');
  if (btOrder === null) {
    return;
  }
  var btSet = document.getElementById('P3P_SEL_TAB_SETTINGS');
  if (btSet === null) {
    return;
  }
  var tabMain = document.getElementById('P3P_TAB_MAIN');
  if (tabMain === null) {
    return;
  }
  var tabOrder = document.getElementById('P3P_TAB_ORDER');
  if (tabOrder === null) {
    return;
  }
  var tabGeneralSet = document.getElementById('P3P_TAB_SETTINGS');
  if (tabGeneralSet === null) {
    return;
  }
  btMain.addEventListener('click', function(){browseTabFunctionality('P3P_TAB_MAIN');});
  btOrder.addEventListener('click', function(){browseTabFunctionality('P3P_TAB_ORDER');});
  btSet.addEventListener('click', function(){browseTabFunctionality('P3P_TAB_SETTINGS');});
  browseTabFunctionality('P3P_TAB_MAIN');
}
function browseTabFunctionality(tab) {
  browseTabSelect(tab,'P3P_SEL_TAB_MAIN','P3P_TAB_MAIN');
  browseTabSelect(tab,'P3P_SEL_TAB_ORDER','P3P_TAB_ORDER');
  browseTabSelect(tab,'P3P_SEL_TAB_SETTINGS','P3P_TAB_SETTINGS');
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

function initSettings() {
  getSettings("P3P_RDML_VERSION");
  getSettings("P3P_PRIMER_NAME_ACRONYM_INTERNAL");
  getSettings("P3P_PRIMER_NAME_ACRONYM_LEFT");
  getSettings("P3P_PRIMER_NAME_ACRONYM_RIGHT");
  getSettings("P3P_PRIMER_NAME_ACRONYM_SPACER");
}

window.resetSettings = resetSettings;
function resetSettings(elem) {
  setSettings("P3P_RDML_VERSION", sett["P3P_RDML_VERSION"]);
  setSettings("P3P_PRIMER_NAME_ACRONYM_INTERNAL", sett["P3P_PRIMER_NAME_ACRONYM_INTERNAL"]);
  setSettings("P3P_PRIMER_NAME_ACRONYM_LEFT", sett["P3P_PRIMER_NAME_ACRONYM_LEFT"]);
  setSettings("P3P_PRIMER_NAME_ACRONYM_RIGHT", sett["P3P_PRIMER_NAME_ACRONYM_RIGHT"]);
  setSettings("P3P_PRIMER_NAME_ACRONYM_SPACER", sett["P3P_PRIMER_NAME_ACRONYM_SPACER"]);
}

function getSettings(tag) {
  if (localStorage.getItem(tag)) {
    setHtmlTagValue(tag, localStorage.getItem(tag));
  } else {
    setHtmlTagValue(tag, sett[tag]);
  }
}

function setSettings(tag, value) {
  setHtmlTagValue(tag, value);
  localStorage.setItem(tag, value);
}

window.changeSettings = changeSettings;
function changeSettings(elem) {
  localStorage.setItem(elem.id, getHtmlTagValue(elem.id))
}

function updateList() {
  retHTML  = '<table style="border: 0; width: 100%; empty-cells: show; table-layout: fixed;">\n';
  retHTML += '  <colgroup>\n';
  retHTML += '    <col width="3%">\n';
  retHTML += '    <col width="22%">\n';
  retHTML += '    <col width="35%">\n';
  retHTML += '    <col width="20%">\n';
  retHTML += '    <col width="20%">\n';
  retHTML += '  </colgroup>\n';
  retHTML += '  <tr>\n';
  retHTML += '    <td><strong>Sel</strong></td>\n';
  retHTML += '    <td><strong>Name</strong></td>\n';
  retHTML += '    <td><strong>Description</strong></td>\n';
  retHTML += '    <td><strong>Forward Primer</strong></td>\n';
  retHTML += '    <td><strong>Reverse Primer</strong></td>\n';
  retHTML += '  </tr>\n';

  for (var i = 0 ; i < primerData.length ; i++) {
    retHTML += '  <tr>\n';
    retHTML += '    <td><input onchange="changeSelectedBox(' + i + ',this);"';
    if (primerData[i].hasOwnProperty('selected') &&
        (primerData[i]['selected'] == "1")) {
      retHTML += "checked=\"checked\" ";
    }
    retHTML += 'type="checkbox"></td>\n';
    retHTML += makeCell(i, 'id')
    retHTML += makeCell(i, 'description')
    retHTML += makeCell(i, 'forwardPrimer')
    retHTML += makeCell(i, 'reversePrimer')
    retHTML += '  </tr>\n';
  }
  retHTML += '</table>\n';
  window.frames['P3M_LIST'].document.body.innerHTML = retHTML;
  updateOrderList();
  updateSelectedPrimer();	
}

function makeCell(count,tag) {
  var retHTML = '    <td onclick="setActivePrimer(' + count + ');">'
  if (primerData[count].hasOwnProperty(tag)) {
    retHTML += primerData[count][tag];
  }
  retHTML += '</td>\n';
  return retHTML;
}

window.frames['P3M_LIST'].setActivePrimer = setActivePrimer;
function setActivePrimer(count) {
  showPrimer = count;
  updateSelectedPrimer();
}

window.frames['P3M_LIST'].changeSelectedBox = changeSelectedBox;
function changeSelectedBox(count, elem) {
  if (primerData[count].hasOwnProperty('selected')) {
    if (elem.checked) {
      primerData[count]['selected'] = "1";
    } else {
      primerData[count]['selected'] = "0";
    }
  }
  updateOrderList();
  saveToLocalStorage();
}

window.changeOrderSelection = changeOrderSelection;
function changeOrderSelection() {
  if (document.getElementById('P3M_SELECT').checked) {
    primerData[showPrimer]['selected'] = "1";
  } else {
    primerData[showPrimer]['selected'] = "0";
  }
  updateList();
  saveToLocalStorage();
}

window.changeSelectedPair = changeSelectedPair;
function changeSelectedPair(elem, id) {
  var value = getHtmlTagValue(elem);
  if (value !== null) {
    primerData[showPrimer][id] = value;
    updateList();
    saveToLocalStorage();
  }
}

function updateOrderList() {
  var txtOrder = document.getElementById('P3M_ORDER_LIST');
  if (txtOrder === null) {
    return;
  }
  order = "";
  for (var i = 0 ; i < primerData.length ; i++) {
    if (primerData[i].hasOwnProperty('selected') &&
        (primerData[i]['selected'] == "1")) {
      var acSpace = getHtmlTagValue("P3P_PRIMER_NAME_ACRONYM_SPACER");
      var pName = primerData[i]['id'].replace(/\s/g, acSpace);
      if (primerData[i].hasOwnProperty('forwardPrimer') &&
          (primerData[i]['forwardPrimer'] != "")) {
	var toAdd = acSpace + getHtmlTagValue("P3P_PRIMER_NAME_ACRONYM_LEFT");
	if (pName.endsWith(toAdd)) {
          order += pName + " ";
	} else {
          order += pName + toAdd + " ";
	}
        order += primerData[i]['forwardPrimer'] + "\n";
      }
      if (primerData[i].hasOwnProperty('probe1') &&
          (primerData[i]['probe1'] != "")) {
        var toAdd = acSpace + getHtmlTagValue("P3P_PRIMER_NAME_ACRONYM_INTERNAL");
        if (pName.endsWith(toAdd)) {
          order += pName + " ";
        } else {
          order += pName + toAdd + " ";
        }
        order += primerData[i]['probe1'] + "\n";
      }
      if (primerData[i].hasOwnProperty('reversePrimer') &&
          (primerData[i]['reversePrimer'] != "")) {
        var toAdd = acSpace + getHtmlTagValue("P3P_PRIMER_NAME_ACRONYM_RIGHT");
        if (pName.endsWith(toAdd)) {
          order += pName + " ";
        } else {
          order += pName + toAdd + " ";
        }
        order += primerData[i]['reversePrimer'] + "\n";
      }
    }
  }
  txtOrder.value = order;
}

function updateSelectedPrimer() {
  if ((showPrimer < primerData.length) &&
      (primerData[showPrimer].hasOwnProperty('selected')) &&
      (primerData[showPrimer]['selected'] == "1")) {
    setHtmlTagValue('P3M_SELECT', "1");
  } else {
    setHtmlTagValue('P3M_SELECT', "0");
  }
  saveAdd(showPrimer, "P3M_NAME", 'id');
  saveAdd(showPrimer, "P3M_DESCRIPTION", 'description');
  saveAdd(showPrimer, "P3M_LEFT_SEQUENCE", 'forwardPrimer');
  saveAdd(showPrimer, "P3M_INTERNAL_SEQUENCE", 'probe1');
  saveAdd(showPrimer, "P3M_RIGHT_SEQUENCE", 'reversePrimer');
  saveAdd(showPrimer, "P3M_AMPLICON", 'amplicon');
  if ((showPrimer < primerData.length) &&
      (primerData[showPrimer].hasOwnProperty('amplicon')) &&
      (primerData[showPrimer]['amplicon'] != ""))  {
    var value = primerData[showPrimer]['forwardPrimer'] + primerData[showPrimer]['amplicon'];
    value += reverseComplement(primerData[showPrimer]['reversePrimer']);
    setHtmlTagValue('P3M_AMPLICON_CALC', value);
  }
}

function saveAdd(count, tag, id) {
  var value = "";
  if ((count < primerData.length) &&
      (primerData[count].hasOwnProperty(id)) &&
      (primerData[count][id] != ""))  {
    value = primerData[count][id];
  }
  setHtmlTagValue(tag, value);
}

function linkHelpTags() {
  var linkRoot =  ""; // `${HELP_LINK_URL}#`;
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

function getHtmlTagValue(tag) {
  var pageElement = document.getElementById(tag);
  if (pageElement !== null) {
    var tagName = pageElement.tagName.toLowerCase();
    if (tagName === 'textarea') {
      if (tag == "SEQUENCE_TEMPLATE") {
        return cleanSeq(pageElement.value);
      }
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
    }
    if (debugMode > 1) {
      add_message("warn","Unknown Type by " + tag + " get: " + pageElement.getAttribute('type'));
    }
  } else {
    if (debugMode > 1) {
      add_message("warn","Missing element by " + tag + " get!");
    }
  }
  return null;
}

function setHtmlTagValue(tag, value) {
  var pageElement = document.getElementById(tag);
  value = value.replace(/\s*$/, "");
  if (pageElement !== null) {
    var tagName = pageElement.tagName.toLowerCase();
    if (tagName === 'textarea') {
      pageElement.value = value;
      return true;
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
    }
    if (debugMode > 1) {
      add_message("warn","Unknown Type by " + tag + " set: " + pageElement.getAttribute('type'));
    }
  } else {
    if (debugMode > 1) {
      add_message("warn","Missing element by " + tag + " set!");
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
  currSet = {};	
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
  } else if (limit == "silent") {
    sel = "all";
  } else {
    sel = limit;
  }
  var fileId = "";
  for (var i = 0; i < fileLines.length; i++) {
    if ((fileLines[i].match(/=/) != null) && (fileLines[i] != "") && (fileLines[i] != "=")) {
      var pair = fileLines[i].split('=');
      if ((pair.length > 1) && (defSet.hasOwnProperty(pair[0]))){
        currSet[pair[0]] = pair[1];
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
  if (limit != "silent") {
    add_message("mess",message);
  }
  showTaskSelection();
}

function runSaveFile(sel, fileName) {
  var con = createSaveFileString(sel);
  saveFile(fileName,con);
}

function reverseComplement(seq){
  var revComp = "";
  for (var i = seq.length; i >= 0 ; i--) {
    switch (seq.charAt(i)) {
      case "a": revComp += "t";
        break;
      case "A": revComp += "T";
        break;
      case "c": revComp += "g";
        break;
      case "C": revComp += "G";
        break;
      case "g": revComp += "c";
        break;
      case "G": revComp += "C";
        break;
      case "t": revComp += "a";
        break;
      case "T": revComp += "A";
        break;
      case "n": revComp += "n";
        break;
      case "N": revComp += "N";
        break;
    }
  }
  return revComp;
}

