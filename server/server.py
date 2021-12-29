#! /usr/bin/env python

#   Copyright (C) 2018 by Andreas Untergasser
#   All rights reserved.
# 
#   This file is part of Primer3Plus. Primer3Plus is a web interface to Primer3.
# 
#   The Primer3Plus is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 3 of the License, or
#   (at your option) any later version.
# 
#   Primer3Plus is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
# 
#   You should have received a copy of the GNU General Public License
#   along with this Primer3Plus. If not, see <https:# www.gnu.org/licenses/>.

import os
import uuid
import re
import subprocess
import threading
import argparse
import json
import datetime
from subprocess import call, Popen, PIPE
from flask import Flask, send_file, flash, send_from_directory, request, redirect, url_for, jsonify
from flask_cors import CORS
from werkzeug.utils import secure_filename
from ipaddress import ip_address

P3PWS = os.path.dirname(os.path.abspath(__file__))

app = Flask(__name__)
CORS(app)
app.config['PRIMER3PLUS'] = os.path.join(P3PWS, "..")
app.config['UPLOAD_FOLDER'] = os.path.join(app.config['PRIMER3PLUS'], "data")
app.config['LOG_FOLDER'] = os.path.join(app.config['PRIMER3PLUS'], "log")
app.config['MAX_CONTENT_LENGTH'] = 8 * 1024 * 1024   #maximum of 8MB

app.config['BASEURL'] = os.environ.get('URL_INDEX', 'http://localhost:1234/index.html')

KILLTIME = 60 # time in seconds till Primer3 is killed!
LOGP3RUNS = True  # log the primer3 runs
LOGIPANONYM = True  # anonymize the ip address in log files

regEq = re.compile(r"PRIMER_THERMODYNAMIC_PARAMETERS_PATH=[^\n]*\n")

P3LIBPFIX = "PRIMER_MISPRIMING_LIBRARY=" +  os.path.join(P3PWS, "mispriming_lib/")
regLibP = re.compile(r"PRIMER_MISPRIMING_LIBRARY=")
P3LIBINFIX = "PRIMER_INTERNAL_MISHYB_LIBRARY=" +  os.path.join(P3PWS, "mispriming_lib/")
regLibIN = re.compile(r"PRIMER_INTERNAL_MISHYB_LIBRARY=")

regLPrim = re.compile(r"PRIMER_LEFT_NUM_RETURNED=([^\n]*)\n")
regIPrim = re.compile(r"PRIMER_INTERNAL_NUM_RETURNED=([^\n]*)\n")
regRPrim = re.compile(r"PRIMER_RIGHT_NUM_RETURNED=([^\n]*)\n")


