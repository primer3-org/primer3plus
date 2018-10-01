const API_URL = process.env.API_URL
const HELP_LINK_URL = process.env.HELP_LINK_URL

// The default Settings loded from the server
var defSet;
// "TAG":["default setting","data type"]

// The old tags which need to be replaced by new tags
var repOld;
// "OLD TAG":"NEW TAG"

var debug = 1;


document.addEventListener("DOMContentLoaded", function() {
  // Send different data to avoid caching
  var dt = new Date();
  var utcDate = dt.toUTCString();
  const formData = new FormData();
  formData.append('stufferData', formData);
  axios
    .post(`${API_URL}/defaultsettings`, formData)
    .then(res => {
        if (res.status === 200) {
          defSet = res.data["def"];
          repOld = res.data["replace"];
          setDefaultParameters(defSet);
      }
    })
    .catch(err => {
      let errorMessage = err
  //    if (err.response) {
  //      errorMessage = err.response.data.errors
  //      .map(error => error.title)
   //     .join('; ')
  //    }
      alert("Error loading default settings from server:\n" + errorMessage);
    })
});

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
    if (pageElement.getAttribute('type') == 'checkbox') {
      if (pageElement.checked == true) {
        return "1";
      } else {
        return "0";
      }
    }
    if (pageElement.getAttribute('type') == 'text') {
        return pageElement.value;
    }
//    alert("Unknown Type by " + tag + ": " + pageElement.getAttribute('type'));
  } else {
    return null;
  }
}

async function setDefaultParameters(para) {
  for (var tag in para) {
    if (para.hasOwnProperty(tag)) {
      setHtmlTagValue(tag, para[tag][0]);	     
    }
  }
  linkHelpTags();
}

function setHtmlTagValue(tag, value) {
  var pageElement = document.getElementById(tag);
  if (pageElement !== null) {
    if (pageElement.getAttribute('type') == 'checkbox') {
      var uVal = parseInt(value);
      if (uVal != 0) {
        pageElement.checked = true;
        return true;
      } else {
        pageElement.checked = false;
        return true;
      }
    }
    if (pageElement.getAttribute('type') == 'text') {
        pageElement.value = value;
        return true;
    }
    return false;
//    alert("Unknown Type by " + tag + ": " + pageElement.getAttribute('type'));
  } else {
    return false;
  }

}


