SHAREDIR=/net/work/projects/mrptask

all: $(SHAREDIR)/penntb-psd.conllu $(SHAREDIR)/penntb-dm.conllu

$(SHAREDIR)/penntb-psd.conllu:
	cat $(SHAREDIR)/sdp/psd/all.sdp | tools/sdp2conllu.pl | tools/enhanced2basic.pl > $@
	tools/enhanced_graph_properties.pl $@

$(SHAREDIR)/penntb-dm.conllu:
	cat $(SHAREDIR)/sdp/dm/all.sdp | tools/sdp2conllu.pl | tools/enhanced2basic.pl > $@
	tools/enhanced_graph_properties.pl $@

experimental_dm_json_to_sdp:
	tools/read_json.pl $(SHAREDIR)/mrp/2019/training/dm/wsj.mrp > dm-wsj.sdp

validate_dm_sdp:
	$(SHAREDIR)/sdp/validate.pl dm-wsj.sdp