def logData(pProg, pKey, pValue, uuid):
    if not LOGP3RUNS:
        return

    runTime = datetime.datetime.utcnow()
    addLine = runTime.strftime("%Y-%m-%dT%H:%M:%S")
    addLine += "\t" + pProg + "\t" + pKey + "\t" + pValue + "\t" + uuid + "\t"
    if LOGIPANONYM:
        ip_bit = ip_address(request.remote_addr).packed
        mod_ip = bytearray(ip_bit)
        if len(ip_bit) == 4:
            mod_ip[3] = 0
        if len(ip_bit) == 16:
            for count_ip in range(6, len(mod_ip)):
                mod_ip[count_ip] = 0
        addLine += str(ip_address(bytes(mod_ip))) + "\t\t"
    else:
        addLine += request.remote_addr + "\t\t"
    addLine += request.headers.get('User-Agent').replace("\t", " ") + "\n"

    statFile = os.path.join(app.config['LOG_FOLDER'], "p3_runs_" + runTime.strftime("%Y_%m_%d") + ".log")
    with open(statFile, "a") as stat:
        stat.write(addLine)


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
        if not os.path.exists(app.config['LOG_FOLDER']):
            os.makedirs(app.config['LOG_FOLDER'])

        # Experiment
        if 'P3_INPUT_FILE' in request.form.keys():
            indata = request.form['P3_INPUT_FILE']
            indata = indata.replace('\r\n', '\n')
            indata = indata.replace('\r', '\n')
            infile = os.path.join(sf, "p3p_" + uuidstr + "_input.txt")
            modin = regEq.sub("", indata)
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
                data += "\n" + "P3P_UUID=" + uuidstr + "\n"
                if not p3p_err_str == "":
                    data += "P3P_ERROR=" + p3p_err_str + "\n"
                if LOGP3RUNS:
                    state = "Primer3_Pick_Fail"
                    prCount = 0
                    llpr = regLPrim.search(data)
                    if llpr:
                        prCount += int(llpr.group(1))
                    inpr = regIPrim.search(data)
                    if inpr:
                        prCount += int(inpr.group(1))
                    rrpr = regRPrim.search(data)
                    if rrpr:
                        prCount += int(rrpr.group(1))
                    if prCount > 0:
                        state = "Primer3_Pick_Success"
                    logData("Primer3Plus", state, str(prCount), uuidstr)
                return jsonify({"outfile": data}), 200
        logData("Primer3Plus", "Primer3_Pick_Error", '0', uuidstr)
        return jsonify(errors=[{"title": "Error in handling POST request!"}]), 400
    return jsonify(errors=[{"title": "Error: No POST request!"}]), 400


