***********************************************************************
*
*  This program written by Paul Edwards.
*  Released to the public domain
*
*  Extensively modified by others
*
***********************************************************************
*
*  VSESUPA - Support routines for PDPCLIB under DOS/VSE
*
*  This assembler code has a long history - starting off as C/370
*  under MVS then modified for GCC, then ported to CMS, MUSIC/SP
*  and then finally VSE. A rewrite should be considered.
*
***********************************************************************
*
         COPY  PDPTOP
*
@@VSESUP CSECT
         PRINT GEN
* REGEQU is not standard
*         REGEQU
R0       EQU   0
R1       EQU   1
R2       EQU   2
R3       EQU   3
R4       EQU   4
R5       EQU   5
R6       EQU   6
R7       EQU   7
R8       EQU   8
R9       EQU   9
R10      EQU   10
R11      EQU   11
R12      EQU   12
R13      EQU   13
R14      EQU   14
R15      EQU   15
SUBPOOL  EQU   0
*
**********************************************************************
*                                                                    *
*  AOPEN - Open a file                                               *
*                                                                    *
*  Parameters are:                                                   *
*  DDNAME - space-padded, 8 character DDNAME to be opened            *
*  MODE - 0 = READ, 1 = WRITE, 2 = UPDATE (update not supported)     *
*  RECFM - 0 = F, 1 = V, 2 = U. This is an output from this function *
*  LRECL - This function will determine the LRECL                    *
*  BLKSIZE - This function will determine the block size             *
*  ASMBUF - pointer to a 32K area which can be written to (only      *
*    needs to be set in move mode)                                   *
*  MEMBER - *pointer* to space-padded, 8 character member name.      *
*    If pointer is 0 (NULL), no member is requested                  *
*                                                                    *
*  Return value:                                                     *
*  An internal "handle" that allows the assembler routines to        *
*  keep track of what's what when READ etc are subsequently          *
*  called.                                                           *
*                                                                    *
*                                                                    *
*  Note - more documentation for this and other I/O functions can    *
*  be found halfway through the stdio.c file in PDPCLIB.             *
*                                                                    *
*                                                                    *
*                                                                    *
*  In the general case of an open of a disk file, ideally the        *
*  OPEN should allocate its storage area (ZDCBAREA - what "handle"   *
*  points to, and then it should copy the DTFSD into part of that    *
*  "DCB area" (it is called that for historical reasons and will     *
*  probably be renamed). The OPEN macro, using register notation,    *
*  points to that area, which will have first been modified to put   *
*  in the DDNAME (DLBL) being opened. This way we only need a        *
*  single DTFSD in the main code, which is reused any number of      *
*  times. However, at the moment we have simply assumed a single     *
*  RECFM=U input file and a single RECFM=U output file, which is     *
*  sufficient to allow a C compile to go through.                    *
*                                                                    *
*  The stdin/stdout/stderr are treated differently - each of those   *
*  has its own DTF, because they are special files (not disks).      *
*  The special files are SYSIPT, SYSLST and SYSLOG respectively.     *
*                                                                    *
*  Another technique that has been used is for accessing members of  *
*  a PDS - they are assumed to be in the CIL, and loaded, then       *
*  data is read from them as if it was a RECFM=U dataset.            *
*                                                                    *
*  Note that under VSE, the "suggested" DCB info is never actually   *
*  used currently.                                                   *
*                                                                    *
*  Also note that the C code is totally flexible in that it will     *
*  do whatever this assembler code tells it to. ie you can set any   *
*  file to any RECFM/LRECL and it will do its work based on that.    *
*  This makes it possible to change anything in here that isn't      *
*  working to your satisfaction, without needing to change the C     *
*  code at all.                                                      *
*                                                                    *
**********************************************************************
         ENTRY @@AOPEN
@@AOPEN  EQU   *
         SAVE  (14,12),,@@AOPEN
         LR    R12,R15
         USING @@AOPEN,R12
         LR    R11,R1
         L     R0,=A(ZDCBLEN)
         AIF   ('&SYS' EQ 'S390').BELOW
* USE DEFAULT LOC=RES for S/370 and S/380
         GETVIS
         AGO   .CHKBLWE
.BELOW   ANOP
         GETVIS LOC=BELOW
.CHKBLWE ANOP
         ST    R13,4(R1)
         ST    R1,8(R13)
         LR    R13,R1
         LR    R1,R11
         USING WORKAREA,R13
*
         L     R3,0(R1)         R3 POINTS TO DDNAME
         L     R4,4(R1)         R4 POINTS TO MODE
         L     R4,0(R4)         R4 now has value of mode
* 08(,R1) has RECFM
* Note that R5 is used as a scratch register
         L     R8,12(,R1)         R8 POINTS TO LRECL
* 16(,R1) has BLKSIZE
* 20(,R1) has ASMBUF pointer
*
         LA    R9,0
         ST    R9,ISMEM
         ST    R9,ISDI
         L     R9,24(,R1)         R9 POINTS TO MEMBER NAME (OF PDS)
         LA    R9,0(,R9)          Strip off high-order bit or byte
*
         LR    R2,R13             Access DCB
         LA    R2,WORKLEN(R2)     Point past save area
         LR    R0,R2              Load output DCB area address
         L     R1,=A(ZDCBLEN)     Load output length of DCB area
         S     R1,=A(WORKLEN)     Adjust for save area
         LR    R5,R11             Preserve parameter list
         LA    R11,0              Pad of X'00' and no input length
         MVCL  R0,R10             Clear DCB area to binary zeroes
         LR    R11,R5             Restore parameter list
* R5 free again
* THIS LINE IS FOR GCC
         LR    R6,R4
* THIS LINE IS FOR C/370
*         L     R6,0(R4)
*
*
*
         LTR   R6,R6
         BNZ   WRITING
*
* So now we're doing the reading code
*
         LA    R4,ENDFILE
* Something like RDJFCB would be good here, if VSE has such a thing
         LTR   R9,R9
         BZ    NOMEM
*
* Although VSE doesn't have PDSes with members, it has something
* similar - libraries. It is actually the Core Image library that
* is the most flexible, allowing binary data to be stored.
* Unfortunately this can't be directly read or written! But what
* we can do is use LNKEDT to build a module, then load it later,
* to be read as a file.
*
         ST    R9,ISMEM
         MVC   MEMBER24,0(R9)
         LA    R9,=C'OPEN    '
         ST    R9,P1VF
         LA    R9,MEMBER24
         ST    R9,P2VF
         LA    R1,PMVF
         CALL  @@VSEFIL
*
* We should be able to have 32k records here
         L     R6,=F'19069'   +++ hardcode to 19069
         ST    R6,DCBLRECL
         LA    R6,2    +++ hardcode to recfm=U
         ST    R6,DCBRECFM
         B     DONEOPEN
NOMEM    DS    0H
*
* Normal datasets just need to be opened - but unfortunately
* we don't know what their DCB info is. What we basically do
* to get around that problem is to hardcode DCB info based on
* the DDNAME. There are various techniques that could be used
* to work around this limitation, and one should be implemented.
*
* We use the register notation, because other than the standard
* files, all files will read/write data from a field in ZDCBAREA
* rather than a variable defined in this CSECT.
*
         CLC   0(8,R3),=C'SYSIN   '
         BNE   NOTSYSI
         LA    R6,80          +++ hardcode to 80
         ST    R6,DCBLRECL
         LA    R6,0           +++ hardcode to fixed
         ST    R6,DCBRECFM
         LA    R5,SYSIN
         ST    R5,PTRDTF
         OPEN  (R5)
         B     DONEOPEN
*
NOTSYSI  DS    0H
*
* All other files currently defined are RECFM=U
*
         L     R6,=F'19069'   +++ hardcode to 19069
         ST    R6,DCBLRECL
         LA    R6,2           +++ hardcode to recfm=U
         ST    R6,DCBRECFM
*
* Here we need to choose tape or disk
* There's probably a better way than looking at the name of
* the DD, to see if it starts with "MT", as a convention, 
* but of course it would be better if this was
* transparent to the programmer in the first place!
*
         CLC   0(2,R3),=C'MT'
         BNE   NOTTAP
         LA    R5,MTIN
         ST    R5,PTRDTF
         OPEN  (R5)
         B     DONEOPEN
*
NOTTAP   DS    0H
         LA    R5,SDIN
         ST    R5,PTRDTF
         OPEN  (R5)
         B     DONEOPEN
* Can't reach here, since all files are currently considered valid
         B     BADOPEN
*
*
*
WRITING  DS    0H
*
* Would be good if we could do a RDJFCB here to get DCB info.
* Instead, we just assume it from the DD name.
*
* Writing to a member of a library is not directly supported in VSE,
* and the workaround for this situation is done outside of this
* assembler code, so nothing to see here folks!
*
* We use the register notation, because other than the standard
* files, all files will read/write data from a field in ZDCBAREA
* rather than a variable defined in this CSECT.
*
WNOMEM   DS    0H
         CLC   0(8,R3),=C'SYSPRINT'
         BNE   NOTSYSPR
         LA    R6,80          +++ hardcode to 80
         ST    R6,DCBLRECL
         LA    R6,0           +++ hardcode to fixed
         ST    R6,DCBRECFM
         L     R6,DCBLRECL
         LA    R5,SYSPRT
         ST    R5,PTRDTF
         OPEN  (R5)
         B     DONEOPWR
*
NOTSYSPR DS    0H
         CLC   0(8,R3),=C'SYSTERM '
         BNE   NOTSYST
         LA    R6,80          +++ hardcode to 80
         ST    R6,DCBLRECL
         LA    R6,0           +++ hardcode to fixed
         ST    R6,DCBRECFM
         L     R6,DCBLRECL
         LA    R5,SYSTRM
         ST    R5,PTRDTF
         OPEN  (R5)
         B     DONEOPWR
*
NOTSYST  DS    0H
         CLC   0(8,R3),=C'SYSPUNCH'
         BNE   NOTSYSPU
         LA    R6,80          +++ hardcode to 80
         ST    R6,DCBLRECL
         LA    R6,0           +++ hardcode to fixed
         ST    R6,DCBRECFM
         LA    R6,1
         ST    R6,ISDI   syspunch is device-independent
         L     R6,DCBLRECL
         LA    R5,SYSPCH
         ST    R5,PTRDTF
         OPEN  (R5)
         B     DONEOPWR
*
NOTSYSPU DS    0H
*
* Assume RECFM=U
* Note that output files can't really use up to the full 19069
* and 18452 is a better match for a 3390 anyway
* However, we're running out of addressable workspace unless a
* restructure is done, so we set a limit of 1000
*
         L     R6,=F'1000'    +++ hardcode to 1000
         ST    R6,DCBLRECL
         LA    R6,2           +++ hardcode to undefined
         ST    R6,DCBRECFM
         L     R6,DCBLRECL
         LA    R5,SDOUT
         ST    R5,PTRDTF
         OPEN  (R5)
         B     DONEOPWR
*
* We've done the open for write, and now need to allocate a buffer 
* that the C code can write to. The buffer needs to be below the
* line, so it's simpler if the assembler code allocates it on
* behalf of the C caller. We should really allocate a buffer size
* based on what is actually required rather than this hardcoded
* maximum possible.
*
DONEOPWR DS    0H
         AIF   ('&OUTM' NE 'M').NMM4
         L     R6,=F'32768'
*
* Give caller an internal buffer to write to. Below the line!
*
* S/370 can't handle LOC=BELOW
*
         AIF   ('&SYS' EQ 'S390').MVT8090  If not 390
         GETVIS LENGTH=(R6)  Use default LOC=RES for S/370 and S/380
         AGO   .GETOENE
.MVT8090 ANOP  ,                  S/390
         GETVIS LENGTH=(R6),LOC=BELOW
.GETOENE ANOP
*
* Give this buffer pointer back to caller
         ST    R1,ASMBUF
         L     R5,20(,R11)        R5 points to ASMBUF
         ST    R1,0(R5)           save the pointer
*
.NMM4    ANOP
         B     DONEOPEN
*
*
* Finished opening file (read or write) and ready to return to
* caller. So set the values that they are expecting.
*
DONEOPEN DS    0H
*
* The LRECL
         L     R6,DCBLRECL
         ST    R6,0(R8)
* The RECFM
         L     R6,DCBRECFM
         L     R5,8(,R11)         Point to RECFM
         ST    R6,0(R5)
* Now return success
         B     RETURNOP
*
*
* We failed to open the file, so free the allocated memory and
* return an error.
*
BADOPEN  DS    0H
         L     R0,=A(ZDCBLEN)
         LR    R1,R13
         L     R7,SAVEAREA+4
         FREEVIS
         L     R15,=F'-1'
         LR    R13,R7
         RETURN (14,12),RC=(15)
*
ENDFILE  LA    R6,1
         ST    R6,RDEOF
         BR    R14
EOFRLEN  EQU   *-ENDFILE
*
*
* Good return - handle is in ZDCBAREA, which is R13. So we don't
* want to free that memory!
*
RETURNOP DS    0H
         LR    R15,R13
         L     R13,SAVEAREA+4
         RETURN (14,12),RC=(15)
         LTORG
*
*
**********************************************************************
*                                                                    *
*  AREAD - Read from file                                            *
*                                                                    *
*  This function takes 3 parameters:                                 *
*                                                                    *
*  1. A handle (previously returned by AOPEN)                        *
*  2. A buffer pointer - this is an output variable - the assembler  *
*     routine will read the data and then inform the caller where    *
*     the data is located.                                           *
*  3. Length of data (also output).                                  *
*                                                                    *
**********************************************************************
         ENTRY @@AREAD
@@AREAD  EQU   *
         SAVE  (14,12),,@@AREAD
         LR    R12,R15
         USING @@AREAD,R12
         LR    R11,R1
*
         AIF ('&SYS' EQ 'S370').NOMOD1
         CALL  @@SETM24
.NOMOD1  ANOP
*
         L     R1,0(R1)         R1 CONTAINS HANDLE
         ST    R13,4(R1)
         ST    R1,8(R13)
         LR    R13,R1
         LR    R1,R11
         USING WORKAREA,R13
*
         L     R3,4(R1)         R3 POINTS TO BUF POINTER
         L     R4,8(R1)         R4 points to a length
*
* See if this is a library file
*
         L     R9,ISMEM
         LTR   R9,R9
         BNZ   GMEM
*
* For non-library files, we read into an internal buffer that
* is stored in the zdcbarea. Set that fact immediately.
*
         LA    R5,INTSTOR         
         ST    R5,0(R3)
*
* The DTF macro is expecting to get the maximum length in R8
*
         L     R8,DCBLRECL
         L     R7,PTRDTF
         GET   (R7),(R5)
* If GET reaches EOF, the "GOTEOF" label will be branched to
* automatically.
         LA    R15,0             SUCCESS
         ST    R8,0(R4)          store length actually read
         B     FINFIL
*
* This is a library file, so we need to call VSEFIL
*
GMEM     DS    0H                got member
         LA    R9,=C'GET     '
         ST    R9,P1VF
         LA    R9,MEMBER24
         ST    R9,P2VF
* Let VSEFIL directly set our caller's parameters
         ST    R3,P3VF
         ST    R4,P4VF
         LA    R1,PMVF
         CALL  @@VSEFIL
         L     R9,0(R4)
         LTR   R9,R9
         BNZ   FINFIL
         B     GOTEOF
GOTEOF   DS    0H
         LA    R15,1             FAIL
FINFIL   DS    0H
*
RETURNAR DS    0H
         LR    R1,R13
         L     R13,SAVEAREA+4
*
         AIF ('&SYS' EQ 'S370').NOMOD2
         LR    R7,R15            Preserve R15 over call
         CALL  @@SETM31
         LR    R15,R7
.NOMOD2  ANOP
*
         RETURN (14,12),RC=(15)
         LTORG
*
*
*
**********************************************************************
*                                                                    *
*  AWRITE - Write to file                                            *
*                                                                    *
*  This function takes 3 parameters:                                 *
*                                                                    *
*  1. A handle (previously returned by AOPEN)                        *
*  2. Address of buffer to be written (also previously obtained      *
*     from AOPEN).                                                   *
*  3. Length of data to be written (which may be ignored for a file  *
*     that is of an expected length, e.g. fixed 80)                  *
*                                                                    *
**********************************************************************
         ENTRY @@AWRITE
@@AWRITE EQU   *
         SAVE  (14,12),,@@AWRITE
         LR    R12,R15
         USING @@AWRITE,R12
         LR    R11,R1             SAVE
*
         AIF   ('&SYS' NE 'S380').N380WR1
         CALL  @@SETM24
.N380WR1 ANOP
*
         L     R1,0(R1)           R1 IS NOW HANDLE
         ST    R13,4(,R1)
         ST    R1,8(,R13)
         LR    R13,R1
         LR    R1,R11             RESTORE
         USING WORKAREA,R13
*
         L     R2,0(,R1)          R2 contains GETMAINed address
         L     R3,4(,R1)          R3 points to the record address
         L     R3,0(,R3)          R3 now has actual buffer address
         L     R8,8(,R1)          R8 points to the length
         L     R8,0(,R8)          R8 now has actual length
*
         L     R5,PTRDTF
         L     R9,ISDI            Is this device-independent?
         LTR   R9,R9
         BNZ   GDI
*
* Normal file. PUT needs the DTF pointer, the buffer, and our
* DTF is expecting the length in R8
*
         PUT   (R5),(R3)
         B     DONEPUT
*
* Got a device-indepentent DTF - we only support a RECSIZE of 81
* including control character for this type - should be made
* more flexible.
*
GDI      DS    0H
         MVC   IO1+1(80),0(R3)   +++ hardcode IO1 and length
         MVI   IO1,C' '          space seems to be OK as control char
         PUT   (R5)
*
* We have written to file, but should really check for any error
*
DONEPUT  DS    0H
*
         AIF   ('&SYS' NE 'S380').N380WR2
         CALL  @@SETM31
.N380WR2 ANOP
*
         L     R13,4(R13)
         LA    R15,0             +++ hardcode success
         RETURN (14,12),RC=(15)
         LTORG
*
**********************************************************************
*                                                                    *
*  ACLOSE - Close file                                               *
*                                                                    *
*  This routine takes a single parameter - a handle as given by the  *
*  (successful) return from AOPEN.                                   *
*                                                                    *
**********************************************************************
         ENTRY @@ACLOSE
@@ACLOSE EQU   *
         SAVE  (14,12),,@@ACLOSE
         LR    R12,R15
         USING @@ACLOSE,R12
         LR    R11,R1           SAVE
*
* The CLOSE appears to be abending when called in 31-bit mode,
* despite it being an SVC. So we need to switch to 24-bit mode
         AIF   ('&SYS' NE 'S380').N380CL1
         CALL  @@SETM24
.N380CL1 ANOP
*
         L     R1,0(R1)         R1 CONTAINS HANDLE
         ST    R13,4(R1)
         ST    R1,8(R13)
         LR    R13,R1
         LR    R1,R11
         USING WORKAREA,R13
*
*
* If we are doing move mode, free internal assembler buffer
*
         AIF   ('&OUTM' NE 'M').NMM6
         L     R5,ASMBUF
         LTR   R5,R5
         BZ    NFRCL
         L     R6,=F'32768'     +++ hardcode length of ASMBUF
         FREEVIS LENGTH=(R6),ADDRESS=(R5)
NFRCL    DS    0H
.NMM6    ANOP
*
*
         L     R5,PTRDTF        Get DTF
         LTR   R5,R5
         BZ    NOTOPEN
         L     R9,ISMEM         Is this a library member?
         LTR   R9,R9
         BNZ   GMEM2
*
* Normal file - just do a close.
*
         CLOSE (R5)
         B     DONECLOS
*
* We have a library member, so call VSEFIL to close
*
GMEM2    DS    0H
         LA    R9,=C'CLOSE   '
         ST    R9,P1VF
         LA    R9,MEMBER24
         ST    R9,P2VF
         LA    R1,PMVF
         CALL  @@VSEFIL
         B     DONECLOS
*
* We probably shouldn't have a specific detection for a close
* of a file that is not open, as it's a logic error regardless.
*
NOTOPEN  DS    0H
         LA    R15,1
         B     RETURNAC
*
* We should have some error detection here, but for now, just
* set success unconditionally
*
DONECLOS DS    0H
         LA    R15,0
*
RETURNAC DS    0H
         LR    R1,R13
         L     R13,SAVEAREA+4
         LR    R7,R15
         L     R0,=A(ZDCBLEN)
         FREEVIS
*
         AIF   ('&SYS' NE 'S380').N380CL2
         CALL  @@SETM31
.N380CL2 ANOP
*
         LR    R15,R7
         RETURN (14,12),RC=(15)
         LTORG
*
*
*
* Note that a lot of these macros use the same storage buffer,
* because by their nature, the C caller will always read or
* write an entire block at a time.
*
*
* This is for reading from stdin
SYSIN    DTFCD DEVADDR=SYSIPT,IOAREA1=IO1,BLKSIZE=80,RECFORM=FIXUNB,   X
               WORKA=YES,EOFADDR=GOTEOF,MODNAME=CARDMOD
CARDMOD  CDMOD RECFORM=FIXUNB,WORKA=YES,TYPEFLE=INPUT
*
* This is for writing to SYSPUNCH in a device-independent manner
* Note that it is a requirement to allow for a control character
SYSPCH   DTFDI DEVADDR=SYSPCH,IOAREA1=IO1,RECSIZE=81
*
* This is for writing to stdout (SYSPRINT)
* At some point this will need to be made device-independent so
* that it can be redirected - and it will need to be increased
* to 121 to do so.
SYSPRT   DTFPR CONTROL=YES,BLKSIZE=80,DEVADDR=SYSLST,MODNAME=PRINTMOD, X
               IOAREA1=IO1,RECFORM=FIXUNB,WORKA=YES
*
* This is for writing to stderr (SYSTERM)
SYSTRM   DTFPR CONTROL=YES,BLKSIZE=80,DEVADDR=SYS005,MODNAME=PRINTMOD, X
               IOAREA1=IO1,RECFORM=FIXUNB,WORKA=YES
PRINTMOD PRMOD CONTROL=YES,RECFORM=FIXUNB,WORKA=YES
*
* This is for writing to a sequential disk file
* Note that the size is kept low (1000) so as to avoid addressability
* problems, because it is currently using a variable in this CSECT
* instead of doing something sensible like using a buffer in the
* dynamic area.
SDOUT    DTFSD BLKSIZE=1016,DEVADDR=SYS009,DEVICE=3350,                X
               IOAREA1=WORKO1,RECFORM=UNDEF,WORKA=YES,                 X
               TYPEFLE=OUTPUT,RECSIZE=(8)
*
* This is for reading from a sequential disk file
SDIN     DTFSD BLKSIZE=19069,DEVADDR=SYS010,DEVICE=3350,               X
               IOAREA1=WORKI1,RECFORM=UNDEF,WORKA=YES,                 X
               TYPEFLE=INPUT,RECSIZE=(8),EOFADDR=GOTEOF
*
* This is for reading from a tape
MTIN     DTFMT BLKSIZE=19069,DEVADDR=SYS011,MODNAME=MTINMOD,           X
               IOAREA1=WORKI1,RECFORM=UNDEF,WORKA=YES,FILABL=NO,       X
               TYPEFLE=INPUT,RECSIZE=(8),EOFADDR=GOTEOF
MTINMOD  MTMOD WORKA=YES,RECFORM=UNDEF
*
* For the standard files, this is sufficient for input and output
IO1      DS    CL200
*
*
*
* This is pretty crappy - storing large variables in the CSECT
* instead of the dynamically-allocated DSECT. But at least the
* fact that they are being shared makes it not so bad.
* An extra 100 bytes to be helpful.
WORKI1   DS    CL19169
WORKO1   DS    CL19169
*
*
***********************************************************************
*
*  GETM - GET MEMORY
*
***********************************************************************
         ENTRY @@GETM
@@GETM   EQU   *
         SAVE  (14,12),,@@GETM
         LR    R12,R15
         USING @@GETM,R12
*
         L     R2,0(,R1)
         AIF ('&COMP' NE 'GCC').GETMC
* THIS LINE IS FOR GCC
         LR    R3,R2
         AGO   .GETMEND
.GETMC   ANOP
* THIS LINE IS FOR C/370
         L     R3,0(,R2)
.GETMEND ANOP
         LR    R4,R3
         LA    R3,8(,R3)
*
* To avoid fragmentation, round up size to 64 byte multiple
*
         A     R3,=A(64-1)
         N     R3,=X'FFFFFFC0'
*
         AIF   ('&SYS' NE 'S380').N380GM1
*         GETMAIN RU,LV=(R3),SP=SUBPOOL,LOC=ANY
*
* When in 380 mode, we need to keep the program below the
* line, but we have the ability to use storage above the
* line, and this is where we get it, with the LOC=ANY parameter.
* For other environments, the default LOC=RES is fine.
*
         GETVIS LENGTH=(R3),LOC=ANY
         AGO   .N380GM2
.N380GM1 ANOP
         GETVIS LENGTH=(R3)
.N380GM2 ANOP
*
         LTR   R15,R15
         BZ    GOODGM
         LA    R15,0
         B     RETURNGM
GOODGM   DS    0H
* WE STORE THE AMOUNT WE REQUESTED FROM MVS INTO THIS ADDRESS
         ST    R3,0(R1)
* AND JUST BELOW THE VALUE WE RETURN TO THE CALLER, WE SAVE
* THE AMOUNT THEY REQUESTED
         ST    R4,4(R1)
         A     R1,=F'8'
         LR    R15,R1
*
RETURNGM DS    0H
         RETURN (14,12),RC=(15)
         LTORG
*
***********************************************************************
*
*  FREEM - FREE MEMORY
*
***********************************************************************
         ENTRY @@FREEM
@@FREEM  EQU   *
         SAVE  (14,12),,@@FREEM
         LR    R12,R15
         USING @@FREEM,R12
*
         L     R2,0(,R1)
         S     R2,=F'8'
         L     R3,0(,R2)
*
         AIF   ('&SYS' NE 'S380').N380FM1
* On S/380, nothing to free - using preallocated memory block
*         FREEMAIN LENGTH=(R3),ADDRESS=(R2)
         AGO   .N380FM2
.N380FM1 ANOP
         FREEVIS LENGTH=(R3),ADDRESS=(R2)
.N380FM2 ANOP
*
RETURNFM DS    0H
         RETURN (14,12),RC=(15)
         LTORG
***********************************************************************
*
*  GETCLCK - GET THE VALUE OF THE MVS CLOCK TIMER AND MOVE IT TO AN
*  8-BYTE FIELD.  THIS 8-BYTE FIELD DOES NOT NEED TO BE ALIGNED IN
*  ANY PARTICULAR WAY.
*
*  E.G. CALL 'GETCLCK' USING WS-CLOCK1
*
*  THIS FUNCTION ALSO RETURNS THE NUMBER OF SECONDS SINCE 1970-01-01
*  BY USING SOME EMPERICALLY-DERIVED MAGIC NUMBERS
*
***********************************************************************
         ENTRY @@GETCLK
@@GETCLK EQU   *
         SAVE  (14,12),,@@GETCLK
         LR    R12,R15
         USING @@GETCLK,R12
*
         L     R2,0(,R1)
         STCK  0(R2)
         L     R4,0(,R2)
         L     R5,4(,R2)
         SRDL  R4,12
         SL    R4,=X'0007D910'
         D     R4,=F'1000000'
         SL    R5,=F'1220'
         LR    R15,R5
*
RETURNGC DS    0H
         RETURN (14,12),RC=(15)
         LTORG
***********************************************************************
*
*  SYSTEM - execute another command
*
***********************************************************************
         ENTRY @@SYSTEM
@@SYSTEM EQU   *
         SAVE  (14,12),,@@SYSTEM
         LR    R12,R15
         USING @@SYSTEM,R12
         LR    R11,R1
*
*         GETVIS LENGTH=SYSTEMLN,SP=SUBPOOL
         ST    R13,4(,R1)
         ST    R1,8(,R13)
         LR    R13,R1
         LR    R1,R11
         USING SYSTMWRK,R13
*
         MVC   CMDPREF,FIXEDPRF
         L     R2,0(R1)
         CL    R2,=F'200'
         BL    LENOK
         L     R2,=F'200'
LENOK    DS    0H
         STH   R2,CMDLEN
         LA    R4,CMDTEXT
         LR    R5,R2
         L     R6,4(R1)
         LR    R7,R2
         MVCL  R4,R6
         LA    R1,CMDPREF
*         SVC   $EXREQ
*
RETURNSY DS    0H
         LR    R1,R13
         L     R13,SYSTMWRK+4
*         FREEMAIN RU,LV=SYSTEMLN,A=(1),SP=SUBPOOL
*
         LA    R15,0
         RETURN (14,12),RC=(15)
* For documentation on this fixed prefix, see SVC 221
* documentation.
FIXEDPRF DC    X'7F01E000000000'
         LTORG
SYSTMWRK DSECT ,             MAP STORAGE
         DS    18A           OUR OS SAVE AREA
CMDPREF  DS    CL8           FIXED PREFIX
CMDLEN   DS    H             LENGTH OF COMMAND
CMDTEXT  DS    CL200         COMMAND ITSELF
SYSTEMLN EQU   *-SYSTMWRK    LENGTH OF DYNAMIC STORAGE
@@VSESUP CSECT ,
***********************************************************************
*
*  IDCAMS - dummy function to keep MVS happy
*
***********************************************************************
         ENTRY @@IDCAMS
@@IDCAMS EQU   *
         SAVE  (14,12),,@@IDCAMS
         LR    R12,R15
         USING @@IDCAMS,R12
*
         LA    R15,0
*
         RETURN (14,12),RC=(15)
         LTORG
*
***********************************************************************
*
*  DYNAL - dummy function to keep MVS happy
*
***********************************************************************
         ENTRY @@DYNAL
@@DYNAL EQU   *
         SAVE  (14,12),,@@DYNAL
         LR    R12,R15
         USING @@DYNAL,R12
*
         LA    R15,0
*
         RETURN (14,12),RC=(15)
         LTORG
*
*
*
* Keep this code last because it uses a different base register
*
         DROP  R12
*
*
*
* This is used by VSEFIL
*
TABDDN   DSECT
         USING     *,R9
DDN      DS        CL8
POINTER  DS        F
TABLEN   EQU       *-TABDDN
*
@@VSESUP CSECT
***********************************************************************
*                                                                     *
*  VSEFIL - contributed by Louis Millon                               *
*                                                                     *
*  Allows access to CIL in order to read RECFM=U binary files in a    *
*  PDS-like manner.                                                   *
*                                                                     *
*  CALL      @@VSEFIL,(OPEN,DDN)                                      *
*  CALL      @@VSEFIL,(GET,DDN,RECADDR,RECLEN)                        *
*  CALL      @@VSEFIL,(CLOSE,DDN)                                     *
*                                                                     *
*  "OPEN" etc must be CL8 with that string. DDN is CL8. Other two F   *
*                                                                     *
***********************************************************************
         ENTRY @@VSEFIL
@@VSEFIL EQU   *
         USING     *,R3
         SAVE      (14,12)
         LR        R3,R15
         LR        R10,R1
         B         DEBCODE
MAXFILE  EQU       20                            NUMBER OF FILE
*                                                WHICH MAY BE OPENED AT
*                                                THE SAME TIME
AREA     DC        (TABLEN*MAXFILE)X'00'
         DC        F'-1'                         END OF TABLE
FILENAME DS        CL8
DEBCODE  DS        0H
         L         R15,0(R10)                    FUNCTION
         CLC       =C'GET',0(R15)
         BE        GET
         CLC       =C'OPEN',0(R15)
         BE        OPEN
         CLC       =C'CLOSE',0(R15)
         BE        CLOSE
         RETURN    (14,12),RC=8                  INVALID FUNCTION
OPEN     DS        0H
         L         R15,4(R10)
         MVC       FILENAME,0(R15)               DDNAME
         LA        R9,AREA
         LA        R15,MAXFILE
LOOPOPEN DS        0H
         CLC       DDN,FILENAME
         BE        ALREADY                       THIS FILE IS ALREADY
*                                                OPENED
         LA        R9,TABLEN(R9)
         BCT       R15,LOOPOPEN                  THE FILE IS NOT OPEN
         LA        R9,AREA                       SEEK FOR A VACANT
         LA        R15,MAXFILE                   POSITION IN THE ARRAY
LOOPOPN2 DS        0H
         CLC       DDN,=8X'0'                    POSITION IS FREE?
         BE        OKOPEN                        YES
         LA        R9,TABLEN(R9)
         BCT       R15,LOOPOPN2                  NEXT OCCURENCE
         RETURN    (14,12),RC=12                 ARRAY IS FULL
ALREADY  RETURN    (14,12),RC=8                  FILE ALREADY OPENED
OKOPEN   DS        0H
         LA        R1,FILENAME
         CDLOAD    (1)
         ST        R0,POINTER
         LTR       R15,R15
         BZ        R15OK
         LNR       R15,R15
         RETURN    (14,12),RC=(15)              CDLOAD FAIL
R15OK    EQU       *
         MVC       DDN,FILENAME
         RETURN    (14,12),RC=0
CLOSE    DS        0H
         L         R15,4(R10)
         MVC       FILENAME,0(R15)
         LA        R9,AREA
         LA        R15,MAXFILE
LOOPCLOS DS        0H
         CLC       DDN,FILENAME
         BE        OKCLOSE
         LA        R9,TABLEN(R9)
         BCT       R15,LOOPCLOS
         RETURN    (14,12),RC=8                  DDNAME NOTFND IN ARRAY
OKCLOSE  DS        0H
         LA        R1,FILENAME
*         CDDELETE  (1)                       REMOVE PHASE FROM GETV
         XC        DDN,DDN
         XC        POINTER,POINTER
         RETURN    (14,12),RC=0
GET      DS        0H
         LA        R15,FILENAME
         MVC       FILENAME,0(R15)
         LA        R9,AREA
         LA        R15,MAXFILE
LOOPGET  DS        0H
         CLC       DDN,FILENAME
         BE        OKGET
         LA        R9,TABLEN(R9)
         BCT       R15,LOOPGET
         RETURN    (14,12),RC=12                 DDNAME NOTFND IN ARRAY
OKGET    DS        0H
         L         R15,POINTER
         CLC       0(4,R15),=F'0'
         BNE       NOEOF
         RETURN    (14,12),RC=8                  EOF
NOEOF    DS        0H
         L         R14,POINTER
         L         R15,12(R10)
         MVC       0(4,R15),0(R14)               LENGTH OF RECORD
         LA        R14,4(R14)                    SKIP RECLEN
         L         R15,08(R10)
         ST        R14,0(R15)                    AADR OF RECORD
         L         R14,POINTER
         AL        R14,0(R14)                    SKIP RECORD
         LA        R14,4(R14)                    AND LENGTH
         ST        R14,POINTER                   NEXT RECORD
         RETURN    (14,12),RC=0
         LTORG
         DROP      R3
***********************************************************************
*                                                                     *
*  GETTZ - Get the offset from GMT in 1.048576 seconds                *
*                                                                     *
***********************************************************************
         ENTRY @@GETTZ
@@GETTZ  LA    R15,0
         BR    R14
***********************************************************************
*
*  SETJ - SAVE REGISTERS INTO ENV
*
***********************************************************************
         ENTRY @@SETJ
         USING @@SETJ,R15
@@SETJ   L     R15,0(R1)          get the env variable
         STM   R0,R14,0(R15)      save registers to be restored
         LA    R15,0              setjmp needs to return 0
         BR    R14                return to caller
         LTORG ,
*
***********************************************************************
*
*  LONGJ - RESTORE REGISTERS FROM ENV
*
***********************************************************************
         ENTRY @@LONGJ
         USING @@LONGJ,R15
@@LONGJ  L     R2,0(R1)           get the env variable
         L     R15,60(R2)         get the return code
         LM    R0,R14,0(R2)       restore registers
         BR    R14                return to caller
         LTORG ,
*
* S/370 doesn't support switching modes so this code is useless,
* and won't compile anyway because "BSM" is not known.
*
         AIF   ('&SYS' EQ 'S370').NOMODE  If S/370 we can't switch mode
***********************************************************************
*
*  SETM24 - Set AMODE to 24
*
***********************************************************************
         ENTRY @@SETM24
         USING @@SETM24,R15
@@SETM24 ICM   R14,8,=X'00'       Sure hope caller is below the line
         BSM   0,R14              Return in amode 24
*
***********************************************************************
*
*  SETM31 - Set AMODE to 31
*
***********************************************************************
         ENTRY @@SETM31
         USING @@SETM31,R15
@@SETM31 ICM   R14,8,=X'80'       Set to switch mode
         BSM   0,R14              Return in amode 31
         LTORG ,
*
.NOMODE  ANOP  ,                  S/370 doesn't support MODE switching
*
*
*
WORKAREA DSECT
SAVEAREA DS    18F
WORKLEN  EQU   *-WORKAREA
* Note that the handle starts from the WORKAREA DSECT, but
* initialization starts at ZDCBAREA (since we don't want to
* initialize our save area). Some more appropriate names
* should probably be found.
ZDCBAREA DS    0H
OPENCLOS DS    F                  OPEN/CLOSE parameter list
BLKSIZE  DS    F                  Save area for input DCB BLKSIZE
LRECL    DS    F                  Save area for input DCB LRECL
BUFFADDR DS    F                  Location of the BLOCK Buffer
BUFFEND  DS    F                  Address after end of current block
BUFFCURR DS    F                  Current record in the buffer
VBSADDR  DS    F                  Location of the VBS record build area
VBSEND   DS    F                  Addr. after end VBS record build area
VBSCURR  DS    F                  Location to store next byte
RDRECPTR DS    F                  Where to store record pointer
RDLENPTR DS    F                  Where to store read length
PTRDTF   DS    F                  Pointer to the DTF in use
DCBLRECL DS    F                  Logical record length
DCBRECFM DS    F                  Record format
JFCBPTR  DS    F
JFCB     DS    0F
DSCB     DS    0F
DSCBCCHH DS    CL5                CCHHR of DSCB returned by OBTAIN
         DS    CL47               Rest of OBTAIN's 148 byte work area
RDEOF    DS    1F
ASMBUF   DS    A                  Pointer to a 32k area for PUTing data
MEMBER24 DS    CL8
ISMEM    DS    F                  Flag whether this is a PDS
ISDI     DS    F                  Flag whether this is dev-independent
PMVF     DS    0F
P1VF     DS    A
P2VF     DS    A
P3VF     DS    A
P4VF     DS    A
* We should probably get rid of this variable and just use ASMBUF
* for both GET (non-library) and PUT.
INTSTOR  DS    CL19169            Internal storage for GET
ZDCBLEN  EQU   *-WORKAREA
*
         END
