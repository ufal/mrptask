Data enhanced using the Stanford enhancer is here:
/lnet/spec/work/people/droganova/Data_for_Enhancer/final_2.4

It has been pruned and some treebanks are missing:
6 treebanks because they have no text (copyright issues)
19 others because their lemmatization is incomplete:

UD_Bambara-CRB
UD_Cantonese-HK
UD_Chinese-HK
UD_Chinese-PUD
UD_French-PUD
UD_Hindi-PUD
UD_Indonesian-PUD
UD_Korean-PUD
UD_Maltese-MUDT
UD_Old_French-SRCMF
UD_Persian-Seraji
UD_Portuguese-GSD
UD_Portuguese-PUD
UD_Spanish-PUD
UD_Swedish_Sign_Language-SSLC
UD_Telugu-MTG
UD_Thai-PUD
UD_Turkish-PUD
UD_Uyghur-UDT

121 treebanks remain.
For the first version we use only automatically enhanced graphs, even in treebanks where some enhancements
are available. This is because it is not trivial to merge partial manual enhancements with automatic ones.

PACKAGE THE DATA FOR RELEASE IN LINDAT:
tar czf deep-ud-2.4-data.tgz deep
