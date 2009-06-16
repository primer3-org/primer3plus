#!/usr/bin/perl

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

use strict;
use HtmlFunctions;

# This CGI prints out the Help-File using the template HTML-File

my $helpHTML = qq{
<div id="primer3plus_help">

<h2><a name="cautions">Cautions</a></h2>
  <p>Some of the most important issues in primer picking can be addressed only before using Primer3. These are sequence
    quality (including making sure the sequence is not vector and not chimeric) and avoiding repetitive elements.<br>
    <br>
    Techniques for avoiding problems include a thorough understanding of possible vector contaminants and cloning
    artifacts coupled with database searches using blast, fasta, or other similarity searching program to screen for
    vector contaminants and possible repeats.  Repbase (J. Jurka, A.F.A. Smit, C. Pethiyagoda, and others, 1995-1996) 
    <a href="ftp://ftp.ncbi.nih.gov/repository/repbase">ftp://ftp.ncbi.nih.gov/repository/repbase</a>
    ) is an excellent source of repeat sequences and pointers to the literature.  Primer3 now allows you to screen
    candidate oligos against a Mispriming Library (or a Mishyb Library in the case of internal oligos).<br>
    <br>
    Sequence quality can be controlled by manual trace viewing and quality clipping or automatic quality clipping
    programs.  Low-quality bases should be changed to N's or can be made part of Excluded Regions. The beginning of
    a sequencing read is often problematic because of primer peaks, and the end of the read often contains many
    low-quality or even meaningless called bases. Therefore when picking primers from single-pass sequence it is
    often best to use the Included Region parameter to ensure that Primer3 chooses primers in the high quality region
    of the read.<br>
    <br>
    In addition, Primer3 takes as input a <a href="#SEQUENCE_QUALITY">Sequence Quality</a> list for use with those
    base calling programs such as Phred that output this information.
  </p>

<h2><a name="SCRIPT_INPUT_PARAMETERS">Script Input Parameters</a></h2>

<h3><a name="PRIMER_TASK">Task</a></h3>
  <p>
  <a href="#SCRIPT_DETECTION">Detection</a><br>
  <a href="#SCRIPT_CLONING">Cloning</a><br>
  <a href="#SCRIPT_SEQUENCING">Sequencing</a><br>
  <a href="#SCRIPT_PRIMER_LIST">Primer List</a><br>
  <a href="#SCRIPT_PRIMER_CHECK">Primer Check</a>  
  </p>


<h3><a name="SCRIPT_DETECTION">Task: Detection</a></h3>
  <p>The Detection task can be used for designing standard PCR primers or hybridisation oligos to DETECT a given sequence.<br>
  The user can indicate:<br>
  excluded regions - primers are not allowed to bind in this region<br>
  targets - primers must amplify one of the targets<br>
  included region - primers must bind within this region<br>
  <br>
  Primer3Plus will select the primer pair which fits best to all selected parameters. It can be located anywhere in the sequence,
  only limited by the regions and targets described above.
  </p>

<h3><a name="SCRIPT_CLONING">Task: Cloning</a></h3>
  <p>The Cloning task can be used to design primers ending or starting exactly at the boundary of the
  included region.<br>
  To clone for example open reading frames the 5'End of the primers should be fixed. Primer3plus 
  picks primers of various length, all forward primers starting at the same nucleotide (A from ATG)
  and all reverse primers starting at the same nucleotide (G from TAG). To have this functionality 
  the parameter "Fix the x prime end of the primer" in general setting should be set to 5 (default).<br>
  <br>
  To to distinguish between different alleles primers must bind with their 3'End fixed to the varying 
  nucleotides. If the parameter "Fix the x prime end of the primer" in general setting is set to 3, 
  primer3plus picks primers of various length, all primers ending at the same nucleotide.<br>
  <br>
  Primer3Plus picks out of all primers the best pair and orders them by quality.<br>
  <br>
  ATTENTION: Due to the inflexibility of the primer position, only the primer length can be altered. In 
  many cases this leads to primers of low quality. Select the cloning function ONLY if you require 
  your primers to start or to end at a certain nucleotide.
  </p>

<h3><a name="SCRIPT_FIX_PRIMER_END">Fix the x prime end of the primer</a></h3>
  <p>This parameter can be set to 5 (default) or 3. It indicates for Primer3Plus which End of the 
  primer should be fixed and which can be extended or cut.
  </p>

