SHAREDIR=/net/work/projects/mrptask
MTOOL=$(SHAREDIR)/mtool

all: $(SHAREDIR)/penntb-psd.conllu $(SHAREDIR)/penntb-dm.conllu

$(SHAREDIR)/penntb-psd.conllu:
	cat $(SHAREDIR)/sdp/psd/all.sdp | tools/sdp2conllu.pl | tools/enhanced2basic.pl > $@
	tools/enhanced_graph_properties.pl $@

$(SHAREDIR)/penntb-dm.conllu:
	cat $(SHAREDIR)/sdp/dm/all.sdp | tools/sdp2conllu.pl | tools/enhanced2basic.pl > $@
	tools/enhanced_graph_properties.pl $@

MRPDATA=$(SHAREDIR)/mrp/2019
$(MRPDATA)/companion/wsj.conllu: $(MRPDATA)/companion/dm/wsj00.conllu $(MRPDATA)/companion/dm/wsj01.conllu $(MRPDATA)/companion/dm/wsj02.conllu $(MRPDATA)/companion/dm/wsj03.conllu $(MRPDATA)/companion/dm/wsj04.conllu
	cat $(MRPDATA)/companion/dm/wsj*.conllu > $@

.PHONY: dmpsd
dmpsd: $(MRPDATA)/training/dan/dm-wsj.sdp $(MRPDATA)/training/dan/psd-wsj.sdp

$(MRPDATA)/training/dan/dm-wsj.sdp: $(MRPDATA)/training/dm/wsj.mrp $(MRPDATA)/companion/wsj.conllu tools/mrp2sdp.pl
	tools/mrp2sdp.pl --companion $(MRPDATA)/companion/wsj.conllu $(MRPDATA)/training/dm/wsj.mrp > $(MRPDATA)/training/dan/dm-wsj.sdp
	tools/mrp2sdp.pl --cpn --companion $(MRPDATA)/companion/wsj.conllu $(MRPDATA)/training/dm/wsj.mrp > $(MRPDATA)/training/dan/dm-wsj.cpn

$(MRPDATA)/training/dan/psd-wsj.sdp: $(MRPDATA)/training/psd/wsj.mrp $(MRPDATA)/companion/wsj.conllu tools/mrp2sdp.pl
	tools/mrp2sdp.pl --companion $(MRPDATA)/companion/wsj.conllu $(MRPDATA)/training/psd/wsj.mrp > $(MRPDATA)/training/dan/psd-wsj.sdp
	tools/mrp2sdp.pl --cpn --companion $(MRPDATA)/companion/wsj.conllu $(MRPDATA)/training/psd/wsj.mrp > $(MRPDATA)/training/dan/psd-wsj.cpn

validate_dm_sdp:
	$(SHAREDIR)/sdp/validate.pl $(MRPDATA)/training/dan/dm-wsj.sdp | tee $(MRPDATA)/training/dan/dm-wsj.log

# Test sample output from the parser on data that the parser holds out for "development".
# We do not expect the #SDP 2015 comment lines. Let's get rid of them.
DEV_PARSED_DM=/lnet/spec/work/people/droganova/Data_for_Enhancer/MRP_data/dm.adadelta.lstm200.layer2.h100.drop0.25_42B_frames.sdp
DEV_PARSED_PSD=/home/droganova/work/Data_for_Enhancer/python_MRP/eval/psd_dev_eval.conllu
devconvert:
	grep -vP '^#SDP 2015' $(DEV_PARSED_DM) > dev.parsed.dm.sdp
	$(SHAREDIR)/sdp/validate.pl dev.parsed.dm.sdp | tee dev.parsed.dm-validate.log
	tools/sdp2mrp.pl --framework dm --source $(MRPDATA)/companion/udpipe.mrp < dev.parsed.dm.sdp > dev.parsed.dm.mrp
	$(MTOOL)/main.py --read mrp --validate all dev.parsed.dm.mrp
	grep -vP '^#SDP 2015' $(DEV_PARSED_PSD) > dev.parsed.psd.sdp
	$(SHAREDIR)/sdp/validate.pl dev.parsed.psd.sdp | tee dev.parsed.psd-validate.log
	tools/sdp2mrp.pl --framework psd --source $(MRPDATA)/companion/udpipe.mrp < dev.parsed.psd.sdp > dev.parsed.psd.mrp
	$(MTOOL)/main.py --read mrp --validate all dev.parsed.psd.mrp
	tools/sdp2mrp.pl --framework eds --source $(MRPDATA)/companion/udpipe.mrp < dev.parsed.dm.sdp > dev.parsed.eds.mrp
	$(MTOOL)/main.py --read mrp --validate all dev.parsed.eds.mrp

