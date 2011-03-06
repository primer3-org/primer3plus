#!/usr/bin/perl -w

#  Copyright (c) 2006 - 2011
#  by Andreas Untergasser and Harm Nijveen
#  All rights reserved.
# 
#  This file is part of Primer3Plus. Primer3Plus is a webinterface to primer3.
# 
#  The Primer3Plus is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
# 
#  Primer3Plus is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
# 
#  You should have received a copy of the GNU General Public License
#  along with Primer3Plus (file gpl.txt in the source distribution);
#  if not, write to the Free Software Foundation, Inc., 51 Franklin St,
#  Fifth Floor, Boston, MA  02110-1301  USA


# Primer3Plus will send two types of information, pairs and lists of primers.
# Pairs are selected and named at the pair level and can be used directly.
# Primerlists from Primer3Plus will have to be realigned. In P3P left and right
# primers coexist without being a pair. In Primer3Manager, each of this primers
# must form a "pair" which has only one primer to match RDML later.
# For primerlists the name and selection is on the primer level, which has to 
# be realigned for Primer3Manager, for each PRIMER_PAIR_4_NAME all missing 
# information is created.
# After the realignment each pair will have a PRIMER_PAIR_4_NAME, 
# a PRIMER_PAIR_4_SELECT, a PRIMER_PAIR_4_AMPLICON, a PRIMER_PAIR_4_DATE and
# PRIMER_LEFT_4_SEQUENCE, PRIMER_INTERNAL_4_SEQUENCE, a PRIMER_RIGHT_4_SEQUENCE.
# A PRIMER_INTERNAL2_4_SEQUENCE is introduced for RDML compartibility.
# They will contain information or empty strings "".

use strict;
use primer3plusFunctions;
use settings;
use HtmlFunctions;
use customPrimerOrder;

my %parametersHTML;
my %completeParameters;
my %resultsHash;
my $primerUnitsCounter;

$primerUnitsCounter = 0;

# Get the HTML-Input and the default settings
getParametersHTML(\%parametersHTML);

#TODO: remove
$parametersHTML{"SCRIPT_DISPLAY_DEBUG_INFORMATION"} = 1;

extractCompleteManagerHash(\%completeParameters, \%parametersHTML);

print "Content-type: text/html\n\n";
print createManagerDisplayHTML( \%completeParameters, \%parametersHTML), "\n";