<h3><a name="SCRIPT_SEQUENCING">Task: Sequencing</a></h3>
  <p>The Sequencing task is developed to design a series of primers on both the forward and reverse 
  strands that can be used for custom primer-based (re-)sequencing of clones. Targets can be defined 
  in the sequence which will be sequenced optimally. The pattern how Primer3Plus picks the primers 
  can be modified on the Advanced settings tab:
  </p>

<h3><a name="PRIMER_SEQUENCING_LEAD">Lead</a></h3>
  <p>Defines the space from the start of the primer to the point were the trace signals are readable 
  (default 50 bp).
  </p>

<h3><a name="PRIMER_SEQUENCING_SPACING">Spacing</a></h3>
  <p>Defines the space from the start of the primer to the start of the next primer on the same 
  strand (default 500 bp).
  </p>

<h3><a name="PRIMER_SEQUENCING_INTERVAL">Interval</a></h3>
  <p>Defines the space from the start of the primer to the start of the next primer on the opposite 
  strand (default 250 bp).
  </p>

<h3><a name="PRIMER_SEQUENCING_ACCURACY">Accuracy</a></h3>
  <p>Defines the size of the area in which primer3plus searches for the best primer (default 20 bp).
  </p>

<h3><a name="SCRIPT_SEQUENCING_REVERSE">Pick Reverse Primers</a></h3>
  <p>Select "Pick Reverse Primers" to pick also primers on the reverse strand (selected by default).
  </p>

<h3><a name="SCRIPT_PRIMER_LIST">Task: Primer List</a></h3>
  <p>With the Primer List task all possible primers that can be designed on the target sequence and 
  meet the current settings will be returned with their corresponding characteristics. This task 
  basically allows manual selection of primers. The run time of the Primer List task can be 
  relatively long, especially when lengthy target sequences are submitted.
  </p>

<h3><a name="SCRIPT_PRIMER_CHECK">Task: Primer Check</a></h3>
  <p>The Primer Check task can be used to obtain information on a specified primer, like its melting 
  temperature or self complementarity. For this task no template sequence is required and only the 
  primer sequence has to be provided.
  </p>

<h3><a name="SERVER_PARAMETER_FILE">Server Parameter File</a></h3>
  <p>A collection of settings for specific applications stored at the server.
  </p>

<h3><a>Naming of Primers</a></h3>
  <p>Primer3Plus will create automatically a name for each primer based on the Sequence ID, the 
  primer number and the primer acronym.
  </p>

<h3><a name="P3P_PRIMER_NAME_ACRONYM_LEFT">Left Primer Acronym</a></h3>
  <p>Acronym for the left primer, by default F
  </p>

<h3><a name="P3P_PRIMER_NAME_ACRONYM_INTERNAL_OLIGO">Internal Oligo Acronym</a></h3>
  <p>Acronym for the internal oligo, by default IN
  </p>

<h3><a name="P3P_PRIMER_NAME_ACRONYM_RIGHT">Right Primer Acronym</a></h3>
  <p>Acronym for the right primer, by default R
  </p>

<h3><a name="P3P_PRIMER_NAME_ACRONYM_SPACER">Primer Name Spacer</a></h3>
  <p>Spacer primer3plus uses between name, number and acronym, by default _
  </p>


<h2><a name="INPUT_PARAMETERS">Input Parameters</a></h2>

<h3><a name="SEQUENCE_TEMPLATE">Source Sequence</a></h3>
  <p>The sequence from which to select primers or hybridization oligos.</p>

<h3><a name="SEQUENCE_ID">Sequence Id</a></h3>
  <p>An identifier that is reproduced in the output to enable you to identify the chosen primers.</p>

<h3><a name="SEQUENCE_TARGET">Targets</a></h3>
  <p>If one or more Targets is specified then a legal primer pair must flank at least one of them.  A Target might
    be a simple sequence repeat site (for example a CA repeat) or a single-base-pair polymorphism.  The value should
    be a space-separated list of<br>
    <pre><tt><i>start</i></tt>,<tt><i>length</i></tt></pre>
    pairs where <tt><i>start</i></tt> is the index of the first base of a Target, and <tt><i>length</i></tt> is its
    length.
  </p>

<h3><a name="SEQUENCE_EXCLUDED_REGION">Excluded Regions</a></h3>
  <p>Primer oligos may not overlap any region specified in this tag. The associated value must be a space-separated list of
    <br>
    <pre><tt><i>start</i></tt>,<tt><i>length</i></tt></pre>
    pairs where <tt><i>start</i></tt> is the index of the first base of the excluded region, and <tt><i>length</i></tt>
    is its length.  This tag is useful for tasks such as excluding regions of low sequence quality or for excluding
    regions containing repetitive elements such as ALUs or LINEs.
  </p>

