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
import sys
import datetime

P3PWS = os.path.dirname(os.path.abspath(__file__))
P3LOG = os.path.join(P3PWS, "..", "log")

def sumLogs(direct, fileKey, monthShift, writeFile):
    if monthShift > 12 or monthShift < 0:
        return
    runTime = datetime.datetime.now(datetime.UTC)
    year = int(runTime.strftime("%Y"))
    month = int(runTime.strftime("%m"))
    month -= monthShift
    timeStamp = ""
    saveStamp = ""
    if month < 1:
        month += 12
        year -= 1
    if month < 10:
        timeStamp = str(year) + "_0" + str(month)
        saveStamp = str(year) + "-0" + str(month)
    else:
        timeStamp = str(year) + "_" + str(month)
        saveStamp = str(year) + "-" + str(month)
    logFile = os.path.join(P3LOG, fileKey + timeStamp + ".log")
    rawdata = ""
    try: 
        with open(logFile, "r") as res:
            rawdata = res.read()
    except OSError as e:
        return

    firstKey = {}
    secondKey = {}
    finalData = {}
        
    tableData = rawdata.split("\n")
    for row in tableData:
        cells = row.split("\t")
        if len(cells) > 5:
            curKey = cells[1] + "_" + cells[2]
            if curKey in finalData:
                finalData[curKey] += 1
            else:
                finalData[curKey] = 1
                firstKey[curKey] = cells[1]
                secondKey[curKey] = cells[2]

    sumFile = os.path.join(P3LOG, fileKey + timeStamp + ".sum")
    with open(sumFile, "w") as sum:
        for curKey in finalData.keys():
            sum.write(saveStamp + "\t" + firstKey[curKey] + "\t" + secondKey[curKey] + "\t" + str(finalData[curKey]) + "\n")


if __name__ == '__main__':
    rawData = ""
    finalData = {}

    logFiles = [f for f in os.listdir(P3LOG) if os.path.isfile(os.path.join(P3LOG, f))]
    for fil in logFiles:
        if not fil.startswith("p3_runs_"):
            continue
        if not fil.endswith(".sum"):
            continue
        with open(os.path.join(P3LOG, fil), "r") as res:
            rawData += res.read()
        rawData += "\n"

    tableData = rawData.split("\n")
    for row in tableData:
        cells = row.split("\t")
        if len(cells) > 3:
            if cells[0] not in finalData:
                finalData[cells[0]] = {}
            if cells[1] not in finalData[cells[0]]:
                finalData[cells[0]][cells[1]] = {}
            if cells[2] not in finalData[cells[0]][cells[1]]:
                finalData[cells[0]][cells[1]][cells[2]] = 0

            print("add " +cells[0] )
            finalData[cells[0]][cells[1]][cells[2]] += int(cells[3])

    sumFile = os.path.join(P3LOG, "joinSum.out")
    with open(sumFile, "w") as sum:
        for primKey in sorted(finalData.keys()):
            for secKey in sorted(finalData[primKey].keys()):
                for tertKey in sorted(finalData[primKey][secKey].keys()):
                    sum.write(primKey + "\t" + secKey + "\t" + tertKey + "\t" + str(finalData[primKey][secKey][tertKey]) + "\n")



