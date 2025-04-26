//  Copyright (C) 2006 - 2018 by Andreas Untergasser and Harm Nijveen
//  All rights reserved.
//
//  This file is part of Primer3Plus. Primer3Plus is a web interface to Primer3.
//
//  The Primer3Plus is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation; either version 3 of the License, or
//  (at your option) any later version.
//
//  Primer3Plus is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this Primer3Plus. If not, see <https://www.gnu.org/licenses/>.

const API_URL = process.env.API_URL
const HELP_LINK_URL = process.env.HELP_LINK_URL
const INDEX_LINK_URL = process.env.INDEX_LINK_URL

var primer3plus_version = "3.4.0";

// The default Settings loaded from the server
var defSet;
// "TAG":["default setting","data type"]

// The current loaded settings (dic)
var currSet = {};
var compFile1 = {};
var compFile2 = {};
var emptySeq = true;

// The old tags which need to be replaced by new tags
var repOld;
// "OLD TAG":"NEW TAG"

// The available server settings files
var server_setting_files;

// The available misspriming library files
var misspriming_lib_files;

var rawResults;
var results = {};

var amp_temp = [];
var amp_melt = [];
var amp_deriv = [];

var debugMode = 0;

var p3p_errors = [];
var p3p_warnings = [];
var p3p_messages = [];

window.gb_exons = "";

var selectedPrimerPair = 0;

var ignore_tags = ["PRIMER_EXPLAIN_FLAG","PRIMER_THERMODYNAMIC_PARAMETERS_PATH",
      "PRIMER_MIN_THREE_PRIME_DISTANCE","P3P_SERVER_SETTINGS_FILE",
      "PRIMER_MASK_3P_DIRECTION","PRIMER_MASK_5P_DIRECTION","PRIMER_MASK_FAILURE_RATE",
      "PRIMER_MASK_KMERLIST_PATH","PRIMER_MASK_KMERLIST_PREFIX","PRIMER_MASK_TEMPLATE",
      "PRIMER_WT_MASK_FAILURE_RATE"];

document.addEventListener("DOMContentLoaded", function() {
  const formData = new FormData();
  axios
    .post(`${API_URL}/defaultsettings`, formData)
    .then(res => {
        if (res.status === 200) {
          defSet = res.data["def"];
          repOld = res.data["replace"];
          server_setting_files = res.data["server_setting_files"];
          misspriming_lib_files = res.data["misspriming_lib_files"];
          setHTMLParameters(defSet);
          window.gb_exons = "";
          initElements();
          checkForUUID();
          showGenomeBrowserButtons();
      }
    })
    .catch(function (error) {
      if (error.response) {
        // The request was made and the server responded with a status code
        // that falls out of the range of 2xx
        let errorMessage = error.response.data.errors
          .map(error => error.title)
          .join('; ')
        add_message("err","Error loading default settings from server: " + errorMessage);
      } else if (error.request) {
        // The request was made but no response was received
        add_message("err","Error: No response from the server trying to load default settings from server.");
      } else {
        // Something happened in setting up the request that triggered an Error
        add_message("err","Error while setting up the request trying to load default settings from server: " + error.message);
      }
    });
});

function loadSetFileFromServer() {
  // Send different data to avoid caching
  var fileName = getHtmlTagValue("P3P_SERVER_SETTINGS_FILE");
  if ((fileName == "Default") || (!(fileName))) {
    setHTMLParameters(defSet);
    add_message("mess","Default settings loaded!");
    return;	  
  } else if (fileName == "None") {
    return;
  }
  const formData = new FormData();
  formData.append('P3P_SERVER_SETTINGS_FILE', fileName);
  axios
    .post(`${API_URL}/settingsFile`, formData)
    .then(res => {
        if (res.status === 200) {
          loadP3File("set", res.data);
          window.gb_exons = "";
          document.getElementById('P3P_DEBUG_TXT_INPUT').value = res.data;
          showGenomeBrowserButtons();
      }
    })
    .catch(function (error) {
      if (error.response) {
        // The request was made and the server responded with a status code
        // that falls out of the range of 2xx
        let errorMessage = error.response.data.errors
          .map(error => error.title)
          .join('; ')
        add_message("err","Error loading server settings file " + fileName + ": " + errorMessage);
      } else if (error.request) {
        // The request was made but no response was received
        add_message("err","Error: No response from the server trying to load server settings file " + fileName + ".");
      } else {
        // Something happened in setting up the request that triggered an Error
        add_message("err","Error while setting up the request trying to load server settings file " + fileName + ": " + error.message);
      }
    });
}

function runPrimer3() {
  cleanRegions();
  var seq = getHtmlTagValue("SEQUENCE_TEMPLATE");
  if (seq.length > 10000) {
    if (seq.length < 100000) {
      var incl = getHtmlTagValue("SEQUENCE_INCLUDED_REGION");
      if (incl == "") {
        add_message("err","Primer3Plus requires a sequence length or an INCLUDED_REGION of < 10000 bp.");
        return;
      }
      var incl_list = incl.split(',');
      if (incl_list.length != 2) {
        add_message("err","Primer3Plus requires a sequence length or an INCLUDED_REGION of < 10000 bp.");
        return;
      }
      var incl_len = incl_list[1];
      if (incl_len > 10000) {
        add_message("err","Primer3Plus requires a sequence length or an INCLUDED_REGION of < 10000 bp.");
        return;
      }
    }
  }
  var saltCorr = getHtmlTagValue("PRIMER_SALT_CORRECTIONS");
  if (saltCorr == 2) {
    document.getElementById('PRIMER_ANNEALING_TEMP').value = 0.0;
  }

  del_all_messages ();
  document.getElementById('P3P_RESULTS_BOX').innerHTML = "";
  var res = document.getElementById('P3P_SEL_TAB_RESULTS');
  if (res != null) {
    res.style.display="inline";
    document.getElementById('P3P_P3_RUNNING').style.display="inline";
    browseTabFunctionality('P3P_TAB_RESULTS'); 
  }
  var p3file = createSaveFileString("primer3");
  document.getElementById('P3P_DEBUG_TXT_INPUT').value = p3file;
  document.getElementById('P3P_DEBUG_TXT_OUTPUT').value = "";
  const formData = new FormData();
  formData.append('P3_INPUT_FILE', p3file);
  formData.append('P3P_GB_RETURN_PATH', getHtmlTagValue('P3P_GB_RETURN_PATH'));
  formData.append('P3P_GB_DB', getHtmlTagValue('P3P_GB_DB'));
  formData.append('P3P_GB_POSITION', getHtmlTagValue('P3P_GB_POSITION'));
  formData.append('P3P_GB_EXONS', getHtmlTagValue('P3P_GB_EXONS'));
  formData.append('P3P_GB_ORIENTATION', getHtmlTagValue('P3P_GB_ORIENTATION'));
  formData.append('P3P_GB_RAW_SEQUENCE', getHtmlTagValue('P3P_GB_RAW_SEQUENCE'));
  formData.append('SEQUENCE_TEMPLATE', getHtmlTagValue('SEQUENCE_TEMPLATE'));
  axios
    .post(`${API_URL}/runprimer3`, formData)
    .then(res => {
        if (res.status === 200) {
          rawResults = res.data.outfile;
          document.getElementById('P3P_DEBUG_TXT_OUTPUT').value = rawResults;
          results = {};
          var fileLines = rawResults.split('\n');
          for (var i = 0; i < fileLines.length; i++) {
            if ((fileLines[i].match(/=/) != null) && (fileLines[i] != "") && (fileLines[i] != "=")) {
              var pair = fileLines[i].split('=');
              results[pair[0]]=fileLines[i].split(/=(.+)/)[1];
            }
          }
          selectedPrimerPair = 0;
          calcP3PResultAdditions();
          processResData();
      }
    })
    .catch(function (error) {
      if (error.response) {
        // The request was made and the server responded with a status code
        // that falls out of the range of 2xx
        let errorMessage = error.response.data.errors
          .map(error => error.title)
          .join('; ')
        add_message("err","Error running Primer3: " + errorMessage);
      } else if (error.request) {
        // The request was made but no response was received
        add_message("err","Error: No response from the server trying to run Primer3.");
      } else {
        // Something happened in setting up the request that triggered an Error
        add_message("err","Error while setting up the request trying to run Primer3: " + error.message);
      }
      document.getElementById('P3P_SEL_TAB_RESULTS').style.display="inline";
      document.getElementById('P3P_P3_RUNNING').style.display="none";
    });
}

function runPrefold() {
  var seq = getHtmlTagValue("SEQUENCE_TEMPLATE");
  if (seq.length < 20) {
    add_message("err","Primer3Prefold requires a sequence > 20 bp.");
    return;
  }
  if (seq.length > 2000) {
    var incl = getHtmlTagValue("SEQUENCE_INCLUDED_REGION");
    if (incl == "") {
      add_message("err","Primer3Prefold requires one included region < 2000 bp.");
      return;
    }
    var incArr = incl.split(",");
    if ((incArr.length != 2) || (parseInt(incArr[1]) > 2000)) {
      add_message("err","Primer3Prefold requires one included region < 2000 bp.");
      return;
    }
  }
  var temp = getHtmlTagValue("PRIMER_ANNEALING_TEMP");
  if ((temp == "") || (parseFloat(temp) < 0.0)) {
    add_message("err","Primer3Prefold requires a an annealing temp > 0&deg;C.");
    return;
  }
  del_all_messages ();
  document.getElementById('P3P_RESULTS_BOX').innerHTML = "";
  var res = document.getElementById('P3P_SEL_TAB_RESULTS');
  if (res != null) {
    res.style.display="inline";
    document.getElementById('P3P_P3_RUNNING').style.display="inline";
    browseTabFunctionality('P3P_TAB_RESULTS'); 
  }
  var p3file = createSaveFileString("all");
  document.getElementById('P3P_DEBUG_TXT_INPUT').value = p3file;
  document.getElementById('P3P_DEBUG_TXT_OUTPUT').value = "";
  const formData = new FormData();
  formData.append('P3_INPUT_FILE', p3file);
  axios
    .post(`${API_URL}/runprefold`, formData)
    .then(res => {
        if (res.status === 200) {
          rawResults = res.data.outfile;
          document.getElementById('P3P_DEBUG_TXT_OUTPUT').value = rawResults;
          results = {};
          var fileLines = rawResults.split('\n');
          for (var i = 0; i < fileLines.length; i++) {
            if ((fileLines[i].match(/=/) != null) && (fileLines[i] != "") && (fileLines[i] != "=")) {
              var pair = fileLines[i].split('=');
              results[pair[0]]=fileLines[i].split(/=(.+)/)[1];
            }
          }
          processPrefoldData();
      }
    })
    .catch(function (error) {
      if (error.response) {
        // The request was made and the server responded with a status code
        // that falls out of the range of 2xx
        let errorMessage = error.response.data.errors
          .map(error => error.title)
          .join('; ')
        add_message("err","Error running UNAFold: " + errorMessage);
      } else if (error.request) {
        // The request was made but no response was received
        add_message("err","Error: No response from the server trying to run UNAFold.");
      } else {
        // Something happened in setting up the request that triggered an Error
        add_message("err","Error while setting up the request trying to run UNAFold: " + error.message);
      }
      document.getElementById('P3P_SEL_TAB_RESULTS').style.display="inline";
      document.getElementById('P3P_P3_RUNNING').style.display="none";
    });
}

function runAmplicon3() {
  var seq = getHtmlTagValue("SEQUENCE_TEMPLATE");
  if (seq.length < 36) {
    add_message("err","Amplicon3Plus requires a sequence > 36 bp.");
    return;
  }
  del_all_messages ();
  document.getElementById('P3P_RESULTS_BOX').innerHTML = "";
  var res = document.getElementById('P3P_SEL_TAB_RESULTS');
  if (res != null) {
    res.style.display="inline";
    document.getElementById('P3P_P3_RUNNING').style.display="inline";
    browseTabFunctionality('P3P_TAB_RESULTS'); 
  }
  var p3file = createSaveFileString("all");
  p3file += "PRIMER_AMPLICON_FORMULA" + "=" + getHtmlTagValue("PRIMER_AMPLICON_FORMULA") + "\n";
  var exp_temp = getHtmlTagValue("SEQUENCE_MELTINGTEMP");
  if (exp_temp != "") {
    p3file += "SEQUENCE_MELTINGTEMP" + "=" + exp_temp + "\n";
  }
  document.getElementById('P3P_DEBUG_TXT_INPUT').value = p3file;
  document.getElementById('P3P_DEBUG_TXT_OUTPUT').value = "";
  const formData = new FormData();
  formData.append('P3_INPUT_FILE', p3file);
  axios
    .post(`${API_URL}/runamplicon3`, formData)
    .then(res => {
        if (res.status === 200) {
          rawResults = res.data.outfile;
          document.getElementById('P3P_DEBUG_TXT_OUTPUT').value = rawResults;
          results = {};
          var fileLines = rawResults.split('\n');
          for (var i = 0; i < fileLines.length; i++) {
            if ((fileLines[i].match(/=/) != null) && (fileLines[i] != "") && (fileLines[i] != "=")) {
              var pair = fileLines[i].split('=');
              results[pair[0]]=fileLines[i].split(/=(.+)/)[1];
            }
          }
          processAmplicon3Data();
      }
    })
    .catch(function (error) {
      if (error.response) {
        // The request was made and the server responded with a status code
        // that falls out of the range of 2xx
        let errorMessage = error.response.data.errors
          .map(error => error.title)
          .join('; ')
        add_message("err","Error running Amplicon3: " + errorMessage);
      } else if (error.request) {
        // The request was made but no response was received
        add_message("err","Error: No response from the server trying to run Amplicon3.");
      } else {
        // Something happened in setting up the request that triggered an Error
        add_message("err","Error while setting up the request trying to run Amplicon3: " + error.message);
      }
      document.getElementById('P3P_SEL_TAB_RESULTS').style.display="inline";
      document.getElementById('P3P_P3_RUNNING').style.display="none";
    });
}

function checkForUUID() {  
  var path = window.location.search; // .pathname;
  if (path.match(/UUID=.+/)) { 
    var uuid = path.split("UUID=")[1];
    const formData = new FormData();
    formData.append('P3P_UUID', uuid);
    axios
      .post(`${API_URL}/loadServerData`, formData)
      .then(res => {
          if (res.status === 200) {
            if (res.data.upfile	!= "") {
              loadP3File("silent",res.data.upfile);
              var sequence = getHtmlTagValue('SEQUENCE_TEMPLATE');
              var exonEle = document.getElementById('P3P_GB_EXONS');
              if (pageElement !== null) {
                window.gb_exons = pocGenomeBrowserCleanORF(exonEle.value);
                setHtmlTagValue('P3P_GB_EXONS', window.gb_exons);
                setHtmlTagValue('PRIMER_FIRST_BASE_INDEX', '0');
              } else {
                window.gb_exons = "";
              }
              var orientation = getHtmlTagValue('P3P_GB_ORIENTATION');
              var orientEle = document.getElementById('OUT_GB_ORIENTATION');
              if (orientEle !== null) {
                if (orientation == "+") {
                  orientEle.innerHTML = "ORF is in forward";
                } else {
                  orientEle.innerHTML = "ORF is in reverse";
                }
              }
              if (exonEle.value != "") {
                var pageElement = document.getElementById('P3P_GB_RAW_SEQUENCE');
                if (pageElement !== null) {
                  pageElement.value = sequence;
                }
                pocGenomeBrowserORF("overlap");
              }
              document.getElementById('P3P_DEBUG_TXT_INPUT').value = res.data.upfile;
            }
            if (res.data.infile != "") {
            //  loadP3File("silent",res.data.infile);
              document.getElementById('P3P_DEBUG_TXT_INPUT').value = res.data.infile;
            }
            if (res.data.outfile != "") {
              rawResults = res.data.outfile;
              document.getElementById('P3P_DEBUG_TXT_OUTPUT').value = rawResults;
              results = {};
              var fileLines = rawResults.split('\n');
              for (var i = 0; i < fileLines.length; i++) {
                if ((fileLines[i].match(/=/) != null) && (fileLines[i] != "") && (fileLines[i] != "=")) {
                  var pair = fileLines[i].split('=');
                  results[pair[0]]=fileLines[i].split(/=(.+)/)[1];
                }
              }
              calcP3PResultAdditions();
              processResData();
            }
            showGenomeBrowserButtons();
          }
      })
      .catch(function (error) {
        if (error.response) {
          // The request was made and the server responded with a status code
          // that falls out of the range of 2xx
          let errorMessage = error.response.data.errors
            .map(error => error.title)
            .join('; ')
          add_message("err","Error loading uuid " + uuid + ": " + errorMessage);
        } else if (error.request) {
          // The request was made but no response was received
          add_message("err","Error: No response from the server trying to load uuid " + uuid + ".");
        } else {
          // Something happened in setting up the request that triggered an Error
          add_message("err","Error while setting up the request trying to load uuid " + uuid + ": " + error.message);
        }
      });
  }
}

function showGenomeBrowserButtons() {
  var exons = getHtmlTagValue('P3P_GB_EXONS');
  var el = document.getElementById('P3P_GENOME_BUTTONS');
  if (el == null) {
    return;
  }
  if ((exons == "") || (exons == "-999")) {
    if (window.gb_exons != "") {
      exons = window.gb_exons;
    }
  }
  if (exons != "") {
    var dButton = document.getElementById('P3P_ACTION_GB_LOAD_SINGLE_EXON');
    if (dButton !== null) {
      var i;
      for(i = dButton.options.length - 1; i >= 0; i--) {
        dButton.remove(i);
      }
      var exonList = exons.split(',');
      var opt1 = document.createElement('option');
      opt1.value = 0;
      opt1.innerHTML = "Choose Exon";
      dButton.appendChild(opt1);
      var orientation = getHtmlTagValue('P3P_GB_ORIENTATION');
      for (i = 0; i < exonList.length; i++) {
        var opt = document.createElement('option');
        opt.value = exonList[i];
        if (orientation == "+") {
          opt.innerHTML = "Exon " + (i + 1) + ": " + exonList[i] + " ";
        } else {
          opt.innerHTML = "Exon " + (exonList.length - i) + ": " + exonList[i] + " ";
        }
        dButton.appendChild(opt);
      }
      dButton.addEventListener('change', loadOrfSingleExon);
    }
    el.style.display = "inline";
  } else {
    el.style.display = "none";
  }
}

function pocGenomeBrowserCleanORF(exons) {
  var retExons = "";
  if (exons != "") {
    var exonList = exons.split(',');
    var lastPos = Infinity;
    var lastStart = 0;
    var printed = 1;
    var sumLen = 0;

    for (var i = 0; i < exonList.length; i++) {
      if (exonList[i] == "") {
        continue;
      }
      var curExon = exonList[i].split('-');
      if (curExon.length != 2) {
        continue;
      }
      var start = parseInt(curExon[0]);
      var end = parseInt(curExon[0]) + parseInt(curExon[1]);
      var len = parseInt(curExon[1]);
      if (sumLen == 0) {
        lastStart = start;
      }
      if (lastPos - start < 0) {
        if (retExons != "") {
          retExons += ",";
        }
        retExons += lastStart + "-" + sumLen;
        lastStart = start;
        sumLen = len;
      } else {
        sumLen += len;
      }
      lastPos = end;
    }
    if (retExons != "") {
      retExons += ",";
    }
    retExons += lastStart + "-" + sumLen;
  }
  return retExons;
}

