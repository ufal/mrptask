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

experimental_dm_json_to_sdp: $(MRPDATA)/training/dm/wsj.mrp $(MRPDATA)/companion/wsj.conllu tools/read_json.pl
	tools/read_json.pl --companion $(MRPDATA)/companion/wsj.conllu $(MRPDATA)/training/dm/wsj.mrp > dm-wsj.sdp

validate_dm_sdp:
	$(SHAREDIR)/sdp/validate.pl dm-wsj.sdp

