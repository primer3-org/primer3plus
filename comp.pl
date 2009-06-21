#!/usr/bin/perl -w

use strict;


my %defaultSettings = (
# Begin Primer3 Input Parameters
# Primer3 "Sequence" Input Tags
  "SEQUENCE_ID"                              => "",
  "SEQUENCE_TEMPLATE"                        => "", 
  "SEQUENCE_INCLUDED_REGION"                 => "",
  "SEQUENCE_TARGET"                          => "",
  "SEQUENCE_EXCLUDED_REGION"                 => "",
  "SEQUENCE_QUALITY"                         => "",
  "SEQUENCE_PRIMER"                          => "",
  "SEQUENCE_PRIMER_REVCOMP"                  => "",
  "SEQUENCE_START_CODON_POSITION"            => "", #"-1000000",
# Primer3 "Global" Input Tags
  "PRIMER_TASK"                              => "pick_detection_primers",
  "PRIMER_PICK_LEFT_PRIMER"                  => "1",
  "PRIMER_PICK_INTERNAL_OLIGO"               => "0",
  "PRIMER_PICK_RIGHT_PRIMER"                 => "1",
  "PRIMER_PICK_ANYWAY"	                     => "1",
  "PRIMER_EXPLAIN_FLAG"                      => "0",
  "PRIMER_LOWERCASE_MASKING"                 => "0",
  "PRIMER_MISPRIMING_LIBRARY"                => "NONE",
  "PRIMER_LIB_AMBIGUITY_CODES_CONSENSUS"     => "1",
  "PRIMER_MAX_LIBRARY_MISPRIMING"            => "12.00",
  "PRIMER_MAX_TEMPLATE_MISPRIMING"           => "12.00",
  "PRIMER_PAIR_MAX_LIBRARY_MISPRIMING"       => "24.00",
  "PRIMER_PAIR_MAX_TEMPLATE_MISPRIMING"      => "24.00",
  "PRIMER_PRODUCT_MIN_TM"                    => "", #"-1000000.0",
  "PRIMER_PRODUCT_OPT_TM"                    => "",
  "PRIMER_PRODUCT_MAX_TM"                    => "", #"1000000.0",
  "PRIMER_PRODUCT_OPT_SIZE"                  => "0",
  "PRIMER_PRODUCT_SIZE_RANGE"                => "150-250 100-300 301-400 401-500 501-600 601-700 701-850 851-1000",  
  "PRIMER_GC_CLAMP"                          => "0",
  "PRIMER_OPT_SIZE"                          => "20",
  "PRIMER_MIN_SIZE"                          => "18",
  "PRIMER_MAX_SIZE"                          => "27",
  "PRIMER_OPT_TM"                            => "60.0",
  "PRIMER_MIN_TM"                            => "57.0",
  "PRIMER_MAX_TM"                            => "63.0",
  "PRIMER_PAIR_MAX_DIFF_TM"                  => "100.0",
  "PRIMER_MIN_GC"                            => "20.0",
  "PRIMER_OPT_GC_PERCENT"                    => "",
  "PRIMER_MAX_GC"                            => "80.0",
  "PRIMER_SALT_MONOVALENT"                   => "50.0",
  "PRIMER_SALT_DIVALENT"                     => "0.0",
  "PRIMER_DNTP_CONC"                         => "0.0",
  "PRIMER_SALT_CORRECTIONS"                  => "0",
  "PRIMER_TM_FORMULA"                        => "0",
  "PRIMER_DNA_CONC"                          => "50.0",
  "PRIMER_MAX_NS_ACCEPTED"                   => "0",
  "PRIMER_MAX_SELF_ANY"                      => "8.00",
  "PRIMER_MAX_SELF_END"                      => "3.00",
  "PRIMER_MAX_POLY_X"                        => "5",
  "PRIMER_LIBERAL_BASE"                      => "1",
  "PRIMER_NUM_RETURN"                        => "5",
  "PRIMER_FIRST_BASE_INDEX"                  => "1",
  "PRIMER_MIN_QUALITY"                       => "0",
  "PRIMER_MIN_END_QUALITY"                   => "0",
  "PRIMER_QUALITY_RANGE_MIN"                 => "0",
  "PRIMER_QUALITY_RANGE_MAX"                 => "100",
  "PRIMER_INSIDE_PENALTY"                    => "",
  "PRIMER_OUTSIDE_PENALTY"                   => "0",
  "PRIMER_MAX_END_STABILITY"                 => "9.0",
  "PRIMER_WT_TM_GT"                          => "1.0",
  "PRIMER_WT_TM_LT"                          => "1.0",
  "PRIMER_WT_SIZE_LT"                        => "1.0",
  "PRIMER_WT_SIZE_GT"                        => "1.0",
  "PRIMER_WT_GC_PERCENT_LT"                  => "0.0",
  "PRIMER_WT_GC_PERCENT_GT"                  => "0.0",
  "PRIMER_WT_SELF_ANY"                       => "0.0",
  "PRIMER_WT_SELF_END"                       => "0.0",
  "PRIMER_WT_NUM_NS"                         => "0.0",
  "PRIMER_PAIR_WT_LIBRARY_MISPRIMING"        => "0.0",
  "PRIMER_WT_SEQ_QUAL"                       => "0.0",
  "PRIMER_WT_END_QUAL"                       => "0.0",
  "PRIMER_WT_POS_PENALTY"                    => "0.0",
  "PRIMER_WT_END_STABILITY"                  => "0.0",
  "PRIMER_WT_TEMPLATE_MISPRIMING"            => "0.0",
  "PRIMER_PAIR_WT_PR_PENALTY"                => "1.0",
  "PRIMER_PAIR_WT_IO_PENALTY"                => "0.0",
  "PRIMER_PAIR_WT_DIFF_TM"                   => "0.0",
  "PRIMER_PAIR_WT_COMPL_ANY"                 => "0.0",
  "PRIMER_PAIR_WT_COMPL_END"                 => "0.0",
  "PRIMER_PAIR_WT_PRODUCT_TM_LT"             => "0.0",
  "PRIMER_PAIR_WT_PRODUCT_TM_GT"             => "0.0",
  "PRIMER_PAIR_WT_PRODUCT_SIZE_GT"           => "0.0",
  "PRIMER_PAIR_WT_PRODUCT_SIZE_LT"           => "0.0",
  "PRIMER_PAIR_WT_LIBRARY_MISPRIMING"        => "0.0",
  "PRIMER_PAIR_WT_TEMPLATE_MISPRIMING"       => "0.0",
  "PRIMER_SEQUENCING_LEAD"                   => "50",
  "PRIMER_SEQUENCING_SPACING"                => "500",
  "SCRIPT_SEQUENCING_REVERSE"                => "1",
  "PRIMER_SEQUENCING_INTERVAL"               => "250",
  "PRIMER_SEQUENCING_ACCURACY"               => "20",
# Primer3 Internal Oligo "Sequence" Input Tags
  "SEQUENCE_INTERNAL_EXCLUDED_REGION"        => "",
  "SEQUENCE_INTERNAL_OLIGO"                  => "",
# Primer3 Internal Oligo "Global" Input Tags
  "PRIMER_INTERNAL_OPT_SIZE"                 => "20",
  "PRIMER_INTERNAL_MIN_SIZE"                 => "18",
  "PRIMER_INTERNAL_MAX_SIZE"                 => "27",
  "PRIMER_INTERNAL_OPT_TM"                   => "60.0",
  "PRIMER_INTERNAL_MIN_TM"                   => "57.0",
  "PRIMER_INTERNAL_MAX_TM"                   => "63.0",
  "PRIMER_INTERNAL_MIN_GC"                   => "20.0",
  "PRIMER_INTERNAL_OPT_GC_PERCENT"           => "",
  "PRIMER_INTERNAL_MAX_GC"                   => "80.0",
  "PRIMER_INTERNAL_SALT_MONOVALENT"          => "50.0",
  "PRIMER_INTERNAL_SALT_DIVALENT"            => "0.0",
  "PRIMER_INTERNAL_DNTP_CONC"                => "0.0",
  "PRIMER_INTERNAL_DNA_CONC"                 => "50.0",
  "PRIMER_INTERNAL_MAX_SELF_ANY"             => "12.00",
  "PRIMER_INTERNAL_MAX_POLY_X"               => "5",
  "PRIMER_INTERNAL_MAX_SELF_END"             => "12.00",
  "PRIMER_INTERNAL_MISHYB_LIBRARY"           => "NONE",   
  "PRIMER_INTERNAL_MAX_LIBRARY_MISHYB"       => "12.00",
  "PRIMER_INTERNAL_MIN_QUALITY"              => "0",
  "PRIMER_INTERNAL_MAX_NS_ACCEPTED"          => "0",
  "PRIMER_INTERNAL_WT_TM_GT"                 => "1.0",
  "PRIMER_INTERNAL_WT_TM_LT"                 => "1.0",
  "PRIMER_INTERNAL_WT_SIZE_LT"               => "1.0",
  "PRIMER_INTERNAL_WT_SIZE_GT"               => "1.0", 
  "PRIMER_INTERNAL_WT_GC_PERCENT_LT"         => "0.0",
  "PRIMER_INTERNAL_WT_GC_PERCENT_GT"         => "0.0",
  "PRIMER_INTERNAL_WT_SELF_ANY"              => "0.0",
  "PRIMER_INTERNAL_WT_NUM_NS"                => "0.0",
  "PRIMER_INTERNAL_WT_LIBRARY_MISHYB"        => "0.0",
  "PRIMER_INTERNAL_WT_SEQ_QUAL"              => "0.0",

  "P3_FILE_FLAG"                             => "0",                            
# End of Primer3 Input Parameters

# Script Parameters
  "SCRIPT_PRINT_INPUT"                       => "0",
  "SCRIPT_FIX_PRIMER_END"                    => "5",
  
  "SCRIPT_CONTAINS_JAVA_SCRIPT"              => "1",
  "SERVER_PARAMETER_FILE"                    => "DEFAULT",

  "P3P_DETECTION_USE_PRODUCT_SIZE"           => "0",
  "P3P_DETECTION_PRODUCT_MIN_SIZE"           => "100",
  "P3P_DETECTION_PRODUCT_OPT_SIZE"           => "200",
  "P3P_DETECTION_PRODUCT_MAX_SIZE"           => "1000",
  "P3P_PRIMER_NAME_ACRONYM_LEFT"             => "F",
  "P3P_PRIMER_NAME_ACRONYM_INTERNAL_OLIGO"   => "IN",
  "P3P_PRIMER_NAME_ACRONYM_RIGHT"            => "R",
  "P3P_PRIMER_NAME_ACRONYM_SPACER"           => "_"
# if you add parameters here also add them to the respective save array
);

