/*********************************************************************/
/*                                                                   */
/*  This Program Written by Paul Edwards.                            */
/*  Released to the Public Domain                                    */
/*                                                                   */
/*********************************************************************/
/*********************************************************************/
/*                                                                   */
/*  doscalls - minimal implementation of OS/2 under PDOS/386         */
/*                                                                   */
/*********************************************************************/

/* note that we don't need a separate table of OS/2 handles
   to file pointers - we rely on the handles less than 3 being
   standard and not clashing with file pointers and then the
   rest are equated. We should possibly create an initialization
   function, similar to initlinux, so that we can more easily
   index into a table containing just stdin, stdout and stderr,
   but for now we'll just code that every time */

/* add special handle 3 for opening of KBD$ */

#define INCL_KBD
#include <os2.h>

#include <stdio.h>
#include <stdlib.h>

#include <pos.h>

ULONG APIENTRY DosWrite(ULONG hfile, void *ptr,
                         ULONG towrite, ULONG *tempWritten)
{
    FILE *f;

    if (hfile == 0) f = stdin;
    else if (hfile == 1) f = stdout;
    else if (hfile == 2) f = stderr;
    else f = (FILE *)hfile;

    *tempWritten = fwrite(ptr, 1, towrite, f);
    fflush(f);
    return (0);
}

void APIENTRY DosExit(int a, int b)
{
    /* I believe the reason you need terminate instead of exit is
       because exit would be calling PDOS's exit to exit, but that
       is not appropriate because the OS/2 executable has its own
       start and exit - and it has already been through that. And
       it is not appropriate for the OS, ie PDOS, to be exiting */
    /* However we currently don't have PosTerminate defined for
       PDOS-generic so we can't use that unless we define it. This
       is currently kludged as a workaround - ie call exit instead -
       which is the correct thing to do for PDOS-generic anyway */
    /* It is probably PDOS/386 that needs to change - exit() should
       indeed be called in both cases. However, it will need start()
       to be called first - probably in the same way that PDOS-generic
       does it. ie detect a "standalone" variable and call start()
       ourselves. That will require a change to start to allow a
       different calling convention to "genmain". We could support
       multiple calling conventions for different environments
       potentially. But in the short term we only need the PDOS-generic
       calling convention. But in the immediate term no change is
       being made to start(). When start() is updated, it should
       probably do a check in exit() to see if there is a deeper
       runnum than currently being closed, because that points to
       an integrity error - start hasn't been called one way or
       another. Also we probably want an option in start to print
       file leaks. Note that if we have a file leak currently, it
       is likely that PDOS/386 will free the memory associated with
       that file, but the file isn't actually closed. And without
       the runnum being incremented any file leak in an OS/2 program
       will presumably be associated with the command.exe - so that is
       where the file will be closed. But the attempt to free the
       associated memory - again - could cause an issue. Note that
       it PDOS/386 doing a free by memid that would have freed the
       memory. Before returning to command.exe. Also note that file
       leaks are actually allowed by C90. And we can probably meet
       that requirement rather than insisting on a stricter version
       of C90. */
#ifdef W32EMUL
    exit(b);
#else
    PosTerminate(b);
#endif
}

ULONG APIENTRY DosOpen(char *fnm, ULONG *handle, ULONG *action1,
               ULONG newsize, ULONG fileattr, ULONG action2,
               ULONG mode, ULONG resvd)
{
    if (strcmp(fnm, "KBD$") == 0)
    {
        *handle = 3;
        return (0);
    }

    if ((action2 & OPEN_ACTION_REPLACE_IF_EXISTS) != 0)
    {
        *handle = (ULONG)fopen(fnm, "w+b");
    }
    else
    {
        *handle = (ULONG)fopen(fnm, "r+b");
    }

    if ((void *)*handle == NULL)
    {
        return (1);
    }
    return (0);
}

ULONG APIENTRY DosClose(ULONG hfile)
{
    FILE *f;

    /* keyboard is exception */
    if (hfile == 3) return (0);

    if (hfile == 0) f = stdin;
    else if (hfile == 1) f = stdout;
    else if (hfile == 2) f = stderr;
    else f = (FILE *)hfile;
    fclose((FILE *)hfile);
    return (0);
}