TEST_PARSED_DM=/home/droganova/work/Data_for_Enhancer/python_MRP/eva/dm_eval.conllu
TEST_PARSED_PSD=/home/droganova/work/Data_for_Enhancer/python_MRP/eval/psd_eval.conllu
testconvert:
	grep -vP '^#SDP 2015' $(TEST_PARSED_DM) > test.parsed.dm.sdp
	$(SHAREDIR)/sdp/validate.pl test.parsed.dm.sdp | tee test.parsed.dm-validate.log
	tools/sdp2mrp.pl --framework dm --source $(MRPDATA)/evaluation/udpipe.mrp < test.parsed.dm.sdp > test.parsed.dm.mrp
	$(MTOOL)/main.py --read mrp --validate all test.parsed.dm.mrp
	grep -vP '^#SDP 2015' $(TEST_PARSED_PSD) > test.parsed.psd.sdp
	$(SHAREDIR)/sdp/validate.pl test.parsed.psd.sdp | tee test.parsed.psd-validate.log
	tools/sdp2mrp.pl --framework psd --source $(MRPDATA)/evaluation/udpipe.mrp < test.parsed.psd.sdp > test.parsed.psd.mrp
	$(MTOOL)/main.py --read mrp --validate all test.parsed.psd.mrp
	tools/sdp2mrp.pl --framework eds --source $(MRPDATA)/evaluation/udpipe.mrp < test.parsed.dm.sdp > test.parsed.eds.mrp
	$(MTOOL)/main.py --read mrp --validate all test.parsed.eds.mrp
	cat test.parsed.dm.mrp test.parsed.psd.mrp test.parsed.eds.mrp > output.mrp
	zip submission.zip output.mrp

# --limit 0:0 should speed up scoring at the cost of not finding the optimal match. Default is 20:500000. We could try e.g. 5:100000 (example from the docs).
devevalquick:
	tools/mrpfilter.pl --source $(MRPDATA)/training/dm/wsj.mrp < dev.parsed.dm.mrp > gold.mrp
	$(MTOOL)/main.py --read mrp --score mrp --limit 0:0 --gold gold.mrp dev.parsed.dm.mrp | tee dev.parsed.dm.eval.txt
	tools/mrpfilter.pl --source $(MRPDATA)/training/psd/wsj.mrp < dev.parsed.psd.mrp > gold.mrp
	$(MTOOL)/main.py --read mrp --score mrp --limit 0:0 --gold gold.mrp dev.parsed.psd.mrp | tee dev.parsed.psd.eval.txt
	tools/mrpfilter.pl --source $(MRPDATA)/training/eds/wsj.mrp < dev.parsed.eds.mrp > gold.mrp
	$(MTOOL)/main.py --read mrp --score mrp --limit 0:0 --gold gold.mrp dev.parsed.eds.mrp | tee dev.parsed.eds.eval.txt

deveval:
	tools/mrpfilter.pl --source $(MRPDATA)/training/dm/wsj.mrp < dev.parsed.dm.mrp > gold.mrp
	$(MTOOL)/main.py --read mrp --score mrp --gold gold.mrp dev.parsed.dm.mrp | tee dev.parsed.dm.eval.txt
	tools/mrpfilter.pl --source $(MRPDATA)/training/psd/wsj.mrp < dev.parsed.psd.mrp > gold.mrp
	$(MTOOL)/main.py --read mrp --score mrp --gold gold.mrp dev.parsed.psd.mrp | tee dev.parsed.psd.eval.txt
	tools/mrpfilter.pl --source $(MRPDATA)/training/eds/wsj.mrp < dev.parsed.eds.mrp > gold.mrp
	$(MTOOL)/main.py --read mrp --score mrp --gold gold.mrp dev.parsed.eds.mrp | tee dev.parsed.eds.eval.txt
