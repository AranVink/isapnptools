/*****************************************************************************
**
** demo.c
*/
static char st_demo_version[] = "$Id: demo.c,v 0.2 2001/04/30 21:43:35 fox Exp $";
/*
** Program which demonstrates how to use the libisapnp library procedures.
** It is similar in functionality to pnpdump, except that it outputs its
** stuff in a different format and that it provides also the following
** functionality:
** - Print the selected 'optimal' configuration
** - Making a list of available IRQ's and DMA's
**
**
** Copyright (C) 1999  Omer Zak (omerz@actcom.co.il)
**
** This library is free software; you can redistribute it and/or
** modify it under the terms of the GNU Library General Public
** License as published by the Free Software Foundation; either
** version 2 of the License, or (at your option) any later version.
**
** This library is distributed in the hope that it will be useful,
** but WITHOUT ANY WARRANTY; without even the implied warranty of
** MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
** Library General Public License for more details.
**
** You should have received a copy of the GNU Library General Public
** License along with this library; if not, write to the 
** Free Software Foundation, Inc., 59 Temple Place - Suite 330, 
** Boston, MA  02111-1307  USA.
**
******************************************************************************
**
** Bug reports and fixes - to  P.J.H.Fox (fox@roestock.demon.co.uk)
** Note:  by sending unsolicited commercial/political/religious
**        E-mail messages (known also as "spam") to any E-mail address
**        mentioned in this file, you irrevocably agree to pay the
**        receipient US$500.- (plus any legal expenses incurred while
**        trying to collect the amount due) per unsolicited
**        commercial/political/religious E-mail message - for
**        the service of receiving your E-mail message.
**
*****************************************************************************/


#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <getopt.h>
#include <isapnp/pnp-access.h>

/* demo.c can be built only under Linux. */

#ifdef __DJGPP__
#error "The __DJGPP__ environment is not supported."
#endif

#ifdef _OS2_
#error "The _OS2_ environment is not supported."
#endif


