
%{
#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#ifdef HAVE_GETOPT_LONG
#include <getopt.h>
#else
/* If not in library, use our own version */
#include "getopt.h"
#endif

#ifdef HAVE_UNISTD_H
#include <unistd.h>
#endif
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include <stdarg.h>
#include <time.h>
#include <isapnp/release.h>
#include <isapnp/errenum.h>
#ifdef HAVE_SFN
#include <isapnp/callback.h>
#include <isapnp/res_acce.h>
#else
#include <isapnp/callbacks.h>
#include <isapnp/res-access.h>
#endif
#include <isapnp/resource.h>

/*
 * Define this if you always want board configuration output
 * (normally you add the (NAME "..") keyword before (ACT .)
 *
 */
/* #define ALWAYSREPORTACTIVATION */

#undef RELEASE_ALWAYSREPACT
#ifdef ALWAYSREPORTACTIVATION
#define RELEASE_ALWAYSREPACT " -DALWAYSREPORTACTIVATION"
#else
#define RELEASE_ALWAYSREPACT ""
#endif

#include <isapnp/iopl.h>
#include <isapnp/pnp.h>

static char rcsid[] = "$Id: isapnp_main.l,v 1.27 2007/03/09 20:06:09 fox Exp $";

#ifdef REALTIME
#include <isapnp/realtime.h>
static long l_realtime_timeout = 5L;
#else
#define delaynus(x) usleep(x)
#endif /* REALTIME */

static int ignorecrc = 0;
static int debug = 0; /* debugging information (independent of verbosity) */

/*
 * verbosity: The higher, the more gets printed
 * 0 - absolutely nothing
 * 1 - PEEKs
 * 2 - configuration confirmation on ACT
 * 3 - board identification on IDENTIFY
 */
static int verbosity = 3;

static char *filename; /* For error reports */
static int linenumber = 1; /* For error reports */
static int sent_key = 0;
static char * identifyformat = "Board %b has Identity %8 %7 %6 %5 %4 %3 %2 %1 %0:  %v Serial No %s [checksum %8]\n";

/*
 * The scanner produces a list of actions, in the form of a function
 * pointer and a string argument
 */
typedef struct action
{
	int (*fn)(char *);
	char *name;
	char *arg;
	int linenum;
	int jumponerror;
} ACTION, *ACTIONPTR;

#define ADDACTIONS 100

static ACTION *actions = (ACTION *)0;
static int maxactions = 0;
static int nextaction = 0;
static int configureaction = 0; /* Backwards reference to skip missing boards */

static int parseerror = 0;

#ifndef HAVE_STRNCASECMP
static int strncasecmp(char *str1, char *str2, unsigned length)
{
  char *buffer1, *buffer2;
  int  counter, return_value;

  /* Allocate space for temp buffer */
  if((buffer1 = malloc(strlen(str1)+1)) == (char *)0) {
    perror("Allocating spare memory");
    exit(1);
  }
  else {
    (void)strcpy(buffer1, str1);
  }
  if((buffer2 = malloc(strlen(str2)+1)) == (char *)0) {
    perror("Allocating spare memory");
    exit(1);
  }
  else {
    (void)strcpy(buffer2, str2);
  }

  /* Decase letters to lower case */
  for(counter = 0 ; counter < strlen(str1) ; counter++)
    if(str1[counter] >= 'a')
      buffer1[counter] = (char)('A' + (str1[counter]-'a'));
  for(counter = 0 ; counter < strlen(str2) ; counter++)
    if(str2[counter] >= 'a')
      buffer2[counter] = (char)('A' + (str2[counter]-'a'));

  /* Now calculate the return value */
  return_value = strncmp(str1, str2, length);

  /* Free up the space */
  (void)free(str1);
  (void)free(str2);

  /* Now give the return value */
  return(return_value);
}
#endif /* !HAVE_STRNCASECMP */

#ifdef _OS2_
void *yy_flex_alloc(int size) 
{
  void *ptr;

  /* Allocate the space */
  if((ptr = malloc(size)) == (void *)0) {
    perror("Allocating Flex Buffer");
    exit(1);
  }

  /* Return the pointer */
  return(ptr);
}
void *yy_flex_realloc(void *ptr, int size)
{
  void *nptr;

  /* Reallocate space */
  if((nptr = realloc(ptr, size)) == (void *)0) {
    perror("ReAllocating Flex Buffer");
    exit(1);
  }

  /* Return the new pointer */
  return(nptr);
}
void yy_flex_free(void *ptr){(void)free(ptr);}
#endif /* _OS2_ */

static char *keyword = 0;

#define IORESCHECK (-1)
#define NOARG (-2)

static void
Warning(const char *str,...)
{
	va_list ap;
	fprintf(stderr, "%s:%d -- Warning - ", filename, linenumber);
	va_start(ap, str);
	vfprintf(stderr, str, ap);
	va_end(ap);
	fputc('\n', stderr);
}

/* Print Fatal of Warning message according to the flag, and return the flag */
static int
WarningOrFatal(int flag, const char *str,...)
{
	va_list ap;
	if(flag)
		fprintf(stderr, "%s:%d -- Fatal - ", filename, linenumber);
	else
		fprintf(stderr, "%s:%d -- Warning - ", filename, linenumber);
	va_start(ap, str);
	vfprintf(stderr, str, ap);
	va_end(ap);
	fputc('\n', stderr);
	return flag;
}

static void
banner(FILE *fp)
{
	fprintf(fp, 
			"%s\n"
			"Release %s\n"
			"\n"
			"This is free software, see the sources for details.\n"
			"This software has NO WARRANTY, use at your OWN RISK\n"
			"\n"
			"For details of the configuration file format, see isapnp.conf(5)\n"
			"For explanations of error messages, see isapnp(8)\n"
			"\n"
			"For latest information and FAQ on isapnp and pnpdump see:\n"
			"http://www.roestock.demon.co.uk/isapnptools/\n"
			"\n"
			"Compiler flags: %s%s\n"
			"\n",
			rcsid,
			libtoolsver,
			libcompilerflags,
			RELEASE_ALWAYSREPACT
		);
}

static void 
usage(char *program_name)
{
	banner(stderr);
	fprintf(stderr,
			"Usage: %s [OPTIONS] configfile\n\n"
			"   -h, --help            show a help summary to stderr\n"
#ifdef REALTIME
			" -t t, --max-realtime=t  maximum real-time priority execution is t seconds\n"
#endif
			"   -v, --version         print the isapnptools version number on stderr\n"
			"\n"
			"   configfile            contains the instructions to configure the boards,\n"
			"                         use - for stdin, see isapnp.conf(5)\n"
			, program_name);
	exit(0);
}

static void
getkeyword(int len)
{
	/* If the keyword wasn't used, free it */
	if(keyword)
		free(keyword);
	/* Save the keyword for errors, could have no gap to argument, if included */
	keyword = (char *)malloc(len + (size_t)1);
	strncpy(keyword, yytext, len);
	keyword[len] = 0;
}

static int
addaction(int (*fn)(char*), int skip)
{
	char *sptr = yytext+skip;
	/* Make sure there is some room */
	if(nextaction == maxactions)
	{
		maxactions += ADDACTIONS;
		actions = (ACTION *)realloc((void *)actions, sizeof(ACTION) * maxactions);
		if(!actions)
		{
			/* This is, like, fatal */
			fprintf(stderr, "%s:%d -- Fatal - Unable to allocate memory for action list processing\n", filename, linenumber);
			parseerror = 1;
			return 0;
		}
	}
	actions[nextaction].fn = fn;
	/* Jumponerror means have method to recover execution flow */
	actions[nextaction].jumponerror = 0;
	if(skip == IORESCHECK)
	{
		actions[nextaction].name = "<IORESCHECK>";
		actions[nextaction].arg = "";
		/* Save linenumber, even though we don't know what it is of ! */
		actions[nextaction].linenum = linenumber;
	}
	else
	{
		if(skip > 0)
			getkeyword(skip);
		/* Save the action name for errors, and show we've taken it */
		if(keyword)
		{
			actions[nextaction].name = keyword;
			keyword = 0;
		}
		else
			actions[nextaction].name = "";
		/* Save linenumber of keyword */
		actions[nextaction].linenum = linenumber;
		if(skip != NOARG)
		{
			/* Skip leading whitespace to argument, counting lines */
			while((*sptr) && isspace(*sptr))
			{
				if(*sptr == '\n')
					linenumber++;
				sptr++;
			}
			/* Now store a copy for the action word to process */
			if(*sptr)
				actions[nextaction].arg = strdup(sptr);
			else
				actions[nextaction].arg = "";
		}
		else
			actions[nextaction].arg = "";
	}
	nextaction++;
	return 1;
}

static int
IgnoreCRC(char *s)
{
	ignorecrc = 1;
	return 0;
}

static int
Read_Port(char *s)
{
	/* Read decimal or hex number */
	read_port = (int)strtol(s, (char**)NULL, 0);
	if((read_port < MIN_READ_ADDR)||(read_port > MAX_READ_ADDR))
	{
		fprintf(stderr, "Port address %s (0x%04x) out of range 0x203..0x3ff\n", s, read_port);
		return 1;
	}
	read_port |= 3;
	if(!allocate_resource(IOport_TAG, read_port, 1, "READPORT"))
	{
		fprintf(stderr, "Read port 0x%04X cannot be allocated - resource conflict (see %s)\n", read_port, conflict_source);
		return 1;
	}
	return 0;
}

static int
checkreadport(void)
{
	if(!read_port)
	{
		fprintf(stderr, "READPORT not set\n");
		return(1);
	}
	return(0);
}

static int
SetVerbosity(char *s)
{
	/* Read decimal or hex number */
	verbosity = (int)strtol(s, (char**)NULL, 0);
	return 0;
}

unsigned char serial_identifier[NUM_CARDS+1][IDENT_LEN];
static char *boardid[NUM_CARDS+1];
static unsigned long serno[NUM_CARDS+1];

static int do_isapnp_isolate(void);
static char * devidstr(unsigned char, unsigned char, unsigned char, unsigned char);
static char * sernostr(unsigned long serno);

static char initdata[INIT_LENGTH] = INITDATA;

static void
send_key(void)
{
	int i;
	CONFIGCONTROL;
	WRITE_DATA(CONFIG_WAIT_FOR_KEY);
	ADDRESS(0);
	ADDRESS(0);
	for(i = 0; i < INIT_LENGTH; i++)
		ADDRESS(initdata[i]);
	delaynus(2000L);
	sent_key = 1;
}

static int
Isolate(char *s)
{
	int i;

	send_key();
	/* Reset the cards */
	CONFIGCONTROL;
	if(toupper(*s) == 'C') /* CLEAR */
		WRITE_DATA(CONFIG_RESET_DRV);
	else /* PRESERVE */
		WRITE_DATA(CONFIG_RESET_CSN | CONFIG_WAIT_FOR_KEY);
	delaynus(2000L);
	/* Send the key again */
	send_key();
	if(boards_found)
	{
		Warning("ISOLATE called twice, or after CSN - clearing board count");
		boards_found = 0;
	}
	/* All cards now isolated, read the first one */
	if(read_port) /* Port specified */
	{
		do_isapnp_isolate();
	}
	else
	{
		for(read_port = START_READ_ADDR; read_port <= MAX_READ_ADDR; read_port += READ_ADDR_STEP)
		{
			if(debug)
				printf("Trying port address %04x\n", read_port);
			if(!allocate_resource(IOport_TAG, read_port, 1, "READPORT"))
			{
				fprintf(stderr, "Read port %04X cannot be allocated - resource conflict (see %s)\n", read_port, conflict_source);
				continue;
			}
			if(do_isapnp_isolate())
				break;
			/* Failed, so release the resource */
			deallocate_resource(IOport_TAG, read_port, 1);
			/*
			 * There is an argument that says don't release the resource in that
			 * there is obviously something there which is enabled, but we might
			 * be expecting it to be there as we want to read its settings.
			 */
			/* Reset the cards */
			CONFIGCONTROL;
			WRITE_DATA(CONFIG_RESET_DRV);
			delaynus(2000L);
			/* Send the key again */
			send_key();
		}
	}
	if(!boards_found)
		return 1; /* Error */
	if(debug)
	{
		printf("Board %d has serial identifier", boards_found);
		for(i = IDENT_LEN; i-- ; )
			printf(" %02x", serial_identifier[boards_found][i]);
		printf(" (%s/%s)\n", boardid[boards_found], sernostr(serno[boards_found]));
	}
	while(do_isapnp_isolate())
	{
		if(debug)
		{
			printf("Board %d has serial identifier", boards_found);
			for(i = IDENT_LEN; i--; )
				printf(" %02x", serial_identifier[boards_found][i]);
			printf(" (%s/%s)\n", boardid[boards_found], sernostr(serno[boards_found]));
		}
	}
	return 0;
}

static int
do_isapnp_isolate(void)
{
	int csum;
	int i;
	int index;
	int newbit;
	int goodaddress = 0;
	int nextboard = boards_found + 1;
	unsigned char c1, c2;
	csum = 0x6a;
	Wake(0);
	SetRdPort(read_port);
	delaynus(1000L);
	SERIALISOLATION;
	delaynus(1000L);
	for(index = 0; index < IDENT_LEN - 1; index++)
	{
		for(i = 0; i < 8; i++)
		{
			newbit = 0x00;
			/* Two reads per identifier bit */
			delaynus(250L);
			c1 = READ_DATA;
			delaynus(250L);
			c2 = READ_DATA;
			if(c1 == 0x55)
			{
				if(c2 == 0xAA)
				{
					goodaddress = 1;
					newbit = 0x80;
				}
				else
				{
					goodaddress = 0;
				}
			}
			serial_identifier[nextboard][index] >>= 1;
			serial_identifier[nextboard][index] |= newbit;
			/* Update checksum */
			if(((csum >> 1) ^ csum) & 1)
				newbit ^= 0x80;
			csum >>= 1;
			csum |= newbit;
		}
		/*
		printf("%02x ", serial_identifier[nextboard][index]);
		*/
	}
	/*
	printf("csum is %02x\n", csum);
	*/
	for(i = 0; i < 8; i++)
	{
		newbit = 0x00;
		/* Two reads per identifier bit */
		delaynus(250L);
		c1 = READ_DATA;
		delaynus(250L);
		c2 = READ_DATA;
		if(c1 == 0x55)
		{
			if(c2 == 0xAA)
			{
				goodaddress = 1;
				newbit = 0x80;
			}
		}
		serial_identifier[nextboard][index] >>= 1;
		serial_identifier[nextboard][index] |= newbit;
	}
	if(goodaddress && (ignorecrc || (serial_identifier[nextboard][8] == csum)))
	{
		boardid[nextboard] = strdup(devidstr(serial_identifier[nextboard][0],
				serial_identifier[nextboard][1], serial_identifier[nextboard][2],
				serial_identifier[nextboard][3])); 
		serno[nextboard] = serial_identifier[nextboard][7] << 24;
		serno[nextboard] |= serial_identifier[nextboard][6] << 16;
		serno[nextboard] |= serial_identifier[nextboard][5] << 8;
		serno[nextboard] |= serial_identifier[nextboard][4];
		boards_found = nextboard;
		CARDSELECTNUMBER;
		WRITE_DATA(nextboard);
		return(1);
	}
	/*
	else
	{
		printf("csum = %02x\n", csum);
	}
	*/
	return(0);
}

static char *
devidstr(unsigned char d1, unsigned char d2, unsigned char d3, unsigned char d4)
{
	static char resstr[] = "PNP0000";
	if(d1 & 0x80)
		return("-------");
	sprintf(resstr, "%c%c%c%x%x%x%x", 'A' + (d1 >> 2) - 1, 'A' + (((d1 & 3) << 3) | (d2 >> 5)) - 1,
	       'A' + (d2 & 0x1f) - 1, d3 >> 4, d3 & 0x0f, d4 >> 4, d4 & 0x0f);
	return resstr;
}

static char *
sernostr(unsigned long serno)
{
	static char serstr[] = "4294967294"; /* 2^32 - 2 is the max possible */
	if(serno == 0xffffffffUL)
		return "-1";
	sprintf(serstr, "%lu", serno);
	return serstr;
}

static int
ident(int csn)
{
	int i;
	unsigned char id[IDENT_LEN];
	char *fptr;
	if((csn < 1)||(csn > boards_found))
		return(1);
	fflush(stdout);
	if(checkreadport())
		return(1);
	Wake(csn);
	delaynus(250L);
	for(i = 0; i < IDENT_LEN; i++)
	{
		if(statuswait())
			return(1);
		id[i] = RESOURCEDATA;
	}
	strcpy(boardid[csn],devidstr(id[0],id[1],id[2],id[3]));
	serno[csn] = (unsigned long) id[4] + (id[5] << 8) +  (id[6] << 16) + (id[7] << 24);
	/* Display result according to format string */
	if(verbosity >= 3)
	{
		for(fptr = identifyformat; *fptr; fptr++)
		{
			switch(*fptr)
			{
			case '%':
			{
				fptr++;
				switch(*fptr)
				{
				case 'b': /* Board */ printf("%d", csn); break;
				case 'v': /* Vendor Id */ printf("%s", boardid[csn]); break;
				case 's': /* Serial number */ printf("%s", sernostr(serno[csn])); break;
				default:
					if(((i = *fptr - '0') >= 0)&&(i < 9))
						printf("%02x", id[i]);
					else
						putchar(*fptr);
					break;
				}
				break;
			}
			case '\\':
			{
				fptr++;
				switch(*fptr)
				{
				case 't': putchar('\t'); break;
				case 'n': putchar('\n'); break;
				default:  putchar(*fptr); break;
				}
				break;
			}
			default:
				putchar(*fptr);
				break;
			}
		}
		fflush(stdout);
	}
	return(0);
}

static int
Identify(char *s)
{
	int err = 0;
	int csn;
	if(*s == '*')
	{
		for(csn = 1; (!err) && (csn <= boards_found); csn++)
			err |= ident(csn);
	}
	else
	{
		csn = (int)strtol(s, (char**)NULL, 0);
		err = ident(csn);
	}
	return err;
}

static int
IdentifyFormat(char *s)
{
	identifyformat = strdup(s+1);                 /* Flex rule guarantees this removes leading " */
	identifyformat[strlen(identifyformat)-1] = 0; /* Flex rule guarantees this removes trailing " */
	return 0;
}

static int
WaitForKey(char *s)
{
	CONFIGCONTROL;
	WRITE_DATA(CONFIG_WAIT_FOR_KEY);
	return 0;
}

static int csn;

static int
SelectCSN(char *s)
{
	if(!sent_key)
		send_key();
	csn = (unsigned int)strtol(s, (char**)NULL, 0);
	/* Check it's sensible, and we won't have array problems */
	if((csn < 1)||(csn > NUM_CARDS))
		return 1;
	if(csn > boards_found)
	{
		for(boards_found++; csn >= boards_found; boards_found++)
			boardid[boards_found] = strdup("-------");
		boards_found = csn;
	}
	if(checkreadport())
		return(1);
	Wake(csn);
	return 0;
}

static int
SelectIdent(char *s)
{
	unsigned long sn;
	if(s[8] == '#')
	{
		/* Specify nth card, rather than serial number */
		sn = (unsigned int)strtol(s+9, (char**)NULL, 0);
		for(csn = 1; csn <= boards_found; csn++)
			if((strncasecmp(s, boardid[csn], 7) == 0)&&(!(--sn)))
				break;
	}
	else
	{
		if(s[8] == '-') /* For the special case -1 */
			sn = (unsigned long)strtol(s+8, (char**)NULL, 0);
		else
			sn = strtoul(s+8, (char**)NULL, 0);
		for(csn = 1; csn <= boards_found; csn++)
			if((serno[csn] == sn)&&(strncasecmp(s, boardid[csn], 7) == 0))
				break;
	}
	if((csn < 1)||(csn > boards_found))
	{
		if(verbosity >= 3)
			printf("Board %s not found - skipping\n", s);
		return(1);
	}
	if(debug)
		printf("Found board %s as Card Select Number %d\n", s, csn);
	if(checkreadport())
		return(1);
	Wake(csn);
	return 0;
}

/*
 * Misc global register setting
 */

static int verifyld = 1;
static int LogDev;
static char *LDName = (char *)0;

#ifdef ALWAYSREPORTACTIVATION
#define DEFNAMELEN (7+1+10+5+1) /* Vendor/Serno[LD] */
static char LDdefname[DEFNAMELEN];
#endif

/* Store logical device settings for confirmation printout */
#define NOOFIODESCS 8
#define IONOTASSIGNED -1
static int LDios[NOOFIODESCS];
#define NOOFINTDESCS 2
#define INTNOTASSIGNED 0
static int LDints[NOOFINTDESCS];
#define NOOFDMADESCS 2
#define DMANOTASSIGNED 4
static int LDdmas[NOOFDMADESCS];

static int
SetLogicalDevice(char *s)
{
	int retval;
	int i;
	LogDev = (int)strtol(s, (char**)NULL, 0);
	LOGICALDEVICENUMBER;
	WRITE_DATA(LogDev);
#ifdef ALWAYSREPORTACTIVATION
	sprintf(LDdefname, "%s/%s[%d]", boardid[csn], sernostr(serno[csn]), LogDev);
	LDName = LDdefname;
#else
	LDName = 0;
#endif
	for(i = 0; i < NOOFIODESCS; i++)
		LDios[i] = IONOTASSIGNED;
	for(i = 0; i < NOOFINTDESCS; i++)
		LDints[i] = INTNOTASSIGNED;
	for(i = 0; i < NOOFDMADESCS; i++)
		LDdmas[i] = DMANOTASSIGNED;
	retval = (verifyld)&&(READ_DATA != LogDev);
	if(retval)
		fprintf(stderr, "LD setting verify failed, this may not be a problem\n"
			"Try adding (VERIFYLD N) to the top of your script\n");
	return retval;
}

static int
VerifyLD(char *s)
{
	while((*s)&&(isspace(*s)))
		s++;
	if((*s)&&(toupper(*s) == 'N'))
		verifyld = 0;
	else
		verifyld = 1;
	return 0;
}

static int
SetLDName(char *s)
{
	char *d;
	while((*s)&&(isspace(*s)))
		s++;
	if(*s == '"')
		s++;
	LDName = d = s;
	/* Process string removing escapes */
	while((*s)&&(*s != '"'))
	{
		if(*s == '\\')
		{
			s++;
			switch(*s)
			{
			case 0: break;
			case 'n': *d++ = '\n'; break;
			case 't': *d++ = '\t'; break;
			case 'f': *d++ = '\f'; break;
			case 'a': *d++ = '\a'; break;
			default:  *d++ = *s;   break;
			}
			s++;
			continue;
		}
		*d++ = *s++;
	}
	*d = 0;
	return 0;
}

/*
 * Register address, etc, for peek and poke
 */
#define MAXNAMELEN 16
#define MAXREGSIZE 8 /* MemReg */

static int Reg = 0;
static int RegSize = 0;
static char RegName[MAXNAMELEN] = {0};

static int
Activate(char *s)
{
	ACTIVATE;
	if(toupper(*s) == 'Y')
		WRITE_DATA(1);
	else
		WRITE_DATA(0);
	if((verbosity >= 2)&&(LDName))
	{
		int ios = 0;
		int i;
		printf("%s:", LDName);
		for(i = 0; i < NOOFIODESCS; i++)
			if(LDios[i] != IONOTASSIGNED)
				ios++;
		if(ios)
		{
			printf(" Port%s", ios > 1 ? "s" : "");
			for(i = 0; i < NOOFIODESCS; i++)
				if(LDios[i] != IONOTASSIGNED)
					printf(" 0x%X", LDios[i]);
			putchar(';');
		}
		for(i = 0; i < NOOFINTDESCS; i++)
			if(LDints[i] != INTNOTASSIGNED)
				printf(" IRQ%d", LDints[i]);
		for(i = 0; i < NOOFDMADESCS; i++)
			if(LDdmas[i] != DMANOTASSIGNED)
				printf(" DMA%d", LDdmas[i]);
		printf(" --- %s\n", toupper(*s) == 'Y' ? "Enabled OK" : "Disabled");
		fflush(stdout);
	}
	return 0;
}

static int
SelectAct(char *s)
{
	Reg = 0x30;
	RegSize = 1;
	strcpy(RegName, "ACT  ");
	return 0;
}

/*
 * Interrupt resource setting
 */

static int INTReg = 0;
static int IRQConflictIsFatal = 0;

static int
SelectINTReg(char *s)
{
	int n;
	n = (int)strtol(s, (char**)NULL, 0);
	if((n < 0)||(n >= NOOFINTDESCS))
		return 1;
	INTReg = n;
	Reg = 0x70 + (n << 1);
	RegSize = 2;
	strcpy(RegName, "INT 0");
	RegName[4] = n + '0';
	return 0;
}

static int
SetIRQLine(char *s)
{
	int n;
	int retval = 0;
	n = (int)strtol(s, (char**)NULL, 0);
	if((n < 0)||(n > 15))
		return 1;
	if(n == 2)
	{
		Warning("IRQ2 is not a valid selection, changing it to IRQ9 (See clarifications 4.6.2)");
		n = 9;
	}
	if(!allocate_resource(IRQ_TAG, n, 1, filename))
		retval = WarningOrFatal(IRQConflictIsFatal, "resource conflict allocating IRQ%d (see %s)", n, conflict_source);
	ADDRESS(0x70 + (INTReg << 1));
	WRITE_DATA(n);
	LDints[INTReg] = n;
	return retval;
}

static int
SetIRQMode(char *s)
{
	int n = 0;
	if(*s++ == '+')
		n |= 2;
	if(toupper(*s) == 'L')
		n |= 1;
	ADDRESS(0x71 + (INTReg << 1));
	WRITE_DATA(n);
	return 0;
}

static int
SetIRQConflict(char *s)
{
	if(toupper(*s) == 'F')
		IRQConflictIsFatal = 1;
	else
		IRQConflictIsFatal = 0;
	return 0;
}

/*
 * I/O resource setting
 */

static int IOReg = 0;
static int IOSize = 0;
static int IOConflictIsFatal = 0;
static int IORangeCheck = 0;

static int
SelectIOReg(char *s)
{
	int n;
	n = (int)strtol(s, (char**)NULL, 0);
	if((n < 0)||(n >= NOOFIODESCS))
		return 1;
	IOReg = n;
	IOSize = 0; /* Need to know if user specifies a size */
	IORangeCheck = 0; /* Only do if user requests it */
	Reg = 0x60 + (n << 1);
	RegSize = 2;
	strcpy(RegName, "IO  0");
	RegName[4] = n + '0';
	return 0;
}

static int
SetIOBaseReg(char *s)
{
	unsigned long n;
	n = strtol(s, (char**)NULL, 0);
	if(n > 0xffff)
		return 1;
	ADDRESS(0x60 + (IOReg << 1));
	WRITE_DATA(((unsigned char)(n >> 8)));
	ADDRESS(0x61 + (IOReg << 1));
	WRITE_DATA(((unsigned char)(n & 0xff)));
	LDios[IOReg] = (int)n;
	return 0;
}

static int
SetIOSize(char *s)
{
	long n;
	n = strtol(s, (char**)NULL, 0);
	if((n < 0)||(n > 0xffff))
		return 1;
	IOSize = (int)n;
	return 0;
}

static int
IOCheck(char *s)
{
	/*
	 * Record fact that check requested, but don't do it
	 * unless we can get resources etc
	 */
	IORangeCheck = 1;
	return 0;
}

/*
 * Called after BASE and SIZE known
 */

static int
CheckIOResource(char *s)
{
	int IOBase = LDios[IOReg];
	int size = IOSize ? IOSize : 8; /* Think of a number for the size, if none given */
	int retval = 0;
	if((IOBase != IONOTASSIGNED) && !allocate_resource(IOport_TAG, IOBase, size, filename))
		retval = WarningOrFatal(IOConflictIsFatal, "resource conflict allocating %d bytes of IO at %X (see %s)", size, IOBase, conflict_source);
	if(IORangeCheck)
	{
		/* Check if device is activated */
		ADDRESS(0x30);
		if(READ_DATA)
			retval = WarningOrFatal(1, "IO range check attempted while device activated");
		else
		{
			int checkisbad = 0;
			int iop;
			int maxaddr = IOBase + size;
			/* This will only work if the device is not activated, but we've checked that */
			ADDRESS(0x31);
			WRITE_DATA(2);
			for(iop = IOBase; iop < maxaddr; iop++)
			{
				if(READ_IOPORT(iop) != 0xaa)
				{
					checkisbad = 1;
					break;
				}
			}
			if(!checkisbad)
			{
				WRITE_DATA(3);
				for(iop = IOBase; iop < maxaddr; iop++)
				{
					if(READ_IOPORT(iop) != 0x55)
					{
						checkisbad = 1;
						break;
					}
				}
			}
			WRITE_DATA(0);
			if(checkisbad)
				retval = WarningOrFatal(1, "IO range check failed for %d bytes of IO at %X", size, IOBase);
		}
	}
	return retval;
}

static int
SetIOConflict(char *s)
{
	if(toupper(*s) == 'F')
		IOConflictIsFatal = 1;
	else
		IOConflictIsFatal = 0;
	return 0;
}

/*
 * DMA resource setting
 */

static int DMAReg = 0;
static int DMAConflictIsFatal = 0;

static int
SelectDMAReg(char *s)
{
	int n;
	n = (int)strtol(s, (char**)NULL, 0);
	if((n < 0)||(n >= NOOFDMADESCS))
		return 1;
	DMAReg = n;
	Reg = 0x74 + n;
	RegSize = 1;
	strcpy(RegName, "DMA 0");
	RegName[4] = n + '0';
	return 0;
}

static int
SetDMAChannelReg(char *s)
{
	int n;
	int retval = 0;
	n = (int)strtol(s, (char**)NULL, 0);
	if((n < 0)||(n > 7))
		return 1;
	if(!allocate_resource(DMA_TAG, n, 1, filename))
		retval = WarningOrFatal(DMAConflictIsFatal, "resource conflict allocating DMA%d (see %s)", n, conflict_source);
	ADDRESS(0x74 + DMAReg);
	WRITE_DATA(n);
	LDdmas[DMAReg] = n;
	return retval;
}

static int
SetDMAConflict(char *s)
{
	if(toupper(*s) == 'F')
		DMAConflictIsFatal = 1;
	else
		DMAConflictIsFatal = 0;
	return 0;
}

/*
 * Memory resource setting stuff
 */

static int MemReg = 0;
static int MEMConflictIsFatal = 0;

static int
SelectMemReg(char *s)
{
	int n;
	n = (int)strtol(s, (char**)NULL, 0);
	if((n < 0)||(n > 3))
		return 1;
	MemReg = n;
	Reg = 0x40 + (n << 3);
	RegSize = 8;
	strcpy(RegName, "MEM 0");
	RegName[4] = n + '0';
	return 0;
}

static int
SetMemBaseReg(char *s)
{
	unsigned long n;
	int retval = 0;
	n = strtoul(s, (char**)NULL, 0);
	/* Specify as absolute address, check for bits not programable */
	if(n & 0xff0000ff)
		return 1;
	if(!allocate_resource(MemRange_TAG, n, 8192, filename)) /* Think of a number for the size */
		retval = WarningOrFatal(MEMConflictIsFatal, "resource conflict allocating Memory at %lX (see %s)", n, conflict_source);
	ADDRESS(0x40 + (MemReg << 3));
	WRITE_DATA(n >> 16);
	ADDRESS(0x41 + (MemReg << 3));
	WRITE_DATA((n >> 8) & 0xff);
	return retval;
}

/*
 * Modes [wb][ru]
 * w = 16 bit
 * b = 8 bit
 * r = upper is range length
 * u = upper is upper limit
 * Note that R/U is a read only bit, so verify
 */
static int
SetMemModeReg(char *s)
{
	int n = 0;
	if(toupper(*s) == 'W')
		n |= 2;
	s++;
	if(toupper(*s) == 'U')
		n |= 1;
	ADDRESS(0x42 + (MemReg << 3));
	WRITE_DATA(n);
	if((READ_DATA ^ n) & 3)	/* Verify */
		return 1;
	return 0;
}

static int
SetMemUpperReg(char *s)
{
	unsigned long n;
	n = strtoul(s, (char**)NULL, 0);
	/* Specify as absolute address, check for bits not programable */
	if(n & 0xff0000ff)
		return 1;
	ADDRESS(0x43 + (MemReg << 3));
	WRITE_DATA(n >> 16);
	ADDRESS(0x44 + (MemReg << 3));
	WRITE_DATA((n >> 8) & 0xff);
	return 0;
}

static int
SetMEMConflict(char *s)
{
	if(toupper(*s) == 'F')
		MEMConflictIsFatal = 1;
	else
		MEMConflictIsFatal = 0;
	return 0;
}

/*
 * General purpose logical device peek and poke
 */

static int
SelectReg(char *s)
{
	int n;
	n = (int)strtol(s, (char**)NULL, 0);
	if((n < 0)||(n > 0xff))
		return 1;
	Reg = n;
	RegSize = 1;
	strcpy(RegName, "-REG-");
	return 0;
}

static int
PokeReg(char *s)
{
	int n;
	n = (int)strtol(s, (char**)NULL, 0);
	/* Can only poke bytes */
	if(RegSize > 1)
	{
		fprintf(stderr, "Can only poke bytes\n");
		return(1);
	}
	if((n < 0)||(n > 0xff))
		return 1;
	ADDRESS(Reg);
	WRITE_DATA(n);
	return 0;
}

/*
 * Peek will work for named stuff too
 */
static int
PeekReg(char *s)
{
	int i;
	int data[MAXREGSIZE];
	ADDRESS(Reg);
	data[0] = READ_DATA;
	if(verbosity >= 1)
		printf("Peek(%s/%s)[%u][0x%02x](%s) is 0x%02X", boardid[csn], sernostr(serno[csn]), LogDev, Reg, RegName, data[0]);
	for(i = 1; i < RegSize; i++)
	{
		ADDRESS(Reg + i);
		data[i] = READ_DATA;
		if(verbosity >= 1)
			printf("%02X", data[i]);
	}
	printf(", (%d", data[0]);
	for(i = 1; i < RegSize; i++)
	{
		ADDRESS(Reg + i);
		if(verbosity >= 1)
			printf(",%d", data[i]);
	}
	if(verbosity >= 1)
		printf(")\n");
	return 0;
}

static void
printgot(void)
{
	if(debug) printf("Got %s\n", yytext);
}

#define ONDEBUG() if (debug) printgot()
#define ADDACTION(x, y) if(!addaction(x, y)) yyterminate()
%}

