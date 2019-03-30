SHAREDIR=/net/work/projects/mrptask

all: $(SHAREDIR)/penntb-psd.conllu $(SHAREDIR)/penntb-dm.conllu

$(SHAREDIR)/penntb-psd.conllu:
	cat $(SHAREDIR)/sdp/psd/all.sdp | tools/sdp2conllu.pl | tools/enhanced2basic.pl > $@
	tools/enhanced_graph_properties.pl $@

$(SHAREDIR)/penntb-dm.conllu:
	cat $(SHAREDIR)/sdp/dm/all.sdp | tools/sdp2conllu.pl | tools/enhanced2basic.pl > $@
	tools/enhanced_graph_properties.pl $@

