// $Date: 2013-03-18 17:43:10 -0400 (Mon, 18 Mar 2013) $ 
// $Revision: 15160 $
// $Author: gforney $

// svn revision character string
char assert_revision[]="$Revision: 15160 $";

#include "options.h"
#include <stdio.h>
#include <stdlib.h>

void _Assert(char *filename, unsigned linenumber){
  /*! \fn void _Assert(char *filename, unsigned linenumber)
      \brief displays the filename and line number if an assert is thrown
  */
  int dummy;
#ifdef _DEBUG
  float x=0.0, y;
#endif

  fflush(NULL);
  fprintf(stderr, "\n*** Error: Assertion failed: %s, line %u\n",filename, linenumber);
  fflush(stderr);
#ifdef _DEBUG
   y=1.0/x;
   fprintf(stderr,"y=%f\n",y);
#endif
   fprintf(stderr,"enter 1 to continue\n");
   scanf("%i",&dummy);
   abort();
}

