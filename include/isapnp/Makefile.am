isapnpincludedir = $(includedir)/isapnp

isapnpinclude_HEADERS = callbacks.h errcodes.h errenum.h iopl.h \
	mysnprtf.h pnp-access.h pnp.h realtime.h release.h \
	res-access.h resource.h

EXTRA_DIST = sfnlfn.dat

CLEANFILES = *~

uninstall-local:
	-rmdir $isapnpincludedir
