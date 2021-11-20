## Process this file with automake to produce Makefile.in

## Where to find isapnp/*.h
INCLUDES = -I$(top_srcdir)/include

EXTRA_DIST = getopt.h sfnlfn.dat

lib_LIBRARIES = libisapnp.a

##include_HEADERS = \
##	  ../include/isapnp/config.h	\
##	  ../include/isapnp/errenum.h	\
##	  ../include/isapnp/mysnprtf.h \
##	  ../include/isapnp/release.h \
##	  ../include/isapnp/callbacks.h \
##	  ../include/isapnp/iopl.h \
##	  ../include/isapnp/pnp-access.h \
##	  ../include/isapnp/res-access.h \
##	  ../include/isapnp/realtime.h \
##	  ../include/isapnp/errcodes.h \
##	  ../include/isapnp/pnp.h \
##	  ../include/isapnp/resource.h

libisapnp_a_SOURCES =  \
	callbacks.c \
	iopl.c \
	pnp-access.c \
	res-access.c \
	realtime.c \
	cardinfo.c \
	pnp-select.c \
	resource.c \
	mysnprtf.c \
	release.c

CLEANFILES = isapnp_main.c *.exe *~

sbin_PROGRAMS = pnpdump isapnp
isapnp_SOURCES = isapnp.c isapnp_main.l
isapnp_LDADD = @LIBOBJS@ libisapnp.a

pnpdump_SOURCES = pnpdump.c pnpdump_main.c
pnpdump_LDADD = @LIBOBJS@ libisapnp.a

