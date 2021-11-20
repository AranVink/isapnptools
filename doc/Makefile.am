
man_MANS = isapnp.8 pnpdump.8 isapnp.conf.5

READMES = README.DOS README.ide README.lib README.OS2 README.initrd README.modules README.borland

noinst_SCRIPTS = man2html

EXTRA_DIST = $(man_MANS) $(READMES) $(noinst_SCRIPTS) isapnpfaq.txt

DISTCLEANFILES = *.html *.[58].*
MAINTAINERCLEANFILES = isapnpfaq.txt

isapnp.8.html: isapnp.8 man2html
	./man2html isapnp.8

pnpdump.8.html: pnpdump.8 man2html
	./man2html pnpdump.8

isapnp.conf.5.html: isapnp.conf.5 man2html
	./man2html isapnp.conf.5

html: isapnp.8.html pnpdump.8.html isapnp.conf.5.html

dvi-local: isapnpfaq.tex
	latex isapnpfaq.tex
	latex isapnpfaq.tex

%.html: %.sgml
	sgml2html $<

%.txt: %.sgml
	sgml2txt $<

%.tex: %.sgml
	sgml2latex $<