function pocGenomeBrowserORF(sel) {
  var sequence = getHtmlTagValue('P3P_GB_RAW_SEQUENCE');
  var exons = getHtmlTagValue('P3P_GB_EXONS');
  var orientation = getHtmlTagValue('P3P_GB_ORIENTATION');
  var eleSeq = document.getElementById('SEQUENCE_TEMPLATE');
  if (sequence == "") {
    return;
  }
  if ((exons == "") || (exons == "-999")) {
    if (window.gb_exons != "") {
      exons = window.gb_exons;
      var eleExon = document.getElementById('P3P_GB_EXONS');
      if (eleExon !== null) {
        eleExon.value = exons;
      }
    }
  }
  if (exons != "") {
    var exonList = exons.split(',');
    var exonSeq = "";
    var exonBound = [];
    for (var i = 0; i < exonList.length; i++) {
      if (exonList[i] == "") {
        continue;
      }
      var curExon = exonList[i].split('-');
      if (curExon.length != 2) {
        continue;
      }
      exonSeq += sequence.substring(parseInt(curExon[0]), parseInt(curExon[0]) + parseInt(curExon[1]));
      exonBound.push(exonSeq.length);
    }

    if (eleSeq !== null) {
      eleSeq.value = exonSeq;
    }

    var overString = "";
    var tarString = "";
    for (var i = 0; i < exonBound.length - 1; i++) {
      overString += exonBound[i] + " ";
      tarString += (exonBound[i] - 1) + ",2 ";
    }

    if (sel == "overlap") {
      tarString = "";
    } else {
      overString = "";
    }

    var eleExcl = document.getElementById('SEQUENCE_EXCLUDED_REGION');
    if (eleExcl !== null) {
      eleExcl.value = "";
    }
    var eleTar = document.getElementById('SEQUENCE_TARGET');
    if (eleTar !== null) {
      eleTar.value = tarString;
    }
    var eleIncl = document.getElementById('SEQUENCE_INCLUDED_REGION');
    if (eleIncl !== null) {
      eleIncl.value = "";
    }
    var eleOver = document.getElementById('SEQUENCE_OVERLAP_JUNCTION_LIST');
    if (eleOver !== null) {
      eleOver.value = overString;
    }
    createSeqWithDeco(-1);
  }
}

function loadOrfOverlaps() {
  pocGenomeBrowserORF("overlap");
}

function loadOrfTargets() {
  pocGenomeBrowserORF("target");
}

function loadOrfGenome() {
  var sequence = getHtmlTagValue('P3P_GB_RAW_SEQUENCE');
  var eleSeq = document.getElementById('SEQUENCE_TEMPLATE');
  var eleExon = document.getElementById('P3P_GB_EXONS');
  eleExon.value = "-999";
  var exons = window.gb_exons;

  if ((exons != "") || (exons != "-999")) {
    var exonList = exons.split(',');
    var exonSeq = "";
    var lastPos = 0;
    for (var i = 0; i < exonList.length; i++) {
      if (exonList[i] == "") {
        continue;
      }
      var curExon = exonList[i].split('-');
      if (parseInt(curExon[0]) > lastPos) {
        exonSeq += sequence.substring(lastPos, parseInt(curExon[0])).toLowerCase();
      }

      exonSeq += sequence.substring(parseInt(curExon[0]), parseInt(curExon[0]) + parseInt(curExon[1])).toUpperCase();
      lastPos = parseInt(curExon[0]) + parseInt(curExon[1]);
      }
    }
    if (sequence.length - 1 > lastPos) {
      exonSeq += sequence.substring(lastPos, sequence.length).toLowerCase();
    }
    sequence = exonSeq;
  if (eleSeq !== null) {
    eleSeq.value = sequence;
  }
  var eleExcl = document.getElementById('SEQUENCE_EXCLUDED_REGION');
  if (eleExcl !== null) {
    eleExcl.value = "";
  }
  var eleTar = document.getElementById('SEQUENCE_TARGET');
  if (eleTar !== null) {
    eleTar.value = "";
  }
  var eleIncl = document.getElementById('SEQUENCE_INCLUDED_REGION');
  if (eleIncl !== null) {
    eleIncl.value = "";
  }
  var eleOver = document.getElementById('SEQUENCE_OVERLAP_JUNCTION_LIST');
  if (eleOver !== null) {
    eleOver.value = "";
  }
  createSeqWithDeco(-1);
}

function loadOrfSingleExon() {
  var sequence = getHtmlTagValue('P3P_GB_RAW_SEQUENCE');
  var dButton = document.getElementById('P3P_ACTION_GB_LOAD_SINGLE_EXON');
  if (dButton !== null) {
    var value = dButton.value;
    var curExon = value.split('-');
    if (curExon.length != 2) {
      return;
    }
    loadOrfGenome();
    var seq_len = sequence.length;
    var pos = parseInt(curExon[0]);
    var len = parseInt(curExon[1]);
    if (len > 9000) {
      return;
    }
    if (len > seq_len) {
      return;
    }
    var eleTar = document.getElementById('SEQUENCE_TARGET');
    if (eleTar !== null) {
      eleTar.value = value.replace(/-/g, ",");
    }
    if (seq_len > 9000) {
      var rest = parseInt((9000 - len) / 2);
      var start = pos - rest;
      if (start < 1) {
        start = 0;
      }
      var end = pos + len + rest;
      if (end > seq_len - 1) {
        end = seq_len - 1;
      }

      var eleIncl = document.getElementById('SEQUENCE_INCLUDED_REGION');
      if (eleIncl !== null) {
        eleIncl.value = start + "," + (end - start);
      }
    }
  }
  createSeqWithDeco(-1);
}

function initRunPrimer3() {
  var pButton = document.getElementById('P3P_ACTION_RUN_PRIMER3');
  if (pButton !== null) {
    pButton.addEventListener('click', runPrimer3);
  }
  var aButton = document.getElementById('P3P_ACTION_GB_LOAD_ORF_OVERLAPS');
  if (aButton !== null) {
    aButton.addEventListener('click', loadOrfOverlaps);
  }
  var bButton = document.getElementById('P3P_ACTION_GB_LOAD_ORF_TARGETS');
  if (bButton !== null) {
    bButton.addEventListener('click', loadOrfTargets);
  }
  var cButton = document.getElementById('P3P_ACTION_GB_LOAD_GENOME');
  if (cButton !== null) {
    cButton.addEventListener('click', loadOrfGenome);
  }
  var dButton = document.getElementById('P3P_ACTION_GB_LOAD_SINGLE_EXON');
  if (dButton !== null) {
    var i;
    for(i = dButton.options.length - 1; i >= 0; i--) {
      dButton.remove(i);
    }
    var opt = document.createElement('option');
    opt.value = 0;
    opt.innerHTML = "Choose Exon";
    dButton.appendChild(opt);
    var opt2 = document.createElement('option');
    opt2.value = 0;
    opt2.innerHTML = "No Exons loaded!";
    dButton.appendChild(opt2);
    if (dButton !== null) {
      dButton.addEventListener('change', loadOrfSingleExon);
    }
  }
}

function initRunAmplicon3() {
  var pButton = document.getElementById('P3P_ACTION_RUN_AMPLICON3');
  if (pButton !== null) {
    pButton.addEventListener('click', runAmplicon3);
  }
}

function initRunPrefold() {
  var pButton = document.getElementById('P3P_ACTION_RUN_PREFOLD');
  if (pButton !== null) {
    pButton.addEventListener('click', runPrefold);
  }
}

function init_primer3_versions() {
  var p3pVer = document.getElementById('P3P_ST_P3P_VERSION');
  if (p3pVer !== null) {
    p3pVer.innerHTML = primer3plus_version;
  }
  var p3Ver = document.getElementById('P3P_ST_P3_VERSION');
  if (p3Ver !== null) {
    // Send different data to avoid caching
    var dt = new Date();
    var utcDate = dt.toUTCString();
    const formData = new FormData();
    formData.append('stufferData', utcDate);
    axios
      .post(`${API_URL}/primer3version`, formData)
      .then(res => {
          if (res.status === 200) {
            p3Ver.innerHTML = res.data;
        }
      })
      .catch(function (error) {
        p3Ver.innerHTML = "---";
      });
  }
}

function processPrefoldData(){
  del_all_messages ();
  var res = document.getElementById('P3P_SEL_TAB_RESULTS');
  if (res != null) {
    res.style.display="inline";
    document.getElementById('P3P_P3_RUNNING').style.display="none";
    browseTabFunctionality('P3P_TAB_RESULTS');
  }

  if (results.hasOwnProperty("P3P_ERROR")) {
    var p3pErrLines = results["P3P_ERROR"].split(';');
    for (var i = 0; i < p3pErrLines.length; i++) {
      add_message("err", p3pErrLines[i]);
    }
  }
  if (results.hasOwnProperty("PRIMER_ERROR")) {
    var p3ErrLines = results["PRIMER_ERROR"].split(';');
    for (var i = 0; i < p3ErrLines.length; i++) {
      add_message("err", p3ErrLines[i]);
    }
  }
  if (results.hasOwnProperty("PRIMER_WARNING")) {
    var p3WarnLines = results["PRIMER_WARNING"].split(';');
    for (var i = 0; i < p3WarnLines.length; i++) {
      add_message("warn", p3WarnLines[i]);
    }
  }

  var returnHTML = '<div class="p3p_fit_to_table">'
  if (results.hasOwnProperty("P3P_UUID")) {
    returnHTML += '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;'
    returnHTML += '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;'
    returnHTML += '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;'
    returnHTML += '<input value="Send to Primer3Plus"'
    returnHTML += ' onclick="window.open(\'index.html?UUID=' + results["P3P_UUID"] + '\', \'_blank\');"'
    returnHTML += ' type="button" style="background: #83db7b;"><br /><br />'
  }
  if (results.hasOwnProperty("P3P_PREFOLD_DELTA_G")) { 
    returnHTML += '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;'
    returnHTML += '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;'
    returnHTML += '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;'
    returnHTML += 'dG = ' + results["P3P_PREFOLD_DELTA_G"];
  }
  returnHTML += '</div>';
  returnHTML += createHTMLsequence(results, -1);
  // document.getElementById('P3P_DEBUG_TXT_OUTPUT').value = returnHTML;
  document.getElementById('P3P_RESULTS_BOX').innerHTML = returnHTML;
}

function processAmplicon3Data(){
  del_all_messages ();
  amp_temp = [];
  amp_melt = [];
  amp_deriv = [];

  var res = document.getElementById('P3P_SEL_TAB_RESULTS');
  if (res != null) {
    res.style.display="inline";
    document.getElementById('P3P_P3_RUNNING').style.display="none";
    browseTabFunctionality('P3P_TAB_RESULTS');
  }
  if (results.hasOwnProperty("AMPLICON_ERROR")) {
    var p3pErrLines = results["AMPLICON_ERROR"].split(';');
    var returnHTML = '<p style="padding: 20px">\n';
    for (var i = 0; i < p3pErrLines.length; i++) {
      add_message("err", p3pErrLines[i]);
      returnHTML += p3pErrLines[i] + '<br />\n';
    }
    returnHTML = '</p>\n';
  } else {
    returnHTML = '<div class="p3p_section">\n<table>\n<colgroup>\n';
    returnHTML += '<col style="width: 5%">\n<col style="width: 20%">\n';
    returnHTML += '<col style="width: 25%">\n<col style="width: 50%">\n</colgroup>\n';
    if (results.hasOwnProperty("AMPLICON_MELTPOINTS")) {
      returnHTML += '<tr>\n<td></td>\n<td style="font-weight: bold; font-size: large;">Melting Temperature:</td>\n';
      returnHTML += '<td style="text-align: right;font-weight: bold;  font-size: large;">';
      returnHTML += results["AMPLICON_MELTPOINTS"].replace(/,/g, "&deg;C, ");
      returnHTML += '&deg;C</td>\n<td></td>\n</tr>\n';
    }
    if (results.hasOwnProperty("AMPLICON_PRODUCT_SIZE")) {
      returnHTML += '<tr>\n<td></td>\n<td>Amplicon Length:</td>\n<td style="text-align: right">';
      returnHTML += results["AMPLICON_PRODUCT_SIZE"] + ' bp</td>\n<td></td>\n</tr>\n';
    }
    if (results.hasOwnProperty("AMPLICON_GC_PERCENT")) {
      returnHTML += '<tr>\n<td></td>\n<td>Amplicon GC:</td>\n<td style="text-align: right">';
      returnHTML += results["AMPLICON_GC_PERCENT"] + '%</td>\n<td></td>\n</tr>\n';
    }
    returnHTML += '<tr>\n<td></td>\n<td></td>\n<td></td>\n<td></td>\n</tr>\n';
    if (results.hasOwnProperty("AMPLICON_MONOVALENT")) {
      returnHTML += '<tr>\n<td></td>\n<td>Monovalent Salt:</td>\n<td style="text-align: right">';
      returnHTML += results["AMPLICON_MONOVALENT"] + ' mM</td>\n<td></td>\n</tr>\n';
    }
    if (results.hasOwnProperty("AMPLICON_DIVALENT")) {
      returnHTML += '<tr>\n<td></td>\n<td>Divalent Salt:</td>\n<td style="text-align: right">';
      returnHTML += results["AMPLICON_DIVALENT"] + ' mM</td>\n<td></td>\n</tr>\n';
    }
    if (results.hasOwnProperty("AMPLICON_DNTPS")) {
      returnHTML += '<tr>\n<td></td>\n<td>DNTPs:</td>\n<td style="text-align: right">';
      returnHTML += results["AMPLICON_DNTPS"] + ' mM</td>\n<td></td>\n</tr>\n';
    }
    if (results.hasOwnProperty("AMPLICON_DMSO")) {
      returnHTML += '<tr>\n<td></td>\n<td>DMSO:</td>\n<td style="text-align: right">';
      returnHTML += results["AMPLICON_DMSO"] + '%</td>\n<td></td>\n</tr>\n';
    }
    if (results.hasOwnProperty("AMPLICON_DMSO_CORRECTION")) {
      returnHTML += '<tr>\n<td></td>\n<td>DMSO Factor:</td>\n<td style="text-align: right">';
      returnHTML += results["AMPLICON_DMSO_CORRECTION"] + '</td>\n<td></td>\n</tr>\n';
    }
    if (results.hasOwnProperty("AMPLICON_FORMAMID")) {
      returnHTML += '<tr>\n<td></td>\n<td>Formamide:</td>\n<td style="text-align: right">';
      returnHTML += results["AMPLICON_FORMAMID"] + ' mol/l</td>\n<td></td>\n</tr>\n';
    }
    if (results.hasOwnProperty("AMPLICON_TEMPERATURES")) {
      amp_temp = results["AMPLICON_TEMPERATURES"].split(',');
    }
    if (results.hasOwnProperty("AMPLICON_MELT_CURVE")) {
      amp_melt = results["AMPLICON_MELT_CURVE"].split(',');
    }
    if (results.hasOwnProperty("AMPLICON_DERIVATIVE_CURVE")) {
      amp_deriv = results["AMPLICON_DERIVATIVE_CURVE"].split(',');
    }
  }
  returnHTML += '</table>\n</div>\n';
  returnHTML += createSVG(amp_temp, amp_deriv, false);
  returnHTML += '<br /><br />\n';
  returnHTML += createSVG(amp_temp, amp_melt, true);
  // document.getElementById('P3P_DEBUG_TXT_OUTPUT').value = returnHTML;
  document.getElementById('P3P_RESULTS_BOX').innerHTML = returnHTML;
}

function createSVG(amp_temp, amp_vals, melt) {
  if (amp_temp.length != amp_vals.length) {
    return "";
  }
  if (amp_temp.length < 10) {
    return "";
  }
  var winYend = 1.0;
  var winYst = 0.0;
  var winYstep = 0.1;
  var col = "blue"
  if (melt == false) {
    winYend = 0.0;
    for (var i = 0; i < amp_vals.length; i++) {
      if (parseFloat(amp_vals[i]) > winYend) {
        winYend = parseFloat(amp_vals[i])
      }
    }
    winYend = parseInt(winYend * 10 + 0.5) / 10.0;
  }
  var retVal = "<polyline fill='none' stroke-linejoin='round' stroke='";
  retVal +=  col + "' stroke-width='1.2' points='";
  for (var i = 0; i < amp_vals.length; i++) {
      var xPos = parseFloat(amp_temp[i] - 60.0) / (95.0 - 60.0) * 500;
      var yPos = 300 - parseFloat(amp_vals[i]) / winYend * 300;
      retVal += xPos + "," + yPos + " ";
  }
  retVal += "' />";
  // The X-Axis
  var xStep = 5;
  for (var i = 0; (i * xStep + 60.0) < (95.0 + xStep); i++) {
      var xPos = (i * xStep) / (95.0 - 60.0) * 500;
      retVal += "<line x1='" + xPos + "' y1='300' x2='" + xPos + "' y2='" + 307 + "' stroke-width='2' stroke='black' />";
      retVal += "<text x='" + xPos + "' y='" + 326;
      retVal += "' font-family='Arial' font-size='15' fill='black' text-anchor='middle'>";
      retVal += (i * xStep + 60.0) + "</text>";
  }
  // The Y-Axis
  for (var i = 0; i *  winYstep < winYend + winYstep; i++) {
      var yPos = 300 - (i *  winYstep) / winYend * 300; 
      retVal += "<line x1='0' y1='" + yPos;
      retVal += "' x2='-7' y2='" + yPos + "' stroke-width='2' stroke='black' />";
      retVal += "<text x='-11' y='" + (yPos + 3);
      retVal += "' font-family='Arial' font-size='15' fill='black' text-anchor='end'>";
      var textValOut = i *  winYstep
      retVal += textValOut.toFixed(1) + "</text>";
  }
  retVal += "<line x1='0' y1='300' x2='505' y2='300' stroke-width='2' stroke='black' stroke-linecap='square'/>";
  retVal += "<line x1='0' y1='-5' x2='0' y2='300' stroke-width='2' stroke='black' stroke-linecap='square'/>";
  retVal += "<text x='-150' y='-40' font-family='Arial' font-size='20' ";
  retVal += "fill='black' transform='rotate(-90)' text-anchor='middle'>";
  if (melt == true) {
    retVal += "Helicity (%)</text>";
  } else {
    retVal += "-dF / dT</text>";
  }
  retVal += "<text x='250' y='350' font-family='Arial' font-size='20' fill='black' text-anchor='middle'>&deg;C</text>";
  retVal += "</svg>";
  var head = "<svg xmlns='http://www.w3.org/2000/svg' viewBox='-80 -60 600 450' width='700px'>";
  return head + retVal;
}

