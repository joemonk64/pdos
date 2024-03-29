/*********************************************************************/
/*                                                                   */
/*  This Program Written by Paul Edwards.                            */
/*  Released to the Public Domain                                    */
/*                                                                   */
/*********************************************************************/
/*********************************************************************/
/*                                                                   */
/*  file - mini stdio implementation                                 */
/*                                                                   */
/*********************************************************************/

#include <stdio.h>

#include "fat.h"
#include "bos.h"
#include "lldos.h"
#include "unused.h"

static FATFILE fatfile;
extern FAT gfat;

FILE *fopen(const char *name, const char *mode)
{
    int rc;

    unused(mode);
    rc = fatOpenFile(&gfat, name, &fatfile);
    if (rc != 0) return (NULL);
    return ((FILE *)1);
}

int fclose(FILE *fp)
{
    unused(fp);
    return (0);
}

size_t fread(void *buf, size_t size, size_t nelem, FILE *fp)
{
    unsigned int readbytes;
    
    unused(size);
    unused(fp);
    fatReadFile(&gfat, &fatfile, buf, (unsigned int)nelem, &readbytes);
    return (readbytes);
}