<h3><a name="PRIMER_PRODUCT_SIZE_RANGE">Product Size Range</a></h3>
  <p>A list of product size ranges, for example
    <br>
    <pre><tt>150-250 100-300 301-400</tt></pre>
    Primer3 first tries to pick primers in the first range.  If that is not possible, it goes to the next range and tries
    again.  It continues in this way until it has either picked all necessary primers or until there are no more ranges.
    For technical reasons this option makes much lighter computational demands than the Product Size option.
  </p>
  
<h3><a name="PRIMER_PRODUCT_SIZE">Product Size</a></h3>
  <p>Minimum, Optimum, and Maximum lengths (in bases) of the PCR product. Primer3 will not generate primers with products
    shorter than Min or longer than Max, and with default arguments Primer3 will attempt to pick primers producing products
    close to the Optimum length. 
  </p>
  
<h3><a name="PRIMER_NUM_RETURN">Number To Return</a></h3>
  <p>The maximum number of primer pairs to return.  Primer pairs returned are sorted by their &quot;quality&quot;, in other
    words by the value of the objective function (where a lower number indicates a better primer pair).  Caution: setting
    this parameter to a large value will increase running time.
  </p>
  
<h3><a name="PRIMER_MAX_END_STABILITY">Max 3' Stability</a></h3>
  <p>The maximum stability for the last five 3' bases of a left or right primer.  Bigger numbers mean more stable 
    3' ends.  The value is the maximum delta G (kcal/mol) for duplex disruption for the five 3' bases as calculated
    using the Nearest-Neighbor parameter values specified by the option of <a href="#PRIMER_TM_FORMULA">'Table of
    thermodynamic parameters'</a>. For example if the table of thermodynamic parameters suggested by 
    <a href="http://dx.doi.org/10.1073/pnas.95.4.1460" target="_blank">SantaLucia 1998, DOI:10.1073/pnas.95.4.1460</a>
    is used the deltaG values for the most stable and for the most labile 5mer duplex are 6.86 kcal/mol (GCGCG)
    and 0.86 kcal/mol (TATAT) respectively. If the table of thermodynamic parameters suggested by 
    <a href="http://dx.doi.org/10.1073/pnas.83.11.3746" target="_blank">Breslauer et al. 1986, 10.1073/pnas.83.11.3746</a>
    is used the deltaG values for the most stable and for the most labile 5mer are 13.4 kcal/mol (GCGCG) and
    4.6 kcal/mol (TATAC) respectively.
  </p>
  
<h3><a name="PRIMER_MAX_LIBRARY_MISPRIMING">Max Mispriming</a></h3>
  <p>The maximum allowed weighted similarity with any sequence in Mispriming Library. Default is 12.
  </p>
  
<h3><a name="PRIMER_MAX_TEMPLATE_MISPRIMING">Max Template Mispriming</a></h3>
  <p>The maximum allowed similarity to ectopic sites in the sequence from which you are designing the primers.
    The scoring system is the same as used for Max Mispriming, except that an ambiguity code is never treated as
    a consensus.
  </p>
  
<h3><a name="PRIMER_PAIR_MAX_LIBRARY_MISPRIMING">Pair Max Mispriming</a></h3>
  <p>The maximum allowed sum of similarities of a primer pair (one similarity for each primer) with any single sequence
    in Mispriming Library. Default is 24. Library sequence weights are not used in computing the sum of similarities.
  </p>
  
<h3><a name="PRIMER_PAIR_MAX_TEMPLATE_MISPRIMING"><strong>Pair Max Template Mispriming</a></h3>
  <p>The maximum allowed summed similarity of both primers to ectopic sites in the sequence from which you are
    designing the primers.  The scoring system is the same as used for Max Mispriming, except that an ambiguity code
    is never treated as a consensus.
  </p>
  
<h3><a name="PRIMER_SIZE">Primer Size</a></h3>
  <p>Minimum, Optimum, and Maximum lengths (in bases) of a primer oligo. Primer3 will not pick primers shorter than Min
    or longer than Max, and with default arguments will attempt to pick primers close with size close to Opt. Min 
    cannot be smaller than 1. Max cannot be larger than 36. (This limit is governed by maximum oligo size for which 
    melting-temperature calculations are valid.) Min cannot be greater than Max.
  </p>