function processResData(){
  del_all_messages ();
  var res = document.getElementById('P3P_SEL_TAB_RESULTS');
  if (res != null) {
    res.style.display="inline";
    document.getElementById('P3P_P3_RUNNING').style.display="none";
    browseTabFunctionality('P3P_TAB_RESULTS');
  }

  if (results.hasOwnProperty("P3P_ERROR")) {
    var p3pErrLines = results["P3P_ERROR"].split(';');
    for (var i = 0; i < p3pErrLines.length; i++) {
      add_message("err", p3pErrLines[i]);
    }
  }
  if (results.hasOwnProperty("PRIMER_ERROR")) {
    var p3ErrLines = results["PRIMER_ERROR"].split(';');
    for (var i = 0; i < p3ErrLines.length; i++) {
      add_message("err", p3ErrLines[i]);
    }
  }
  if (results.hasOwnProperty("PRIMER_WARNING")) {
    var p3WarnLines = results["PRIMER_WARNING"].split(';');
    for (var i = 0; i < p3WarnLines.length; i++) {
      add_message("warn", p3WarnLines[i]);
    }
  }
  
  // Figure out if any primers were returned
  var pair_count = 0;
  var primer_count = 0;
  if (results.hasOwnProperty("PRIMER_PAIR_NUM_RETURNED")){
    pair_count = parseInt(results["PRIMER_PAIR_NUM_RETURNED"]);
  }
  if (results.hasOwnProperty("PRIMER_LEFT_NUM_RETURNED")){
    primer_count += parseInt(results["PRIMER_LEFT_NUM_RETURNED"]);
  }
  if (results.hasOwnProperty("PRIMER_INTERNAL_NUM_RETURNED")){
    primer_count += parseInt(results["PRIMER_INTERNAL_NUM_RETURNED"]);
  }
  if (results.hasOwnProperty("PRIMER_RIGHT_NUM_RETURNED")){
    primer_count += parseInt(results["PRIMER_RIGHT_NUM_RETURNED"]);
  }
  var returnHTML = ""
  // Write some help if no primers found
  if (primer_count == 0){
    returnHTML += "<br/ >Primer3Plus could not pick any primers. Try less strict settings.<br /><br />";       
  } 
  // If only one primer was found we write the results different
  else if (primer_count == 1) {
    returnHTML += createResultsPrimerCheck(results);
  }
  // Print out pair boxes
  else if (pair_count != 0) {
    returnHTML += createResultsDetection(results);
  } 
  // Sequencing needs a different sequenceprint
  else if (results["PRIMER_TASK"] == "pick_sequencing_primers") {
    returnHTML += createResultsPrimerList(results, -2);
  } 
  // Primer Lists do not highlight primers in sequenceprint
  else if (results["PRIMER_TASK"] == "pick_primer_list") {
    returnHTML += createResultsPrimerList(results, -1);
  } 
  // The regular output
  else {
    returnHTML += createResultsPrimerList(results, -2);
  }
  returnHTML += '<div id="p3p_uuid_link">\n  Link to the results (valid 3 days): \n';
  var linkAddr = INDEX_LINK_URL + "?UUID=" + results["P3P_UUID"];
  returnHTML += '<a href="' + linkAddr + '">' + linkAddr + '</a>\n';
  returnHTML += '</div>\n';
  // Add statistics
  returnHTML += createPrimerStatistics(results);

//  document.getElementById('P3P_DEBUG_TXT_OUTPUT').value = returnHTML;
  document.getElementById('P3P_RESULTS_BOX').innerHTML = returnHTML;
}

window.updateResultsElement = updateResultsElement;
function updateResultsElement(elm) {
  results[elm.id] = getHtmlTagValue(elm.id);
}

function createPrimer3ManagerBar() {
  var ret = '<table>\n';
  ret += '  <colgroup>\n';
  ret += '    <col style="width: 25%">\n';
  ret += '    <col style="width: 75%">\n';
  ret += '  </colgroup>\n';
  ret += '  <tr>\n';
  ret += '    <td><input id="P3P_ALL_PRIMERS_SELECTED" type="checkbox"> &nbsp; Select all Primers</td>\n';
  ret += '    <td style="text-align: right;">\n';
  if (results.hasOwnProperty("P3P_GB_FILE") && (results["P3P_GB_FILE"] != "")){
    ret += '      <input value="Return to UCSC Genome Browser" onclick="goToGenomeBrowser(\'';
    ret += getHtmlTagValue('P3P_GB_RETURN_PATH') + '?db=' + getHtmlTagValue('P3P_GB_DB')
    ret += '&position=' + getHtmlTagValue('P3P_GB_POSITION') + '&hgct_customText='
    ret += `${API_URL}/getbed/` + results["P3P_GB_FILE"] + '\');"type="button">&nbsp;\n';
  }
  ret += '      <input value="Send Selected Primers to Primer3Manager" onclick="uploadToPrimer3Manager();" type="button">&nbsp;\n';
  ret += '      <input value="Go to Primer3Manager" onclick="goToPrimer3Manager();"type="button">&nbsp;\n';
  ret += '    </td>';
  ret += '  </tr>';
  ret += '</table>';
  return ret;
}

window.uploadToPrimer3Manager = uploadToPrimer3Manager;
function uploadToPrimer3Manager(){
  var clData = localStorage.getItem("P3M_ALL_DATA");
  if (clData === null) {
    clData = [];
  } else {
    clData = JSON.parse(clData);
  }
  var newData = [];
  var rawTask = saveGetTag("PRIMER_TASK");
  var task = " - ";
  if (rawTask == "generic") {
    task += "Generic Primers";
  } else if (rawTask == "pick_cloning_primers") {
    task += "Cloning Primers";
  } else if (rawTask == "pick_discriminative_primers") {
    task += "Discriminative Primers";
  } else if (rawTask == "pick_sequencing_primers") {
    task += "Sequencing Primers";
  } else if (rawTask == "pick_primer_list") {
    task += "Primer List";
  } else if (rawTask == "check_primers") {
    task += "Check Primers";
  }

  var selAll = false;
  if (getHtmlTagValue("P3P_ALL_PRIMERS_SELECTED") == "1") {
    selAll = true;
  }
  primSet = {};
  var today = new Date();
  var dd = today.getDate();
  var mm = today.getMonth() + 1; //January is 0!
  var yyyy = today.getFullYear();
  if(dd < 10) {
    dd = '0'+dd
  } 
  if(mm < 10) {
    mm = '0'+mm
  } 
  if (results.hasOwnProperty("PRIMER_PAIR_NUM_RETURNED") && (parseInt(results["PRIMER_PAIR_NUM_RETURNED"]) > 0 )) {
    var seq = results["SEQUENCE_TEMPLATE"];
    var fistBase = parseInt(saveGetTag("PRIMER_FIRST_BASE_INDEX"));  
    for (var pairCount = 0 ; pairCount < parseInt(results["PRIMER_PAIR_NUM_RETURNED"]) ; pairCount++) {
      if ((results["PRIMER_PAIR_" + pairCount + "_SELECTED"] == "1") || selAll) {
        var primSet = {};	      
        primSet["forwardPrimer"] = results["PRIMER_LEFT_" + pairCount + "_SEQUENCE"];
        if (results.hasOwnProperty("PRIMER_INTERNAL_" + pairCount + "_SEQUENCE")) {
          primSet["probe1"] = results["PRIMER_INTERNAL_" + pairCount + "_SEQUENCE"];
        }
        primSet["reversePrimer"] = results["PRIMER_RIGHT_" + pairCount + "_SEQUENCE"];
        primSet["amplicon"] = results["PRIMER_PAIR_" + pairCount + "_AMPLICON"];
        primSet["id"] = results["PRIMER_PAIR_" + pairCount + "_NAME"];

        primSet["description"] = "Primer3Plus " + task + " - " + dd + '.' + mm + '.' + yyyy;
        primSet["selected"] = "1";
        localStorage.setItem("P3M_NEW_DATA", true);
        newData.push(primSet);
      }
    }
  } else {
    for (var tag in results) {
      if(tag.endsWith("_SEQUENCE")){
        // Add the name
        var nameKeyComplete = tag.split('_');
        var namePrimerType = nameKeyComplete[1];
        var nameNumber = nameKeyComplete[2];
        var nameKeyName = tag.replace(/SEQUENCE$/, "NAME");
        var nameKeySelected = tag.replace(/SEQUENCE$/, "SELECTED");
        if ((results[nameKeySelected] == "1") || selAll) {
          var primSet = {};
          if (namePrimerType == "LEFT" ) {
            primSet["forwardPrimer"] = results[tag];
          } else if (namePrimerType == "INTERNAL") {
            primSet["probe1"] = results[tag];
          } else if (namePrimerType == "RIGHT") {
            primSet["reversePrimer"] = results[tag];
          }
          primSet["id"] = results[nameKeyName];
          primSet["description"] = "Primer3Plus " + task + " - " + dd + '.' + mm + '.' + yyyy;
          primSet["selected"] = "1";
          localStorage.setItem("P3M_NEW_DATA", true);
          newData.push(primSet);
        }
      }
    }
  }
  if (localStorage.getItem("P3M_NEW_DATA")) {
    for (var i = 0 ; i < clData.length ; i++) {
      newData.push(clData[i]);
    }
    localStorage.setItem("P3M_ALL_DATA", JSON.stringify(newData));
  }
  goToPrimer3Manager();
}

window.goToPrimer3Manager = goToPrimer3Manager;
function goToPrimer3Manager(){
  var win = window.open("primer3manager.html", 'Primer3Manager');
  win.focus();
}

window.goToGenomeBrowser = goToGenomeBrowser;
function goToGenomeBrowser(linkAddr){
  var win = window.open(linkAddr, 'GenomeBrowser');
  win.focus();
}


function createResultsPrimerCheck(res) {
  var linkRoot = `${HELP_LINK_URL}#`;
  var thAdd = "";
  if (res["PRIMER_THERMODYNAMIC_OLIGO_ALIGNMENT"] == "1") {
    thAdd = "_TH";
  }
  var thTmAdd = "";
  if (res["PRIMER_THERMODYNAMIC_TEMPLATE_ALIGNMENT"] == "1") {
    thTmAdd = "_TH";
  }
  // Figure out which primer to return
  // This function will be only run if only one primer was found
  var type;
  if (res.hasOwnProperty("PRIMER_LEFT_0_SEQUENCE")) {
      type = "LEFT";
  }
  if (res.hasOwnProperty("PRIMER_RIGHT_0_SEQUENCE")) {
      type = "RIGHT";
  }
  if (res.hasOwnProperty("PRIMER_INTERNAL_0_SEQUENCE")) {
      type = "INTERNAL";
  }
  res["PRIMER_" + type + "0_SELECTED"] = "1";
  var retHTML = createPrimer3ManagerBar();
  retHTML += '<div class="p3p_fit_to_table">\n<table>\n';
  retHTML += '  <colgroup>\n';
  retHTML += '    <col style="width: 17%">\n';
  retHTML += '    <col style="width: 83%">\n';
  retHTML += '  </colgroup>\n';
  retHTML += '  <tr class="p3p_left_primer">\n';
  retHTML += '    <td class="p3p_oligo_cell">Oligo:</td>\n';
  retHTML += '    <td class="p3p_oligo_cell">';
  retHTML += '<input id="PRIMER_' + type + '0_NAME" onchange="updateResultsElement(this);" ';
  retHTML += 'value="' + res["PRIMER_" + type + "_0_NAME"] + '" size="40" type="text"></td>\n';
  retHTML += '  </tr>\n';
  retHTML += '  <tr>\n';
  retHTML += '    <td class="p3p_oligo_cell"><a href="' + linkRoot + 'PRIMER_RIGHT_4_SEQUENCE">Sequence:</a></td>\n';
  retHTML += '    <td class="p3p_oligo_cell">';
  retHTML += '<input id="PRIMER_' + type + '0_SEQUENCE" onchange="updateResultsElement(this);" ';
  retHTML += 'value="' + res["PRIMER_" + type + "_0_SEQUENCE"] + '" size="90" type="text"></td>\n';
  retHTML += '  </tr>\n';
  retHTML += '  <tr>\n';
  retHTML += '    <td class="p3p_oligo_cell"><a href="' + linkRoot + 'PRIMER_RIGHT_4">Length:</a></td>\n';
  retHTML += '    <td class="p3p_oligo_cell">';
  var primerPos = res["PRIMER_" + type + "_0"].split(',');
  retHTML += primerPos[1];
  retHTML += ' bp</td>\n  </tr>\n';
  retHTML += '  <tr>\n';
  retHTML += '    <td class="p3p_oligo_cell"><a href="' + linkRoot + 'PRIMER_RIGHT_4_TM">Tm:</a></td>\n';
  retHTML += '    <td class="p3p_oligo_cell">' + Number.parseFloat(res["PRIMER_" + type + "_0_TM"]).toFixed(1);
  retHTML += ' C</td>\n  </tr>\n';
  retHTML += '  <tr>\n';
  retHTML += '    <td class="p3p_oligo_cell"><a href="' + linkRoot + 'PRIMER_RIGHT_4_GC_PERCENT">GC:</a></td>\n';
  retHTML += '    <td class="p3p_oligo_cell">' + Number.parseFloat(res["PRIMER_" + type + "_0_GC_PERCENT"]).toFixed(1);
  retHTML += ' %</td>\n  </tr>\n';
  retHTML += '  <tr>\n';
  retHTML += '    <td class="p3p_oligo_cell"><a href="' + linkRoot + 'PRIMER_RIGHT_4_SELF_ANY" + thAdd + ">Any Dimer:</a></td>\n';
  retHTML += '    <td class="p3p_oligo_cell">' + Number.parseFloat(res["PRIMER_" + type + "_0_SELF_ANY" + thAdd]).toFixed(1);
  retHTML += '</td>\n  </tr>\n';
  retHTML += partCheckSecStruct(res, linkRoot, "PRIMER_" + type + "_0_SELF_ANY_STUCT", "PRIMER_" + type + "_4_SELF_ANY_STUCT", "Secondary Structure");
  retHTML += '  <tr>\n';
  retHTML += '    <td class="p3p_oligo_cell"><a href="' + linkRoot + 'PRIMER_RIGHT_4_SELF_END" + thAdd + ">End Dimer:</a></td>\n';
  retHTML += '    <td class="p3p_oligo_cell">' + Number.parseFloat(res["PRIMER_" + type + "_0_SELF_END" + thAdd]).toFixed(1);
  retHTML += '</td>\n  </tr>\n';
  retHTML += partCheckSecStruct(res, linkRoot, "PRIMER_" + type + "_0_SELF_END_STUCT", "PRIMER_" + type + "_4_SELF_END_STUCT", "Secondary Structure");
  if (res.hasOwnProperty("PRIMER_" + type + "_0_TEMPLATE_MISPRIMING" + thTmAdd) &&
      (res["PRIMER_" + type + "_0_TEMPLATE_MISPRIMING" + thTmAdd] != "")) {
    retHTML += '  <tr>\n    <td class="p3p_oligo_cell"><a href="' + linkRoot;
    retHTML += 'PRIMER_RIGHT_4_TEMPLATE_MISPRIMING' + thTmAdd + '">Template Mispriming:</a></td>\n';
    retHTML += '<td class="p3p_oligo_cell">' + Number.parseFloat(res["PRIMER_" + type + "_0_TEMPLATE_MISPRIMING" + thTmAdd]).toFixed(1);
    retHTML += '</td>\n  </tr>\n';
  }
  if (res["PRIMER_THERMODYNAMIC_OLIGO_ALIGNMENT"] == "1") {
    retHTML += '  <tr>\n    <td class="p3p_oligo_cell"><a href="' + linkRoot + 'PRIMER_RIGHT_4_HAIRPIN_TH">Hairpin:</a></td>\n';
    retHTML += '    <td class="p3p_oligo_cell">' + Number.parseFloat(res["PRIMER_" + type + "_0_HAIRPIN_TH"]).toFixed(1);
    retHTML += '</td>\n  </tr>\n';
  }
  retHTML += partCheckSecStruct(res, linkRoot, "PRIMER_" + type + "_0_HAIRPIN_STUCT", "PRIMER_" + type + "_4_HAIRPIN_STUCT", "Secondary Structure");
  retHTML += '  <tr>\n    <td class="p3p_oligo_cell"><a href="' + linkRoot + 'PRIMER_RIGHT_4_END_STABILITY">3\' Stability:</a></td>\n';
  retHTML += '    <td class="p3p_oligo_cell">' + Number.parseFloat(res["PRIMER_" + type + "_0_END_STABILITY"]).toFixed(1);
  retHTML += ' &Delta;G</td>\n  </tr>\n  <tr>\n';
  retHTML += '    <td class="p3p_oligo_cell"><a href="' + linkRoot + 'PRIMER_RIGHT_4_PENALTY">Penalty:</a></td>\n';
  retHTML += '    <td class="p3p_oligo_cell">' + Number.parseFloat(res["PRIMER_" + type + "_0_PENALTY"]).toFixed(3);
  retHTML += '</td>\n  </tr>\n';
  // Now the optional fields
  if (res.hasOwnProperty("PRIMER_" + type + "_0_POSITION_PENALTY") &&
      (res["PRIMER_" + type + "_0_POSITION_PENALTY"] != "")) {
    retHTML += '  <tr>\n    <td class="p3p_oligo_cell"><a href="' + linkRoot + 'PRIMER_RIGHT_4_POSITION_PENALTY">Position Penalty:</a></td>\n';
    retHTML += '    <td class="p3p_oligo_cell">' + Number.parseFloat(res["PRIMER_" + type + "_0_POSITION_PENALTY"]).toFixed(3);
    retHTML += '</td>\n  </tr>\n';
  }
  if (res.hasOwnProperty("PRIMER_" + type + "_0_LIBRARY_MISPRIMING") &&
      (res["PRIMER_" + type + "_0_LIBRARY_MISPRIMING"] != "")) {
    retHTML += '  <tr>\n    <td class="p3p_oligo_cell"><a href="' + linkRoot;
    retHTML += 'PRIMER_RIGHT_4_LIBRARY_MISPRIMING">Library Mispriming:</a></td>\n';
    retHTML += '   <td class="p3p_oligo_cell">' + res["PRIMER_" + type + "_0_LIBRARY_MISPRIMING"] + '</td>\n  </tr>\n';
  }
  if (res.hasOwnProperty("PRIMER_" + type + "_0_LIBRARY_MISHYB") &&
      (res["PRIMER_" + type + "_0_LIBRARY_MISHYB"] != "")) {
    retHTML += '  <tr>\n    <td class="p3p_oligo_cell"><a href="' + linkRoot;
    retHTML += 'PRIMER_INTERNAL_4_LIBRARY_MISHYB">Library Mishyb:</a></td>\n';
    retHTML += '   <td class="p3p_oligo_cell">' + res["PRIMER_" + type + "_0_LIBRARY_MISHYB"] + '</td>\n  </tr>\n';
  }
  if (res.hasOwnProperty("PRIMER_" + type + "_0_MIN_SEQ_QUALITY") &&
      (res["PRIMER_" + type + "_0_MIN_SEQ_QUALITY"] != "")) {
    retHTML += '     <tr>\n    <td class="p3p_oligo_cell"><a href="' + linkRoot;
    retHTML += 'PRIMER_RIGHT_4_MIN_SEQ_QUALITY">Min Seq Quality:</a></td>\n';
    retHTML += '   <td class="p3p_oligo_cell">' + res["PRIMER_" + type + "_0_MIN_SEQ_QUALITY"] + '</td>\n  </tr>\n';
  }
  if (res.hasOwnProperty("PRIMER_" + type + "_0_PROBLEMS") &&
      (res["PRIMER_" + type + "_0_PROBLEMS"] != "")) {
    retHTML += '     <tr>\n    <td class="p3p_oligo_cell_problem"><a href="' + linkRoot;
    retHTML += 'PRIMER_RIGHT_4_PROBLEMS">Problems:</a></td>\n';
    retHTML += '   <td class="p3p_oligo_cell_problem">';
    retHTML += res["PRIMER_" + type + "_0_PROBLEMS"] + '</td>\n  </tr>\n';
  }
  retHTML += '</table>\n</div>\n';

  return retHTML;
}

function partCheckSecStruct(res, linkRoot, tag, help, description) {
  var retHTML = "";
  if (res.hasOwnProperty(tag) && (res[tag] != "")) {
      retHTML += '  <tr>\n    <td class="p3p_oligo_cell"><a href="' + linkRoot;
      retHTML += help + '" target="p3p_help">' + description + ':</a></td>\n<td class="p3p_oligo_cell"><pre>\n';
      var secStr = res[tag];
      secStr = secStr.replace(/\\n/g, "\n");
      secStr = secStr.replace(/U\+25(\d\d)/g, "&#x25$1;");
      retHTML += secStr + '</pre></td>\n';
      retHTML += '  </tr>\n  </tr>\n';
    }
  return retHTML;
}