ULONG APIENTRY DosRead(ULONG hfile, void *ptr,
                       ULONG toread, ULONG *tempRead)
{
    FILE *f;

    if (hfile == 0) f = stdin;
    else if (hfile == 1) f = stdout;
    else if (hfile == 2) f = stderr;
    else f = (FILE *)hfile;

    *tempRead = fread(ptr, 1, toread, f);
    return (0);
}

ULONG APIENTRY DosDelete(char *name)
{
    remove(name);
    return (0);
}

ULONG APIENTRY DosMove(char *a, char *b)
{
    rename(a, b);
    return (0);
}

ULONG APIENTRY DosExecPgm(char *err_obj, USHORT sz, USHORT flags,
                          char *string, void *junk1, RESULTCODES *results,
                          char *string2)
{
    int rc;

    rc = system(string + strlen(string) + 1 + 3);
    results->codeResult = rc;
    return (0);
}

ULONG APIENTRY DosSetFilePtr(ULONG hfile, LONG newpos,
                              int dir, ULONG *retpos)
{
    FILE *f;

    if (hfile == 0) f = stdin;
    else if (hfile == 1) f = stdout;
    else if (hfile == 2) f = stderr;
    else f = (FILE *)hfile;

    fseek(f, newpos, dir);
    *retpos = ftell(f);
    return (0);
}

ULONG APIENTRY DosGetDateTime(DATETIME *dt)
{
    return (0);
}

ULONG APIENTRY DosDevIOCtl(ULONG handle,
                           ULONG category,
                           ULONG function,
                           void *parmptr,
                           ULONG parmmax,
                           ULONG *parmlen,
                           void *dataptr,
                           ULONG datamax,
                           ULONG *datalen)
{
    static int linebuf = 1;
    static KBDKEYINFO cd;

    if (function == 0x51)
    {
        if (linebuf)
        {
            linebuf = 0;
            setvbuf(stdin, NULL, _IONBF, 0);
        }
        else
        {
            linebuf = 1;
            setvbuf(stdin, NULL, _IOLBF, 0);
        }
    }
    /* this algorithm won't work for people who are using e0 as a
       legitimate character. Need to find out what e0 goes through
       with as a scancode, and set that scancode here, and get
       PDPCLIB to test that scancode first */
    else if (function == 0x74)
    {
        /* make sure to use a non-standard 0 (OS/2 uses 1) for a
           scancode of an ESC so that PDPCLIB does not attempt to
           double it. Currently all our scancodes are 0 since
           PDPCLIB doesn't need them */
        cd.chChar = fgetc(stdin);
        *(KBDKEYINFO *)dataptr = cd;
    }
    return (0);
}

ULONG APIENTRY DosAllocMem(void *base, ULONG size, ULONG flags)
{
    char *p;

    p = malloc(size);
    *(char **)base = p;
    if (p == NULL) return (1);
    return (0);
}

ULONG APIENTRY DosFreeMem(void *base)
{
    free(base);
    return (0);
}

ULONG APIENTRY DosScanEnv(void *name, void *result)
{
    *(char **)result = getenv(name);
    return (0);
}

ULONG APIENTRY DosSetRelMaxFH(LONG *req, ULONG *max)
{
    return (0);
}

ULONG APIENTRY DosGetInfoBlocks(TIB **tib, PIB **pib)
{
    /* OS/2 appears to have a space before the qqq, but
       PDPCLIB doesn't seem to care either way */
    /* static char cmd[] = "ppp\0qqq rrr"; */

    static char cmd[310]; /* will have NUL terminator */
    static PIB mypib = { 0, 0, 0, cmd };

    if (pib != NULL)
    {
        char *p;

        strncpy(cmd, PosGetCommandLine(), sizeof cmd - 1);

        /* this simple algorithm prevents the program name from
           having a space in it, so may want to fix */
        p = strchr(cmd, ' ');
        if (p != NULL)
        {
            *p = '\0';
        }
        *pib = &mypib;
    }
    return (0);
}