/*
# LD n      = Logical device, ie write to reg 7
# IO n      = IO descriptor n
# MEM n     = MEM descriptor n (24bit descriptors only for ISA)
# DMA n     = DMA descriptor n
# REG n     = Select register n
# POKE n    = Poke a value
# PEEK      = Read a value and print on stdout
# BASE n    = IO/Mem address n
# UPPER n   = Mem upper address/range n
# INT n     = Interrupt req n
# IRQ n     = Interrupt level n
# MODE      = IRQ line levels etc/Memory width etc
# CHANNEL n = DMA channel
# ACT       = Activate

(IGNORECRC)
(READPORT 0x207)
(ISOLATE3
(CSN 1 (LD 0 (REG 0x42 (POKE 0x00) (PEEK))))
(CONFIGURE DFX0000/1493 (LD 0 (REG 0x42 (POKE 0x00) (PEEK))))
(CONFIGURE DFX0000/1493 (LD 0 (MEM 0 (BASE 0x400000) (MODE wu) (UPPER 0x800000)) (DMA 0 (CHANNEL 1))))
(CONFIGURE DFX0000/1493 (LD 0 (IO 0 (BASE 0x3e8)) (INT 0 (IRQ 12 (MODE +E))) (ACT Y)))
(WAITFORKEY)
*/