function createResultsDetection(res){
  var ret = createPrimer3ManagerBar();

  var maxPrimers = parseInt(res["PRIMER_PAIR_NUM_RETURNED"]) - 1;
  ret += '<div class="p3p_fit_to_table">\n';
  ret += '  <input value="First Primer Pair" type="button" onclick="changeFirstPrimerPair();"';
  if (selectedPrimerPair < 1) {
    ret += ' disabled';
  }
  ret += '>\n  <input value="Previous Primer Pair" type="button" onclick="changeSelectedPrimerPair(-1);"';
  if (selectedPrimerPair < 1) {
    ret += ' disabled';
  }
  ret += '>\n  <input value="Next Primer Pair" type="button" onclick="changeSelectedPrimerPair(1);"';
  if (selectedPrimerPair > maxPrimers - 1) {
    ret += ' disabled';
  }
  ret += '>\n  <input value="Last Primer Pair" type="button" onclick="changeLastPrimerPair(' + maxPrimers + ');"';
  if (selectedPrimerPair > maxPrimers - 1) {
    ret += ' disabled';
  }
  ret += '>\n</div>\n';

  ret += createPrimerBox(res, selectedPrimerPair);

  ret += '<div class="p3p_fit_to_table">\n';
  ret += '  <input value="First Primer Pair" type="button" onclick="changeFirstPrimerPair();"';
  if (selectedPrimerPair < 1) {
    ret += ' disabled';
  }
  ret += '>\n  <input value="Previous Primer Pair" type="button" onclick="changeSelectedPrimerPair(-1);"';
  if (selectedPrimerPair < 1) {
    ret += ' disabled';
  }
  ret += '>\n  <input value="Next Primer Pair" type="button" onclick="changeSelectedPrimerPair(1);"';
  if (selectedPrimerPair > maxPrimers - 1) {
    ret += ' disabled';
  }
  ret += '>\n  <input value="Last Primer Pair" type="button" onclick="changeLastPrimerPair(' + maxPrimers + ');"';
  if (selectedPrimerPair > maxPrimers - 1) {
    ret += ' disabled';
  }
  ret += '>\n</div>\n';

  ret += createHTMLsequence(res, selectedPrimerPair);
  return ret;
}

window.changeFirstPrimerPair = changeFirstPrimerPair;
function changeFirstPrimerPair() {
  selectedPrimerPair = 0;
  var returnHTML = createResultsDetection(results);
  returnHTML += createPrimerStatistics(results);
  document.getElementById('P3P_RESULTS_BOX').innerHTML = returnHTML;
}

window.changeSelectedPrimerPair = changeSelectedPrimerPair;
function changeSelectedPrimerPair(it) {
  selectedPrimerPair = selectedPrimerPair + it;
  var returnHTML = createResultsDetection(results);
  returnHTML += createPrimerStatistics(results);
  document.getElementById('P3P_RESULTS_BOX').innerHTML = returnHTML;
}

window.changeLastPrimerPair = changeLastPrimerPair;
function changeLastPrimerPair(it) {
  selectedPrimerPair = it;
  var returnHTML = createResultsDetection(results);
  returnHTML += createPrimerStatistics(results);
  document.getElementById('P3P_RESULTS_BOX').innerHTML = returnHTML;
}

function createPrimerBox(res, nr) {
  var retHtml = "";
  var linkRoot = `${HELP_LINK_URL}#`;
  var selection = nr + 1;
  var primerAny = "";
  var primerEnd = "";
  var productTM = "";
  var productOligDiff = "";
  var pairPenalty = "";
  var productMispriming = "";
  var productToA = "";
  
  if (res.hasOwnProperty("PRIMER_PAIR_" + nr + "_PRODUCT_TM") &&
      (res["PRIMER_PAIR_" + nr + "_PRODUCT_TM"] != "")) {
    productTM += '<a href="' + linkRoot + 'PRIMER_PAIR_4_PRODUCT_TM" target="p3p_help">Tm:</a> ';
    productTM += Number.parseFloat(res["PRIMER_PAIR_" + nr + "_PRODUCT_TM"]).toFixed(1);
    productTM += ' C';
  }
  if (res.hasOwnProperty("PRIMER_PAIR_" + nr + "_PRODUCT_TM_OLIGO_TM_DIFF") &&
      (res["PRIMER_PAIR_" + nr + "_PRODUCT_TM_OLIGO_TM_DIFF"] != "")) {
    productOligDiff += '<a href="' + linkRoot + 'PRIMER_PAIR_4_PRODUCT_TM_OLIGO_TM_DIFF" target="p3p_help">dT:</a> ';
    productOligDiff += Number.parseFloat(res["PRIMER_PAIR_" + nr + "_PRODUCT_TM_OLIGO_TM_DIFF"]).toFixed(1);
    productOligDiff += ' C';
  }
  if (res.hasOwnProperty("PRIMER_PAIR_" + nr + "_COMPL_ANY") &&
      (res["PRIMER_PAIR_" + nr + "_COMPL_ANY"] != "")) {
    primerAny += '<a href="' + linkRoot + 'PRIMER_PAIR_4_COMPL_ANY" target="p3p_help">Any:</a> ';
    primerAny += Number.parseFloat(res["PRIMER_PAIR_" + nr + "_COMPL_ANY"]).toFixed(1);
  } else if (res.hasOwnProperty("PRIMER_PAIR_" + nr + "_COMPL_ANY_TH") &&
      (res["PRIMER_PAIR_" + nr + "_COMPL_ANY_TH"] != "")) {
    primerAny += '<a href="' + linkRoot + 'PRIMER_PAIR_4_COMPL_ANY_TH" target="p3p_help">Any:</a> ';
    primerAny += Number.parseFloat(res["PRIMER_PAIR_" + nr + "_COMPL_ANY_TH"]).toFixed(1);
  }
  if (res.hasOwnProperty("PRIMER_PAIR_" + nr + "_COMPL_END") &&
      (res["PRIMER_PAIR_" + nr + "_COMPL_END"] != "")) {
    primerEnd += '<a href="' + linkRoot + 'PRIMER_PAIR_4_COMPL_END" target="p3p_help">End:</a> ';
    primerEnd += Number.parseFloat(res["PRIMER_PAIR_" + nr + "_COMPL_END"]).toFixed(1);
  } else if (res.hasOwnProperty("PRIMER_PAIR_" + nr + "_COMPL_END_TH") &&
      (res["PRIMER_PAIR_" + nr + "_COMPL_END_TH"] != "")) {
    primerEnd += '<a href="' + linkRoot + 'PRIMER_PAIR_4_COMPL_END_TH" target="p3p_help">End:</a> ';
    primerEnd += Number.parseFloat(res["PRIMER_PAIR_" + nr + "_COMPL_END_TH"]).toFixed(1);
  }
  if (res.hasOwnProperty("PRIMER_PAIR_" + nr + "_TEMPLATE_MISPRIMING") &&
      (res["PRIMER_PAIR_" + nr + "_TEMPLATE_MISPRIMING"] != "")) {
    productMispriming += '<a href="' + linkRoot + 'PRIMER_PAIR_4_TEMPLATE_MISPRIMING" target="p3p_help">TB:</a> ';
    productMispriming += Number.parseFloat(res["PRIMER_PAIR_" + nr + "_TEMPLATE_MISPRIMING"]).toFixed(1);
  } else if (res.hasOwnProperty("PRIMER_PAIR_" + nr + "_TEMPLATE_MISPRIMING_TH") &&
      (res["PRIMER_PAIR_" + nr + "_TEMPLATE_MISPRIMING_TH"] != "")) {
    productMispriming += '<a href="' + linkRoot + 'PRIMER_PAIR_4_TEMPLATE_MISPRIMING_TH" target="p3p_help">TB:</a> ';
    productMispriming += Number.parseFloat(res["PRIMER_PAIR_" + nr + "_TEMPLATE_MISPRIMING_TH"]).toFixed(1);
  }
  if (res.hasOwnProperty("PRIMER_PAIR_" + nr + "_T_OPT_A") &&
      (res["PRIMER_PAIR_" + nr + "_T_OPT_A"] != "")) {
    productToA += '<a href="' + linkRoot + 'PRIMER_PAIR_4_T_OPT_A" target="p3p_help">T opt A:</a> ';
    productToA += Number.parseFloat(res["PRIMER_PAIR_" + nr + "_T_OPT_A"]).toFixed(1);
  }
  if (res.hasOwnProperty("PRIMER_PAIR_" + nr + "_PENALTY") &&
      (res["PRIMER_PAIR_" + nr + "_PENALTY"] != "")) {
    pairPenalty += '<a href="' + linkRoot + 'PRIMER_PAIR_4_PENALTY" target="p3p_help">Penalty:</a> ';
    pairPenalty += Number.parseFloat(res["PRIMER_PAIR_" + nr + "_PENALTY"]).toFixed(3);
  }

  retHtml += '<div class="p3p_pair_box_div">\n';
  retHtml += '<table class="p3p_pair_box_table">\n';
  retHtml += '  <colgroup>\n';
  retHtml += '    <col style="width: 11.0%">\n';
  retHtml += '    <col style="width: 2.0%">\n';
  retHtml += '    <col style="width: 9.0%">\n';
  retHtml += '    <col style="width: 9.0%">\n';
  retHtml += '    <col style="width: 9.5%">\n';
  retHtml += '    <col style="width: 9.0%">\n';
  retHtml += '    <col style="width: 7.5%">\n';
  retHtml += '    <col style="width: 7.5%">\n';
  retHtml += '    <col style="width: 6.5%">\n';
  retHtml += '    <col style="width: 7.5%">\n';
  retHtml += '    <col style="width: 9.5%">\n';
  retHtml += '    <col style="width: 11.5%">\n';
  retHtml += '  </colgroup>\n';
  retHtml += '  <tr>\n';
  retHtml += '    <td colspan="12" class="p3p_pair_box_cell">\n';
  retHtml += '      <input id="PRIMER_PAIR_' + nr + '_SELECTED" onchange="updateResultsElement(this);" ';
  if (res.hasOwnProperty("PRIMER_PAIR_" + nr + "_SELECTED") &&
      (res["PRIMER_PAIR_" + nr + "_SELECTED"] == "1")) {
    retHtml += "checked=\"checked\" ";
  }
  retHtml += 'type="checkbox">&nbsp;Pair ' + (nr + 1 ) +':\n      ';
  retHtml += '<input id="PRIMER_PAIR_' + nr + '_NAME" onchange="updateResultsElement(this);" value="';
  retHtml += res["PRIMER_PAIR_" + nr + "_NAME"] + '" size="40" type="text">\n      ';
  retHtml += '</td>\n    </tr>';

  retHtml += partPrimerData(res, nr, "LEFT");
  retHtml += partPrimerData(res, nr, "INTERNAL");
  retHtml += partPrimerData(res, nr, "RIGHT");

  retHtml += '  <tr class="p3p_primer_pair">\n';
  retHtml += '    <td colspan="4" class="p3p_pair_box_cell_s"><strong>Pair:</strong>&nbsp;&nbsp;&nbsp;\n';
  retHtml += '      <a href="' + linkRoot + 'PRIMER_PAIR_4_PRODUCT_SIZE">Product Size:</a>&nbsp;\n';
  retHtml += '&nbsp;' + res["PRIMER_PAIR_" + nr + "_PRODUCT_SIZE"] + ' bp</td>\n';
  retHtml += '    <td class="p3p_pair_box_cell_s">' + productTM + '</td>\n';
  retHtml += '    <td class="p3p_pair_box_cell_s">' + productOligDiff + '</td>\n';
  retHtml += '    <td class="p3p_pair_box_cell_s">' + primerAny + '</td>\n';
  retHtml += '    <td class="p3p_pair_box_cell_s">' + primerEnd + '</td>\n';
  retHtml += '    <td colspan="2" class="p3p_pair_box_cell_s">' + productMispriming + '</td>\n';
  retHtml += '    <td class="p3p_pair_box_cell_s">' + productToA + '</td>\n';
  retHtml += '    <td class="p3p_pair_box_cell_s">' + pairPenalty + '</td>\n';
  retHtml += '  </tr>\n';
  retHtml += partBoxSecStruct(res, linkRoot, "PRIMER_PAIR_" + nr + "_COMPL_ANY_STUCT",
                              "PRIMER_PAIR_4_COMPL_ANY_STUCT", "Compl Any Secondary Structure");
  retHtml += partBoxSecStruct(res, linkRoot, "PRIMER_PAIR_" + nr + "_COMPL_END_STUCT",
                              "PRIMER_PAIR_4_COMPL_END_STUCT", "Compl End Secondary Structure");
  retHtml += '</table>\n';
  retHtml += '</div>\n';
  return retHtml;
}

function partPrimerData(res, nr, type) {
  var linkRoot = `${HELP_LINK_URL}#`;
  var thAdd = "";
  if (res["PRIMER_THERMODYNAMIC_OLIGO_ALIGNMENT"] == 1) {
    thAdd = "_TH";
  }
  var thTmAdd = "";
  if (res["PRIMER_THERMODYNAMIC_TEMPLATE_ALIGNMENT"] == 1) {
    thTmAdd = "_TH";
  }
  var cssName;
  var writeName;
  if (type == "LEFT") {
    cssName = "left_primer";
    writeName = "Left Primer";
  }
  else if (type == "INTERNAL") {
    cssName = "internal_oligo";
    writeName = "Internal Oligo";
  }
  else if (type == "RIGHT") {
    cssName = "right_primer";
    writeName = "Right Primer";
  }
  var retHTML = "";
  if (res.hasOwnProperty("PRIMER_" + type + "_" + nr + "_SEQUENCE") &&
      (res["PRIMER_" + type + "_" + nr + "_SEQUENCE"] != "")) {
    var primerPos = res["PRIMER_" + type + "_" + nr].split(',');
    var primerTM  = Number.parseFloat(res["PRIMER_" + type + "_" + nr + "_TM"]).toFixed(1);
    var primerBound = "--";
    if (res.hasOwnProperty("PRIMER_" + type + "_" + nr + "_BOUND" + thTmAdd)) {
      primerBound = Number.parseFloat(res["PRIMER_" + type + "_" + nr + "_BOUND" + thTmAdd]).toFixed(3);
    }
    var primerGC  = Number.parseFloat(res["PRIMER_" + type + "_" + nr + "_GC_PERCENT"]).toFixed(1);
    var primerAny = Number.parseFloat(res["PRIMER_" + type + "_" + nr + "_SELF_ANY" + thAdd]).toFixed(1);
    var primerEnd = Number.parseFloat(res["PRIMER_" + type + "_" + nr + "_SELF_END" + thAdd]).toFixed(1);
    var primerTemplateBinding = "";
    if (res.hasOwnProperty("PRIMER_" + type + "_" + nr + "_TEMPLATE_MISPRIMING" + thTmAdd)) {
      primerTemplateBinding = Number.parseFloat(res["PRIMER_" + type + "_" + nr + "_TEMPLATE_MISPRIMING" + thTmAdd]).toFixed(1);
    }
    var primerHairpin = "";
    if (res["PRIMER_THERMODYNAMIC_OLIGO_ALIGNMENT"] == "1") {
      primerHairpin = Number.parseFloat(res["PRIMER_" + type + "_" + nr + "_HAIRPIN_TH"]).toFixed(1);
    }
    var primerEndStability = -1.0;
    if (type != "INTERNAL") {
      primerEndStability =Number.parseFloat(res["PRIMER_" + type + "_" + nr + "_END_STABILITY"]).toFixed(1);
    }
    var primerPenalty = Number.parseFloat(res["PRIMER_" + type + "_" + nr + "_PENALTY"]).toFixed(3);

    retHTML += '  <tr class="p3p_' + cssName + '">\n';
    retHTML += '    <td colspan="2" class="p3p_pair_box_cell">&nbsp;' + writeName  + ' ' + (nr +1) + ':</td>\n';
    retHTML += '    <td colspan="10" class="p3p_pair_box_cell">'; 
    retHTML += '<input id="PRIMER_' + type + '_' + nr + '_SEQUENCE" onchange="updateResultsElement(this);" ';
    retHTML += 'value="' + res["PRIMER_" + type + "_" + nr + "_SEQUENCE"] + '" size="90" type="text"></td>\n';
    retHTML += '  </tr>\n';
    retHTML += '  <tr>\n';
    retHTML += '    <td class="p3p_pair_box_cell_s"><a href="' + linkRoot;
    retHTML += 'PRIMER_RIGHT_4" target="p3p_help">Start:</a> ' + primerPos[0] + '</td>\n';
    retHTML += '    <td colspan="2" class="p3p_pair_box_cell_s"><a href="' + linkRoot;
    retHTML += 'PRIMER_RIGHT_4" target="p3p_help">Length:</a> ' + primerPos[1] + ' bp</td>\n';
    retHTML += '    <td class="p3p_pair_box_cell_s"><a href="' + linkRoot;
    retHTML += 'PRIMER_RIGHT_4_TM" target="p3p_help">Tm:</a> ' + primerTM + ' C </td>\n';
    retHTML += '    <td class="p3p_pair_box_cell_s"><a href="' + linkRoot;
    retHTML += 'PRIMER_RIGHT_4_BOUND" target="p3p_help">B:</a> ' + primerBound + ' % </td>\n';
    retHTML += '    <td class="p3p_pair_box_cell_s"><a href="' + linkRoot;
    retHTML += 'PRIMER_RIGHT_4_GC_PERCENT" target="p3p_help">GC:</a> ' + primerGC + ' %</td>\n';
    retHTML += '    <td class="p3p_pair_box_cell_s"><a href="' + linkRoot;
    retHTML += 'PRIMER_RIGHT_4_SELF_ANY' + thAdd + '" target="p3p_help">Any:</a> ' + primerAny + '</td>\n';
    retHTML += '    <td class="p3p_pair_box_cell_s"><a href="' + linkRoot;
    retHTML += 'PRIMER_RIGHT_4_SELF_END' + thAdd + '" target="p3p_help">End:</a> ' + primerEnd + '</td>\n';
    retHTML += '    <td class="p3p_pair_box_cell_s"><a href="' + linkRoot;
    retHTML += 'PRIMER_RIGHT_4_TEMPLATE_MISPRIMING' + thTmAdd +'" target="p3p_help">TB:</a> ' + primerTemplateBinding + '</td>\n';
    retHTML += '    <td class="p3p_pair_box_cell_s">';
    if (res["PRIMER_THERMODYNAMIC_OLIGO_ALIGNMENT"] == "1") {
      retHTML += '<a href="' + linkRoot + 'PRIMER_RIGHT_4_HAIRPIN_TH">HP:</a> ' + primerHairpin;
    }
    retHTML += '</td>\n';
    retHTML += '    <td class="p3p_pair_box_cell_s">';
    if (type != "INTERNAL") {
      retHTML += '<a href="' + linkRoot + 'PRIMER_RIGHT_4_END_STABILITY" target="p3p_help">3\' Stab:</a> ' + primerEndStability;
    } else {
      if (("PRIMER_INTERNAL_" + nr + "_REVERSE_COMPLEMENTED" in res) &&
          (res["PRIMER_INTERNAL_" + nr + "_REVERSE_COMPLEMENTED"] == 1)) {
        retHTML += '<a href="' + linkRoot + 'PRIMER_INTERNAL_4_REVERSE_COMPLEMENTED" target="p3p_help">RevComp</a> ';
      }
    }
    retHTML += '</td>\n';
    retHTML += '    <td class="p3p_pair_box_cell_s"><a href="' + linkRoot;
    retHTML += 'PRIMER_RIGHT_4_PENALTY" target="p3p_help">Penalty:</a> ' + primerPenalty + '</td>\n';
    retHTML += '  </tr>\n';

    retHTML += partBoxSecStruct(res, linkRoot, "PRIMER_" + type + "_" + nr + "_SELF_ANY_STUCT",
                                "PRIMER_RIGHT_4_SELF_ANY_STUCT", "Self Any Secondary Structure");
    retHTML += partBoxSecStruct(res, linkRoot, "PRIMER_" + type + "_" + nr + "_SELF_END_STUCT",
                                "PRIMER_RIGHT_4_SELF_END_STUCT", "Self End Secondary Structure");
    retHTML += partBoxSecStruct(res, linkRoot, "PRIMER_" + type + "_" + nr + "_HAIRPIN_STUCT",
                                "PRIMER_RIGHT_4_HAIRPIN_STUCT", "Hairpin Secondary Structure");

    if ((res.hasOwnProperty("PRIMER_" + type + "_" + nr + "_POSITION_PENALTY") &&
        (res["PRIMER_" + type + "_" + nr + "_POSITION_PENALTY"] != "")) ||
        (res.hasOwnProperty("PRIMER_" + type + "_" + nr + "_MIN_SEQ_QUALITY") &&
        (res["PRIMER_" + type + "_" + nr + "_MIN_SEQ_QUALITY"] != ""))) {
      var primerPosPen = "";
      var primerMinSeqQual = "";
      if (res.hasOwnProperty("PRIMER_" + type + "_" + nr + "_POSITION_PENALTY") &&
          (res["PRIMER_" + type + "_" + nr + "_POSITION_PENALTY"] != "")) {
        primerPosPen = '<a href="' + linkRoot + 'PRIMER_RIGHT_4_POSITION_PENALTY" target="p3p_help">Position Penalty:</a>&nbsp;&nbsp;';
        primerPosPen += res["PRIMER_" + type + "_" + nr + "_POSITION_PENALTY"];
      }
      if (res.hasOwnProperty("PRIMER_" + type + "_" + nr + "_MIN_SEQ_QUALITY") &&
          (res["PRIMER_" + type + "_" + nr + "_MIN_SEQ_QUALITY"] != "")) {
        primerMinSeqQual = '<a href="' + linkRoot + 'PRIMER_RIGHT_4_MIN_SEQ_QUALITY" target="p3p_help">Min Seq Quality:</a>&nbsp;&nbsp;';
        primerMinSeqQual += res["PRIMER_" + type + "_" + nr + "_MIN_SEQ_QUALITY"];
      }
      retHTML += '  <tr>\n';
      retHTML += '    <td colspan="3" class="p3p_pair_box_cell">' + primerPosPen + '</td>\n';
      retHTML += '    <td colspan="2" class="p3p_pair_box_cell">' + primerMinSeqQual + '</td>\n';
      retHTML += '    <td class="p3p_pair_box_cell"></td>\n';
      retHTML += '    <td class="p3p_pair_box_cell"></td>\n';
      retHTML += '    <td class="p3p_pair_box_cell"></td>\n';
      retHTML += '    <td class="p3p_pair_box_cell"></td>\n';
      retHTML += '    <td class="p3p_pair_box_cell"></td>\n';
      retHTML += '    <td class="p3p_pair_box_cell"></td>\n';
      retHTML += '  </tr>\n';
    }
    if (res.hasOwnProperty("PRIMER_" + type + "_" + nr + "_LIBRARY_MISPRIMING") &&
        (res["PRIMER_" + type + "_" + nr + "_LIBRARY_MISPRIMING"] != "")) {
      retHTML += '  <tr>\n';
      retHTML += '    <td colspan="12" class="p3p_pair_box_cell">';
      retHTML += '<a href="' + linkRoot + 'PRIMER_RIGHT_4_LIBRARY_MISPRIMING" target="p3p_help">Library Mispriming:</a>&nbsp;';
      retHTML += res["PRIMER_" + type + "_" + nr + "_LIBRARY_MISPRIMING"] + '</td>\n';
      retHTML += '  </tr>\n';
    }

    if (res.hasOwnProperty("PRIMER_" + type + "_" + nr + "_LIBRARY_MISHYB") &&
        (res["PRIMER_" + type + "_" + nr + "_LIBRARY_MISHYB"] != "")) {
      retHTML += '  <tr>\n';
      retHTML += '    <td colspan="12" class="p3p_pair_box_cell">';
      retHTML += '<a href="' + linkRoot + 'PRIMER_INTERNAL_4_LIBRARY_MISHYB" target="p3p_help">Library Mishyb:</a>&nbsp;';
      retHTML += res["PRIMER_" + type + "_" + nr + "_LIBRARY_MISHYB"] + '</td>\n';
      retHTML += '  </tr>\n';
    }
    if (res.hasOwnProperty("PRIMER_" + type + "_" + nr + "_PROBLEMS") && 
	 	(res["PRIMER_" + type + "_" + nr + "_PROBLEMS"] != "")) {
      retHTML += '  <tr>\n';
      retHTML += '    <td class="primer3plus_cell_no_border_problem" colspan="2"><a href="';
      retHTML += linkRoot + 'PRIMER_RIGHT_4_PROBLEMS" target="p3p_help">Problems:</a></td>\n';
      retHTML += '    <td class="primer3plus_cell_no_border_problem" colspan="9">' + res["PRIMER_" + type + "_" + nr + "_PROBLEMS"] + '</td>\n';
      retHTML += '  </tr>\n';
    }
  }
  return retHTML;
}

