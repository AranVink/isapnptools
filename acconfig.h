/* Define this if you want to abort on resource dump error */
#undef ABORT_ONRESERR

/*
 * Define REALTIME if you want to run with realtime scheduling, this
 * is not really an option any more
 */
#undef REALTIME

/*
 * Define HAVE_PROC if you want to read allocated resource data from /proc
 */
#undef HAVE_PROC

/*
 * Define ENABLE_PCI if you want to check PCI resource usage (requires HAVE_PROC)
 */
#undef ENABLE_PCI

/*
 * Define this if you always want board configuration output
 * (normally you add the (NAME "..") keyword before (ACT .)
 */
#undef ALWAYSREPORTACTIVATION

/*
 * Define this to enable debugging code (see cardinfo.c)
 */
#undef DEBUG

/*
 * Define this to enable additional pnpdump output (show all valid address ranges)
 */
#undef DUMPADDR

/*
 * Define this to something else if required
 */
#undef GONEFILE

/*
 * Define this to enable tag debugging code
 */
#undef TAG_DEBUG

/*
 * Define this to check board ident
 */
#undef WANT_TO_VALIDATE

/*
 * Define this to use short file name includes (8.3)
 */
#undef HAVE_SFN

@BOTTOM@

#if defined __TURBOC__ || defined __BORLANDC__
#include <config.bor>
#endif
