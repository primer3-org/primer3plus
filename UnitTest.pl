#!/usr/bin/perl -w

#  Copyright (c) 2006, 2007
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

use Test::More tests => 7;

BEGIN {
	use_ok('Primer3Functions');
	use_ok('Settings');
}
require_ok('Primer3Functions');
require_ok('Settings');

$| = 1;

testReverseSequence();
testConstructCombinedHash();

# checkPrimer
$test_name   = "checkPrimer";
$resultsHash = {};

%$inputHash = Settings::return_default_settings();

#foreach $param (primer3plus_Functions::primer3_primer_check_parameters()) {
#	$inputHash->{$param} = "";
#}

#$inputHash->{"PRIMER_LEFT_INPUT"} = "AAAAAAAAAAAAAAAAAAAAAAA";
$inputHash->{"PRIMER_LEFT_INPUT"} = "TATGCTCACGCACATCACTATC";

@outarray = Primer3Functions::checkPrimer( $inputHash, $resultsHash );

print "inputHash:\n";
foreach $key ( keys %$inputHash ) {
	print "$key: $inputHash->{$key}\n";
}

print "ResultsHash:\n";

foreach $key ( keys %$resultsHash ) {
	print "$key: $resultsHash->{$key}\n";
}

print $resultsHash->{PRIMER_LEFT_END_STABILITY}, "\n";
print "@outarray\n";

# read_HTML_parameters
# createSequenceFile
# createSettingsFile
# loadFile
# checkParameters
# add_start_len_list
# read_sequence_markup
# read_sequence_markup_1_delim
# len_to_delim
# prepareForPrimer3
# runPrimer3
# detection
# readPrimerFile
# executePrimer3

# makeUniqueID

# Various ways to say "ok"
#ok($this eq $that, $test_name);
#is  ($this, $that,    $test_name);
#isnt($this, $that,    $test_name);

# Rather than print STDERR "# here's what went wrong\n"
#diag("here's what went wrong");

#like  ($this, qr/that/, $test_name);
#unlike($this, qr/that/, $test_name);

#cmp_ok($this, '==', $that, $test_name);

#is_deeply($complex_structure1, $complex_structure2, $test_name);

sub testReverseSequence {
	my $reverseSequenceNotOk = shift;
	my $sequence             = shift;
	my $test_name            = shift;
	my $reverseSequenceOk    = shift;

	# reverseSequence
	$test_name            = "reverseSequence()";
	$sequence             = "AGCTGCGATCGATCGCCGATC";
	$reverseSequenceOk    = "GATCGGCGATCGATCGCAGCT";
	$reverseSequenceNotOk = "GATCGGCGATCGATCGCAGC";

	cmp_ok( reverseSequence($sequence),
			'eq', $reverseSequenceOk, $test_name . "Ok" );
	cmp_ok( reverseSequence($sequence),
			'ne', $reverseSequenceNotOk, $test_name . "NotOk" );
}

#this the testConstructCombinedHash function
sub testConstructCombinedHash {
	my $test_name;

	# constructCombinedHash
	$test_name    = "constructCombinedHash()";
	%hash1        = ( a => "1", b => "2" );
	%hash2        = ( a => "3", c => "4" );
	%hashresultOk = ( a => "3", b => "2", c => "4" );

	is_deeply( { constructCombinedHash( %hash1, %hash2 ) },
			   \%hashresultOk, $test_name . "Ok" );

}