function partBoxSecStruct(res, linkRoot, tag, help, description) {
  var retHTML = "";
  if (res.hasOwnProperty(tag) && (res[tag] != "")) {
      retHTML += '  <tr>\n';
      retHTML += '    <td colspan="12" class="p3p_pair_box_cell">';
      retHTML += '<a href="' + linkRoot + help + '" target="p3p_help">' + description + ':</a><br />\n<pre>\n   ';
      var secStr = res[tag];
      secStr = secStr.replace(/\\n/g, "\n   ");
      secStr = secStr.replace(/U\+25(\d\d)/g, "&#x25$1;");
      retHTML += secStr + '</pre></td>\n';
      retHTML += '  </tr>\n';
    }
  return retHTML;
}

function createHTMLsequence(res, primerNr) {
  // primerNr 
  //   > 0  -- Mark the indicated Primer Pair
  //    -1  -- Mark no Primers
  //    -2  -- Mark all Primers
  if (!(res.hasOwnProperty("SEQUENCE_TEMPLATE")) ||
      (res["SEQUENCE_TEMPLATE"] == "")) {
    return "";
  }      
  var seq = res["SEQUENCE_TEMPLATE"];
  var format = seq.replace(/\w/g, "N");
  var firstBase = parseInt(res["PRIMER_FIRST_BASE_INDEX"]);
  var targets;
  if (res.hasOwnProperty("SEQUENCE_INCLUDED_REGION") &&
      (res["SEQUENCE_INCLUDED_REGION"] != "")) {
    format = addRegion(format,res["SEQUENCE_INCLUDED_REGION"],firstBase,"I");
  }
  if (res.hasOwnProperty("SEQUENCE_EXCLUDED_REGION") &&
      (res["SEQUENCE_EXCLUDED_REGION"] != "")) {
    targets = res["SEQUENCE_EXCLUDED_REGION"].split(' ');
    for(var i = 0 ; i < targets.length ; i++) {
      format = addRegion(format,targets[i],firstBase,"E");
    }
  }
  if (res.hasOwnProperty("SEQUENCE_TARGET") &&
      (res["SEQUENCE_TARGET"] != "")) {
    targets = res["SEQUENCE_TARGET"].split(' ');
    for(var i = 0 ; i < targets.length ; i++) {
      format = addRegion(format,targets[i],firstBase,"T");
    }
  }
  // Add Primers if needed
  if (primerNr >= 0) {
    // Add only one primer pair e.g. Detection
    if (res.hasOwnProperty("PRIMER_INTERNAL_" + primerNr) &&
        (res["PRIMER_INTERNAL_" + primerNr] != "")) {
      format = addRegion(format,res["PRIMER_INTERNAL_" + primerNr],firstBase,"O");
    }
    if (res.hasOwnProperty("PRIMER_RIGHT_" + primerNr) &&
        (res["PRIMER_RIGHT_" + primerNr] != "")) {
      format = addRegion(format,res["PRIMER_RIGHT_" + primerNr],firstBase,"R");
    }
    if (res.hasOwnProperty("PRIMER_LEFT_" + primerNr) &&
        (res["PRIMER_LEFT_" + primerNr] != "")) {
      format = addRegion(format,res["PRIMER_LEFT_" + primerNr],firstBase,"F");
    }
  }
  else if (primerNr == -2) {
    // Mark all primers on the sequence e.g. Sequencing
    var counter = 0;
    while (res.hasOwnProperty("PRIMER_INTERNAL_" + counter)) {
      format = addRegion(format,res["PRIMER_INTERNAL_" + counter],firstBase,"O");
      counter++;
    }
    counter = 0;
    while (res.hasOwnProperty("PRIMER_RIGHT_" + counter)) {
      format = addRegion(format,res["PRIMER_RIGHT_" + counter],firstBase,"R");
      counter++;
    }
    counter = 0;
    while (res.hasOwnProperty("PRIMER_LEFT_" + counter)) {
      format = addRegion(format,res["PRIMER_LEFT_" + counter],firstBase,"F");
      counter++;
    }
  }  
  if (res.hasOwnProperty("SEQUENCE_OVERLAP_JUNCTION_LIST") &&
      (res["SEQUENCE_OVERLAP_JUNCTION_LIST"] != "")) {
    targets = res["SEQUENCE_OVERLAP_JUNCTION_LIST"].split(' ');
    for(var i = 0 ; i < targets.length ; i++) {
      format = addRegion(format,"" + (parseInt(targets[i]) - 1) + ",2",firstBase,"-");
    }
  }

  // Handy for testing:
  // seq = format;
    
  var resHTML = '<div class="p3p_result_sequence">\n<table>\n';
  resHTML += '  <colgroup>\n';
  resHTML += '    <col style="width: 13%;">\n';
  resHTML += '    <col style="width: 87%">\n';
  resHTML += '  </colgroup>\n';

  var preFormat = "J";
  for (var i = 0 ; i < seq.length ; i++) {
    var base = seq.charAt(i);
    var baseFormat = format.charAt(i);
    if ((i % 50) == 0) {
      resHTML += '  <tr>\n    <td style="text-align: right;">' + (i + firstBase) + '&nbsp;&nbsp;</td>\n    <td>';
    }
    if (preFormat != baseFormat) {
      if (preFormat != "J") {
        resHTML += '</a>';
      }
    }
    if (((i % 10) == 0) && !((i % 50) == 0)) {
      resHTML += '&nbsp;&nbsp;';
    }
    if (preFormat != baseFormat) {
      if (baseFormat == "N") {
        resHTML += '<a>';
      } else if (baseFormat == "E") {
        resHTML += '<a class="p3p_excluded_region">';
      } else if (baseFormat == "T") {
        resHTML += '<a class="p3p_target">';
      } else if (baseFormat == "I") {
        resHTML += '<a class="p3p_included_region">';
      } else if (baseFormat == "F") {
        resHTML += '<a class="p3p_left_primer">';
      } else if (baseFormat == "O") {
        resHTML += '<a class="p3p_internal_oligo">';
      } else if (baseFormat == "R") {
        resHTML += '<a class="p3p_right_primer">';
      } else if (baseFormat == "B") {
        resHTML += '<a class="p3p_left_right_primer">';
      } else if (baseFormat == "-") {
        resHTML += '<a class="p3p_primer_overlap_pos">';
      }
      preFormat = baseFormat;
    }
    resHTML += base;
    if (((i + 1) % 50) == 0) {
      // If the next is a linebreak end the <a> in new round
      resHTML += '</a></td>\n  </tr>\n';
      preFormat = "J";
    }
  }
  if ((seq.length % 50) != 0) {
    resHTML += '</a></td>\n  </tr>\n';
  }
  resHTML += '</table></div>\n';
  return resHTML;
}

function addRegion(formatString, region, firstBase, letter) {
  var reg = region.split(',');
  var regionStart  = parseInt(reg[0].replace(/\s/g, "")) - firstBase;
  var regionLength = parseInt(reg[1].replace(/\s/g, ""));
  if (regionStart < 0) {
    regionLength = regionLength - regionStart;
    regionStart = 0;
  }
  if (letter == "R") {
    regionStart = regionStart - regionLength + 1;  
  }
  var regionEnd = regionStart + regionLength;
  if (regionEnd > formatString.length) { // check for -1 !! todo
    regionEnd = formatString.length;
  }
  var ret = formatString.substring(0, regionStart);
  var toMod = formatString.substring(regionStart,regionEnd);
  if ((letter != "F") && (letter != "R")) {
    toMod = toMod.replace(/\w/g, letter);
  }
  if (letter == "F") {
    toMod = toMod.replace(/[^RB]/g, "F");
    toMod = toMod.replace(/R/g, "B");
  }
  if  (letter == "R") {
    toMod = toMod.replace(/[^FB]/g, "R");
    toMod = toMod.replace(/F/g, "B");
  }
  ret += toMod;
  ret += formatString.substring(regionEnd); 
  return ret;
}

function createResultsPrimerList (res, printSeqStyle) {
  var retHTML = createPrimer3ManagerBar();
  if (res.hasOwnProperty("PRIMER_LEFT_0_SEQUENCE")) {
    retHTML += '<h2 class="primer3plus_left_primer" style="padding-left: 15px">Left Primers:</h2>\n';
    retHTML += divLongList(res,"LEFT");
  }
  if (res.hasOwnProperty("PRIMER_INTERNAL_0_SEQUENCE")) {
    retHTML += '<h2 class="primer3plus_internal_oligo" style="padding-left: 15px">Internal Oligos:</h2>\n';
    retHTML += divLongList(res,"INTERNAL");
  }
  if (res.hasOwnProperty("PRIMER_RIGHT_0_SEQUENCE")) {
    retHTML += '<h2 class="primer3plus_right_primer" style="padding-left: 15px">Right Primers:</h2>\n';
    retHTML += divLongList(res,"RIGHT");
  }
  retHTML += createHTMLsequence(res, printSeqStyle);
  return retHTML;
}

function divLongList (res, primerType) {
  var linkRoot = `{HELP_LINK_URL}#`;
  var thAdd = "";
  if (res["PRIMER_THERMODYNAMIC_OLIGO_ALIGNMENT"] == "1") {
  	  thAdd = "_TH";
  }
  var thTmAdd = "";
  if (res["PRIMER_THERMODYNAMIC_TEMPLATE_ALIGNMENT"] == "1") {
  	  thTmAdd = "_TH";
  }
  var retHTML = '<div class="p3p_long_list">\n<table class="p3p_long_list_table">\n';
  retHTML += '  <colgroup>\n';
  retHTML += '    <col style="width: 16%">\n';
  retHTML += '    <col style="width: 28%">\n';
  retHTML += '    <col style="width: 6.5%;">\n';
  retHTML += '    <col style="width: 6.5%;">\n';
  retHTML += '    <col style="width: 6.0%;">\n';
  retHTML += '    <col style="width: 6.5%;">\n';
  retHTML += '    <col style="width: 5.5%;">\n';
  retHTML += '    <col style="width: 5.5%;">\n';
  retHTML += '    <col style="width: 6.5%;">\n';
  retHTML += '    <col style="width: 6.5%;">\n';
  retHTML += '    <col style="width: 7.5%;">\n';
  retHTML += '  </colgroup>\n';
  retHTML += '  <tr>\n';
  retHTML += '    <td class="p3p_cell_long_list_l">&nbsp; &nbsp; &nbsp; &nbsp; Name</td>\n';
  retHTML += '    <td class="p3p_cell_long_list_l">Sequence</td>\n';
  retHTML += '    <td class="p3p_cell_long_list_r"><a href="' + linkRoot + 'PRIMER_RIGHT_4">Start</a></td>\n';
  retHTML += '    <td class="p3p_cell_long_list_r"><a href="' + linkRoot + 'PRIMER_RIGHT_4">Length</a></td>\n';
  retHTML += '    <td class="p3p_cell_long_list_r"><a href="' + linkRoot + 'PRIMER_RIGHT_4_TM">Tm</a></td>\n';
  retHTML += '    <td class="p3p_cell_long_list_r"><a href="' + linkRoot + 'PRIMER_RIGHT_4_GC_PERCENT">GC %</a></td>\n';
  retHTML += '    <td class="p3p_cell_long_list_r"><a href="' + linkRoot + 'PRIMER_RIGHT_4_SELF_ANY' + thAdd + '">Any</a></td>\n';
  retHTML += '    <td class="p3p_cell_long_list_r"><a href="' + linkRoot + 'PRIMER_RIGHT_4_SELF_END' + thAdd + '">End</a></td>\n';
  retHTML += '    <td class="p3p_cell_long_list_r"><a href="' + linkRoot + 'PRIMER_RIGHT_4_TEMPLATE_MISPRIMING' + thAdd + '">TB</a></td>\n';
  retHTML += '    <td class="p3p_cell_long_list_r">'
  if (primerType != "INTERNAL") {
    retHTML += '<a href="' + linkRoot + 'PRIMER_RIGHT_4_END_STABILITY">3\' Stab</a>';
  } else {
    retHTML += '<a href="' + linkRoot + 'PRIMER_INTERNAL_4_REVERSE_COMPLEMENTED" target="p3p_help">Rev</a> ';
  }
  retHTML += '</td>\n';
  retHTML += '    <td class="p3p_cell_long_list_r"><a href="' + linkRoot + 'PRIMER_RIGHT_4_PENALTY">Penalty</a></td>\n';
  retHTML += '  </tr>\n';
  var counter = 0;
  while ((res.hasOwnProperty("PRIMER_" + primerType + "_" + counter)) && (counter < 500)) {
    var primerPos = res["PRIMER_" + primerType + "_" + counter].split(',');
    retHTML += '  <tr>\n    <td class="p3p_cell_long_list_l">';
    retHTML += '<input id="PRIMER_' + primerType + "_" + counter + '_SELECTED" onchange="updateResultsElement(this);" type="checkbox">&nbsp;';
    retHTML += '<input id="PRIMER_' + primerType + "_" + counter + '_NAME" onchange="updateResultsElement(this);"';
    retHTML += 'value="' + res["PRIMER_" + primerType + "_" + counter + "_NAME"] + '" size="10" type="text"></td>\n';
    retHTML += '    <td class="p3p_cell_long_list_l"><input id="PRIMER_' + primerType + "_" + counter + '_SEQUENCE" onchange="updateResultsElement(this);" value="';
    retHTML += res["PRIMER_" + primerType + "_" + counter + "_SEQUENCE"] + '" size="30" type="text"></td>\n';
    retHTML += '    <td class="p3p_cell_long_list_r">' + primerPos[0] + '</td>\n';
    retHTML += '    <td class="p3p_cell_long_list_r">' + primerPos[1] + '</td>\n';
    retHTML += '    <td class="p3p_cell_long_list_r">' + Number.parseFloat(res["PRIMER_" + primerType + "_" + counter + "_TM"]).toFixed(1) + '</td>\n';
    retHTML += '    <td class="p3p_cell_long_list_r">' + Number.parseFloat(res["PRIMER_" + primerType + "_" + counter + "_GC_PERCENT"]).toFixed(1) + '</td>\n';
    retHTML += '    <td class="p3p_cell_long_list_r">' + Number.parseFloat(res["PRIMER_" + primerType + "_" + counter + "_SELF_ANY" + thAdd]).toFixed(1) + '</td>\n';
    retHTML += '    <td class="p3p_cell_long_list_r">' + Number.parseFloat(res["PRIMER_" + primerType + "_" + counter + "_SELF_END" + thAdd]).toFixed(1) + '</td>\n';
    var primerTemplateBinding = "";
    if (res.hasOwnProperty("PRIMER_" + primerType + "_" + counter + "_TEMPLATE_MISPRIMING" + thTmAdd)) {
      primerTemplateBinding = Number.parseFloat(res["PRIMER_" + primerType + "_" + counter + "_TEMPLATE_MISPRIMING" + thTmAdd]).toFixed(1);
    }
    retHTML += '    <td class="p3p_cell_long_list_r">' + primerTemplateBinding + '</td>\n';
    retHTML += '    <td class="p3p_cell_long_list_r">';
    if (primerType != "INTERNAL") {
      retHTML += Number.parseFloat(res["PRIMER_" + primerType + "_" + counter + "_END_STABILITY"]).toFixed(1);
    } else {
      if (("PRIMER_INTERNAL_" + counter + "_REVERSE_COMPLEMENTED" in res) &&
          (res["PRIMER_INTERNAL_" + counter + "_REVERSE_COMPLEMENTED"] == 1)) {
        retHTML += 'Rev';
      }
    }
    retHTML += '</td>\n';
    retHTML += '    <td class="p3p_cell_long_list_r">' + Number.parseFloat(res["PRIMER_" + primerType + "_" + counter + "_PENALTY"]).toFixed(3) + '</td>\n';
    retHTML += '  </tr>\n';
    counter++;
  }
  retHTML += '</table>\n</div>\n';
  retHTML += '<br>\n';
  return retHTML;
}