@app.route('/api/v1/runprefold', methods=['POST'])
def runprefold():
    if request.method == 'POST':
        uuidstr = str(uuid.uuid4())

        # Get subfolder
        sf = os.path.join(app.config['UPLOAD_FOLDER'], uuidstr[0:2])
        if not os.path.exists(sf):
            os.makedirs(sf)
        if not os.path.exists(app.config['LOG_FOLDER']):
            os.makedirs(app.config['LOG_FOLDER'])

        # Experiment
        data = ""
        if 'P3_INPUT_FILE' in request.form.keys():
            indata = request.form['P3_INPUT_FILE']
            indata = indata.replace('\r\n', '\n')
            indata = indata.replace('\r', '\n')
            infile = os.path.join(sf, "prf_" + uuidstr + "_input.txt")
            with open(infile, "w") as infileHandle:
                infileHandle.write(indata)

            # Run UNAFold
            outfile = os.path.join(sf, "p3p_" + uuidstr + "_upload.txt")
            seqfile = os.path.join(sf, "prf_" + uuidstr + "_seq.txt")
            p3efile = os.path.join(sf, "prf_" + uuidstr + "_error.txt")
            logfile = os.path.join(sf, "prf_" + uuidstr + ".log")
            errfile = os.path.join(sf, "prf_" + uuidstr + ".err")
            p3p_err_str = ""
            dat_temp = 0.0
            dat_mv = 0.0
            dat_dv = 0.0
            dat_start = 0
            dat_id = ""
            dat_seq = ""
            dat_use_seq = ""
            dat_incl = ""
            dat_incl_start = 0
            dat_incl_len = 0
            dat_incl_found = False
            with open(logfile, "w") as log:
                with open(errfile, "w") as err:
                    with open(outfile, "w") as out:
                        line_data = indata.split("\n")
                        for line in line_data:
                            curr = line.split("=")
                            if len(curr) != 2:
                                continue
                            if curr[0] == "PRIMER_ANNEALING_TEMP":
                                dat_temp = re.sub("[^0-9\.]", "", curr[1])
                                data += "PRIMER_ANNEALING_TEMP=" + dat_temp + "\n"
                            if curr[0] == "PRIMER_SALT_DIVALENT":
                                dat_dv = re.sub("[^0-9\.]", "", curr[1])
                                data += "PRIMER_SALT_DIVALENT=" + dat_dv + "\n"
                            if curr[0] == "PRIMER_SALT_MONOVALENT":
                                dat_mv = re.sub("[^0-9\.]", "", curr[1])
                                data += "PRIMER_SALT_MONOVALENT=" + dat_mv + "\n"
                            if curr[0] == "PRIMER_FIRST_BASE_INDEX":
                                dat_start = int(re.sub("[^0-9]", "", curr[1]))
                                data += "PRIMER_FIRST_BASE_INDEX=" + str(dat_start) + "\n"
                            if curr[0] == "SEQUENCE_ID":
                                dat_id = re.sub("[^0-9A-Za-z _,\.]", "", curr[1])
                                data += "SEQUENCE_ID=" + dat_id + "\n"
                            if curr[0] == "SEQUENCE_INCLUDED_REGION":
                                dat_incl = re.sub("[^0-9,]", "", curr[1])
                                incl_spl = dat_incl.split(",")
                                if len(incl_spl) == 2:
                                    dat_incl_start = int(incl_spl[0])
                                    dat_incl_len = int(incl_spl[1])
                                    dat_incl_found = True
                            if curr[0] == "SEQUENCE_TEMPLATE":
                                dat_seq = re.sub("[^ACGTNacgtn]", "", curr[1])
                                dat_use_seq = dat_seq
                                data += "SEQUENCE_TEMPLATE=" + dat_seq + "\n"

                        out.write(data)

                        if dat_incl_found:
                            dat_incl_start -= int(dat_start)
                            if dat_incl_start >= 0 and dat_incl_len  >= 20 and len(dat_seq) > dat_incl_start:
                                dat_use_seq = dat_seq[dat_incl_start: (dat_incl_start + dat_incl_len)]

                        if len(dat_use_seq) > 2000:
                            return jsonify(errors = [{"title": "Sequence to long. Limit with SEQUENCE_INCLUDED_REGION to < 2000 bp."}]), 400

                        if len(dat_use_seq) < 20:
                            return jsonify(errors = [{"title": "Sequence to short < 20 bp."}]), 400

                        if float(dat_mv) < 1.0 or float(dat_mv) > 1000.0:
                            return jsonify(errors = [{"title": "Monovalent ions must be 1.0 - 1000.0."}]), 400

                        if float(dat_dv) < 1.0 or float(dat_dv) > 1000.0:
                            return jsonify(errors = [{"title": "Divalent ions must be 1.0 - 1000.0."}]), 400

                        if float(dat_temp) < 1.0 or float(dat_temp) > 99.0:
                            return jsonify(errors = [{"title": "Annealing Temp.  must be 1.0 - 99.0."}]), 400

                        with open(seqfile, "w") as seqout:
                            seqout.write(dat_use_seq)

                        # Do not trust user input for command line
                        dat_mv = str(float(dat_mv) / 1000.0)
                        dat_dv = str(float(dat_dv) / 1000.0)
                        dat_temp = str(float(dat_temp))

                        try:  # hybrid-ss-min seq.txt -n DNA -N 0.05 -M 0.0015 -t 60.0 -T 60.0 -o seq.txt
                            p3_args = ['hybrid-ss-min', seqfile, '-n', 'DNA', '-N', dat_mv, 
                                       '-M', dat_dv, '-t', dat_temp, '-T', dat_temp, '-o', seqfile]
                        #   print('\nCall: ' + " ".join(p3_args) + "\n")
                        #   print('\nInput: ' + seqfile + "\n")
                            stat = {'timeout':False}
                            proc = subprocess.Popen(p3_args, stdout=log, stderr=err)
                            timer = threading.Timer(KILLTIME, p3_watchdog, (proc, stat))
                            timer.start()
                            proc.wait()
                            timer.cancel()
                            if stat['timeout'] and not proc.returncode == 100:
                                p3p_err_str += "Error: UNAFold was teminated due to long runtime of more than " + str(KILLTIME)  + " seconds!"
                        except OSError as e:
                            if e.errno == os.errno.ENOENT:
                                return jsonify(errors = [{"title": "UNAFold Binary not found! Use server www.primer3plus.com"}]), 400
                            else:
                                return jsonify(errors = [{"title": "OSError " + str(e.errno)  + " running binary ./hybrid-ss-min!"}]), 400