<h3><a name="PRIMER_TM">Primer T<sub>m</sub></a></h3>
  <p>Minimum, Optimum, and Maximum melting temperatures (Celsius) for a primer oligo. Primer3 will not pick oligos with
    temperatures smaller than Min or larger than Max, and with default conditions will try to pick primers with melting
    temperatures close to Opt.<br>
    <br>
    By default Primer3 uses the oligo melting temperature formula and the table of thermodynamic parameters given in
    <a href="http://dx.doi.org/10.1073/pnas.83.11.3746" target="_blank"> Breslauer et al. 1986,
    DOI:10.1073/pnas.83.11.3746</a>~For more information see caption <a href="#PRIMER_TM_FORMULA">
    Table of thermodynamic parameters</a>
  </p>

<h3><a name="PRIMER_PAIR_MAX_DIFF_TM">Maximum T<sub>m</sub> Difference</a></h3>
  <p>Maximum acceptable (unsigned) difference between the melting temperatures of the left and right primers.
  </p>

<h3><a name="PRIMER_TM_FORMULA">Table of thermodynamic parameters</a></h3>
  <p>Option for the table of Nearest-Neighbor thermodynamic parameters and for the method of melting temperature 
    calculation. Two different tables of thermodynamic parameters are available:
    <ol>
    <li><a href="http://dx.doi.org/10.1073/pnas.83.11.3746" target="_blank"> Breslauer et al. 1986, DOI:10.1073/
            pnas.83.11.3746</a> In that case the formula for melting temperature calculation suggested by
        <a href="http://www.pubmedcentral.nih.gov/articlerender.fcgi?tool=pubmed&pubmedid=2243783" target="_blank">
            Rychlik et al. 1990</a> is used (this is used until Primer3 version 1.0.1). This is the default value
            of Primer3 (for backward compatibility).
   </li>
   <li><a href="http://dx.doi.org/10.1073/pnas.95.4.1460" target="_blank">
            SantaLucia 1998, DOI:10.1073/pnas.95.4.1460</a> This is the <i>recommended</i> value.
   </li>
   </ol>
   For specifying the salt correction method for melting temperature calculation see
   <a href="#PRIMER_SALT_CORRECTIONS">Salt correction formula</a>
  </p>

<h3><a name="PRIMER_PRODUCT_TM">Product T<sub>m</sub></a></h3>
  <p>The minimum, optimum, and maximum melting temperature of the amplicon.  Primer3 will not pick a product with melting 
    temperature less than min or greater than max. If Opt is supplied and the
    <a href="#PAIR_WT_PRODUCT_TM">Penalty Weights for Product Size</a>
    are non-0 Primer3 will attempt to pick an amplicon with melting temperature close to Opt.<br>
    <br>
    The maximum allowed melting temperature of the amplicon. Primer3 calculates product T<sub>m</sub> calculated using
    the formula from Bolton and McCarthy, PNAS 84:1390 (1962) as presented in Sambrook, Fritsch and Maniatis, Molecular
    Cloning, p 11.46 (1989, CSHL Press).<br>
    <blockquote>T<sub>m</sub> = 81.5 + 16.6(log<sub>10</sub>([Na+])) + .41*(%GC) - 600/length,</blockquote>
    where [Na+] is the molar sodium concentration, (%GC) is the percent of Gs and Cs in the sequence, and length is the
    length of the sequence.<br>
    <br>
    A similar formula is used by the prime primer selection program in GCG (
    <a href="http://www.gcg.com">http://www.gcg.com</a>
    ), which instead uses 675.0 / length in the last term (after F. Baldino, Jr, M.-F. Chesselet, and M.E. Lewis, Methods
    in Enzymology 168:766 (1989) eqn (1) on page 766 without the mismatch and formamide terms).  The formulas here and in
    Baldino et al. assume Na+ rather than K+.  According to J.G. Wetmur, Critical Reviews in BioChem. and Mol. Bio.
    26:227 (1991) 50 mM K+ should be equivalent in these formulae to .2 M Na+.  Primer3 uses the same salt concentration
    value for calculating both the primer melting temperature and the oligo melting temperature.  If you are planning to
    use the PCR product for hybridization later this behavior will not give you the T<sub>m</sub> under hybridization
    conditions.
  </p>
  
<h3><a name="PRIMER_GC_PERCENT">Primer GC%</a></h3>
  <p>Minimum, Optimum, and Maximum percentage of Gs and Cs in any primer.
  </p>
  
