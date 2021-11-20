/*****************************************************************************
**
** demo2.c
*/
static char st_demo2_version[] __attribute__((unused)) = "$Id: demo2.c,v 0.2 2001/04/30 21:45:01 fox Exp $";
/*
** Demo of usage of the retrieve_device_ID() procedure.
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
#include <isapnp/pnp-access.h>

/* demo2.c can be built only under Linux. */

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
/* You don't need the following procedure in your code.  It merely
** prints the device ID in a more human-readable form.
*/

char *
devidstr(unsigned char d1, unsigned char d2,
	 unsigned char d3, unsigned char d4);

/****************************************************************************/
/* demo2 does not use any command line arguments.
** If you want to change its behavior, modify the constants in the
** initialization code of the l_interrog_args structure.
*/

int
main(int argc, char **argv)
{
  /* I/O to interrogate_isapnp */
  interrogate_args l_interrog_args;
  interrogate_results l_interrog_results;

  /* Miscellaneous variables */
  int l_ret;     /* Return code */

  /**************************************************************************/
  /* First thing to do - initialize the interrogate_args structure. */
  l_interrog_args.m_non_fatal_error_callback_p = NULL;
  l_interrog_args.m_progress_report_callback_p = NULL;
  l_interrog_args.m_numcards = -1;  /* autodetect */
  l_interrog_args.m_readport = -1;  /* autodetect */
  l_interrog_args.m_reset_flag = 0; /* Don't reset cards */
  l_interrog_args.m_ignore_csum_flag = 0; /* Take checksum into account */
#ifdef REALTIME
  l_interrog_args.m_realtime_timeout = 5L;
#endif
  l_interrog_args.m_debug_flag = 0; /* No debug mode */

  /**************************************************************************/
  /* The following prints identifying information about the program.
  ** You don't need it in your code.
  */
  printf("Demo2 program - demonstrating retrieve_device_ID()\n"
	 "                       Version %s\n"
	 "Compiled w/ compile-time flags %s\n\n",
	 libtoolsver, libcompilerflags);

  /**************************************************************************/
  /* This call initializes the libisapnp.
  ** l_interrog_results points at the ISA PnP resources array, and is needed
  ** by subsequent libisapnp procedure calls.
  */
  l_ret = interrogate_isapnp(&l_interrog_args, &l_interrog_results);
  if (0 != l_ret) {
    printf("*** Error %d while trying to interrogate the ISA PnP cards ***\n",
	   l_ret);
    exit(1);
  }

  /**************************************************************************/
  /* The following call implements the optimal configuration.
  ** Uncomment it if you want this.
  */

  /*
  **  int l_alloc_result;
  **  l_alloc_result = alloc_resources(l_interrog_results.m_resource_p,
  **				     l_interrog_results.m_resource_count,
  **			     NULL, 0);
  */

  /**************************************************************************/
  /* Now retrieve the device IDs of all found ISA cards. */
  {
    int l_number_of_cards;
    int l_current_card;
    char l_ID_str[5];

    l_ret = get_number_of_cards(&l_interrog_results, &l_number_of_cards);

    if (0 != l_ret) {
      printf("*** Error %d while trying to get No. of ISA PnP cards ***\n",
	     l_ret);
      exit(1);
    }

    /* Loop over all cards */
    for (l_current_card = 0;
	 l_current_card < l_number_of_cards; l_current_card++) {
      l_ret = retrieve_device_ID(&l_interrog_results,
				 l_current_card,
				 l_ID_str);
      if (0 != l_ret) {
	printf("*** Error %d while trying to retrieve device ID"
	       " of card %d ***\n", l_ret, l_current_card);
	exit(1);
      }

      /* Now print the ID string in two forms. */
      printf("Card %d:  ID string is 0x%02x %02x %02x %02x or \"%s\"\n",
	     l_current_card,
	     l_ID_str[0] & 0x00ff, l_ID_str[1] & 0x00ff,
	     l_ID_str[2] & 0x00ff, l_ID_str[3] & 0x00ff,
	     devidstr(l_ID_str[0], l_ID_str[1], l_ID_str[2], l_ID_str[3]));
    }
  }

  /**************************************************************************/
  printf("\n - - - - DONE! - - - -\n");

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


/* End of demo2.c */
