const API_URL = process.env.API_URL

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
          setDefaultParameters();
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

async function handleSuccess(res) {
  var rhtml = '<select class="form-control" id="genome-select">\n'
  for (var i = 0; i < res.length; i++) {
    rhtml += '  <option value="' + res[i].file + '"'
    if (res[i].preselect == true) {
      rhtml += ' selected'
    }
    rhtml += '>' + res[i].name + '</option>\n'
  }
  rhtml += '</select>\n'
//  targetGenomes.innerHTML = rhtml
}

async function setDefaultParameters() {
//  console.log(defSet)
  for (var tag in defSet) {
    if (defSet.hasOwnProperty(tag)) {
      console.log(tag + " -> " + defSet[tag]);
    }
  }

}



