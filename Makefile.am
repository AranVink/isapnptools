SUBDIRS = include src doc

EXTRA_SUBDIRS = demos

EXTRA_DIST = makeDOSr.bat

CLEANFILES = *~

dist-hook:
	cp isapnp.lsm $(distdir)
#	cp acconfig.h $(distdir)
	cp -ar $(srcdir)/config-scripts $(distdir)
	cp -ar $(srcdir)/test $(distdir)
	mkdir $(distdir)/etc
	cp $(srcdir)/etc/isapnp* $(distdir)/etc
	mkdir $(distdir)/demos
	cp $(srcdir)/demos/Makefile.* $(distdir)/demos
	cp $(srcdir)/demos/*.c $(distdir)/demos

short-file-names:
	for info in `cat $(srcdir)/src/sfnlfn.dat`;\
	do \
		sfn=`echo $$info | sed 's/^\([^:]*\).*$$/\1/'`;\
		lfn=`echo $$info | sed 's/^[^:]*:\([^:]*\).*$$/\1/'`;\
		test -f $(srcdir)/src/$$lfn && mv -f $(srcdir)/src/$$lfn $(srcdir)/src/$$sfn;\
		cat $(srcdir)/src/Makefile | sed "s/$$lfn/$$sfn/g" > $(srcdir)/src/Makefile.tmp && mv $(srcdir)/src/Makefile.tmp $(srcdir)/src/Makefile;\
	done
	for info in `cat $(srcdir)/include/isapnp/sfnlfn.dat`; \
	do \
		sfn=`echo $$info | sed 's/^\([^:]*\).*$$/\1/'`;\
		lfn=`echo $$info | sed 's/^[^:]*:\([^:]*\).*$$/\1/'`;\
		test -f $(srcdir)/include/isapnp/$$lfn && mv -f $(srcdir)/include/isapnp/$$lfn $(srcdir)/include/isapnp/$$sfn; \
		cat $(srcdir)/src/Makefile | sed "s/$$lfn/$$sfn/g" > $(srcdir)/src/Makefile.tmp && mv $(srcdir)/src/Makefile.tmp $(srcdir)/src/Makefile;\
		cat $(srcdir)/include/isapnp/Makefile | sed "s/$$lfn/$$sfn/g" > $(srcdir)/include/isapnp/Makefile.tmp && mv $(srcdir)/include/isapnp/Makefile.tmp $(srcdir)/include/isapnp/Makefile;\
	done

long-file-names:
	for info in `cat $(srcdir)/src/sfnlfn.dat`;\
	do \
		sfn=`echo $$info | sed 's/^\([^:]*\).*$$/\1/'`;\
		lfn=`echo $$info | sed 's/^[^:]*:\([^:]*\).*$$/\1/'`;\
		test -f $(srcdir)/src/$$sfn && mv -f $(srcdir)/src/$$sfn $(srcdir)/src/$$lfn;\
		cat $(srcdir)/src/Makefile | sed "s/$$sfn/$$lfn/g" > $(srcdir)/src/Makefile.tmp && mv $(srcdir)/src/Makefile.tmp $(srcdir)/src/Makefile;\
	done
	for info in `cat $(srcdir)/include/isapnp/sfnlfn.dat`; \
	do \
		sfn=`echo $$info | sed 's/^\([^:]*\).*$$/\1/'`;\
		lfn=`echo $$info | sed 's/^[^:]*:\([^:]*\).*$$/\1/'`;\
		test -f $(srcdir)/include/isapnp/$$sfn && mv -f $(srcdir)/include/isapnp/$$sfn $(srcdir)/include/isapnp/$$lfn; \
		cat $(srcdir)/src/Makefile | sed "s/$$sfn/$$lfn/g" > $(srcdir)/src/Makefile.tmp && mv $(srcdir)/src/Makefile.tmp $(srcdir)/src/Makefile;\
		cat $(srcdir)/include/isapnp/Makefile | sed "s/$$sfn/$$lfn/g" > $(srcdir)/include/isapnp/Makefile.tmp && mv $(srcdir)/include/isapnp/Makefile.tmp $(srcdir)/include/isapnp/Makefile;\
	done
