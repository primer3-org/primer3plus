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
package customPrimerOrder;
use CGI::Carp qw(fatalsToBrowser);
use Exporter;
use HtmlFunctions;

our (@ISA, @EXPORT, @EXPORT_OK, $VERSION);

@ISA = qw(Exporter);
@EXPORT = qw(&customPrimerOrder);
$VERSION = "1.00";

sub customPrimerOrder {
  my ($hash, $counter, $name, $fullName) ; 
  $hash = shift;

  my $templateText = getWrapper();
  my $formHTML;

###########################################################
# Here starts the part we consider NOT covered by the GPL #
# to allow Users and Companies to adapt the orderform to  #
# their needs. Modifications from here till the next      #
# bock do not have to be made available as open source    #
###########################################################

  $formHTML = qq{<br><div id="primer3plus_order">
   <h1>Primers to order:</h1>
   <a>Please copy this message and send it via e-mail to your order address:</a><br>
   <br>
   <form action="">
      <textarea name="copy_out" cols="80" rows="20">
};

for($counter = 0; $counter <= $hash->{"PRIMER_PAIR_NUM_RETURNED"}; $counter++) {
   if ($hash->{"PRIMER_PAIR_$counter\_SELECT"} == 1 ) {
   	   $name = $hash->{"PRIMER_PAIR_$counter\_NAME"};
       $name =~ s/ /_/g;
       if ($hash->{"PRIMER_LEFT_$counter\_SEQUENCE"} ne "") {
           $fullName = $name . $hash->{"P3P_PRIMER_NAME_ACRONYM_SPACER"} . $hash->{"P3P_PRIMER_NAME_ACRONYM_LEFT"};
           $formHTML .= qq{$fullName $hash->{"PRIMER_LEFT_$counter\_SEQUENCE"}};
           $formHTML .= "\n";
       }
       if ($hash->{"PRIMER_RIGHT_$counter\_SEQUENCE"} ne "") {
           $fullName = $name . $hash->{"P3P_PRIMER_NAME_ACRONYM_SPACER"} . $hash->{"P3P_PRIMER_NAME_ACRONYM_RIGHT"};
           $formHTML .= qq{$fullName $hash->{"PRIMER_RIGHT_$counter\_SEQUENCE"}};
           $formHTML .= "\n";
       }
       if ($hash->{"PRIMER_INTERNAL_$counter\_SEQUENCE"} ne "") {
           $fullName = $name . $hash->{"P3P_PRIMER_NAME_ACRONYM_SPACER"} . $hash->{"P3P_PRIMER_NAME_ACRONYM_INTERNAL"};
           $formHTML .= qq{$fullName $hash->{"PRIMER_INTERNAL_$counter\_SEQUENCE"}};
           $formHTML .= "\n";
       }       
   }
};

$formHTML .= qq{   </textarea>
   </form>
};

  my $returnString = $templateText;

  $returnString =~ s/<!-- Primer3plus will include code here -->/$formHTML/;

##########################################################
# Here ends the part we consider NOT part of the GPL     #
# to allow Users and Companies to adapt the orderform to #
# their needs. Modifications from the upper block till   #
# here do not have to be made available as open source   #
##########################################################

  return $returnString;

}

