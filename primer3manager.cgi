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

$parametersHTML{"SCRIPT_DISPLAY_DEBUG_INFORMATION"} = 1;


print "Content-type: text/html\n\n";
print mainResultsHTML( \%parametersHTML, \%parametersHTML ), "\n";