function createPrimerStatistics(res) {
  var retHTML = '<div id="p3p_statictics">\n<table class="p3p_table_with_border">\n';
  retHTML += '  <colgroup>\n';
  retHTML += '    <col style="width: 20%">\n';
  retHTML += '    <col style="width: 80%">\n';
  retHTML += '  </colgroup>\n';
  retHTML += '  <tr>\n';
  retHTML += '    <td class="p3p_cell_with_border" colspan="2">Statistics:</td>\n';
  retHTML += '  </tr>\n';
  var content = createPrimerStatisticsPart(res,"PRIMER_LEFT_EXPLAIN", "Left Primer");
  content += createPrimerStatisticsPart(res,"PRIMER_INTERNAL_EXPLAIN", "Internal Oligo");
  content += createPrimerStatisticsPart(res,"PRIMER_RIGHT_EXPLAIN", "Right Primer");
  content += createPrimerStatisticsPart(res,"PRIMER_PAIR_EXPLAIN", "Primer Pair");
  if (content == ""){
    return "";
  } else {
    retHTML += content;
    retHTML += '</table>\n</div>\n';
    return retHTML;
  }
}

function createPrimerStatisticsPart(res,type,name) {
  var retHTML = "";
  if (res.hasOwnProperty(type) && (res[type] != "")) {
    retHTML += '  <tr>\n';
    retHTML += '    <td class="p3p_cell_with_border">' + name + ':</td>\n';
    retHTML += '    <td class="p3p_cell_with_border">' + res[type] + '</td>\n';
    retHTML += '  </tr>\n';
  }
  return retHTML;
}