<h3><a name="PRIMER_MAX_SELF_ANY">Max Complementarity</a></h3>
  <p>The maximum allowable local alignment score when testing a single primer for (local) self-complementarity and the
    maximum allowable local alignment score when testing for complementarity between left and right primers.  Local
    self-complementarity is taken to predict the tendency of primers to anneal to each other without necessarily causing
    self-priming in the PCR.  The scoring system gives 1.00 for complementary bases, -0.25 for a match of any base 
    (or N) with an N, -1.00 for a mismatch, and -2.00 for a gap. Only single-base-pair gaps are allowed.  For example,
    the alignment<br>
    <pre>
    5' ATCGNA 3'
       || | |
    3' TA-CGT 5'
    </pre>
    is allowed (and yields a score of 1.75), but the alignment
    <pre>
    5' ATCCGNA 3'
       ||  | |
    3' TA--CGT 5'
    </pre>
    is not considered.  Scores are non-negative, and a score of 0.00 indicates that there is no reasonable local
    alignment between two oligos.
  </p>
  
<h3><a name="PRIMER_MAX_SELF_END">Max 3' Complementarity</a></h3>
  <p>The maximum allowable 3'-anchored global alignment score when testing a single primer for self-complementarity, and
    the maximum allowable 3'-anchored global alignment score when testing for complementarity between left and right
    primers.  The 3'-anchored global alignment score is taken to predict the likelihood of PCR-priming primer-dimers, for
    example<br>
    <pre>
    5' ATGCCCTAGCTTCCGGATG 3'
                 ||| |||||
              3' AAGTCCTACATTTAGCCTAGT 5'
    </pre>
    or
    <pre>
    5` AGGCTATGGGCCTCGCGA 3'
                   ||||||
                3' AGCGCTCCGGGTATCGGA 5'
    </pre>
    The scoring system is as for the Max Complementarity argument.  In the examples above the scores are 7.00 and 
    6.00 respectively.  Scores are non-negative, and a score of 0.00 indicates that there is no reasonable 3'-anchored
    global alignment between two oligos.  In order to estimate 3'-anchored global alignments for candidate primers and
    primer pairs, Primer assumes that the sequence from which to choose primers is presented 5'->3'.  It is nonsensical
    to provide a larger value for this parameter than for the Maximum (local) Complementarity parameter because the
    score of a local alignment will always be at least as great as the score of a global alignment.
  </p>

<h3><a name="PRIMER_MAX_POLY_X">Max Poly-X</a></h3>
  <p>The maximum allowable length of a mononucleotide repeat, for example AAAAAA.
  </p>
  
<h3><a name="SEQUENCE_INCLUDED_REGION">Included Region</a></h3>
  <p>A sub-region of the given sequence in which to pick primers.  For example, often the first dozen or so bases of a
    sequence are vector, and should be excluded from consideration. The value for this parameter has the form<br>
    <pre><tt><i>start</i></tt>,<tt><i>length</i></tt></pre>
    where <tt><i>start</i></tt> is the index of the first base to consider, and <tt><i>length</i></tt> is the number
    of subsequent bases in the primer-picking region.
  </p>
  
<h3><a name="SEQUENCE_START_CODON_POSITION">Start Codon Position</a></h3>
  <p>This parameter should be considered EXPERIMENTAL at this point. Please check the output carefully; some erroneous
    inputs might cause an error in Primer3. Index of the first base of a start codon.  This parameter allows Primer3
    to select primer pairs to create in-frame amplicons e.g. to create a template for a fusion protein.  Primer3 will
    attempt to select an in-frame left primer, ideally starting at or to the left of the start codon, or to the right
    if necessary. Negative values of this parameter are legal if the actual start codon is to the left of available
    sequence. If this parameter is non-negative Primer3 signals an error if the codon at the position specified by
    this parameter is not an ATG.  A value less than or equal to -10^6 indicates that Primer3 should ignore this 
    parameter.<br>
    <br>
    Primer3 selects the position of the right primer by scanning right from the left primer for a stop codon.  Ideally
    the right primer will end at or after the stop codon.
  </p>
  
<h3><a name="PRIMER_MISPRIMING_LIBRARY">Mispriming Library</a></h3>
  <p>This selection indicates what mispriming library (if any) Primer3 should use to screen for interspersed repeats or
    for other sequence to avoid as a location for primers. The human and rodent libraries on the web page are adapted
    from Repbase (J. Jurka, A.F.A. Smit, C. Pethiyagoda, et al., 1995-1996)
    <a href="ftp://ftp.ncbi.nih.gov/repository/repbase">ftp://ftp.ncbi.nih.gov/repository/repbase</a>
    . The human library is humrep.ref concatenated with simple.ref, translated to FASTA format.  There are two rodent
    libraries. One is rodrep.ref translated to FASTA format, and the other is rodrep.ref concatenated with simple.ref,
    translated to FASTA format.<br>
    <br>
    The <i>Drosophila</i> library is the concatenation of two libraries from the 
    <a href="http://www.fruitfly.org">Berkeley Drosophila Genome Project</a>:<br>
    <ol>
    <li> A library of transposable elements
    <a href="http://genomebiology.com/2002/3/12/research/0084"><i>The transposable elements of the Drosophila melanogaster
    euchromatin - a genomics perspective</i> J.S. Kaminker, C.M. Bergman, B. Kronmiller, J. Carlson, R. Svirskas,
    S. Patel, E. Frise, D.A. Wheeler, S.E. Lewis, G.M. Rubin, M. Ashburner and S.E. Celniker Genome Biology (2002)
    3(12):research0084.1-0084.20</a>, 
    <a href="http://www.fruitfly.org/p_disrupt/datasets/ASHBURNER/D_mel_transposon_sequence_set.fasta">
    http://www.fruitfly.org/p_disrupt/datasets/ASHBURNER/D_mel_transposon_sequence_set.fasta<a/><br><br>
    </li>
    <li> A library of repetitive DNA sequences <a href="http://www.fruitfly.org/sequence/sequence_db/na_re.dros">
    http://www.fruitfly.org/sequence/sequence_db/na_re.dros</a>.
    </li>
    </ol>
    Both were downloaded 6/23/04.<br>
    <br>
    The contents of the libraries can be viewed at the following links:
    <ul>
    <li> <a href="cat_humrep_and_simple.cgi">HUMAN</a> (contains microsatellites)
    </li>
    <li> <a href="cat_rodrep_and_simple.cgi">RODENT_AND_SIMPLE</a> (contains microsatellites)
    </li>
    <li> <a href="cat_rodent_ref.cgi">RODENT</a> (does not contain microsatellites)
    </li>
    <li> <a href="cat_drosophila.cgi">DROSOPHILA</a>
    </ul>
  </p>

<h3><a name="PRIMER_GC_CLAMP">CG Clamp</a></h3>
  <p>Require the specified number of consecutive Gs and Cs at the 3' end of both the left and right primer.  (This
    parameter has no effect on the hybridization oligo if one is requested.)
  </p>

<h3><a name="PRIMER_SALT_MONOVALENT">Concentration of monovalent cations</a></h3>
  <p>The millimolar concentration of salt (usually KCl) in the PCR. Primer3 uses this argument to calculate oligo
    melting temperatures.
  </p>

<h3><a name="PRIMER_SALT_DIVALENT">Concentration of divalent cations</a></h3>
  <p>The millimolar concentration of divalent salt cations (usually MgCl<sup>2+</sup> in the PCR). Primer3 converts
    concentration of divalent cations to concentration of monovalent cations using formula suggested in the paper 
    <a href="http://www.clinchem.org/cgi/content/full/47/11/1956" target="blank"> Ahsen et al., 2001</a>
    <br>
    <pre>                     [Monovalent cations] = [Monovalent cations] + 120*(&#8730;([divalent cations] - [dNTP])) </pre>

    According to the formula concentration of desoxynucleotide triphosphate [dNTP] must be smaller than concentration
    of divalent cations. The concentration of dNTPs is included to the formula beacause of some magnesium is bound by
    the dNTP. Attained concentration of monovalent cations is used to calculate oligo/primer melting temperature. See
    <a href="#PRIMER_DNTP_CONC"> Concentration of dNTPs</a> to specify the concentration of dNTPs.
  </p>

<h3><a name="PRIMER_DNTP_CONC">Concentration of dNTPs</a></h3>
  <p>The millimolar concentration of deoxyribonucleotide triphosphate. This argument is considered only if
    <a href="#PRIMER_SALT_DIVALENT">Concentration of divalent cations</a> is specified.
  </p>

<h3><a name="PRIMER_SALT_CORRECTIONS">Salt correction formula</a></h3>
  <p>Option for specifying the salt correction formula for the melting temperature calculation. <br><br>
    <ol>There are three different options available:
    <li><a href="http://dx.doi.org/10.1002/bip.360030207" target="_blank"> Schildkraut and Lifson 1965, DOI:10.1002/bip.360030207</a>
        (this is used until the version 1.0.1 of Primer3).The default value of Primer3 version 1.1.0 (for backward compatibility)</li>
    <li><a href="http://dx.doi.org/10.1073/pnas.95.4.1460" target="_blank">SantaLucia 1998, DOI:10.1073/pnas.95.4.1460</a> 
        This is the <i>recommended</i> value.</li>
    <li><a href="http://dx.doi.org/10.1021/bi034621r" target="_blank">Owczarzy et al. 2004, DOI:10.1021/bi034621r</a></li>
    </ol>
  </p>

<h3><a name="PRIMER_DNA_CONC">Annealing Oligo Concentration</a></h3>
  <p>The nanomolar concentration of annealing oligos in the PCR. Primer3 uses this argument to calculate oligo melting
    temperatures.  The default (50nM) works well with the standard protocol used at the Whitehead/MIT Center for
    Genome Research--0.5 microliters of 20 micromolar concentration for each primer oligo in a 20 microliter reaction
    with 10 nanograms template, 0.025 units/microliter Taq polymerase in 0.1 mM each dNTP, 1.5mM MgCl2, 50mM KCl,
    10mM Tris-HCL (pH 9.3) using 35 cycles with an annealing temperature of 56 degrees Celsius.  This parameter
    corresponds to 'c' in Rychlik, Spencer and Rhoads' equation (ii) (Nucleic Acids Research, vol 18, num 21) where
    a suitable value (for a lower initial concentration of template) is &quot;empirically determined&quot;.  The value
    of this parameter is less than the actual concentration of oligos in the reaction because it is the concentration
    of annealing oligos, which in turn depends on the amount of template (including PCR product) in a given cycle.
    This concentration increases a great deal during a PCR; fortunately PCR seems quite robust for a variety of
    oligo melting temperatures.
  </p>

<h3><a name="PRIMER_MAX_NS_ACCEPTED">Max Ns Accepted</a></h3>
  <p>Maximum number of unknown bases (N) allowable in any primer.
  </p>

<h3><a name="PRIMER_LIBERAL_BASE">Liberal Base</a></h3>
  <p>This parameter provides a quick-and-dirty way to get Primer3 to accept IUB / IUPAC codes for ambiguous bases (i.e.
    by changing all unrecognized bases to N).  If you wish to include an ambiguous base in an oligo, you must set
    <a href=#PRIMER_MAX_NS_ACCEPTED>Max Ns Accepted</a> to a non-0 value. Perhaps '-' and '* ' should be squeezed
    out rather than changed to 'N', but currently they simply get converted to N's.  The authors invite user comments.
  </p>

<h3><a name="PRIMER_FIRST_BASE_INDEX">First Base Index</a></h3>
  <p>The index of the first base in the input sequence.  For input and output using 1-based indexing (such as that
    used in GenBank and to which many users are accustomed) set this parameter to 1.  For input and output using
    0-based indexing set this parameter to 0.  (This parameter also affects the indexes in the contents of the
    files produced when the primer file flag is set.) In the WWW interface this parameter defaults to 1.
  </p>

<h3><a name="PRIMER_INSIDE_PENALTY">Inside Target Penalty</a></h3>
  <p>Non-default values valid only for sequences with 0 or 1 target regions.  If the primer is part of a pair
    that spans a target and overlaps the target, then multiply this value times the number of nucleotide positions
    by which the primer overlaps the (unique) target to get the 'position penalty'.  The effect of this parameter
    is to allow Primer3 to include overlap with the target as a term in the objective function.
  </p>

<h3><a name="PRIMER_OUTSIDE_PENALTY">Outside Target Penalty</a></h3>
  <p>Non-default values valid only for sequences with 0 or 1 target regions.  If the primer is part of a pair that
    spans a target and does not overlap the target, then multiply this value times the number of nucleotide
    positions from the 3' end to the (unique) target to get the 'position penalty'. The effect of this parameter
    is to allow Primer3 to include nearness to the target as a term in the objective function.
  </p>

<h3><a name=SHOW_DEBUGGING>Show Debuging Info</a></h3>
  <p>Include the input to primer3_core as part of the output.
  </p>
  
<h3><a name="PRIMER_LOWERCASE_MASKING">Lowercase masking</a></h3>
  <p>If checked candidate primers having lowercase letter exactly at 3' end are rejected. This option allows to
    design primers overlapping lowercase-masked regions. This property relies on the assumption that masked 
    features (e.g. repeats) can partly overlap primer, but they cannot overlap the 3'-end of the primer. In other
    words, the lowercase letters in other positions are accepted, assuming that the masked features do not influence
    the primer performance if they do not overlap the 3'-end of primer.
  </p>

<h2><a name=SEQUENCE_QUALITY>Sequence Quality</a></h2>

<h3><a name="SEQUENCE_QUALITY">Sequence Quality</a></h3>
  <p>A list of space separated integers. There must be exactly one integer for each base in the Source Sequence if this
    argument is non-empty. High numbers indicate high confidence in the base call at that position and low numbers
    indicate low confidence in the base call at that position.
  </p>

<h3><a name="PRIMER_MIN_QUALITY">Min Sequence Quality</a></h3>
  <p>The minimum sequence quality (as specified by Sequence Quality) allowed within a primer.
  </p>
  
<h3><a name="PRIMER_MIN_END_QUALITY">Min 3' Sequence Quality</a></h3>
  <p>The minimum sequence quality (as specified by Sequence Quality) allowed within the 3' pentamer of a primer.
  </p>
  
<h3><a name="PRIMER_QUALITY_RANGE_MIN">Sequence Quality Range Min</a></h3>
  <p>The minimum legal sequence quality (used for interpreting Min Sequence Quality and Min 3' Sequence Quality).
  </p>
  
<h3><a name="PRIMER_QUALITY_RANGE_MAX">Sequence Quality Range Max</a></h3>
  <p>The maximum legal sequence quality (used for interpreting Min Sequence Quality and Min 3' Sequence Quality).
  </p>


<h2><a name="generic_penalty_weights">Penalty Weights</a></h2>
  <p>This section describes "penalty weights", which allow the user to modify the criteria that Primer3 uses to select
    the "best" primers.  There are two classes of weights: for some parameters there is a 'Lt' (less than) and a
    'Gt' (greater than) weight.  These are the weights that Primer3 uses when the value is less or greater than
    (respectively) the specified optimum. The following parameters have both 'Lt' and 'Gt' weights:
    <ul>
    <li> Product Size </li>
    <li> Primer Size </li>
    <li> Primer T<sub>m</sub> </li>
    <li> Product T<sub>m</sub> </li>
    <li> Primer GC% </li>
    <li> Hyb Oligo Size </li>
    <li> Hyb Oligo T<sub>m</sub> </li>
    <li> Hyb Oligo GC% </li>
    </ul>
    The <a href="#PRIMER_INSIDE_PENALTY">Inside Target Penalty</a> and <a href="#PRIMER_OUTSIDE_PENALTY">Outside
    Target Penalty</a> are similar, except that since they relate to position they do not lend them selves to the
    'Lt' and 'Gt' nomenclature.<br>
    <br>
    For the remaining parameters the optimum is understood and the actual value can only vary in one direction from
    the optimum:<br>
    <br>
    <ul>
    <li>Primer Self Complementarity </li>
    <li>Primer 3' Self Complementarity </li>
    <li>Primer #N's </li>
    <li>Primer Mispriming Similarity </li>
    <li>Primer Sequence Quality </li>
    <li>Primer 3' Sequence Quality </li>
    <li>Primer 3' Stability </li>
    <li>Hyb Oligo Self Complementarity </li>
    <li>Hyb Oligo 3' Self Complementarity </li>
    <li>Hyb Oligo Mispriming Similarity </li>
    <li>Hyb Oligo Sequence Quality </li>
    <li>Hyb Oligo 3' Sequence Quality </li>
    </ul>
    The following are weights are treated specially:<br>
    <br>
    Position Penalty Weight<br>
    &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; Determines the overall weight of the position penalty in calculating 
    the penalty for a primer.<br><br>
    Primer Weight<br>
    &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; Determines the weight of the 2 primer penalties in calculating the
    primer pair penalty.<br><br>
    Hyb Oligo Weight<br>
    &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; Determines the weight of the hyb oligo penalty in calculating the
    penalty of a primer pair plus hyb oligo.<br><br>
    <br>
    The following govern the weight given to various parameters of primer pairs (or primer pairs plus hyb oligo).
    <ul>
    <li>T<sub>m</sub> difference </li>
    <li>Primer-Primer Complementarity </li>
    <li>Primer-Primer 3' Complementarity </li>
    <li>Primer Pair Mispriming Similarity </li>
    </ul>
  </p>


<h2><a name="internal_oligo_generic">Hyb Oligos (Internal Oligos)</a></h2>
  <p>Parameters governing choice of internal oligos are analogous to the parameters governing choice of primer pairs.
    The exception is Max 3' Complementarity which is meaningless when applied to internal oligos used for
    hybridization-based detection, since primer-dimer will not occur.  We recommend that Max 3' Complementarity 
    be set at least as high as Max Complementarity.
  </p>
</div>

</div>	
};


print "Content-type: text/html\n\n";
print createHelpHTML($helpHTML), "\n";