%option noyywrap
%option nounput
%option caseless

DIGIT	[0-9]
HEXDIGIT	[0-9a-f]
ID		[@A-Z[\\^\]_]{3}{HEXDIGIT}{4}
STRING	["][^"]*["]

%s LEVEL1
%s LEVEL2
%s LEVEL3
%s LEVEL4ACT
%s LEVEL4IO
%s LEVEL4MEM
%s LEVEL4DMA
%s LEVEL4INT
%s LEVEL4REG
%s LEVEL5INT
%s NOMORE
%s NOMLEVEL3
%s CONFIG
%s LOGDEV
%s IOSET
%s MEMSET
%s DMASET
%s ACTSET
%s INTSET
%s REGSET
%s IRQSET
%s PEARSHAPED
%s CONFLICT
%s CONFLICT2
%s CONFLICT2RET

%%

<INITIAL>"("	BEGIN(LEVEL1);

<LEVEL1>")"		BEGIN(INITIAL);
<LEVEL1>"DEBUG"	BEGIN(NOMORE); debug = 1; banner(stdout); ONDEBUG();
<LEVEL1>"IGNORECRC"	BEGIN(NOMORE); ADDACTION(IgnoreCRC, 9); ONDEBUG();
<LEVEL1>"CONFLICT"  BEGIN(CONFLICT); ONDEBUG();
<LEVEL1>"VERIFYLD"([ \t\n]*[YyNn])?	BEGIN(NOMORE); ADDACTION(VerifyLD, 8); ONDEBUG();
<LEVEL1>"IDENTIFY-FORMAT"[ \t\n]*["]([^"]|[\\].)*["]	BEGIN(NOMORE); ADDACTION(IdentifyFormat, 15); ONDEBUG();
<LEVEL1>"READPORT"[ \t\n]*0x{HEXDIGIT}+ |
<LEVEL1>"READPORT"[ \t\n]*{DIGIT}+	{ BEGIN(NOMORE); ADDACTION(Read_Port, 8); ONDEBUG(); }
<LEVEL1>"VERBOSITY"[ \t\n]*0x{HEXDIGIT}+ |
<LEVEL1>"VERBOSITY"[ \t\n]*{DIGIT}+	{ BEGIN(NOMORE); ADDACTION(SetVerbosity, 9); ONDEBUG(); }
<LEVEL1>"IDENTIFY"[ \t\n]*\* |
<LEVEL1>"IDENTIFY"[ \t\n]*0x{HEXDIGIT}+ |
<LEVEL1>"IDENTIFY"[ \t\n]*{DIGIT}+	{ BEGIN(NOMORE); ADDACTION(Identify, 8); ONDEBUG(); }
<LEVEL1>"ISOLATE"([ \t\n]*(CLEAR|PRESERVE))?	BEGIN(NOMORE); ADDACTION(Isolate, 7); ONDEBUG();
<LEVEL1>"CONFIGURE"[ \t\n]*{ID}"/"[#-]?{DIGIT}+ 	BEGIN(CONFIG); configureaction = nextaction; ADDACTION(SelectIdent, 9); ONDEBUG();
<LEVEL1>"CSN"[ \t\n]*{DIGIT}+ 	BEGIN(CONFIG); configureaction = nextaction; ADDACTION(SelectCSN, 3); ONDEBUG();
<LEVEL1>"WAITFORKEY"	BEGIN(NOMORE); ADDACTION(WaitForKey, 10); ONDEBUG();

<NOMORE>")"		BEGIN(INITIAL);

<CONFLICT>")"	BEGIN(INITIAL);
<CONFLICT>"("	BEGIN(CONFLICT2);

<CONFLICT2>"IO"[ \t\n]*(FATAL|WARNING)	BEGIN(CONFLICT2RET); ADDACTION(SetIOConflict, 2); ONDEBUG();
<CONFLICT2>"IRQ"[ \t\n]*(FATAL|WARNING)	BEGIN(CONFLICT2RET); ADDACTION(SetIRQConflict, 3); ONDEBUG();
<CONFLICT2>"MEM"[ \t\n]*(FATAL|WARNING)	BEGIN(CONFLICT2RET); ADDACTION(SetMEMConflict, 3); ONDEBUG();
<CONFLICT2>"DMA"[ \t\n]*(FATAL|WARNING)	BEGIN(CONFLICT2RET); ADDACTION(SetDMAConflict, 3); ONDEBUG();

<CONFLICT2RET>")"	BEGIN(CONFLICT);

<CONFIG>")"		BEGIN(INITIAL); actions[configureaction].jumponerror = nextaction;
<CONFIG>"("		BEGIN(LEVEL2);

<LEVEL2>")"		BEGIN(CONFIG);
<LEVEL2>"LD"[ \t\n]*{DIGIT}+	BEGIN(LOGDEV); ADDACTION(SetLogicalDevice, 2); ONDEBUG();

<LOGDEV>")"		BEGIN(CONFIG);
<LOGDEV>"("		BEGIN(LEVEL3);

<LEVEL3>")"		BEGIN(LOGDEV);
<LEVEL3>"NAME"[ \t\n]*{STRING}	ADDACTION(SetLDName, 4); ONDEBUG();
<LEVEL3>"IO"	BEGIN(IOSET);  getkeyword(2); ONDEBUG();
<LEVEL3>"MEM"	BEGIN(MEMSET); getkeyword(3); ONDEBUG();
<LEVEL3>"DMA"	BEGIN(DMASET); getkeyword(3); ONDEBUG();
<LEVEL3>"INT"	BEGIN(INTSET); getkeyword(3); ONDEBUG();
<LEVEL3>"REG"	BEGIN(REGSET); getkeyword(3); ONDEBUG();
<LEVEL3>"ACT"	BEGIN(ACTSET); getkeyword(3); ONDEBUG();

<ACTSET>[YN]	BEGIN(NOMLEVEL3); ADDACTION(Activate, 0); ONDEBUG();
<ACTSET>"("		BEGIN(LEVEL4ACT); ADDACTION(SelectAct, NOARG);

<INTSET,MEMSET,DMASET,REGSET,ACTSET,NOMLEVEL3>")"		BEGIN(LOGDEV);

<IOSET>")"		ADDACTION(CheckIOResource, IORESCHECK); BEGIN(LOGDEV);
<IOSET>{DIGIT}+	ADDACTION(SelectIOReg, 0); ONDEBUG();
<IOSET>"("		BEGIN(LEVEL4IO);

<MEMSET>{DIGIT}+	ADDACTION(SelectMemReg, 0); ONDEBUG();
<MEMSET>"("		BEGIN(LEVEL4MEM);

<DMASET>{DIGIT}+	ADDACTION(SelectDMAReg, 0); ONDEBUG();
<DMASET>"("		BEGIN(LEVEL4DMA);

<INTSET>{DIGIT}+	ADDACTION(SelectINTReg, 0); ONDEBUG();
<INTSET>"("		BEGIN(LEVEL4INT);

<REGSET>0x{HEXDIGIT}+	|
<REGSET>{DIGIT}+	ADDACTION(SelectReg, 0); ONDEBUG();
<REGSET>"("		BEGIN(LEVEL4REG);

<LEVEL4ACT>")"		BEGIN(ACTSET);
<LEVEL4ACT>"PEEK"	ADDACTION(PeekReg, 4); ONDEBUG();

<LEVEL4IO>")"		BEGIN(IOSET);
<LEVEL4IO>"BASE"[ \t\n]*0x{HEXDIGIT}+	|
<LEVEL4IO>"BASE"[ \t\n]*{DIGIT}+	ADDACTION(SetIOBaseReg, 4); ONDEBUG();
<LEVEL4IO>"SIZE"[ \t\n]*0x{HEXDIGIT}+	|
<LEVEL4IO>"SIZE"[ \t\n]*{DIGIT}+	ADDACTION(SetIOSize, 4); ONDEBUG();
<LEVEL4IO>"PEEK"	ADDACTION(PeekReg, 4); ONDEBUG();
<LEVEL4IO>"CHECK"	ADDACTION(IOCheck, 5); ONDEBUG();

<LEVEL4MEM>")"		BEGIN(MEMSET);
<LEVEL4MEM>"BASE"[ \t\n]*0x{HEXDIGIT}+	|
<LEVEL4MEM>"BASE"[ \t\n]*{DIGIT}+	ADDACTION(SetMemBaseReg, 4); ONDEBUG();
<LEVEL4MEM>"UPPER"[ \t\n]*0x{HEXDIGIT}+	|
<LEVEL4MEM>"UPPER"[ \t\n]*{DIGIT}+	ADDACTION(SetMemUpperReg, 5); ONDEBUG();
<LEVEL4MEM>"MODE"[ \t\n]*[BW][RU]	ADDACTION(SetMemModeReg, 4); ONDEBUG();
<LEVEL4MEM>"PEEK"	ADDACTION(PeekReg, 4); ONDEBUG();

<LEVEL4DMA>")"		BEGIN(DMASET);
<LEVEL4DMA>"CHANNEL"[ \t\n]*{DIGIT}+	ADDACTION(SetDMAChannelReg, 7); ONDEBUG();
<LEVEL4DMA>"PEEK"	ADDACTION(PeekReg, 4); ONDEBUG();

<LEVEL4INT>")"		BEGIN(INTSET);
<LEVEL4INT>"IRQ"[ \t\n]*{DIGIT}+	BEGIN(IRQSET); ADDACTION(SetIRQLine, 3); ONDEBUG();
<LEVEL4INT>"PEEK"	ADDACTION(PeekReg, 4); ONDEBUG();

<LEVEL4REG>")"		BEGIN(REGSET);
<LEVEL4REG>"POKE"[ \t\n]*0x{HEXDIGIT}+	|
<LEVEL4REG>"POKE"[ \t\n]*{DIGIT}+	ADDACTION(PokeReg, 4); ONDEBUG();
<LEVEL4REG>"PEEK"	ADDACTION(PeekReg, 4); ONDEBUG();

<IRQSET>")"		BEGIN(INTSET);
<IRQSET>"("		BEGIN(LEVEL5INT);

<LEVEL5INT>")"		BEGIN(IRQSET);
<LEVEL5INT>"MODE"[ \t\n]*[+-][EL]	ADDACTION(SetIRQMode, 4); ONDEBUG();

"#"	{ /* Swallow comment to eol */ register int c; while(((c = input()) != '\n') && (c != EOF)) ; linenumber++; }
[ \t]*	/* Swallow whitespace */
[\n]	{ linenumber++; /* Count these */ }
.	BEGIN(PEARSHAPED); fprintf(stderr, "Don't know what to do with %s", yytext); parseerror = 1;

<PEARSHAPED>.*$	fprintf(stderr, "%s on or around line %d\n", yytext, linenumber); yyterminate();

%%

int
isapnp_main(int argc, char **argv)
{
	int i;
	char *program = argv[0];
	int retval;

	/* Process command line options */
	const struct option longopts[] =
	{
		{"help", no_argument, NULL, 'h'},
#ifdef REALTIME
		{"max-realtime", required_argument, NULL, 't'},
#endif
		{"version", no_argument, NULL, 'v'},
		{0, 0, 0, 0},
	};
	int opt;

	while ((opt = getopt_long(argc, argv, "t:vh", longopts, NULL)) != EOF)
	{
		switch (opt)
		{
		case 'h':
			usage(program);
			break;
#ifdef REALTIME
		case 't':
			l_realtime_timeout = atol(optarg);
			break;
#else
		case 't':
			fprintf(stderr, "Realtime support not compiled in - option ignored\n");
			break;
#endif
		case 'v':
			fprintf(stderr, "Version: isapnp from %s-%s\n", PACKAGE, VERSION);
			exit(0);
			break;
		case '?':
#if 1
			fprintf(stderr, "unrecognized option.\n");
#endif
			usage(program);
			return 1;
		case ':':
#if 1
			fprintf(stderr, "missing parameter.\n");
#endif
			usage(program);
			return 1;
		default:
			fprintf(stderr,
					"?? getopt returned character code 0x%x ('%c').\n",
					opt, opt);
			return 1;
		}

	}
	argc -= optind - 1;
	argv += optind - 1;

	if(argc != 2)
	{
		usage(program);
		exit(1);
	}

	/* Initialize callbacks */
	callbacks_init(normal_fatal_error_callback,
		       normal_non_fatal_error_callback,
		       null_progress_report_callback);

	read_port = 0;	/* Flag we haven't set it yet */

	/* Open configuration file: '-' is stdin */
	filename = argv[1];
	if(strcmp(filename, "-") != 0)
		yyin = fopen(filename, "r");
	else
		yyin = stdin;
	/* Check we have open configuration file before doing anything else */
	if(!yyin)
	{
		fprintf(stderr, "Unable to open configuration file '%s' - ", filename);
		perror("");
		exit(1);
	}
	if(acquire_pnp_io_privileges() != 0)
	{	
		perror("Unable to get io permission for WRITE_DATA");
		exit(1);
	}
	retval = 0;
	/* Read in resource allocations */
	alloc_system_resources();
	yylex();
	if(parseerror)
	{
		fprintf(stderr, "%s:%d -- Fatal - Error occurred parsing config file --- no action taken\n", filename, linenumber);
		retval = 1;
	}
	else
	{
#ifdef REALTIME
		setroundrobin(l_realtime_timeout);
#endif /* REALTIME */
		for(i = 0; i < nextaction; i++)
		{
			if(debug)
				printf("Executing %s %s\n", actions[i].name, actions[i].arg);
			linenumber = actions[i].linenum;
			if(actions[i].fn(actions[i].arg))
			{
				fflush(stdout); /* Make sure peeks etc output first */
				if(actions[i].jumponerror)
				{
					i = actions[i].jumponerror - 1; /* To compensate for the ++ */
					continue;
				}
				fprintf(stderr, "%s:%d -- Fatal - Error occurred executing request '%s %s' --- further action aborted\n", filename, linenumber, actions[i].name, actions[i].arg);
				retval = 1;
				break;
			}
		}
	}
	/* Release resources */
	if (relinquish_pnp_io_privileges() != 0) {
		perror("Unable to release io permission for WRITE_DATA");
		exit(1);
	}
	return retval;
}
