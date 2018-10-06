#! /usr/bin/env python

import os
import uuid
import re
import subprocess
import argparse
import json
from subprocess import call
from flask import Flask, send_file, flash, send_from_directory, request, redirect, url_for, jsonify
from flask_cors import CORS
from werkzeug.utils import secure_filename

P3PWS = os.path.dirname(os.path.abspath(__file__))

app = Flask(__name__)
CORS(app)
app.config['PRIMER3PLUS'] = os.path.join(P3PWS, "..")
app.config['UPLOAD_FOLDER'] = os.path.join(app.config['PRIMER3PLUS'], "data")
app.config['MAX_CONTENT_LENGTH'] = 8 * 1024 * 1024   #maximum of 8MB

def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in set(['json', 'fa'])

@app.route('/api/v1/upload', methods=['POST'])
def upload_file():
    if request.method == 'POST':
        uuidstr = str(uuid.uuid4())

        # Get subfolder
        sf = os.path.join(app.config['UPLOAD_FOLDER'], uuidstr[0:2])
        if not os.path.exists(sf):
            os.makedirs(sf)

        # Experiment
        if 'showExample' in request.form.keys():
            fexpname = os.path.join(SAGEWS, "sample.abi")
            genome = os.path.join(SAGEWS, "sample.fa")
        else:
            if 'queryFile' not in request.files:
                return jsonify(errors = [{"title": "Chromatogram file is missing!"}]), 400
            fexp = request.files['queryFile']
            if fexp.filename == '':
                return jsonify(errors = [{"title": "Chromatogram file name is missing!"}]), 400
            if not allowed_file(fexp.filename):
                return jsonify(errors = [{"title": "Chromatogram file has incorrect file type!"}]), 400
            fexpname = os.path.join(sf, "sage_" + uuidstr + "_" + secure_filename(fexp.filename))
            fexp.save(fexpname)

            # Genome
            if 'genome' in request.form.keys():
                genome = request.form['genome']
                if genome == '':
                    return jsonify(errors = [{"title": "Genome index is missing!"}]), 400
                genome = os.path.join(app.config['SAGE'], "fm", genome)
            else:
                return jsonify(errors = [{"title": "No input reference file provided!"}]), 400

        # Run Primer3 
        outfile = os.path.join(sf, "p3p_" + uuidstr + "_output.txt")
        logfile = os.path.join(sf, "p3p_" + uuidstr + ".log")
        errfile = os.path.join(sf, "p3p_" + uuidstr + ".err")
        with open(logfile, "w") as log:
            with open(errfile, "w") as err:
                try: 
                    return_code = call(['primer3core', 'align', '-g', genome,'-o', outfile, fexpname], stdout=log, stderr=err)
                except OSError as e:
                    if e.errno == os.errno.ENOENT:
                        return jsonify(errors = [{"title": "Binary ./primer3core not found!"}]), 400
                    else:
                        return jsonify(errors = [{"title": "OSError " + str(e.errno)  + " running binary ./primer3core!"}]), 400
        if return_code != 0:
            errInfo = "!"
            with open(errfile, "r") as err:
                errInfo = ": " + err.read()
            return jsonify(errors = [{"title": "Error in running Primer3Plus" + errInfo}]), 400
        return jsonify(data = json.loads(open(outfile).read()))
    return jsonify(errors = [{"title": "Error in handling POST request!"}]), 400

@app.route('/api/v1/settingsFile', methods=['POST'])
def loadsettingsfile():
    if request.method == 'POST':
        if 'P3P_SERVER_SETTINGS_FILE' in request.form.keys():
            filename = secure_filename(request.form['P3P_SERVER_SETTINGS_FILE'])
            return send_from_directory(os.path.join(P3PWS, "settings_files"),filename), 200
    return jsonify(errors = [{"title": "Could not find file on server!"}]), 400

@app.route('/api/v1/defaultsettings', methods=['POST'])
def defaultsettings():
    return send_from_directory(os.path.join(P3PWS, "settings_files"),"default_settings.json"), 200

if __name__ == '__main__':
    app.run(host = '0.0.0.0', port=3300, debug = True, threaded=True)
