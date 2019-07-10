SHAREDIR=/net/work/projects/mrptask

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

# Test sample output from the parser.
# We do not expect the #SDP 2015 comment lines. Let's get rid of them.
test:
	grep -vP '^#SDP 2015' /lnet/spec/work/people/droganova/Data_for_Enhancer/MRP_data/dm.adadelta.lstm200.layer2.h100.drop0.25_42B.pred > pokus.sdp
	$(SHAREDIR)/sdp/validate.pl pokus.sdp | tee pokus-validate.log