my %oldSettings = (
# Begin Primer3 Input Parameters
# Primer3 "Sequence" Input Tags
"PRIMER_NAME_ACRONYM_SPACER"               => "_"
# if you ad parameters here also add them to the respective save array
);

print "Starting up...\n";

compareHashesDefault(\%defaultSettings, \%oldSettings);


print "Ending script...\n";

sub compareHashesDefault() {
	my %hash1 = %{(shift)};
	my %hash2 = %{(shift)};
	
	my %allPossibleKeys;
	my %inBothHashes;
	my %onlyHash1;
	my %onlyHash2;
	
	
	
	my $theKey;
	
	#Extract all Keys first into one Hash
	foreach $theKey (keys(%hash1)){
		$allPossibleKeys{$theKey} = 1;
	}
	foreach $theKey (keys(%hash2)){
		$allPossibleKeys{$theKey} = 1;
	}
		
	#Now split the Hashes	
	foreach $theKey (keys(%allPossibleKeys)){
		if ((defined $hash1{$theKey}) and (defined $hash2{$theKey})) {
			$inBothHashes{$theKey} = 1;
		} elsif (defined $hash1{$theKey}) {
			$onlyHash1{$theKey} = 1;
		} elsif (defined $hash2{$theKey}) {
			$onlyHash2{$theKey} = 1;
		} else {
			print "THIS SHOULD NOT HAPPEN!\n";
		}
	}
		
	# Print out the Hashes
	
	print "Only in Hash1:\n";
	foreach $theKey (keys(%onlyHash1)){
		print "$theKey = $hash1{$theKey} = ----\n";
	}
	print "\n\nOnly in Hash2:\n";
	foreach $theKey (keys(%onlyHash2)){
		print "$theKey = ---- = $hash2{$theKey}\n";
	}
	print "\n\nIn Both Hashes:\n";
	foreach $theKey (keys(%inBothHashes)){
		print "$theKey = $hash1{$theKey} = $hash2{$theKey}\n";
	}
	
	
	
	
}