function calcP3PResultAdditions(){
  // Name the primers
  var acLeft  = saveGetTag("P3P_PRIMER_NAME_ACRONYM_LEFT");
  var acRight = saveGetTag("P3P_PRIMER_NAME_ACRONYM_RIGHT");
  var acOligo = saveGetTag("P3P_PRIMER_NAME_ACRONYM_INTERNAL");
  var acSpace = saveGetTag("P3P_PRIMER_NAME_ACRONYM_SPACER");
  var seqName = saveGetTag("SEQUENCE_ID");
  var task    = saveGetTag("PRIMER_TASK");
  if (seqName.length > 2 ) {
    seqName = seqName.replace(/ /, "_");
  } else {
    seqName = "Primer";
  }
  if (results.hasOwnProperty("PRIMER_PAIR_NUM_RETURNED") && (parseInt(results["PRIMER_PAIR_NUM_RETURNED"]) > 0 )) {
    var seq = results["SEQUENCE_TEMPLATE"];
    var fistBase = parseInt(saveGetTag("PRIMER_FIRST_BASE_INDEX"));  
    for (var pairCount = 0 ; pairCount < parseInt(results["PRIMER_PAIR_NUM_RETURNED"]) ; pairCount++) {
      // Add the amplicons
      var left  = results["PRIMER_LEFT_" + pairCount].split(',');
      var right = results["PRIMER_RIGHT_" + pairCount].split(',');    
      var start = parseInt(left[0]) + parseInt(left[1]) - fistBase;
      var end   = parseInt(right[0]) - parseInt(right[1]) - fistBase + 1;
      var amp   = seq.substring(start, end);
      results["PRIMER_PAIR_" + pairCount + "_AMPLICON"] = amp;
      // Add the name
      var nameKeyValue = seqName;
      if ( pairCount != "0" ) {
        nameKeyValue += acSpace + (parseInt(pairCount) + 1);
      }
      results["PRIMER_PAIR_" + pairCount + "_NAME"] = nameKeyValue;
      // Add select value
      var selValue = "0";
      if ( pairCount == 0 ) {
        selValue = "1";
      }
      results["PRIMER_PAIR_" + pairCount + "_SELECTED"] = selValue;
    }
  } else {
    for (var tag in results) {
      if(tag.endsWith("_SEQUENCE")){
        // Add the name
        var nameKeyComplete = tag.split('_');
        var namePrimerType = nameKeyComplete[1];
        var nameNumber = nameKeyComplete[2];
        var nameKeyName = tag.replace(/SEQUENCE$/, "NAME");
        var nameKeyValue = seqName;
        if ( nameNumber != "0" ) {
          nameKeyValue += acSpace + (parseInt(nameNumber) + 1);
        }
        if (namePrimerType == "RIGHT" ) {
          nameKeyValue += acSpace + acRight;
        } else if (namePrimerType == "INTERNAL") {
          nameKeyValue += acSpace + acOligo;
        } else if (namePrimerType == "LEFT") {
          nameKeyValue += acSpace + acLeft;
        } else {
          nameKeyValue += "??";
        }
        results[nameKeyName] = nameKeyValue;
        // Add select value
        nameKeyName = tag.replace(/SEQUENCE$/, "SELECTED");
        if (task == "pick_sequencing_primers") {
          results[nameKeyName] = "1";
	} else {
          results[nameKeyName] = "0";
        }
      }
    }
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

function initElements(){
  addServerFiles();
  linkHelpTags();
  initTabFunctionality();
  initResetDefautl();
  initRunPrimer3();
  initRunAmplicon3();  
  initRunPrefold();
  initTaskFunctionality();
  initLoadSeqFile();
  initSaveFile();
  initLoadExample();
  initLoadAmplicon();
  initSelectionFeature();
  initExplainSeqRegions();
  initLoadSetFile();
  initLoadAllFile();
  init_message_buttons();
  initDebug();
  init_primer3_versions();
  initLoadCompareFunct();
}

function updateInterface(){
  var res = document.getElementById('P3P_SEL_TAB_RESULTS');
  if (res !== null) {
    browseTabFunctionality('P3P_TAB_MAIN');	  
    res.style.display="none";
  }
  showTaskSelection();
}

function linkHelpTags() {
  var linkRoot = `${HELP_LINK_URL}#`;
  for (var tag in defSet) {
    if (defSet.hasOwnProperty(tag)) {
      var pageElement = document.getElementById(tag + '_HELP');
      if (pageElement !== null) {
        pageElement.href = linkRoot + tag;
        pageElement.target = "p3p_help";
      } else {
        if (debugMode > 1) {
          if (!(ignore_tags.includes(tag)) && !(tag.startsWith("P3_"))) {
            add_message("warn","Missing help element for tag " + tag + "!");
          }
        }
      }
    }
  }
  if (debugMode > 1) {
    var all_elements = document.querySelectorAll('*[id]');
    for (var i = 0; i < all_elements.length; ++i) {
      var id_s = all_elements[i].id;
      if ((id_s.startsWith("SEQUENCE_")) || (id_s.startsWith("PRIMER_")) || 
          (id_s.startsWith("P3_"))) {
          if (ignore_tags.includes(id_s)) {
            continue;
          }
          if (defSet.hasOwnProperty(id_s)) {
            continue;
          }
          if (id_s.endsWith("_HELP")) {
            continue;
          }
          add_message("warn","No data for tag " + id_s + "!");
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

function blaParameters() {
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

function saveGetTag(tag){
  var res = getHtmlTagValue(tag);
  if (res === null) {
    if (defSet.hasOwnProperty(tag)) {
      return defSet[tag];
    } else {
      return null;
    }       
  } else {
    return res;
  }
}

function getHtmlTagValue(tag) {
  if (tag.startsWith("P3_")) {
    return null;
  }
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

function setHTMLParameters(para) {
  currSet = {};
  for (var tag in para) {
    if (para.hasOwnProperty(tag)) {
      currSet[tag] = para[tag][0];
      setHtmlTagValue(tag, para[tag][0]);	     
    }
  }
}

function setHtmlTagValue(tag, value) {
  if (tag.startsWith("P3_")) {
    return true;
  }
  if (ignore_tags.includes(tag)) {
    return true;
  }
  if (tag == "SEQUENCE_TEMPLATE") {
    if (value == "") {
      emptySeq = true;
    } else {
      emptySeq = false;
    }
  }
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

function initSelectionFeature() {
  var btExcluded = document.getElementById('P3P_ACTION_SEL_EXCLUDED');
  if (btExcluded !== null) {
    btExcluded.addEventListener('click', function(){setSelectionRegion("SEQUENCE_EXCLUDED_REGION")});
  }
  var btTarget = document.getElementById('P3P_ACTION_SEL_TARGET');
  if (btTarget !== null) {
    btTarget.addEventListener('click', function(){setSelectionRegion("SEQUENCE_TARGET")});
  }
  var btIncluded = document.getElementById('P3P_ACTION_SEL_INCLUDED');
  if (btIncluded !== null) {
    btIncluded.addEventListener('click', function(){setSelectionRegion("SEQUENCE_INCLUDED_REGION")});
  }
  var btClear = document.getElementById('P3P_ACTION_SEL_CLEAR');
  if (btClear !== null) {
    btClear.addEventListener('click', clearSelectionRegion);
  }
  var btRegFrSeq = document.getElementById('P3P_ACTION_SEL_Reg_F_SEQ');
  if (btRegFrSeq !== null) {
    btRegFrSeq.addEventListener('click', readRegionsfromSeq);
  }
  var fieldExcluded = document.getElementById('SEQUENCE_EXCLUDED_REGION');
  if (fieldExcluded !== null) {
    fieldExcluded.addEventListener('focusout', function(){createSeqWithDeco(-1);});
  }
  var fieldTarget = document.getElementById('SEQUENCE_TARGET');
  if (fieldTarget !== null) {
    fieldTarget.addEventListener('focusout', function(){createSeqWithDeco(-1);});
  }
  var fieldIncluded = document.getElementById('SEQUENCE_INCLUDED_REGION');
  if (fieldIncluded !== null) {
    fieldIncluded.addEventListener('focusout', function(){createSeqWithDeco(-1);});
  }
  var fieldOverlap = document.getElementById('SEQUENCE_OVERLAP_JUNCTION_LIST');
  if (fieldOverlap !== null) {
    fieldOverlap.addEventListener('focusout', function(){createSeqWithDeco(-1);});
  }
  var seq = document.getElementById('SEQUENCE_TEMPLATE');
  if (seq !== null) {
    seq.addEventListener('change',checkRegionsfromSeq);
    seq.addEventListener('keyup', function (event) {
      if (event.key == "-") {
        event.preventDefault();
        var seqBox = document.getElementById("SEQUENCE_TEMPLATE");
        var start = cleanSeq(seqBox.value.substring(0, seqBox.selectionStart));
        var firstBase = 0;
        if (getHtmlTagValue("PRIMER_FIRST_BASE_INDEX")) {
          firstBase = parseInt(getHtmlTagValue("PRIMER_FIRST_BASE_INDEX"));
        }
        var pos = start.length + firstBase;
        var addField = document.getElementById("SEQUENCE_OVERLAP_JUNCTION_LIST");
        if (addField !== null) {
          var con = addField.value;
          if (con == "") {
            addField.value = pos;
          } else {
            addField.value = con + " " + pos;
          }
        }
        createSeqWithDeco(pos);
      }
    });
  }
}

function checkRegionsfromSeq() {
  if (getHtmlTagValue("SEQUENCE_TEMPLATE") != null) {
    seq = getHtmlTagValue("SEQUENCE_TEMPLATE");
    if (seq == "") {
      emptySeq = true;
    } else {
      if (emptySeq == true) {
        readRegionsfromSeq()
      }
      emptySeq = false;
    }
  }
}

function readRegionsfromSeq() {
  var seq = document.getElementById("SEQUENCE_TEMPLATE").value;
  var seqPos = 0;
  if (getHtmlTagValue("PRIMER_FIRST_BASE_INDEX")) {
    seqPos = parseInt(getHtmlTagValue("PRIMER_FIRST_BASE_INDEX"));
  }
  var exc = "";
  var tar = "";
  var inc = "";
  var ovl = "";
  var exc_open = 0;
  var tar_open = 0;
  var inc_open = 0;
  var exc_sec = 0;
  var tar_sec = 0;
  var inc_sec = 0;
  for (var i = 0 ; i < seq.length ; i++) {
    var letter = seq.charAt(i);
    if (letter.match(/[ACGTNacgtn]/)) {
      seqPos++;
      exc_sec++;
      tar_sec++;
      inc_sec++;
    }
    if ((letter == '<') && (exc_open == 0)) {
      exc_sec = 0;
      exc_open = 1;
      exc += seqPos + ",";
    }
    if ((letter == '>') && (exc_open == 1)) {
      exc_open = 0;
      exc += exc_sec + " ";
    }
    if ((letter == '[') && (tar_open == 0)) {
      tar_sec = 0;
      tar_open = 1;
      tar += seqPos + ",";
    }
    if ((letter == ']') && (tar_open == 1)) {
      tar_open = 0;
      tar += tar_sec + " ";
    }
    if ((letter == '{') && (inc_open == 0)) {
      inc_sec = 0;
      inc_open = 1;
      inc += seqPos + ",";
    }
    if ((letter == '}') && (inc_open == 1)) {
      inc_open = 2;
      inc += inc_sec + " ";
    }
    if (letter == '-') {
      ovl += seqPos + " ";
    }
  }
  if (exc_open == 1) {
    exc += exc_sec + " ";
  }
  if (tar_open == 1) {
    tar += tar_sec + " ";
  }
  if (inc_open == 1) {
    inc += inc_sec + " ";
  }
  var excBox = document.getElementById("SEQUENCE_EXCLUDED_REGION");
  if (excBox) {
    excBox.value = exc;
  }
  var tarBox = document.getElementById("SEQUENCE_TARGET");
  if (tarBox) {
    tarBox.value = tar;
  }
  var incBox = document.getElementById("SEQUENCE_INCLUDED_REGION");
  if (incBox) {
    incBox.value = inc;
  }
  var ovlBox = document.getElementById("SEQUENCE_OVERLAP_JUNCTION_LIST");
  if (ovlBox) {
    ovlBox.value = ovl;
  }
  cleanRegions();
  createSeqWithDeco(-1);
}

function cleanRegions() {
  var excBox = document.getElementById("SEQUENCE_EXCLUDED_REGION");
  var val = "";
  if (excBox) {
    val = excBox.value;
    val = val.replace(/[^0-9, ]/g, "");
    val = val.replace(/\s+/g, " ");
    val = val.replace(/\s+$/g, "");
    excBox.value = val;
  }
  var tarBox = document.getElementById("SEQUENCE_TARGET");
  if (tarBox) {
    val = tarBox.value;
    val = val.replace(/[^0-9, ]/g, "");
    val = val.replace(/\s+/g, " ");
    val = val.replace(/\s+$/g, "");
    tarBox.value = val;
  }
  var incBox = document.getElementById("SEQUENCE_INCLUDED_REGION");
  if (incBox) {
    val = incBox.value;
    val = val.replace(/[^0-9, ]/g, "");
    val = val.replace(/\s+/g, " ");
    val = val.replace(/\s+$/g, "");
    incBox.value = val;
  }
  var ovlBox = document.getElementById("SEQUENCE_OVERLAP_JUNCTION_LIST");
  if (ovlBox) {
    val = ovlBox.value;
    val = val.replace(/[^0-9 ]/g, "");
    val = val.replace(/\s+/g, " ");
    val = val.replace(/\s+$/g, "");
    ovlBox.value = val;
  }
}

function setSelectionRegion(tag) {
  var seqBox = document.getElementById("SEQUENCE_TEMPLATE");
  var start = cleanSeq(seqBox.value.substring(0, seqBox.selectionStart));
  var center = cleanSeq(seqBox.value.substring(seqBox.selectionStart, seqBox.selectionEnd));
  var firstBase = 0;
  if (getHtmlTagValue("PRIMER_FIRST_BASE_INDEX")) {
    firstBase = parseInt(getHtmlTagValue("PRIMER_FIRST_BASE_INDEX"));
  }
  if (center.length < 1) {
    return;
  }
  var pos = "" + (start.length + firstBase) + "," + center.length;
  var addField = document.getElementById(tag);
  if (addField !== null) {
    var con = addField.value;
    if (con == "") {
      addField.value = pos;
    } else {
      addField.value = con + " " + pos;
    }
  }
  createSeqWithDeco(start.length + firstBase + center.length);
}

function cleanSeq(seq) {
  return seq.replace(/[^ACGTNacgtn]/g, "");
}

function clearSelectionRegion() {
  var seqBox = document.getElementById("SEQUENCE_TEMPLATE");
  seqBox.value = cleanSeq(seqBox.value);
  var delExcl = document.getElementById("SEQUENCE_EXCLUDED_REGION");
  if (delExcl !== null) {
    delExcl.value = "";
  }
  var delTar = document.getElementById("SEQUENCE_TARGET");
  if (delTar !== null) {
    delTar.value = "";
  }
  var delIncl = document.getElementById("SEQUENCE_INCLUDED_REGION");
  if (delIncl !== null) {
    delIncl.value = "";
  }
  var delOverlap = document.getElementById("SEQUENCE_OVERLAP_JUNCTION_LIST");
  if (delOverlap !== null) {
    delOverlap.value = "";
  }
}

function createSeqWithDeco(pointer) {
  var firstBase = 0;
  if (getHtmlTagValue("PRIMER_FIRST_BASE_INDEX")) {
    firstBase = parseInt(getHtmlTagValue("PRIMER_FIRST_BASE_INDEX"));
  }
  var seqBox = document.getElementById("SEQUENCE_TEMPLATE");
  var seq = cleanSeq(seqBox.value);
  seq = addSelDeco(seq, firstBase, "SEQUENCE_EXCLUDED_REGION", "<", ">");
  seq = addSelDeco(seq, firstBase, "SEQUENCE_TARGET", "[", "]");
  seq = addSelDeco(seq, firstBase, "SEQUENCE_INCLUDED_REGION", "{", "}");
  seq = addOverlapDeco(seq, firstBase);	
  seqBox.value = seq;
}

function addSelDeco(seq, firstBase, tag, start, end) {
  var addField = document.getElementById(tag);
  if ((addField !== null) && (addField.value.length > 0)) {
    var posList = addField.value.split(" ");
    for (var i = 0 ; i < posList.length ; i++) {
      var lin = posList[i].split(",");
      seq = addSelDecoToSeq(seq, firstBase, parseInt(lin[0]), start);
      seq = addSelDecoToSeq(seq, firstBase, parseInt(lin[0]) + parseInt(lin[1]), end);
    }
  }
  return seq;
}

function addOverlapDeco(seq, firstBase) {
  var addField = document.getElementById("SEQUENCE_OVERLAP_JUNCTION_LIST");
  if ((addField !== null) && (addField.value.length > 0)) {
    var posList = addField.value.split(" ");
    for (var i = 0 ; i < posList.length ; i++) {
      seq = addSelDecoToSeq(seq, firstBase, parseInt(posList[i]), "-");
    }
  }
  return seq;
}

function addSelDecoToSeq(seq, firstBase, pos, deco) {
  var trueCount = 0;
  var ret = "";
  if (firstBase == pos) {
    ret += deco;
  }
  for (var i = 0 ; i < seq.length ; i++) {
    var letter = seq.charAt(i);
    ret += letter;	  
    if (letter.match(/[ACGTNacgtn]/)) {
      trueCount++;
    }
    if ((trueCount + firstBase) == pos) {
      ret += deco;
    }
  }
  return ret;
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

function initLoadAllFile() {
  var pButton = document.getElementById('P3P_SELECT_ALL_FILE');
  if (pButton !== null) {
    pButton.addEventListener('change', runLoadAllFile, false);
  }
}
function runLoadAllFile(f) {
  var file = f.target.files[0];
  if (file) { // && file.type.match("text/*")) {
    var reader = new FileReader();
    reader.onload = function(event) {
      var txt = event.target.result;
      loadP3File("file", txt);
    }
    reader.readAsText(file);
    document.getElementById("P3P_SELECT_ALL_FILE").value = "";
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
    } else if (txt.match(/P3_FILE_TYPE=results/) != null) {
      sel = "res";
      message += "results from Primer3Plus file";
      results = {};
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
      if ((sel != "res") && (pair.length > 1) && (defSet.hasOwnProperty(pair[0]))){
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
      } else if (sel == "res") {
        setHtmlTagValue(pair[0], pair[1]);
        results[pair[0]] = pair[1];	      
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
  if (sel == "res") {
    processResData();
  } else {
    showTaskSelection();
    showGenomeBrowserButtons();
  }
}
function initLoadCompareFunct() {
  var pFile1 = document.getElementById('P3P_COMPARE_FILE_ONE');
  if (pFile1 !== null) {
    pFile1.addEventListener('change', runLoadCompFile1, false);
  }
  var pFile2 = document.getElementById('P3P_COMPARE_FILE_TWO');
  if (pFile2 !== null) {
    pFile2.addEventListener('change', runLoadCompFile2, false);
  }
  var btRunComp = document.getElementById('P3P_ACTION_RUN_COMPARE');
  if (btRunComp !== null) {
    btRunComp.addEventListener('click', runCompFiles);
  }
  var btRunConv = document.getElementById('P3P_ACTION_RUN_CONVERT_OLD');
  if (btRunConv !== null) {
    btRunConv.addEventListener('click', runConvertFile);
  }
}
function runLoadCompFile1(f) {
  var file = f.target.files[0];
  if (file) { // && file.type.match("text/*")) {
    var reader = new FileReader();
    reader.onload = function(event) {
      var txt = event.target.result;
      loadCompareFile(1, txt);
    }
    reader.readAsText(file);
  } else {
    add_message("err","Error opening file");
  }
}
function runLoadCompFile2(f) {
  var file = f.target.files[0];
  if (file) { // && file.type.match("text/*")) {
    var reader = new FileReader();
    reader.onload = function(event) {
      var txt = event.target.result;
      loadCompareFile(2, txt);
    }
    reader.readAsText(file);
  } else {
    add_message("err","Error opening file");
  }
}
function resetCompFiles() {
  compFile1 = {};
  compFile2 = {};
  var pFile1 = document.getElementById('P3P_COMPARE_FILE_ONE');
  if (pFile1 !== null) {
    pFile1.value = "";
  }
  var pFile2 = document.getElementById('P3P_COMPARE_FILE_TWO');
  if (pFile2 !== null) {
    pFile2.value = "";
  }
}
function loadCompareFile(target,txt) {
  txt = txt.replace(/\r\n/g, "\n");
  txt = txt.replace(/\r/g, "\n");
  txt = txt.replace(/^\s*/, "");
  var fileLines = txt.split('\n');
  var ret;
  if (target == 1) {
    compFile1 = {};
    ret = compFile1;
  } else if (target == 2) {
    compFile2 = {};
    ret = compFile2;
  }
  for (var i = 0; i < fileLines.length; i++) {
    if (fileLines[i] == "") {
      continue;
    } else if (fileLines[i] == "=") {
      ret["="] = "Single equal to run Primer3 present"
    } else if (fileLines[i].match(/=/) != null) {
      var pair = fileLines[i].split('=');
      ret[pair[0]] = pair[1];
    }
  }
}
function runCompFiles() {
  var ret = "";
  var data = [];
  var allTags = {};
  var usedTags = [];
  var dataName = [];
  if (Object.keys(compFile1).length != 0) {
    data[data.length] = compFile1;
    dataName[dataName.length] = "File 1 upload";
    for (var tag in compFile1) {
      if (compFile1.hasOwnProperty(tag)) {
        allTags[tag] = 1;
      } 
    }
  }
  if (Object.keys(compFile2).length != 0) {
    data[data.length] = compFile2;
    dataName[dataName.length] = "File 2 upload";
    for (var tag in compFile2) {
      if (compFile2.hasOwnProperty(tag)) {
        allTags[tag] = 1;
      }
    }
  }
  var fileName = getHtmlTagValue("P3P_SERVER_SETTINGS_FILE");
  if ((fileName) && (fileName != "None") && (data.length < 2)) {
    data[data.length] = currSet;
    dataName[dataName.length] = fileName;
    for (var tag in currSet) {
      if (currSet.hasOwnProperty(tag)) {
        allTags[tag] = 1;
      } 
    }
  }
  // Find the differences
  for (var tag in allTags) {
    if (allTags.hasOwnProperty(tag)) {
      usedTags.push(tag);
    }
  }
  usedTags.sort();
  ret += '<h2 class="p3p_fit_to_table">Results:</h2>';
  if (data.length == 0) {
    ret += '<p class="p3p_fit_to_table">\n  <strong style="color: red;">Select a file and/or default settings to display or compare.</strong>\n</p>';
  } else if (data.length == 1) {
    ret += '<h3 class="p3p_fit_to_table">Display file contents:</h3>';	  
    ret += '<table class="p3p_table_with_border">\n';
    ret += '  <colgroup>\n';
    ret += '    <col style="width: 40%">\n';
    ret += '    <col style="width: 60%">\n';
    ret += '  </colgroup>\n';
    ret += '  <tr>\n';
    ret += '    <td class="p3p_comp_file_l"><strong>Tag</strong></td>\n';
    ret += '    <td class="p3p_comp_file_r"><strong>' + dataName[0] + '</strong></td>\n';
    ret += '  </tr>\n';
    for (var i = 0; i < usedTags.length; i++) {
      ret += '  <tr>\n';
      ret += '    <td class="p3p_comp_file_l">' + usedTags[i] + '</td>\n';
      ret += '    <td class="p3p_comp_file_r">' + data[0][usedTags[i]] + '</td>\n';
      ret += '  </tr>\n'; 
    }
    ret += '</table>\n';
  } else {
    var different = '<h3 class="p3p_fit_to_table">Differences between both:</h3>';
    var samesame = '<h3 class="p3p_fit_to_table">Idential values in both:</h3>';
    var header = '<table class="p3p_table_with_border">\n';
    header += '  <colgroup>\n';
    header += '    <col style="width: 40%">\n';
    header += '    <col style="width: 30%">\n';
    header += '    <col style="width: 30%">\n';
    header += '  </colgroup>\n';
    header += '  <tr>\n';
    header += '    <td class="p3p_comp_file_l"><strong>Tag</strong></td>\n';
    header += '    <td class="p3p_comp_file_r"><strong>' + dataName[0] + '</strong></td>\n';
    header += '    <td class="p3p_comp_file_r"><strong>' + dataName[1] + '</strong></td>\n';
    header += '  </tr>\n';
    different += header;
    samesame += header;
    var tagHtml = ["", "", ""];
    for (var i = 0; i < usedTags.length; i++) {
      var k = 0;
      var tagVal1 = '<a style="color: red">Tag absent in file</a>';
      var tagVal2 = '<a style="color: red">Tag absent in file</a>';
      if (data[0].hasOwnProperty(usedTags[i]) && data[1].hasOwnProperty(usedTags[i])){
        tagVal1 = data[0][usedTags[i]];
        tagVal2 = data[1][usedTags[i]];
        k = 0;	      
      } else if (data[0].hasOwnProperty(usedTags[i]) && !(data[1].hasOwnProperty(usedTags[i]))){
        tagVal1 = data[0][usedTags[i]];
        k = 1;
      } else if (!(data[0].hasOwnProperty(usedTags[i])) && data[1].hasOwnProperty(usedTags[i])){
        tagVal2 = data[1][usedTags[i]];
        k = 2;
      }
      var oneTag = '  <tr>\n';
      oneTag += '    <td class="p3p_comp_file_l">' + usedTags[i] + '</td>\n';
      oneTag += '    <td class="p3p_comp_file_r">' + tagVal1 + '</td>\n';
      oneTag += '    <td class="p3p_comp_file_r">' + tagVal2 + '</td>\n';
      oneTag += '  </tr>\n';
      if (data[0][usedTags[i]] == data[1][usedTags[i]]) {
        samesame += oneTag;
      } else {
        tagHtml[k] += oneTag;
      }
    }
    different += tagHtml[0] + tagHtml[1] + tagHtml[2] + '</table>\n';
    samesame += '</table>\n';
    ret += different;
    ret += samesame;
  } 
  document.getElementById('P3P_RESULTS_BOX').innerHTML = ret;
}

function runConvertFile() {
  var dict = getCompareHash();
  var remTags = ["PRIMER_TASK", "SCRIPT_PRINT_INPUT", "SCRIPT_FIX_PRIMER_END", "SCRIPT_CONTAINS_JAVA_SCRIPT", 
                 "SCRIPT_SEQUENCING_REVERSE", "SCRIPT_DETECTION_USE_PRODUCT_SIZE", "SCRIPT_DETECTION_PRODUCT_MIN_SIZE",
                 "SCRIPT_DETECTION_PRODUCT_OPT_SIZE", "SCRIPT_DETECTION_PRODUCT_MAX_SIZE", "SERVER_PARAMETER_FILE"]
  ret = ""
  if (Object.keys(compFile1).length != 0) {
    for (var tag in compFile1) {
      if (remTags.includes(tag)) {
        continue;
      }
      if (tag == "SCRIPT_TASK") {
        task = "generic"
        if (compFile1[tag] == "Cloning") {
          task = "pick_cloning_primers"
        }
        if (compFile1[tag] == "Sequencing") {
          task = "pick_sequencing_primers"
        }
        if (compFile1[tag] == "Primer_List") {
          task = "pick_primer_list"
        }
        if (compFile1[tag] == "Primer_Check") {
          task = "check_primers"
        }
        ret += "PRIMER_TASK=" + task + "\n";
      } else {
        if (tag in dict) {
          ret += dict[tag];
        } else {
          ret += tag;
        }
        ret += "=" + compFile1[tag] + "\n";
      }
    }
    saveFile('Primer3Plus_Settings.txt',ret);
  }
}

// Functions to load the sequence and settings files
function initSaveFile() {
  var pButtonSeq = document.getElementById('P3P_ACTION_SEQUENCE_SAVE');
  if (pButtonSeq !== null) {
    pButtonSeq.addEventListener('click', function(){runSaveFile('seq','Primer3Plus_Sequence.txt');});
  }
  var pButtonSet = document.getElementById('P3P_ACTION_SETTINGS_SAVE');
  if (pButtonSet !== null) {
    pButtonSet.addEventListener('click', function(){runSaveFile('set','Primer3Plus_Settings.txt');});
  }
  var pButtonAll = document.getElementById('P3P_ACTION_ALL_SAVE');
  if (pButtonAll !== null) {
    pButtonAll.addEventListener('click', function(){runSaveFile('all','Primer3Plus_Complete.txt');});
  }
  var pButtonP3 = document.getElementById('P3P_ACTION_ALL_P3_SAVE');
  if (pButtonP3 !== null) {
    pButtonP3.addEventListener('click', function(){runSaveFile('primer3','Primer3_Input.txt');});
  }
  var pButtonRes = document.getElementById('P3P_ACTION_RESULTS_P3P_SAVE');
  if (pButtonRes !== null) {
    pButtonRes.addEventListener('click', function(){runSaveFile('results','Primer3Plus_Results.txt');});
  }
}

function runSaveFile(sel, fileName) {
  var con = createSaveFileString(sel);
  saveFile(fileName,con);
}

// This function creates the files to save 
// and the Primer3 input file!!
function createSaveFileString(sel) {
  var data = {};
  var usedTags = [];
  var ret = "";
  // Extract the used tags with values
  if (sel != "results") {
    for (var tag in defSet) {
      if (defSet.hasOwnProperty(tag)) {
        if (ignore_tags.includes(tag)) {
          continue;
        }
        var val = getHtmlTagValue(tag);
        if (val !== null) {
          if (((sel == "seq") && tag.startsWith("SEQUENCE_")) ||
              ((sel == "set") && tag.startsWith("PRIMER_")) ||
              ((sel == "set") && tag.startsWith("P3P_")) ||
              ((sel == "all")) ||
              ((sel == "primer3") && !(tag.startsWith("P3P_")))) {
                data[tag] = val;
          }
        }
      }
    }
  } else {	  
    data = results;
  }
  // Fix data for Primer3
  if (sel == "primer3") {
    data["PRIMER_EXPLAIN_FLAG"] = "1";
    data["PRIMER_THERMODYNAMIC_PARAMETERS_PATH"] = "Add Path to the Primer3 /src/primer3_config/ folder";
    if (data.hasOwnProperty("PRIMER_INTERNAL_MISHYB_LIBRARY") &&
        ((data["PRIMER_INTERNAL_MISHYB_LIBRARY"] == "NONE") ||
         (data["PRIMER_INTERNAL_MISHYB_LIBRARY"] == ""))) {
      delete data["PRIMER_INTERNAL_MISHYB_LIBRARY"];
    }
    if (data.hasOwnProperty("PRIMER_MISPRIMING_LIBRARY") &&
        ((data["PRIMER_MISPRIMING_LIBRARY"] == "NONE") ||
         (data["PRIMER_MISPRIMING_LIBRARY"] == ""))) {
      delete data["PRIMER_MISPRIMING_LIBRARY"]; 
    }
    for (var tag in data) {
      if (data.hasOwnProperty(tag)) {
        if (tag.startsWith("SEQUENCE_") && (data[tag] == "")) {
          delete data[tag];
        }
        if (tag.startsWith("PRIMER_MUST_MATCH_") && (data[tag] == "")) {
          delete data[tag];
        }
        if (tag.startsWith("PRIMER_INTERNAL_MUST_MATCH_") && (data[tag] == "")) {
          delete data[tag];
        }
        if (tag.startsWith("PRIMER_PRODUCT_MAX_TM") && (data[tag] == "")) {
          delete data[tag];
        }
        if (tag.startsWith("PRIMER_PRODUCT_MIN_TM") && (data[tag] == "")) {
          delete data[tag];
        }
        if (tag.startsWith("PRIMER_PRODUCT_OPT_SIZE") && (data[tag] == "")) {
          delete data[tag];
        }
        if (tag.startsWith("PRIMER_PRODUCT_OPT_TM") && (data[tag] == "")) {
          delete data[tag];
        }
      }
    }
    if (data.hasOwnProperty("PRIMER_PRODUCT_OPT_SIZE") &&
        (data["PRIMER_PRODUCT_OPT_SIZE"] != "") && 
        data.hasOwnProperty("P3P_TMP_PRODUCT_MIN_SIZE") &&
        (data["P3P_TMP_PRODUCT_MIN_SIZE"] != "") && 
        data.hasOwnProperty("P3P_TMP_PRODUCT_MAX_SIZE") &&
        (data["P3P_TMP_PRODUCT_MAX_SIZE"] != "")) {
       data["PRIMER_PRODUCT_SIZE_RANGE"] = data["P3P_TMP_PRODUCT_MIN_SIZE"] + "-" + data["P3P_TMP_PRODUCT_MAX_SIZE"];
    }
    // Handle the tasks
    if (data.hasOwnProperty("PRIMER_TASK") &&
        (data["PRIMER_TASK"] == "pick_cloning_primers")) {
      data["PRIMER_PICK_ANYWAY"] = "1";
      if (data.hasOwnProperty("SEQUENCE_EXCLUDED_REGION")) {
        delete data["SEQUENCE_EXCLUDED_REGION"];
      }
      if (data.hasOwnProperty("SEQUENCE_TARGET")) {
        delete data["SEQUENCE_TARGET"];
      }
      if (data.hasOwnProperty("SEQUENCE_OVERLAP_JUNCTION_LIST")) {
        delete data["SEQUENCE_OVERLAP_JUNCTION_LIST"];
      }
      if (data.hasOwnProperty("SEQUENCE_PRIMER_PAIR_OK_REGION_LIST")) {
        delete data["SEQUENCE_PRIMER_PAIR_OK_REGION_LIST"];
      }
      if (data.hasOwnProperty("SEQUENCE_PRIMER")) {
        delete data["SEQUENCE_PRIMER"];
      }
      if (data.hasOwnProperty("SEQUENCE_INTERNAL_OLIGO")) {
        delete data["SEQUENCE_INTERNAL_OLIGO"];
      }
      if (data.hasOwnProperty("SEQUENCE_PRIMER_REVCOMP")) {
        delete data["SEQUENCE_PRIMER_REVCOMP"];
      }
    }
    if (data.hasOwnProperty("PRIMER_TASK") &&
        (data["PRIMER_TASK"] == "pick_discriminative_primers")) {
      data["PRIMER_PICK_ANYWAY"] = "1";
      if (data.hasOwnProperty("SEQUENCE_EXCLUDED_REGION")) {
        delete data["SEQUENCE_EXCLUDED_REGION"];
      }
      if (data.hasOwnProperty("SEQUENCE_INCLUDED_REGION")) {
        delete data["SEQUENCE_INCLUDED_REGION"];
      }
      if (data.hasOwnProperty("SEQUENCE_OVERLAP_JUNCTION_LIST")) {
        delete data["SEQUENCE_OVERLAP_JUNCTION_LIST"];
      }
      if (data.hasOwnProperty("SEQUENCE_PRIMER_PAIR_OK_REGION_LIST")) {
        delete data["SEQUENCE_PRIMER_PAIR_OK_REGION_LIST"];
      }
      if (data.hasOwnProperty("SEQUENCE_PRIMER")) {
        delete data["SEQUENCE_PRIMER"];
      }
      if (data.hasOwnProperty("SEQUENCE_INTERNAL_OLIGO")) {
        delete data["SEQUENCE_INTERNAL_OLIGO"];
      }
      if (data.hasOwnProperty("SEQUENCE_PRIMER_REVCOMP")) {
        delete data["SEQUENCE_PRIMER_REVCOMP"];
      }
    }
    if (data.hasOwnProperty("PRIMER_TASK") &&
        (data["PRIMER_TASK"] == "pick_sequencing_primers")) {
      // Make space for enough primers
      data["PRIMER_NUM_RETURN"] = "1000";
      if (data.hasOwnProperty("SEQUENCE_EXCLUDED_REGION")) {
        delete data["SEQUENCE_EXCLUDED_REGION"];
      }
      if (data.hasOwnProperty("SEQUENCE_INCLUDED_REGION")) {
        delete data["SEQUENCE_INCLUDED_REGION"];
      }
      if (data.hasOwnProperty("SEQUENCE_OVERLAP_JUNCTION_LIST")) {
        delete data["SEQUENCE_OVERLAP_JUNCTION_LIST"];
      }
      if (data.hasOwnProperty("SEQUENCE_PRIMER_PAIR_OK_REGION_LIST")) {
        delete data["SEQUENCE_PRIMER_PAIR_OK_REGION_LIST"];
      }
      if (data.hasOwnProperty("SEQUENCE_PRIMER")) {
        delete data["SEQUENCE_PRIMER"];
      }
      if (data.hasOwnProperty("SEQUENCE_INTERNAL_OLIGO")) {
        delete data["SEQUENCE_INTERNAL_OLIGO"];
      }
      if (data.hasOwnProperty("SEQUENCE_PRIMER_REVCOMP")) {
        delete data["SEQUENCE_PRIMER_REVCOMP"];
      }
    }
    if (data.hasOwnProperty("PRIMER_TASK") &&
        (data["PRIMER_TASK"] == "pick_primer_list")) {
      if (data.hasOwnProperty("SEQUENCE_PRIMER")) {
        delete data["SEQUENCE_PRIMER"];
      }
      if (data.hasOwnProperty("SEQUENCE_INTERNAL_OLIGO")) {
        delete data["SEQUENCE_INTERNAL_OLIGO"];
      }
      if (data.hasOwnProperty("SEQUENCE_PRIMER_REVCOMP")) {
        delete data["SEQUENCE_PRIMER_REVCOMP"];
      }
    }
    if (data.hasOwnProperty("PRIMER_TASK") &&
        (data["PRIMER_TASK"] == "check_primers")) {
      data["PRIMER_PICK_ANYWAY"] = "1";
      if (data.hasOwnProperty("SEQUENCE_EXCLUDED_REGION")) {
        delete data["SEQUENCE_EXCLUDED_REGION"];
      }
      if (data.hasOwnProperty("SEQUENCE_TARGET")) {
        delete data["SEQUENCE_TARGET"];
      }
      if (data.hasOwnProperty("SEQUENCE_INCLUDED_REGION")) {
        delete data["SEQUENCE_INCLUDED_REGION"];
      }
      if (data.hasOwnProperty("SEQUENCE_OVERLAP_JUNCTION_LIST")) {
        delete data["SEQUENCE_OVERLAP_JUNCTION_LIST"];
      }
      if (data.hasOwnProperty("SEQUENCE_PRIMER_PAIR_OK_REGION_LIST")) {
        delete data["SEQUENCE_PRIMER_PAIR_OK_REGION_LIST"];
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
    ret += "P3_FILE_TYPE=all\n\nP3_FILE_ID=User data\n";
  }  
  if (sel == "results") {
    ret += "P3_FILE_TYPE=results\n\nP3_FILE_ID=User results\n";
  } 

  //Print the array data
  for (var tag in data) {
    usedTags.push(tag);
  }
  usedTags.sort();
  for (var i = 0; i < usedTags.length; i++) {
    ret += usedTags[i] + "=" + data[usedTags[i]] + "\n"; 
  }

  // Add the lonley "=" for Primer3
  if (sel == "primer3") {
    ret += "=\n";
  }
  return ret;
}

// Conect the debug info
function initDebug() {
  var btn = document.getElementById('P3P_DEBUG_MODE');
  if (btn !== null) {
    placeDebugTab();
    btn.addEventListener('change', function(){
      debugMode = getHtmlTagValue("P3P_DEBUG_MODE");
      placeDebugTab();    
    });
  }
}
function placeDebugTab() {
  var tb = document.getElementById('P3P_SEL_TAB_DEBUG');
  if (tb) {
    if (debugMode > 0) {
      tb.style.display="inline";
    } else {
      tb.style.display="none";
    }
  }
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
  if (!(btMain === null)) {
    var tabMain = document.getElementById('P3P_TAB_MAIN');
    if (!(tabMain === null)) {
      btMain.addEventListener('click', function(){browseTabFunctionality('P3P_TAB_MAIN');});
    }
  }
  var btGeneralSet = document.getElementById('P3P_SEL_TAB_GENERAL_SETTINGS');
  if (!(btGeneralSet === null)) {
    var tabGeneralSet = document.getElementById('P3P_TAB_GENERAL_SETTINGS');
    if (!(tabGeneralSet === null)) {
      btGeneralSet.addEventListener('click', function(){browseTabFunctionality('P3P_TAB_GENERAL_SETTINGS');});
    }
  }
  var btAdvanced = document.getElementById('P3P_SEL_TAB_ADVANCED_PRI');
  if (!(btAdvanced === null)) {
    var tabAdvanced = document.getElementById('P3P_TAB_ADVANCED_PRI');
    if (!(tabAdvanced === null)) {
      btAdvanced.addEventListener('click', function(){browseTabFunctionality('P3P_TAB_ADVANCED_PRI');});
    }
  }
  var btInternal = document.getElementById('P3P_SEL_TAB_INTERNAL');
  if (!(btInternal === null)){
    var tabInternal = document.getElementById('P3P_TAB_INTERNAL_OLIGO');
    if (!(tabInternal === null)) {
      btInternal.addEventListener('click', function(){browseTabFunctionality('P3P_TAB_INTERNAL_OLIGO');});
    }
  }
  var btPenalties = document.getElementById('P3P_SEL_TAB_PENALTIES');
  if (!(btPenalties === null)) {
    var tabPenalties = document.getElementById('P3P_TAB_PENALTIES');
    if (!(tabPenalties === null)) {
      btPenalties.addEventListener('click', function(){browseTabFunctionality('P3P_TAB_PENALTIES');});
    }
  }
  var btAdvancedSeq = document.getElementById('P3P_SEL_TAB_ADVANCED_SEQ');
  if (!(btAdvancedSeq === null)) {
    var tabAdvancedSeq = document.getElementById('P3P_TAB_ADVANCED_SEQUENCE');
    if (!(tabAdvancedSeq === null)) {
      btAdvancedSeq.addEventListener('click', function(){browseTabFunctionality('P3P_TAB_ADVANCED_SEQUENCE');});
    }
  }
  var btDebug = document.getElementById('P3P_SEL_TAB_DEBUG');
  if (!(btDebug === null)) {
    var tabDebug = document.getElementById('P3P_TAB_DEBUG');
    if (!(tabDebug === null)) {
      btDebug.addEventListener('click', function(){browseTabFunctionality('P3P_TAB_DEBUG');});
    }
  }
  var btResults = document.getElementById('P3P_SEL_TAB_RESULTS');
  if (!(btResults === null)) {
    var tabResults = document.getElementById('P3P_TAB_RESULTS');
    if (!(tabResults === null)) {
      btResults.addEventListener('click', function(){browseTabFunctionality('P3P_TAB_RESULTS');});
    }
  }
  browseTabFunctionality('P3P_TAB_MAIN');
}
function browseTabFunctionality(tab) {
  browseTabSelect(tab,'P3P_SEL_TAB_MAIN','P3P_TAB_MAIN');
  browseTabSelect(tab,'P3P_SEL_TAB_GENERAL_SETTINGS','P3P_TAB_GENERAL_SETTINGS');
  browseTabSelect(tab,'P3P_SEL_TAB_ADVANCED_PRI','P3P_TAB_ADVANCED_PRI');
  browseTabSelect(tab,'P3P_SEL_TAB_INTERNAL','P3P_TAB_INTERNAL_OLIGO');
  browseTabSelect(tab,'P3P_SEL_TAB_PENALTIES','P3P_TAB_PENALTIES');
  browseTabSelect(tab,'P3P_SEL_TAB_ADVANCED_SEQ','P3P_TAB_ADVANCED_SEQUENCE');
  browseTabSelect(tab,'P3P_SEL_TAB_DEBUG','P3P_TAB_DEBUG');
  browseTabSelect(tab,'P3P_SEL_TAB_RESULTS','P3P_TAB_RESULTS');
}
function browseTabSelect(sel,btn,tab) {
  var button = document.getElementById(btn);
  var tabField = document.getElementById(tab);
  if (button === null) {
    return;
  }
  if (tabField === null) {
    return;
  }
  if (sel == tab) {
    button.style.background="rgb(255, 255, 230)";
    button.style.position="relative";
    button.style.top="2px";
    button.style.zIndex="1";
    tabField.style.display="inline";
  } else {
    button.style.background="white";
    button.style.position="static";
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
  if (task === null) {
    return;
  }
  var x = task.selectedIndex;
  var id = "P3P_EXPLAIN_TASK_" + task.options[x].value.toUpperCase();
  if ((prevSelectedTab != "") && document.getElementById(prevSelectedTab)) {
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
  del_all_messages();	
  window.gb_exons = "";
  setHTMLParameters(defSet);
  document.getElementById('P3P_DEBUG_TXT_INPUT').value = "";
  document.getElementById('P3P_DEBUG_TXT_OUTPUT').value = "";
  var serv = document.getElementById('P3P_SERVER_SETTINGS_FILE');
  if (serv !== null) {
    serv.selectedIndex = 0;
  }
  resetCompFiles();
  updateInterface();
}

function reverseComplement(seq){
    var revComp = "";
    for (var i = seq.length - 1; i >= 0 ; i--) {
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
            default: revComp += "n";
        }
    }
    return revComp;
}


function initLoadAmplicon() {
  var pButton = document.getElementById('P3P_ACTION_LOAD_AMPLICON');
  if (pButton !== null) {
    pButton.addEventListener('click', runLoadAmplicon);
  }
}

function runLoadAmplicon() {
  var seq = 'GCCCGAGAGCTGGAGGTATTAAGTGAGCGGCTTGAAGAGGCTGGGGGTGCCACTGCTGCCCAGCTGGAGAT' +
  'GAACAAGAAACGTGAAGCTGAGTTCCTGAAGCTGGCGCGTGACCTCGAGGAGGCCACGCTGCACTATGAAGCCACAGCTGC' +
  'TGCTCTGAGGAAGAAGCATGCGGACAGCGTGGCTGAGATGGGGGAGCAGCTGGACAACCTGCAGCGCGTCAAGCAGAAACT' +
  'GGAAAAGGAGAAAAGCGAGCTGAAAATGGAAGTGGATGATCTGACATCCAACATGGAGCAAACGGTTAAGGGAAAAGCAAA' +
  'TGCAGAAAAACTTTGTCGCACTTATGAAGATCATCTTAATGAGACAAAAACTAAACTGGATGAAATGA';
  setHTMLParameters(defSet);
  setHtmlTagValue("SEQUENCE_TEMPLATE", seq);
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

function getCompareHash() {
  var dict = {"PRIMER_SEQUENCE_ID": "SEQUENCE_ID",
              "MARKER_NAME": "SEQUENCE_ID",
              "SEQUENCE": "SEQUENCE_TEMPLATE",
              "INCLUDED_REGION": "SEQUENCE_INCLUDED_REGION",
              "TARGET": "SEQUENCE_TARGET",
              "EXCLUDED_REGION": "SEQUENCE_EXCLUDED_REGION",
              "PRIMER_INTERNAL_OLIGO_EXCLUDED_REGION": "SEQUENCE_INTERNAL_EXCLUDED_REGION",
              "PRIMER_LEFT_INPUT": "SEQUENCE_PRIMER",
              "PRIMER_INTERNAL_OLIGO_INPUT": "SEQUENCE_INTERNAL_OLIGO",
              "PRIMER_RIGHT_INPUT": "SEQUENCE_PRIMER_REVCOMP",
              "PRIMER_START_CODON_POSITION": "SEQUENCE_START_CODON_POSITION",
              "PRIMER_SEQUENCE_QUALITY": "SEQUENCE_QUALITY",
              "PRIMER_DEFAULT_PRODUCT": "PRIMER_PRODUCT_SIZE_RANGE",
              "PRIMER_INTERNAL_OLIGO_MIN_SIZE": "PRIMER_INTERNAL_MIN_SIZE",
              "PRIMER_DEFAULT_SIZE": "PRIMER_OPT_SIZE",
              "PRIMER_INTERNAL_OLIGO_OPT_SIZE": "PRIMER_INTERNAL_OPT_SIZE",
              "PRIMER_INTERNAL_OLIGO_MAX_SIZE": "PRIMER_INTERNAL_MAX_SIZE",
              "PRIMER_IO_WT_SIZE_LT": "PRIMER_INTERNAL_WT_SIZE_LT",
              "PRIMER_IO_WT_SIZE_GT": "PRIMER_INTERNAL_WT_SIZE_GT",
              "PRIMER_INTERNAL_OLIGO_MIN_GC": "PRIMER_INTERNAL_MIN_GC",
              "PRIMER_INTERNAL_OLIGO_OPT_GC_PERCENT": "PRIMER_INTERNAL_OPT_GC_PERCENT",
              "PRIMER_INTERNAL_OLIGO_MAX_GC": "PRIMER_INTERNAL_MAX_GC",
              "PRIMER_IO_WT_GC_PERCENT_LT": "PRIMER_INTERNAL_WT_GC_PERCENT_LT",
              "PRIMER_IO_WT_GC_PERCENT_GT": "PRIMER_INTERNAL_WT_GC_PERCENT_GT",
              "PRIMER_INTERNAL_OLIGO_MIN_TM": "PRIMER_INTERNAL_MIN_TM",
              "PRIMER_INTERNAL_OLIGO_OPT_TM": "PRIMER_INTERNAL_OPT_TM",
              "PRIMER_INTERNAL_OLIGO_MAX_TM": "PRIMER_INTERNAL_MAX_TM",
              "PRIMER_MAX_DIFF_TM": "PRIMER_PAIR_MAX_DIFF_TM",
              "PRIMER_IO_WT_TM_LT": "PRIMER_INTERNAL_WT_TM_LT",
              "PRIMER_IO_WT_TM_GT": "PRIMER_INTERNAL_WT_TM_GT",
              "PRIMER_TM_SANTALUCIA": "PRIMER_TM_FORMULA",
              "PRIMER_SALT_CONC": "PRIMER_SALT_MONOVALENT",
              "PRIMER_INTERNAL_OLIGO_SALT_CONC": "PRIMER_INTERNAL_SALT_MONOVALENT",
              "PRIMER_DIVALENT_CONC": "PRIMER_SALT_DIVALENT",
              "PRIMER_INTERNAL_OLIGO_DIVALENT_CONC": "PRIMER_INTERNAL_SALT_DIVALENT",
              "PRIMER_INTERNAL_OLIGO_DNTP_CONC": "PRIMER_INTERNAL_DNTP_CONC",
              "PRIMER_INTERNAL_OLIGO_DNA_CONC": "PRIMER_INTERNAL_DNA_CONC",
              "PRIMER_SELF_ANY": "PRIMER_MAX_SELF_ANY",
              "PRIMER_INTERNAL_OLIGO_SELF_ANY": "PRIMER_INTERNAL_MAX_SELF_ANY",
              "PRIMER_WT_COMPL_ANY": "PRIMER_WT_SELF_ANY",
              "PRIMER_IO_WT_COMPL_ANY": "PRIMER_INTERNAL_WT_SELF_ANY",
              "PRIMER_SELF_END": "PRIMER_MAX_SELF_END",
              "PRIMER_INTERNAL_OLIGO_SELF_END": "PRIMER_INTERNAL_MAX_SELF_END",
              "PRIMER_WT_COMPL_END": "PRIMER_WT_SELF_END",
              "PRIMER_IO_WT_COMPL_END": "PRIMER_INTERNAL_WT_SELF_END",
              "PRIMER_NUM_NS_ACCEPTED": "PRIMER_MAX_NS_ACCEPTED",
              "PRIMER_INTERNAL_OLIGO_NUM_NS": "PRIMER_INTERNAL_MAX_NS_ACCEPTED",
              "PRIMER_IO_WT_NUM_NS": "PRIMER_INTERNAL_WT_NUM_NS",
              "PRIMER_INTERNAL_OLIGO_MAX_POLY_X": "PRIMER_INTERNAL_MAX_POLY_X",
              "PRIMER_INTERNAL_OLIGO_MISHYB_LIBRARY": "PRIMER_INTERNAL_MISHYB_LIBRARY",
              "PRIMER_MAX_MISPRIMING": "PRIMER_MAX_LIBRARY_MISPRIMING",
              "PRIMER_INTERNAL_OLIGO_MAX_MISHYB": "PRIMER_INTERNAL_MAX_LIBRARY_MISHYB",
              "PRIMER_PAIR_MAX_MISPRIMING": "PRIMER_PAIR_MAX_LIBRARY_MISPRIMING",
              "PRIMER_WT_REP_SIM": "PRIMER_WT_LIBRARY_MISPRIMING",
              "PRIMER_IO_WT_REP_SIM": "PRIMER_INTERNAL_WT_LIBRARY_MISHYB",
              "PRIMER_PAIR_WT_REP_SIM": "PRIMER_PAIR_WT_LIBRARY_MISPRIMING",
              "PRIMER_INTERNAL_OLIGO_MIN_QUALITY": "PRIMER_INTERNAL_MIN_QUALITY",
              "PRIMER_IO_WT_SEQ_QUAL": "PRIMER_INTERNAL_WT_SEQ_QUAL",
              "PRIMER_IO_WT_END_QUAL": "PRIMER_INTERNAL_WT_END_QUAL",
              "PRIMER_FILE_FLAG": "P3_FILE_FLAG",
              "PRIMER_COMMENT": "P3_COMMENT",
              "COMMENT": "P3_COMMENT",
              "PRIMER_NAME_ACRONYM_LEFT": "P3P_PRIMER_NAME_ACRONYM_LEFT",
              "PRIMER_NAME_ACRONYM_INTERNAL_OLIGO": "P3P_PRIMER_NAME_ACRONYM_INTERNAL",
              "PRIMER_NAME_ACRONYM_RIGHT": "P3P_PRIMER_NAME_ACRONYM_RIGHT",
              "PRIMER_NAME_ACRONYM_SPACER": "P3P_PRIMER_NAME_ACRONYM_SPACER",
              "SCRIPT_SEQUENCING_LEAD": "PRIMER_SEQUENCING_LEAD",
              "SCRIPT_SEQUENCING_SPACING": "PRIMER_SEQUENCING_SPACING",
              "SCRIPT_SEQUENCING_INTERVAL": "PRIMER_SEQUENCING_INTERVAL",
              "SCRIPT_SEQUENCING_ACCURACY": "PRIMER_SEQUENCING_ACCURACY",
              "SCRIPT_DETECTION_PICK_LEFT": "PRIMER_PICK_LEFT_PRIMER",
              "SCRIPT_DETECTION_PICK_HYB_PROBE": "PRIMER_PICK_INTERNAL_OLIGO",
              "SCRIPT_DETECTION_PICK_RIGHT": "PRIMER_PICK_RIGHT_PRIMER"};
  return dict;
}

