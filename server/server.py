#! /usr/bin/env python

import os
import uuid
import re
import subprocess
import threading
import argparse
import json
from subprocess import call,Popen,PIPE
from flask import Flask, send_file, flash, send_from_directory, request, redirect, url_for, jsonify
from flask_cors import CORS
from werkzeug.utils import secure_filename

P3PWS = os.path.dirname(os.path.abspath(__file__))

app = Flask(__name__)
CORS(app)
app.config['PRIMER3PLUS'] = os.path.join(P3PWS, "..")
app.config['UPLOAD_FOLDER'] = os.path.join(app.config['PRIMER3PLUS'], "data")
app.config['MAX_CONTENT_LENGTH'] = 8 * 1024 * 1024   #maximum of 8MB

app.config['BASEURL'] = os.environ.get('URL_INDEX', 'http://localhost:1234/index.html')
P3CONFPATH = os.environ.get('P3_CONFIG_PATH', '../../primer3/src/primer3_config/')

KILLTIME = 60 # time in seconds till Primer3 is killed!

P3PATHFIX = "PRIMER_THERMODYNAMIC_PARAMETERS_PATH=" +  os.path.join(P3PWS, P3CONFPATH) + "\n"
regEq = re.compile(r"PRIMER_THERMODYNAMIC_PARAMETERS_PATH=[^\n]*\n")

P3LIBPFIX = "PRIMER_MISPRIMING_LIBRARY=" +  os.path.join(P3PWS, "mispriming_lib/")
regLibP = re.compile(r"PRIMER_MISPRIMING_LIBRARY=")
P3LIBINFIX = "PRIMER_INTERNAL_MISHYB_LIBRARY=" +  os.path.join(P3PWS, "mispriming_lib/")
regLibIN = re.compile(r"PRIMER_INTERNAL_MISHYB_LIBRARY=")

def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in set(['json', 'fa'])

uuid_re = re.compile(r'(^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})-{0,1}([ap]{0,1})([cj]{0,1})$')
def is_valid_uuid(s):
   return uuid_re.match(s) is not None

def p3_watchdog(proc, stat):
    """Kill process on timeout and note in stat"""
    stat['timeout'] = True
    proc.kill()

@app.route('/api/v1/runprimer3', methods=['POST'])
def runp3():
    if request.method == 'POST':
        uuidstr = str(uuid.uuid4())

        # Get subfolder
        sf = os.path.join(app.config['UPLOAD_FOLDER'], uuidstr[0:2])
        if not os.path.exists(sf):
            os.makedirs(sf)

        # Experiment
        if 'P3_INPUT_FILE' in request.form.keys():
            indata = request.form['P3_INPUT_FILE']
            indata = indata.replace('\r\n', '\n')
            indata = indata.replace('\r', '\n')
            infile = os.path.join(sf, "p3p_" + uuidstr + "_input.txt")
            modin = regEq.sub(P3PATHFIX, indata)
            modin = regLibP.sub(P3LIBPFIX, modin)
            modin = regLibIN.sub(P3LIBINFIX, modin)
            with open(infile, "w") as infileHandle:
                infileHandle.write(modin)

            # Run Primer3 
            outfile = os.path.join(sf, "p3p_" + uuidstr + "_output.txt")
            p3efile = os.path.join(sf, "p3p_" + uuidstr + "_error.txt")
            logfile = os.path.join(sf, "p3p_" + uuidstr + ".log")
            errfile = os.path.join(sf, "p3p_" + uuidstr + ".err")
            p3p_err_str = ""
            with open(logfile, "w") as log:
                with open(errfile, "w") as err:
                    try:
                        p3_args = ['primer3_core', '--strict_tags', '--output=' + outfile, '--error=' + p3efile, infile]
                      #  print('\nCall: ' + " ".join(p3_args) + "\n")
                      #  print('\nInput: ' + infile + "\n")
                        stat = {'timeout':False}
                        proc = subprocess.Popen(p3_args, stdout=log, stderr=err)
                        timer = threading.Timer(KILLTIME, p3_watchdog, (proc, stat))
                        timer.start()
                        proc.wait()
                        timer.cancel()
                        if stat['timeout'] and not proc.returncode == 100:
                            p3p_err_str += "Error: Primer3 was teminated due to long runtime of more than " + str(KILLTIME)  + " seconds!"
                    except OSError as e:
                        if e.errno == os.errno.ENOENT:
                            return jsonify(errors = [{"title": "Binary ./primer3core not found!"}]), 400
                        else:
                            return jsonify(errors = [{"title": "OSError " + str(e.errno)  + " running binary ./primer3core!"}]), 400
#        print (str(return_code) + "\n")                    
        with open(errfile, "r") as err:
            errInfo = "" + err.read()
            with open(outfile, "r") as out:
                data = out.read() 
                if not p3p_err_str == "":
                    data += "\n" + "P3P_ERROR=" + p3p_err_str + "\n"
                return data, 200
    return jsonify(errors = [{"title": "Error in handling POST request!"}]), 400

@app.route('/api/v1/upload', methods=['GET','POST'])
def uploadData():
#    print(".......up............." + request.method)
    if (request.method == 'GET') or (request.method == 'POST'):
        uuidstr = str(uuid.uuid4())

        # Get subfolder
        sf = os.path.join(app.config['UPLOAD_FOLDER'], uuidstr[0:2])
        if not os.path.exists(sf):
            os.makedirs(sf)

        # Write Data to File
        upfile = os.path.join(sf, "p3p_" + uuidstr + "_upload.txt")
        with open(upfile, "w") as dat:
            if request.method == 'POST':
                for tag in request.form.keys():
                    tag = tag.replace('=', '_')
                    tag = tag.replace('\n', '_')
                    val = request.form[tag]
                    val = val.replace('=', '_')
                    val = val.replace('\n', '_')
                    dat.write(tag + "=" + val + "\n")
            if request.method == 'GET':
                for tag in request.args.keys():
                    tag = tag.replace('=', '_')
                    tag = tag.replace('\n', '_')
                    val = request.args.get(tag)
                    val = val.replace('=', '_')
                    val = val.replace('\n', '_')
                    dat.write(tag + "=" + val + "\n")
        # print (upfile)
        return redirect(app.config['BASEURL'] + "?UUID=" + uuidstr, code=302)
    return redirect(app.config['BASEURL'], code=302)

@app.route('/api/v1/loadServerData', methods=['POST'])
def loadServerData():
    if request.method == 'POST':
        if 'P3P_UUID' in request.form.keys():
            uuid = secure_filename(request.form['P3P_UUID'])
            if is_valid_uuid(uuid):
                sf = os.path.join(app.config['UPLOAD_FOLDER'], uuid[0:2])
                if os.path.exists(sf):
                    upfile = os.path.join(sf, "p3p_" + uuid + "_upload.txt")
                    if os.path.isfile(upfile):          
                        with open(upfile, "r") as out:
                            data = out.read()
                            return data, 200
    return "", 400

@app.route('/api/v1/primer3version', methods=['POST'])
def p3version():
    try:
        process = Popen(["primer3_core", "-about"], stdout=PIPE)
        (output, err) = process.communicate()
        exit_code = process.wait()
    except OSError as e:
        if e.errno == os.errno.ENOENT:
            return "Binary ./primer3core not found!", 200
        else:
            return "OSError " + str(e.errno)  + " running binary ./primer3core!", 200
    if exit_code != 0:
        return "Error in running Primer3Plus!", 200
    return output, 200

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