#        print (str(return_code) + "\n")                    
        with open(errfile, "r") as err:
            with open(outfile, "a") as out:
                errInfo = "" + err.read()
                outdata = ""
                excl_reg = ""
                in_reg = False
                try: 
                    with open(seqfile + ".ct", "r") as res:
                        outdata = res.read()
                except OSError as e:
                    return jsonify(errors = [{"title": "UNAFold cound not process the request."}]), 400

                state = "no_sec_struct"
                line_data = outdata.split("\n")
                deltG = line_data[0].split("\t")
                if len(deltG) > 1:
                    data += "P3P_PREFOLD_DELTA_G=" + re.sub("dG = ", "", deltG[1]) + "\n"
                data += "P3P_UUID=" + uuidstr + "\n"
                excl_reg = ""
                inc_start = 0
                inc_end = 0
                inc_last = 0
                if len(line_data) > 20:
                    cells = line_data[1].split("\t")
                    for line in line_data:
                        cells = line.split("\t")
                        if len(cells) > 6:
                            if int(cells[4]) == 0 and in_reg == True:
                                inc_end = int(cells[0]) - 1
                                excl_reg += str(dat_incl_start + dat_start + inc_start)
                                excl_reg += "," + str(inc_end - inc_start) + " "
                                in_reg = False
                            if int(cells[4]) != 0 and in_reg == False:
                                inc_start = int(cells[0]) - 1
                                in_reg = True
                            if int(cells[4]) != 0:
                                inc_last = int(cells[0]) - 1
                    if in_reg == True:
                        excl_reg += str(dat_incl_start + dat_start + inc_start)
                        excl_reg += "," + str(inc_last - inc_start) + " "
                    data += "SEQUENCE_EXCLUDED_REGION=" + re.sub(" +$", "", excl_reg) + "\n"
                    out.write("SEQUENCE_EXCLUDED_REGION=" + re.sub(" +$", "", excl_reg) + "\n")
                    state = "found_sec_struct"
                else:
                    data += "P3P_ERROR=UNAFold did not return data.\n"
                logData("Primer3Prefold", "UNAFold_run", state, uuidstr)
                return jsonify({"outfile": data}), 200
    return jsonify(errors=[{"title": "Error: No POST request!"}]), 400


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
        logData("Primer3Plus", "Post_Get_Data", '0', uuidstr)
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
                    upData = "";
                    if os.path.isfile(upfile):          
                        with open(upfile, "r") as upfh:
                            upData = upfh.read()
                    infile = os.path.join(sf, "p3p_" + uuid + "_input.txt")
                    inData = "";
                    if os.path.isfile(infile):
                        with open(infile, "r") as infh:
                            inData = infh.read()
                    outfile = os.path.join(sf, "p3p_" + uuid + "_output.txt")
                    outData = "";
                    if os.path.isfile(outfile):          
                        with open(outfile, "r") as outfh:
                            outData = outfh.read()
                            outData += "\n" + "P3P_UUID=" + uuid + "\n"
                    logData("Primer3Plus", "Load_Server_Data", '0', uuid)
                    return jsonify({"upfile": upData, "infile": inData, "outfile": outData}), 200
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
            logData("Primer3Plus", "Load_Settings_File", '0', "---")
            return send_from_directory(os.path.join(P3PWS, "settings_files"),filename), 200
    return jsonify(errors = [{"title": "Could not find file on server!"}]), 400


@app.route('/api/v1/defaultsettings', methods=['POST'])
def defaultsettings():
    logData("Primer3Plus", "Load_Default_Settings", '0', "---")
    return send_from_directory(os.path.join(P3PWS, "settings_files"),"default_settings.json"), 200


@app.route('/api/v1/health', methods=['GET'])
def health():
    return jsonify(status="OK")


if __name__ == '__main__':
    app.run(host = '0.0.0.0', port=3300, debug = True, threaded=True)