#ifdef __cplusplus
extern "C" {
#endif

/****************************************************************************/
/* Was the former demo2.h file */

#include <isapnp/res-access.h>


void prepare_to_inspect(void);
resource_inspector inspect_resource;
void finish_inspection(void);

/****************************************************************************/



/****************************************************************************/
/* Callbacks needed by the libisapnp procedures                             */
/****************************************************************************/

#include <isapnp/callbacks.h>

/* Forward declarations - this way I am making sure that the typedefs and the
** actual declarations (below) match each other.
*/
non_fatal_error pnpdump_non_fatal_error_callback;
progress_report pnpdump_progress_report_callback;

/* The callbacks themselves */

void
pnpdump_non_fatal_error_callback(int in_errno, int in_isapnp_error)
{
  if (in_isapnp_error >= ISAPNP_E_LAST_ERROR_CODE) {
    fprintf(stderr, "Unknown fatal error - error code is %d: %s\n",
	    in_isapnp_error, strerror(in_errno));
  }
  else if (ISAPNP_E_PRINT_PROGRESS_REPORT_BUF == in_isapnp_error) {
    fprintf(stderr,progress_report_buf);
  }
  else {
    if (0 == in_errno) {
      fprintf(stderr,"%s",st_error_messages[in_isapnp_error]);
    }
    else {
      fprintf(stderr, "%s: %s\n",
	      st_error_messages[in_isapnp_error],
	      strerror(in_errno));
    }
  }
}

void
pnpdump_progress_report_callback(const char *in_msg)
{
  /* Ignore the progress report messages */
}

/****************************************************************************/

static void 
usage(char *program_name)
{
  fprintf(stderr, "\n%s\nRelease %s\nThis is free software, see the sources for details.\n"
	  "For latest information, see "
	  "http://www.roestock.demon.co.uk/isapnptools/\n"
	  "This software has NO WARRANTY, use at your OWN RISK\n\n"

	  "Usage: %s [--scan] [--optimal] [--irqlist] [--dmalist] [--numcards=num]\n"
	  "          [--readport=port] [--reset] [--ignorecsum]"
#ifdef REALTIME
	  " [--max-realtime=n]"
#endif /* REALTIME */
	  "\n"
	  "          [--version] [--debug]\n",
	  st_demo_version, libtoolsver, program_name);
}

/****************************************************************************/

int
main(int argc, char **argv)
{
  /* Local variables */
  char *l_prog_name_str = argv[0];
  int l_alloc_result;

  /* I/O to interrogate_isapnp */
  interrogate_args l_interrog_args;
  interrogate_results l_interrog_results;

  /* Command line options */
  int l_scan_flag = 0;          /* "scan" */
  int l_optimal_flag = 0;       /* "optimal" */
  int l_irqlist_flag = 0;       /* "irqlist" */
  int l_dmalist_flag = 0;       /* "dmalist" */
  /* int l_version_flag = 0;       ** "version" **      not used */

  const struct option longopts[] = {
    {"scan",    no_argument, NULL, 's'},     /* Scan all cards */
    {"optimal", no_argument, NULL, 'o'},     /* Find optimal configuration */
    {"irqlist", no_argument, NULL, 'i'},     /* List all free IRQs */
    {"dmalist", no_argument, NULL, 'd'},     /* List all free DMAs */
    {"numcards", required_argument, NULL, 'n'}, /* No. of cards */
    {"readport", required_argument, NULL, 'r'}, /* PnP port */
    {"reset",   no_argument, NULL, 'R'},     /* Force reset of all ISA
					     ** PnP cards */
    {"ignorecsum", no_argument, NULL, 'I'},  /* Ignore checksum */
#ifdef REALTIME
    {"max-realtime", required_argument, NULL, 't'},
#endif
    {"version", no_argument, NULL, 'v'},     /* Display version */
    {"debug", no_argument, NULL, 'D'},       /* Run in debug mode */
    {0, 0, 0, 0},
  };

  /* Miscellaneous variables */
  int l_opt;
  int l_ret;     /* Return code */

  /**************************************************************************/
  /* First thing to do - initialize the interrogate_args structure.  Some
  ** of its fields will later be modified from command line arguments.
  */
  l_interrog_args.m_non_fatal_error_callback_p = pnpdump_non_fatal_error_callback;
  l_interrog_args.m_progress_report_callback_p = pnpdump_progress_report_callback;
  l_interrog_args.m_numcards = -1;  /* Default = autodetect */
  l_interrog_args.m_readport = -1;  /* Default = autodetect */
  l_interrog_args.m_reset_flag = 0;
  l_interrog_args.m_ignore_csum_flag = 0;
#ifdef REALTIME
  l_interrog_args.m_realtime_timeout = 5L;
#endif
  l_interrog_args.m_debug_flag = 0;

  /**************************************************************************/
  /* Decode command line arguments */

  while ((l_opt = getopt_long(argc, argv, "soidn:r:RItvD", longopts, NULL))
	 != EOF) {
    switch (l_opt) {
    case 's':
      l_scan_flag = 1;
      break;

    case 'o':
      l_optimal_flag = 1;
      break;

    case 'i':
      l_irqlist_flag = 1;
      break;

    case 'd':
      l_dmalist_flag = 1;
      break;

    case 'n':
      l_interrog_args.m_numcards = atoi(optarg);
      if ((l_interrog_args.m_numcards < 0)
	  || (l_interrog_args.m_numcards >= NUM_CARDS)) {
	fprintf(stderr, "Cannot handle %d boards, recompile with larger NUM_CARDS\n", l_interrog_args.m_numcards);
	exit(1);
      }
      break;

    case 'r':
      /* Read decimal or hex number */
      l_interrog_args.m_readport = (int) strtol(optarg, (char **) NULL, 0);
      if ((l_interrog_args.m_readport < MIN_READ_ADDR)
	  || (l_interrog_args.m_readport > MAX_READ_ADDR))	{
	fprintf(stderr, "Port address %s (0x%04x) out of range 0x%04x..0x%04x\n",
		optarg, l_interrog_args.m_readport, MIN_READ_ADDR, MAX_READ_ADDR);
	exit(1);
      }
      l_interrog_args.m_readport |= 3;
      break;

    case 'R':
      l_interrog_args.m_reset_flag = 1;
      break;

    case 'I':
      l_interrog_args.m_ignore_csum_flag = 1;
      break;

    case 't':
#ifdef REALTIME
      l_interrog_args.m_realtime_timeout = atol(optarg);
#else
      fprintf(stderr, "Realtime support not compiled in - option ignored\n");
#endif
      break;

    case 'v':
      fprintf(stderr, "Version: demo from %s"
	              "         compiled using compile-time flags %s\n",
	      libtoolsver, libcompilerflags);
      break;

    case 'D':
      l_interrog_args.m_debug_flag = 1;
      break;

    case '?':
      fprintf(stderr, "unrecognized option.\n");
      usage(l_prog_name_str);
      return 1;

    case ':':
      fprintf(stderr, "missing parameter.\n");
      usage(l_prog_name_str);
      return 1;
    default:
      fprintf(stderr,
	      "?? getopt returned character code 0x%x ('%c').\n",
	      l_opt, l_opt);
      return 1;
    }
  }

  /**************************************************************************/

  l_ret = interrogate_isapnp(&l_interrog_args, &l_interrog_results);
  if (0 != l_ret) {
    printf("!!! Error while trying to interrogate the ISA PnP cards !!!\n");
    exit(1);
  }

  printf("# %s\n# Release %s\n# This is free software, see the sources for details.\n"
	 "# This software has NO WARRANTY, use at your OWN RISK\n"
	 "#\n"
	 "# For latest information and FAQ on isapnp and pnpdump see:\n"
	 "# http://www.roestock.demon.co.uk/isapnptools/\n"
	 "#\n"
	 "# Compiler flags: %s" ,
	 st_demo_version, libtoolsver, libcompilerflags);
  printf("\n\n");

  /**************************************************************************/
  /* Implement the optimal configuration, if so requested. */
  if (l_optimal_flag) {
    l_alloc_result = alloc_resources(l_interrog_results.m_resource_p,
				     l_interrog_results.m_resource_count,
				     NULL, 0);
  }
  else {
    l_alloc_result = 0;
  }

  /**************************************************************************/
  /* Now inspect the resources data.  The procedures which do the actual
  ** inspection need to be customized.
  */
  if (0 != l_scan_flag) {
    /* The actual customizable code is in the procedures:
    ** prepare_inspect(), inspect_resource() and finish_inspection().
    ** Their implementation follows this procedure.
    */
    prepare_to_inspect();
    for_each_resource(l_interrog_results.m_resource_p,
		      l_interrog_results.m_resource_count,
		      inspect_resource, stdout, l_alloc_result);
    finish_inspection();
  }

  /**************************************************************************/
  {
    /* Retrieve IRQ/DMA information, if any was requested. */
    long l_irq;
    long l_dma;

    l_ret = get_free_irqs_dmas((0 != l_irqlist_flag) ? &l_irq : NULL,
			       (0 != l_dmalist_flag) ? &l_dma : NULL);
    if (0 != l_ret) {
      printf("!!! Error while trying to get IRQ/DMA information !!!\n");
      exit(1);
    }

    if (0 != l_irqlist_flag) {
      printf("Free IRQ bit mask: 0x%04x\n",(int) l_irq);
    }
    if (0 != l_dmalist_flag) {
      printf("Free DMA bit mask: 0x%02x\n",(int) l_dma);
    }
  }

  /**************************************************************************/

  return(0);
}

/****************************************************************************/
/* Auxiliary procedures - used by inspect_resource().
*/

char *
devidstr(unsigned char d1, unsigned char d2,
	 unsigned char d3, unsigned char d4)
{
  static char resstr[] = "PNP0000";
  sprintf(resstr, "%c%c%c%x%x%x%x",
	  'A' + (d1 >> 2) - 1, 'A' + (((d1 & 3) << 3) | (d2 >> 5)) - 1,
	  'A' + (d2 & 0x1f) - 1, d3 >> 4, d3 & 0x0f, d4 >> 4, d4 & 0x0f);
  return resstr;
}

/****************************************************************************/
/* Definitions of procedures for inspecting the resources, which are called
** after interrogation of the ISA PnP cards.
*/

int st_res_index = -1;
       /* Illegal value, to catch failure to call prepare_to_inspect() */

void
prepare_to_inspect()
{
  st_res_index = 0;
}

void
inspect_resource(FILE *out_file, struct resource *in_res_ptr, int in_selected)
{
  st_res_index++;
  fprintf(out_file, "Resource record %03d: ", st_res_index);
  switch (in_res_ptr->type) {
    case NewBoard_PSEUDOTAG:
      fprintf(out_file, "NewBoard_PSEUDOTAG\n");
      fprintf(out_file, "                     tag(0x%02x)\n",
	      (unsigned int) in_res_ptr->tag);
      {
	int ll_csn = in_res_ptr->start;
	/*
	unsigned long l_serialno = (unsigned long)
	  serial_identifier[ll_csn][4] +
	  (serial_identifier[ll_csn][5] << 8) +
	  (serial_identifier[ll_csn][6] << 16) +
	  (serial_identifier[ll_csn][7] << 24);
	*/
	fprintf(out_file, "                     board ID=%s\n",
		devidstr(serial_identifier[ll_csn][0],
			 serial_identifier[ll_csn][1],
			 serial_identifier[ll_csn][2],
			 serial_identifier[ll_csn][3]));
      }
      break;

    case PnPVerNo_TAG:
      fprintf(out_file, "PnPVerNo_tag\n");
      fprintf(out_file, "                     tag(0x%02x)\n",
	      (unsigned int) in_res_ptr->tag);
      if (in_res_ptr->len != 2) {
	fprintf(out_file, "    *** length error - should be 2, is %d.\n",
		in_res_ptr->len);
      }
      fprintf(out_file, "                     Version %d.%d, Vendor version %x.%x\n",
	      in_res_ptr->data[0] >> 4, in_res_ptr->data[0] & 0x0f,
	      in_res_ptr->data[1] >> 4, in_res_ptr->data[1] & 0x0f);
      break;
    case LogDevId_TAG:
      fprintf(out_file, "LogDevId_TAG\n");
      fprintf(out_file, "                     tag(0x%02x)\n",
	      (unsigned int) in_res_ptr->tag);
      fprintf(out_file, "                     dev_ids[0]=%s\n",
	      devidstr(in_res_ptr->data[0], in_res_ptr->data[1],
		       in_res_ptr->data[2], in_res_ptr->data[3]));
      break;
    case CompatDevId_TAG:
      fprintf(out_file, "CompatDevId_TAG\n");
      fprintf(out_file, "                     tag(0x%02x)\n",
	     (unsigned int) in_res_ptr->tag);
      fprintf(out_file, "                     dev_ids[i]=%s\n",
	      devidstr(in_res_ptr->data[0], in_res_ptr->data[1],
		       in_res_ptr->data[2], in_res_ptr->data[3]));
      break;
    case IRQ_TAG:
      fprintf(out_file, "IRQ_TAG\n");
      fprintf(out_file, "                     tag(0x%02x) data(%s)\n",
	     (unsigned int) in_res_ptr->tag,
	     (NULL != in_res_ptr->data) ? (char *)(in_res_ptr->data) : "---");
      fprintf(out_file, "                     IRQ=%ld  flags=0x%02x\n",
	      in_res_ptr->value, in_res_ptr->data[2]);
      /* !!!! Decode the flags !!!!! */
      break;
    case DMA_TAG:
      fprintf(out_file, "DMA_TAG\n");
      fprintf(out_file, "                     tag(0x%02x)\n",
	      (unsigned int) in_res_ptr->tag);
      fprintf(out_file, "                     DMA=%ld  flags=0x%02x\n",
              in_res_ptr->value, in_res_ptr->data[1]);
      /* !!!!! Decode the flags !!!!! */
      break;
    case StartDep_TAG:
      fprintf(out_file, "StartDep_TAG\n");
      fprintf(out_file, "                     tag(0x%02x) data(%s)\n",
	     (unsigned int) in_res_ptr->tag,
	     (NULL != in_res_ptr->data) ? (char *)(in_res_ptr->data) : "---");
      fprintf(out_file, "    (starting dependencies)\n");
      break;
    case EndDep_TAG:
      fprintf(out_file, "EndDep_TAG\n");
      fprintf(out_file, "                     tag(0x%02x)\n",
	     (unsigned int) in_res_ptr->tag);
      fprintf(out_file,
	      "-------------------- there are %d alternatives.\n",
	      in_res_ptr->alternatives[in_res_ptr->value].len);
      for_each_resource(in_res_ptr->alternatives[in_res_ptr->value].resources,
			in_res_ptr->alternatives[in_res_ptr->value].len,
			inspect_resource, out_file, in_selected);
      fprintf(out_file,
	      "-------------------- end of alternatives' details.\n");
      break;
    case IOport_TAG:
      fprintf(out_file, "IOport_TAG\n");
      fprintf(out_file, "                     tag(0x%02x)\n",
	     (unsigned int) in_res_ptr->tag);
      fprintf(out_file, "                     IO-start=0x%04lx  IO-length=%-2ld  IO-flags=0x%02x\n",
	      in_res_ptr->value, in_res_ptr->size, in_res_ptr->data[0]);
      /* !!!!! ????->value, not ->start?????? */
      /* !!!! Decode the flags !!!!!!! */
      break;
    case FixedIO_TAG:
      fprintf(out_file, "FixedIO_TAG\n");
      fprintf(out_file, "                     tag(0x%02x) data(%s)\n",
	      (unsigned int) in_res_ptr->tag,
	      (NULL != in_res_ptr->data) ? (char *)(in_res_ptr->data) : "---");
      fprintf(out_file, "                     IO-start=0x%04lx  IO-length=%-2ld  IO-flags=(fixed I/O)\n",
	      in_res_ptr->start, in_res_ptr->size);
      /* !!!!! ????->start, not ->value?????? */
      break;
    case MemRange_TAG:
      fprintf(out_file, "MemRange_TAG\n");
      fprintf(out_file, "                     tag(0x%02x) data(%s)\n",
	     (unsigned int) in_res_ptr->tag,
	     (NULL != in_res_ptr->data) ? (char *)(in_res_ptr->data) : "---");
      fprintf(out_file, "                     mem-start=0x%04lx  mem-length=%ld\n  mem-flags=0x%04x\n",
	      in_res_ptr->value, in_res_ptr->size, in_res_ptr->data[0]);
      /* !!!!! Decode the memory flags !!!!!!! */
      break;
    case ANSIstr_TAG:
      fprintf(out_file, "ANSIstr_TAG\n");
      fprintf(out_file, "                     tag(0x%02x) data(%s)\n",
	     (unsigned int) in_res_ptr->tag,
	     in_res_ptr->data);
      break;
    case UNICODEstr_TAG:
      fprintf(out_file, "UNICODEstr_TAG\n");
      fprintf(out_file, "                     tag(0x%02x) data(%s)\n",
	     (unsigned int) in_res_ptr->tag,
	     in_res_ptr->data);
      break;
    case VendorShort_TAG:
      fprintf(out_file, "VendorShort_TAG\n");
      fprintf(out_file, "                     tag(0x%02x) data(%s)\n",
	     (unsigned int) in_res_ptr->tag,
	     (NULL != in_res_ptr->data) ? (char *)(in_res_ptr->data) : "---");
      break;
    case VendorLong_TAG:
      fprintf(out_file, "VendorLong_TAG\n");
      fprintf(out_file, "                     tag(0x%02x) data(%s)\n",
	     (unsigned int) in_res_ptr->tag,
	     (NULL != in_res_ptr->data) ? (char *)(in_res_ptr->data) : "---");
      break;
    case End_TAG:
      fprintf(out_file, "End_TAG\n");
      fprintf(out_file, "                     tag(0x%02x)\n",
	     (unsigned int) in_res_ptr->tag);
      fprintf(out_file, "                     Presumably, this is the end.\n");
      break;
    case Mem32Range_TAG:
      fprintf(out_file, "Mem32Range_TAG\n");
      fprintf(out_file, "                     tag(0x%02x) data(%s)\n",
	     (unsigned int) in_res_ptr->tag,
	     (NULL != in_res_ptr->data) ? (char *)(in_res_ptr->data) : "---");
      break;
    case FixedMem32Range_TAG:
      fprintf(out_file, "FixedMem32Range_TAG\n");
      fprintf(out_file, "                     tag(0x%02x) data(%s)\n",
	     (unsigned int) in_res_ptr->tag,
	     (NULL != in_res_ptr->data) ? (char *)(in_res_ptr->data) : "---");
      break;
    default:
      fprintf(out_file, "*** Unknown tag type 0x%02x ***\n", in_res_ptr->type);
      break;
  }
}

void
finish_inspection(void)
{
}


#ifdef WANT_TO_COMPILE_TRASH
/* !!!! The code from this on is NOT compiled.
** !!!! It was retained only as comments, to help users of isapnplib to
** !!!! understand how to access the information in the resource records.
*/




/*****************************************************************************
**
*/


#include <stdlib.h>
#include <string.h>		/* For strncpy */

#define TAG_DEBUG 0
#define DUMPADDR 0




#define LARGE_LEN 65536



/* Global state variables used for printing resource information. */
unsigned long serialno = 0;
char devid[8];											   /* Copy as devidstr							    * returns pointer to						    * static buffer subject						    * to change */

int nestdepth;
int curid;
int curdma, depdma;
int curio, depio;
int curint, depint;
int curmem, depmem;
int starteddeps;
char *indep = "";


unsigned char tmp[TMP_LEN];
unsigned char large[LARGE_LEN];
static char *devstring = 0;

int showmasks = 0;
int do_autoconfig = 0;


void dumpdata(int);


int do_dumpregs = 0;
void dumpregs(int);


void
lengtherror(int len, char *msg)
{
	int i;
	printf("# Bad tag length for %s in 0x%02x", msg, tmp[0]);
	if (tmp[0] & 0x80)
	{
		printf(" 0x%02x 0x%02x", len & 255, len >> 8);
		for (i = 0; i < len; i++)
			printf(" 0x%02x", large[i]);
	}
	else
	{
		for (i = 1; i <= len; i++)
			printf(" 0x%02x", tmp[i]);
	}
	printf("\n");
}

#ifdef ABORT_ONRESERR
#define BREAKORCONTINUE   goto oncorruptresourcedata
#else
#define BREAKORCONTINUE   break
#endif

static void
showmask(unsigned long mask)
{
	int i;
	int firsttime = 1;

	if (showmasks)
	{
		printf(" mask 0x%lx", mask);
	}
	else
	{
		for (i = 0; mask; i++, mask >>= 1)
		{
			if (mask & 0x1)
			{
				if (!firsttime)
				{
					printf(mask == 1 ? " or " : ", ");
				}
				else
				{
					printf(" ");
					firsttime = 0;
				}
				printf("%d", i);
			}
		}
	}
}


static int IORangeCheck = 0;

static void
print_resource(FILE * output_file, struct resource *res, int selected)
{
	static int logdevno = 0;
	int type = res->type;
	int len = res->len;
	int i;
	char *comment_if_not_selected = selected ? " " : "#";

	switch (type)
	{
	case NewBoard_PSEUDOTAG:
		{
			int csn = res->start;

			logdevno = 0;
			serialno = (unsigned long)
				serial_identifier[csn][4] +
				(serial_identifier[csn][5] << 8) +
				(serial_identifier[csn][6] << 16) +
				(serial_identifier[csn][7] << 24);
			strncpy(devid, devidstr(serial_identifier[csn][0],
									serial_identifier[csn][1],
									serial_identifier[csn][2],
									serial_identifier[csn][3]), 8);

			printf("# Card %d: (serial identifier", csn);
			for (i = IDENT_LEN; i--;)
				printf(" %02x", serial_identifier[csn][i]);
			printf(")\n");
			if (serialno == 0xffffffffUL)
			{
				printf("# Vendor Id %s, No Serial Number (-1), checksum 0x%02X.\n", devid, serial_identifier[csn][8]);
			}
			else
			{
				printf("# Vendor Id %s, Serial Number %lu, checksum 0x%02X.\n", devid, serialno, serial_identifier[csn][8]);
			}
			if (res->len != IDENT_LEN)
			{
				i = 0;
				printf("# Ident byte %d, (%02x) differs from resource data (%02x)\n", i, serial_identifier[csn][i], res->data[0]);
				printf("#Assuming the card is broken and this is the start of the resource data\n");
			}
			else
			{
				for (i = 1; i < IDENT_LEN; i++)
				{
					if ((res->data[i] != serial_identifier[csn][i]) && (i < (IDENT_LEN - 1)))
						printf("# Ident byte %d, (%02x) differs from resource data (%02x)\n", i, serial_identifier[csn][i], res->data[i]);
				}
			}
		}

		break;
	case PnPVerNo_TAG:
		{
			break;
		}
	case LogDevId_TAG:
		{
			int reg;
			static char *regfns[8] =
			{"Device capable of taking part in boot process",
			 "Device supports I/O range check register",
			 "Device supports reserved register @ 0x32",
			 "Device supports reserved register @ 0x33",
			 "Device supports reserved register @ 0x34",
			 "Device supports reserved register @ 0x35",
			 "Device supports reserved register @ 0x36",
			 "Device supports reserved register @ 0x37"};
			if ((len < 5) || (len > 6))
			{
				lengtherror(len, "LogDevId_TAG");
				BREAKORCONTINUE;
			}
			indep = "";
			if (nestdepth)
			{
				/* If we have a device name, show it (the last description string before the END DF flag is it) */
				if (serialno == 0xffffffffUL)
					printf(" (NAME \"%s/-1[%d]", devid, logdevno-1);
				else
					printf(" (NAME \"%s/%lu[%d]", devid, serialno, logdevno-1);
				if(devstring)
					printf("{%-20s}", devstring);
				printf("\")\n");
				printf("%s (ACT Y)\n", comment_if_not_selected);
				while (nestdepth)
				{
					printf(")");
					nestdepth--;
				}
				printf("\n");
			}
			printf("#\n# %sLogical device id %s\n", indep, devidstr(res->data[0], res->data[1], res->data[2], res->data[3]));
			indep = "    ";
			IORangeCheck = 0;
			for (i = 0, reg = 1; reg < 256; i++, reg <<= 1)
			{
				if (res->data[4] & reg)
				{
					printf("# %s%s\n", indep, regfns[i]);
					if(i == 1)
						IORangeCheck = 1;
				}
			}
			for (i = 0, reg = 1; reg < 256; i++, reg <<= 1)
			{
				if (res->data[5] & reg)
				{
					printf("# %sDevice supports vendor reserved register @ 0x%02x\n", indep, 0x38 + i);
				}
			}
			printf("#\n# Edit the entries below to uncomment out the configuration required.\n");
			printf("# Note that only the first value of any range is given, this may be changed if required\n");
			printf("# Don't forget to uncomment the activate (ACT Y) when happy\n\n");
			if (serialno == 0xffffffffUL)
				printf("(CONFIGURE %s/-1 (LD %d\n", devid, logdevno++);
			else
				printf("(CONFIGURE %s/%lu (LD %d\n", devid, serialno, logdevno++);
			nestdepth = 2;
			curdma = 0;
			depdma = 0;
			curio = 0;
			depio = 0;
			curint = 0;
			depint = 0;
			curmem = 0;
			depmem = 0;
			starteddeps = 0;
			break;
		}
	case CompatDevId_TAG:
		{
			if (len != 4)
			{
				lengtherror(len, "CompatDevId_TAG");
				BREAKORCONTINUE;
			}
			printf("# %sCompatible device id %s\n", indep, devidstr(res->data[0], res->data[1], res->data[2], res->data[3]));
			break;
		}
	case IRQ_TAG:
		{
			int firstirq = 0;
			char *edge = "+E";
			if ((len < 2) || (len > 3))
			{
				lengtherror(len, "IRQ_TAG");
				BREAKORCONTINUE;
			}
			if ((len >= 2) && (res->data[0] || res->data[1]))
			{
				printf("# %sIRQ", indep);
				if(res->errflags & RES_ERR_NO_IRQ)
					printf("# %s%s*** Bad resource data: No IRQ specified\n", indep, indep);
				if(res->errflags & RES_ERR_IRQ2)
					printf("# %s%s*** Bad resource data (Clarifications 4.6.2): IRQ 2 invalid, changing to 9\n", indep, indep);
				showmask(res->mask);
				printf(".\n");
				firstirq = res->value;
				if (len == 3)
				{
					if (res->data[2] & 1)
					{
						printf("# %s%sHigh true, edge sensitive interrupt\n", indep, indep);
						edge = "+E";
					}
					if (res->data[2] & 2)
					{
						printf("# %s%sLow true, edge sensitive interrupt\n", indep, indep);
						edge = "-E";
					}
					if (res->data[2] & 4)
					{
						printf("# %s%sHigh true, level sensitive interrupt\n", indep, indep);
						edge = "+L";
					}
					if (res->data[2] & 8)
					{
						printf("# %s%sLow true, level sensitive interrupt\n", indep, indep);
						edge = "-L";
					}
				}
				else
				{
					printf("# %s%sHigh true, edge sensitive interrupt (by default)\n", indep, indep);
				}
				printf("%s (INT %d (IRQ %ld (MODE %s)))\n",
					   comment_if_not_selected, curint, res->value, edge);
				curint++;
				if (!starteddeps)
					depint = curint;
			}
			else
			{
				printf("# %s*** ERROR *** No IRQ specified!\n", indep);
			}
			break;
		}
	case DMA_TAG:
		{
			int firstdma = 4;							   /* Ie, no DMA */
			if (len != 2)
			{
				lengtherror(len, "DMA_TAG");
				BREAKORCONTINUE;
			}
			if (res->mask)
			{
				printf("# %s%sDMA channel",
					   indep, (curdma == 0) ? "First " : "Next ");
				firstdma = res->value;
				showmask(res->mask);
				printf(".\n");
			}
			else
			{
				printf("# %s*** ERROR *** No DMA channel specified!\n", indep);
			}
			if ((res->data[1] & 3) == 0)
				printf("# %s%s8 bit DMA only\n", indep, indep);
			if ((res->data[1] & 3) == 1)
				printf("# %s%s8 & 16 bit DMA\n", indep, indep);
			if ((res->data[1] & 3) == 2)
				printf("# %s%s16 bit DMA only\n", indep, indep);
			printf("# %s%sLogical device is%s a bus master\n", indep, indep, res->data[2] & 4 ? "" : " not");
			printf("# %s%sDMA may%s execute in count by byte mode\n", indep, indep, res->data[1] & 8 ? "" : " not");
			printf("# %s%sDMA may%s execute in count by word mode\n", indep, indep, res->data[1] & 0x10 ? "" : " not");
			if ((res->data[1] & 0x60) == 0x00)
				printf("# %s%sDMA channel speed in compatible mode\n", indep, indep);
			if ((res->data[1] & 0x60) == 0x20)
				printf("# %s%sDMA channel speed type A\n", indep, indep);
			if ((res->data[1] & 0x60) == 0x40)
				printf("# %s%sDMA channel speed type B\n", indep, indep);
			if ((res->data[1] & 0x60) == 0x60)
				printf("# %s%sDMA channel speed type F\n", indep, indep);
			printf("%s (DMA %d (CHANNEL %d))\n", comment_if_not_selected, curdma, firstdma);
			curdma++;
			if (!starteddeps)
				depdma = curdma;
			break;
		}
	case StartDep_TAG:
		{
			if (len > 1)
			{
				lengtherror(len, "StartDep_TAG");
				BREAKORCONTINUE;
			}
			putchar('\n');
			if (!starteddeps)
				printf("# Multiple choice time, choose one only !\n\n");
			if (res->len == 0)
			{
				printf("# %sStart dependent functions: priority acceptable\n", indep);
			}
			else
				switch (res->data[0])
				{
				case 0:
					printf("# %sStart dependent functions: priority preferred\n", indep);
					break;
				case 1:
					printf("# %sStart dependent functions: priority acceptable\n", indep);
					break;
				case 2:
					printf("# %sStart dependent functions: priority functional\n", indep);
					break;
				default:
					printf("# %sStart dependent functions: priority INVALID\n", indep);
					break;
				}
			indep = "      ";
			starteddeps = 1;
			curio = depio;
			curdma = depdma;
			curint = depint;
			curmem = depmem;
			break;
		}
	case EndDep_TAG:
		{
			int i;
			if (len > 0)
			{
				lengtherror(len, "EndDep_TAG");
				BREAKORCONTINUE;
			}
			for (i = 0; i < res->end; i++)
			{
				for_each_resource(res->alternatives[i].resources,
								  res->alternatives[i].len,
								  print_resource,
								  stdout,
								  selected && (res->value == i));
			}
			indep = "    ";
			printf("\n# %sEnd dependent functions\n", indep);
			break;
		}
	case IOport_TAG:
		{
			if (len != 7)
			{
				lengtherror(len, "IOport_TAG");
				printf("# Bad tag length in 0x%02x\n", res->tag);
				BREAKORCONTINUE;
			}
			printf("# %sLogical device decodes %s IO address lines\n", indep, res->data[0] ? "16 bit" : "10 bit");
			printf("# %s%sMinimum IO base address 0x%04lx\n", indep, indep, res->start);
			printf("# %s%sMaximum IO base address 0x%04lx\n", indep, indep, res->end - 1);
			printf("# %s%sIO base alignment %ld bytes\n", indep, indep, res->step);
			if(res->errflags & RES_ERR_NO_STEP)
				printf("# %s%s*** Bad resource data: Base alignment 0 - changed to 1\n", indep, indep);
			printf("# %s%sNumber of IO addresses required: %d\n", indep, indep, res->data[6]);
#if DUMPADDR
			for (i = ((res->data[3] << 8) + res->data[2]); i <= ((res->data[5] << 8) + res->data[4]); i += res->data[5])
			{
				printf("# %s%s0x%04x..0x%04x\n", indep, indep, indep, i, i + res->data[6] - 1);
			}
#endif /* DUMPADDR */
			printf("%s (IO %d (SIZE %d) (BASE 0x%04lx)%s)\n",
				   comment_if_not_selected, curio, res->data[6], res->value, IORangeCheck ? " (CHECK)" : "");
			curio++;
			if (!starteddeps)
				depio = curio;
			break;
		}
	case FixedIO_TAG:
		{
			if (len != 3)
			{
				lengtherror(len, "FixedIO_TAG");
				printf("# Bad tag length in 0x%02x\n", res->tag);
				BREAKORCONTINUE;
			}
			printf("# %sFixed IO base address 0x%04lx\n", indep, res->start);
			printf("# %s%sNumber of IO addresses required: %ld\n", indep, indep, res->size);
			printf("%s (IO %d (SIZE %ld) (BASE 0x%04lx)%s)\n",
				   comment_if_not_selected, curio, res->size, res->start, IORangeCheck ? " (CHECK)" : "");
			curio++;
			if (!starteddeps)
				depio = curio;
			break;
		}
	case MemRange_TAG:
		{
			char width = 'w';

			if (len != 9)
			{
				lengtherror(len, "MemRange_TAG");
				printf("# %sInvalid length for memory range tag 0x%02x\n", indep, res->tag);
				BREAKORCONTINUE;
			}
			printf("# %sMemory is %s\n", indep, res->data[0] & 1 ? "writeable" : "non-writeable (ROM)");
			printf("# %sMemory is %s\n", indep, res->data[0] & 2 ? "read cacheable, write-through" : "non-cacheable");
			printf("# %sMemory decode supports %s\n", indep, res->data[0] & 4 ? "range length" : "high address");
			if ((res->data[0] & 0x18) == 0x00)
			{
				width = 'b';
				printf("# %smemory is 8-bit only\n", indep);
			}
			if ((res->data[0] & 0x18) == 0x08)
				printf("# %smemory is 16-bit only\n", indep);
			if ((res->data[0] & 0x18) == 0x10)
				printf("# %smemory is 8-bit and 16-bit\n", indep);
			if (res->data[0] & 0x20)
				printf("# %smemory is shadowable\n", indep);
			if (res->data[0] & 0x40)
				printf("# %smemory is an expansion ROM\n", indep);
			printf("# %sMinimum memory base address 0x%06lx\n", indep, res->start);
			printf("# %sMaximum memory base address 0x%06lx\n", indep, res->end - 1);
			printf("# %sRange base alignment mask 0xff%04lx bytes\n", indep, res->step);
			printf("# %sRange length %ld bytes\n", indep, res->size);
#ifdef DUMPADDR
#if 0
			***untested ***
				for (i = ((res->data[2] << 16) + (res->data[1] << 8));
					 i <= ((res->data[4] << 16) + (res->data[3] << 8));
					 i += ((res->data[6] << 8) + res->data[5]))
			{
				printf("# %s%s0x%06x..0x%06x\n", indep, indep,
					 i, i + (res->data[8] << 16) + (res->data[7] << 8) - 1);
			}
#endif
#endif /* DUMPADDR */
			printf("# Choose UPPER = Range, or UPPER = Upper limit to suit hardware\n");
			printf("%s (MEM %d (BASE 0x%06lx) (MODE %cu) (UPPER 0x%06lx))\n",
				   comment_if_not_selected,
				   curmem, res->start, width, res->start + res->size);
			printf("# (MEM %d (BASE 0x%06lx) (MODE %cr) (UPPER 0x%06lx))\n", curmem, res->start, width, res->size);	/* XXX AJR */
			curmem++;
			if (!starteddeps)
				depmem = curmem;
			break;
		}
	case ANSIstr_TAG:
		{
			printf("# %sANSI string -->", indep);
			/* Remember the device name */
			if(devstring)
				free(devstring);
			devstring = (char *)malloc(len + 1);
			if(!devstring)
			{
				fprintf(stderr, "Out of memory to store board device string\n");
				exit(1);
			}
			for (i = 0; i < len; i++)
				devstring[i] = res->data[i];
			devstring[i] = 0;
			printf("%s<--\n", devstring);
			break;
		}
	case UNICODEstr_TAG:
		{
			printf("# %sUNICODE string -->", indep);
			/* Remember the device name */
			if(devstring)
				free(devstring);
			devstring = (char *)malloc(len + 1);
			if(!devstring)
			{
				fprintf(stderr, "Out of memory to store board device string\n");
				exit(1);
			}
			for (i = 0; i < len; i++)
				putchar(devstring[i] = res->data[i]);
			devstring[i] = 0;
			printf("<--\n");
			break;
		}
	case VendorShort_TAG:
	case VendorLong_TAG:
		{
			printf("# %sVendor defined tag: ", indep);
			printf(" %02x", res->tag);
			for (i = 0; i < len; i++)
				printf(" %02x", res->data[i]);
			putchar('\n');
			break;
		}
	case End_TAG:
		{
			char *indep = "";
			if (nestdepth)
			{
				/* If we have a device name, show it (the last description string before the END DF flag is it) */
				if (serialno == 0xffffffffUL)
					printf(" (NAME \"%s/-1[%d]", devid, logdevno-1);
				else
					printf(" (NAME \"%s/%lu[%d]", devid, serialno, logdevno-1);
				if(devstring)
					printf("{%-20s}", devstring);
				printf("\")\n");
				printf("%s (ACT Y)\n", comment_if_not_selected);
				while (nestdepth)
				{
					printf(")");
					nestdepth--;
				}
				printf("\n");
			}
			/* Cancel any device names */
			if(devstring)
				free(devstring);
			devstring = 0;
			printf("# %sEnd tag... Checksum 0x%02x (%s)\n\n", indep, csum, (csum % 256) ? "BAD" : "OK");
			break;
		}
	case Mem32Range_TAG:
	case FixedMem32Range_TAG:
		{
			if (len != 17)
			{
				lengtherror(len, "Mem32Range_TAG or FixedMem32Range_TAG");
				BREAKORCONTINUE;
			}
			printf("# %s32-bit MemRange tag %02x ...\n", indep, type);
			break;
		}
	default:
		{
			printf("# %sUnknown tag %02x ...\n", indep, type);
			BREAKORCONTINUE;
		}
	}
	return;
#ifdef ABORT_ONRESERR
  oncorruptresourcedata:
	printf("# Resource data dump aborted\n");
	exit(1);
#endif
}


#endif /* WANT_TO_COMPILE_TRASH */


/* End of demo.c */
