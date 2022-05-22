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

var rawResults = "";
var p3p_errors = [];

document.addEventListener("DOMContentLoaded", function() {
  const formData = new FormData();
  axios
    .post(`${API_URL}/statistics`, formData)
    .then(res => {
        if (res.status === 200) {
          rawResults = res.data.outfile;
          formatTable();
      }
    })
    .catch(function (error) {
      if (error.response) {
        // The request was made and the server responded with a status code
        // that falls out of the range of 2xx
        let errorMessage = error.response.data.errors
          .map(error => error.title)
          .join('; ')
        add_message("err","Error loading statistics from server: " + errorMessage);
      } else if (error.request) {
        // The request was made but no response was received
        add_message("err","Error: No response from the server trying to load statistics from server.");
      } else {
        // Something happened in setting up the request that triggered an Error
        add_message("err","Error while setting up the request trying to load statistics from server: " + error.message);
      }
    });
});

function add_message(level,message) {
  var arr = null;
  if (level == "err") {
    arr = p3p_errors;
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

function formatTable() {
  if (rawResults != "") {
    var lineSplit = rawResults.split('\n');
    var res = '<div class="p3p_section">\n<table>\n'
    for (var i = 0; i < lineSplit.length; i++) {
      var colSplit = lineSplit[i].split('\t');
      res += "<tr>\n";
      for (var k = 0; k < colSplit.length; k++) {
        var alig = ""
        if (k != 0) {
          alig = ' style="text-align: right"'
        }
        if (i == 0) {
          res += "<th" + alig + ">" + colSplit[k] + "</th>\n";
        } else {
          res += "<td" + alig + ">" + colSplit[k] + "</td>\n";
        }
      }
      res += "</tr>\n";
    }
    res += '</div>\n</table>\n'

    document.getElementById('P3P_RESULTS_BOX').innerHTML = res
    document.getElementById('P3P_P3_RUNNING').style.display="none";
  }
}



