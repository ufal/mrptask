This folder contains software created by the ÚFAL-Oslo team for the
CoNLL 2019 shared task in Meaning Representation Parsing (MRP).
The software consists mainly of conversion scripts; the main part
of our system are third-party graph parsers.

The ".pl" extension denotes Perl scripts. In order to run them,
* make sure that a Perl interpreter is installed on your system;
* make sure that the module "JSON::Parse" has been added to Perl
  (try "cpanm JSON::Parse" or "cpan JSON::Parse").

The ".py" extension denotes Python 3 scripts. In order to run them,
make sure that a Python 3 interpreter is installed on your system.

MRP dentoes the JSON-based universal graph-representing format that
was used in the shared task.

SDP denotes an older vertical file format used in the SemEval
Semantic Dependency Parsing tasks in 2014 and 2015.

CoNLL-U is the vertical format used by the Universal Dependencies
project. Within this shared task it was used for the companion data.



mrp2sdp.pl

  Converts MRP data to SDP. Usage:

      perl mrp2sdp.pl --companion data/wsj.conllu < data/wsj.mrp > data/wsj.sdp
          --cpn ... instead of SDP, output a CPN file required by one of the parsers



eval2sdp.pl

  Converts input evaluation files (MRP JSON) to the SDP format.
  Reads the UDPipe-preprocessed input file (udpipe.mrp). The file input.mrp is not needed now,
  although it contains the extra attribute "targets". But targets cannot be encoded in SDP,
  and we will generate all targets for all sentences anyways.

      perl eval2sdp.pl < data/udpipe.mrp > data/eval.sdp
          --cpn ... instead of SDP, output a CPN file required by one of the parsers



sdp2mrp.pl

  Converts SDP data to MRP. Usage:

      perl sdp2mrp.pl --framework (dm|psd) --source source.mrp < input.sdp > output.mrp

  This script can be used to convert the output of an SDP parser
  back to the required MRP format. The source MRP file is needed
  because of input strings, source tokenization and anchoring of
  tokens in the input string.



mrpfilter.pl

  Takes two MRP files: source and target. Assumes that target is subset of source
  in terms of sentence ids (while the annotation can differ). Prints those graphs
  from source that also appear in target, in the order in which they appear in
  target. Usage:

      perl mrpfilter.pl --source source.mrp < target.mrp > filtered.mrp



amr2mrp.py

  Converts the output of the JAMR parser to the required MRP format.
  Usage:

      python amr2mrp.py -i input.amr -o output.mrp
