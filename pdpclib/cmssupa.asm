**********************************************************************
*                                                                    *
*  THIS PROGRAM WRITTEN BY PAUL EDWARDS.                             *
*  RELEASED TO THE PUBLIC DOMAIN                                     *
*                                                                    *
**********************************************************************
*
* MODS BY DAVE WADE
*
*
*   1 - CHANGE REQUEST TYPE FROM RU TO R ON ALL GETMAIN/FREEMAIN
*
*   2 - REMOVE IEFJFCB AND REPLACE WITH DS 176
*
*   3 - ADD SVC 202 ROUTINE TO ALLOW CMS FUNCTIONS TO BE CALLED
*
**********************************************************************
*                                                                    *
*  CMSSUPA - SUPPORT ROUTINES FOR PDPCLIB UNDER CMS                  *
*                                                                    *
*  Note that it is necessary for these routines to stay below the    *
*  line because they are using macros like "GET" that are documented *
*  in z/VM as needing to be executed in AMODE 24. In order to lift   *
*  this 24-bit restriction it will be necessary to switch to         *
*  native CMS macros.                                                *
*                                                                    *
**********************************************************************
         COPY  PDPTOP
         PRINT NOGEN
* YREGS IS NOT AVAILABLE WITH IFOX
*         YREGS
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
         CSECT
**********************************************************************
*                                                                    *
*  AOPEN - Open a file                                               *
*                                                                    *
**********************************************************************
         ENTRY @@AOPEN
@@AOPEN  EQU   *
         SAVE  (14,12),,@@AOPEN
         LR    R12,R15
         USING @@AOPEN,R12
         LR    R11,R1
         GETMAIN R,LV=WORKLEN,SP=SUBPOOL
         ST    R13,4(R1)
         ST    R1,8(R13)
         LR    R13,R1
         LR    R1,R11
         USING WORKAREA,R13
*
         L     R3,0(R1)         R3 POINTS TO DDNAME
         L     R4,4(R1)         R4 POINTS TO MODE
         L     R5,8(R1)         R5 POINTS TO RECFM
         L     R8,12(R1)        R8 POINTS TO LRECL
         L     R9,16(R1)        R9 POINTS TO MEMBER NAME (OF PDS)
         AIF   ('&SYS' EQ 'S390').BELOW
* CAN'T USE "BELOW" ON MVS 3.8
         GETMAIN R,LV=ZDCBLEN,SP=SUBPOOL
         AGO   .CHKBLWE
.BELOW   ANOP
         GETMAIN R,LV=ZDCBLEN,SP=SUBPOOL,LOC=BELOW
.CHKBLWE ANOP
         LR    R2,R1
* THIS LINE IS FOR GCC
         LR    R6,R4
* THIS LINE IS FOR C/370
*         L     R6,0(R4)
         LTR   R6,R6
         BNZ   WRITING
* READING
         USING IHADCB,R2
         MVC   ZDCBAREA(INDCBLN),INDCB
         LA    R10,JFCB
* EXIT TYPE 07 + 80 (END OF LIST INDICATOR)
         ICM   R10,B'1000',=X'87'
         ST    R10,JFCBPTR
         LA    R10,JFCBPTR
         LA    R4,ENDFILE
         ST    R4,DCBEODAD
         ST    R10,DCBEXLST
         MVC   DCBDDNAM,0(R3)
         MVC   OPENMB,OPENMAC
*
         RDJFCB ((R2),INPUT)
         LTR   R9,R9
* DW * DON'T SUPPORT MEMBER NAME FOR NOW
*        BZ    NOMEM
         B     NOMEM
         USING ZDCBAREA,R2
*        MVC   JFCBELNM,0(R9)
*        OI    JFCBIND1,JFCPDS
* DW * END OF MOD
NOMEM    DS    0H
*         OPEN  ((R2),INPUT),MF=(E,OPENMB),MODE=31,TYPE=J
* CAN'T USE MODE=31 ON MVS 3.8, OR WITH TYPE=J
         OPEN  ((R2),INPUT),MF=(E,OPENMB),TYPE=J
         B     DONEOPEN
WRITING  DS    0H
         USING ZDCBAREA,R2
         MVC   ZDCBAREA(OUTDCBLN),OUTDCB
         LA    R10,JFCB
* EXIT TYPE 07 + 80 (END OF LIST INDICATOR)
         ICM   R10,B'1000',=X'87'
         ST    R10,JFCBPTR
         LA    R10,JFCBPTR
         ST    R10,DCBEXLST
         MVC   DCBDDNAM,0(R3)
         MVC   WOPENMB,WOPENMAC
*
         RDJFCB ((R2),OUTPUT)
         LTR   R9,R9
* DW * NO MEMBER ON VM/370
*        BZ    WNOMEM
         B     WNOMEM
         USING ZDCBAREA,R2
*        MVC   JFCBELNM,0(R9)
*        OI    JFCBIND1,JFCPDS
* DW * END OF MOD
WNOMEM   DS    0H
*         OPEN  ((R2),OUTPUT),MF=(E,WOPENMB),MODE=31,TYPE=J
* CAN'T USE MODE=31 ON MVS 3.8, OR WITH TYPE=J
         OPEN  ((R2),OUTPUT),MF=(E,WOPENMB),TYPE=J
DONEOPEN DS    0H
         SR    R6,R6
         LH    R6,DCBLRECL
         ST    R6,0(R8)
* DW * VM/370 IS MISSING THESE DEFS
*        TM    DCBRECFM,DCBRECF
         TM    DCBRECFM,RECF
* END
         BNO   VARIABLE
         L     R6,=F'0'
         B     DONESET
VARIABLE DS    0H
         L     R6,=F'1'
DONESET  DS    0H
         ST    R6,0(R5)
         LR    R15,R2
         B     RETURNOP
*
ENDFILE  LA    R6,1
         ST    R6,RDEOF
         BR    R14
EOFRLEN  EQU   *-ENDFILE
*
RETURNOP DS    0H
         LR    R1,R13
         L     R13,SAVEAREA+4
         LR    R7,R15
         FREEMAIN R,LV=WORKLEN,A=(R1),SP=SUBPOOL
         LR    R15,R7
         RETURN (14,12),RC=(15)
         LTORG
* OPENMAC  OPEN  (,INPUT),MF=L,MODE=31
* CAN'T USE MODE=31 ON MVS 3.8
OPENMAC  OPEN  (,INPUT),MF=L,TYPE=J
OPENMLN  EQU   *-OPENMAC
* WOPENMAC OPEN  (,OUTPUT),MF=L,MODE=31
* CAN'T USE MODE=31 ON MVS 3.8
WOPENMAC OPEN  (,OUTPUT),MF=L
WOPENMLN EQU   *-WOPENMAC
*INDCB    DCB   MACRF=GL,DSORG=PS,EODAD=ENDFILE,EXLST=JPTR
* LEAVE OUT EODAD AND EXLST, FILLED IN LATER
INDCB    DCB   MACRF=GL,DSORG=PS,EODAD=ENDFILE,EXLST=JPTR
INDCBLN  EQU   *-INDCB
JPTR     DS    F
OUTDCB   DCB   MACRF=PL,DSORG=PS
OUTDCBLN EQU   *-OUTDCB
*
*
*
**********************************************************************
*                                                                    *
*  AREAD - Read from file                                            *
*                                                                    *
**********************************************************************
         ENTRY @@AREAD
@@AREAD  EQU   *
         SAVE  (14,12),,@@AREAD
         LR    R12,R15
         USING @@AREAD,R12
         LR    R11,R1
         AIF ('&SYS' EQ 'S370').NOMOD1
         CALL  @@SETM24
.NOMOD1  ANOP
*         AIF   ('&SYS' NE 'S370').BELOW1
* CAN'T USE "BELOW" ON MVS 3.8
*         GETMAIN R,LV=WORKLEN,SP=SUBPOOL
*         AGO   .NOBEL1
*.BELOW1  ANOP
*         GETMAIN R,LV=WORKLEN,SP=SUBPOOL,LOC=BELOW
*.NOBEL1  ANOP
         L     R2,0(R1)         R2 CONTAINS HANDLE
         USING ZDCBAREA,R2
         LA    R1,SAVEADCB
         ST    R13,4(R1)
         ST    R1,8(R13)
         LR    R13,R1
         LR    R1,R11
         USING WORKAREA,R13
*
*        L     R2,0(R1)         R2 CONTAINS HANDLE
         L     R3,4(R1)         R3 POINTS TO BUF POINTER
         LA    R6,0
         ST    R6,RDEOF
         GET   (R2)
         ST    R1,0(R3)
         L     R15,RDEOF
*
RETURNAR DS    0H
         LR    R1,R13
         L     R13,SAVEAREA+4
         LR    R7,R15
*        FREEMAIN R,LV=WORKLEN,A=(R1),SP=SUBPOOL
         AIF ('&SYS' EQ 'S370').NOMOD2
         CALL  @@SETM31
.NOMOD2  ANOP
         LR    R15,R7
         RETURN (14,12),RC=(15)
*
*
*
**********************************************************************
*                                                                    *
*  AWRITE - Write to file                                            *
*                                                                    *
**********************************************************************
         ENTRY @@AWRITE
@@AWRITE EQU   *
         SAVE  (14,12),,@@AWRITE
         LR    R12,R15
         USING @@AWRITE,R12
         LR    R11,R1
         AIF ('&SYS' EQ 'S370').NOMOD3
         CALL  @@SETM24
.NOMOD3  ANOP
*         AIF   ('&SYS' NE 'S370').BELOW2
* CAN'T USE "BELOW" ON MVS 3.8
*         GETMAIN R,LV=WORKLEN,SP=SUBPOOL
*         AGO   .NOBEL2
*.BELOW2  ANOP
*         GETMAIN R,LV=WORKLEN,SP=SUBPOOL,LOC=BELOW
*.NOBEL2  ANOP
         USING ZDCBAREA,R2
         L     R2,0(R1)
         LA    R1,SAVEADCB
         ST    R13,4(R1)
         ST    R1,8(R13)
         LR    R13,R1
         LR    R1,R11
         USING WORKAREA,R13
*
         L     R3,4(R1)         R3 POINTS TO BUF POINTER
* Another parameter is passed, containing record length,
* but we can ignore this in CMS, since for both F and V
* we can just request a full sized buffer from the OS
* without ill-effect
         PUT   (R2)
         ST    R1,0(R3)
         AIF ('&SYS' EQ 'S370').NOMOD4
         CALL  @@SETM31
.NOMOD4  ANOP
         LA    R15,0
*
RETURNAW DS    0H
         LR    R1,R13
         L     R13,SAVEAREA+4
         LR    R14,R15
*         FREEMAIN R,LV=WORKLEN,A=(R1),SP=SUBPOOL
         LR    R15,R14
         RETURN (14,12),RC=(15)
*
*
*
**********************************************************************
*                                                                    *
*  ASETL - Set length of last record                                 *
*                                                                    *
**********************************************************************
         ENTRY @@ASETL
@@ASETL  SAVE  (14,12),,@@ASETL
         LR    R12,R15
         USING @@ASETL,R12
         L     R2,0(,R1)          R2 contains handle
         L     R3,4(,R1)          R3 points to length of next record
         USING ZDCBAREA,R2
*
         STH   R3,DCBLRECL
*
         RETURN (14,12),RC=0
*
**********************************************************************
*                                                                    *
*  ACLOSE - Close file                                               *
*                                                                    *
**********************************************************************
         ENTRY @@ACLOSE
@@ACLOSE EQU   *
         SAVE  (14,12),,@@ACLOSE
         LR    R12,R15
         USING @@ACLOSE,R12
         LR    R11,R1
         AIF   ('&SYS' EQ 'S390').BELOW3
* CAN'T USE "BELOW" ON MVS 3.8
         GETMAIN R,LV=WORKLEN,SP=SUBPOOL
         AGO   .NOBEL3
.BELOW3  ANOP
         GETMAIN R,LV=WORKLEN,SP=SUBPOOL,LOC=BELOW
.NOBEL3  ANOP
         ST    R13,4(R1)
         ST    R1,8(R13)
         LR    R13,R1
         LR    R1,R11
         USING WORKAREA,R13
*
         L     R2,0(R1)         R2 CONTAINS HANDLE
         MVC   CLOSEMB,CLOSEMAC
*         CLOSE ((R2)),MF=(E,CLOSEMB),MODE=31
* CAN'T USE MODE=31 WITH MVS 3.8
         CLOSE ((R2)),MF=(E,CLOSEMB)
         FREEPOOL ((R2))
         FREEMAIN R,LV=ZDCBLEN,A=(R2),SP=SUBPOOL
         LA    R15,0
*
RETURNAC DS    0H
         LR    R1,R13
         L     R13,SAVEAREA+4
         LR    R7,R15
         FREEMAIN R,LV=WORKLEN,A=(R1),SP=SUBPOOL
         LR    R15,R7
         RETURN (14,12),RC=(15)
         LTORG
* CLOSEMAC CLOSE (),MF=L,MODE=31
* CAN'T USE MODE=31 WITH MVS 3.8
CLOSEMAC CLOSE (),MF=L
CLOSEMLN EQU   *-CLOSEMAC
*
*
*
**********************************************************************
*                                                                    *
*  GETM - GET MEMORY                                                 *
*                                                                    *
**********************************************************************
         ENTRY @@GETM
@@GETM   EQU   *
         SAVE  (14,12),,@@GETM
         LR    R12,R15
         USING @@GETM,R12
*
         L     R2,0(R1)
* THIS LINE IS FOR GCC
         LR    R3,R2
* THIS LINE IS FOR C/370
*         L     R3,0(R2)
         LR    R4,R3
         A     R3,=F'8'
*
* It would be nice to allocate memory with the default
* LOC=RES. However, due to the fact that we need to be
* in AMODE 24 to use things like "GET", it is necessary
* for this program to reside below the line. As such,
* we need to use LOC=ANY to get ATL memory.
*
         AIF   ('&SYS' EQ 'S390').ANYCHKY
         AIF   ('&SYS' EQ 'S370').GOT370
* For S/380, need to switch to AMODE 24 before
* requesting ATL memory
         CALL  @@SETM24
         GETMAIN RU,LV=(R3),SP=SUBPOOL,LOC=ANY
         CALL  @@SETM31
         AGO   .ANYCHKE
.GOT370  ANOP
* CAN'T USE "ANY" ON MVS 3.8
         GETMAIN R,LV=(R3),SP=SUBPOOL
         AGO   .ANYCHKE
.ANYCHKY ANOP
         GETMAIN RU,LV=(R3),SP=SUBPOOL,LOC=ANY
.ANYCHKE ANOP
*
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
*
*
**********************************************************************
*                                                                    *
*  FREEM - FREE MEMORY                                               *
*                                                                    *
**********************************************************************
         ENTRY @@FREEM
@@FREEM  EQU   *
         SAVE  (14,12),,@@FREEM
         LR    R12,R15
         USING @@FREEM,R12
*
         L     R2,0(R1)
         S     R2,=F'8'
         L     R3,0(R2)
         AIF   ('&SYS' EQ 'S370').F370
         FREEMAIN RU,LV=(R3),A=(R2),SP=SUBPOOL
         AGO   .FINFREE
.F370    ANOP
* S/370
         FREEMAIN R,LV=(R3),A=(R2),SP=SUBPOOL
.FINFREE ANOP
*
RETURNFM DS    0H
         RETURN (14,12),RC=(15)
         LTORG
*
*
*
**********************************************************************
*
*  @@SVC202 - ISSUES AN SVC 202 CALL
*
*  E.G. @@SVC202(PARMS,CODE,ERROR)
*
* WHERE :-
*
*  PARMS IS A POINTER TO AN SVC202 PARAMETER LIST
*
*  CODE IS A CODE TO SAY OF &CONTROL IS ON OR OFF
*
* AND ERROR IS SET TO -1
*
**********************************************************************
         ENTRY @@SVC202
@@SVC202 EQU *
         SAVE  (14,12),,@@SVC202
         LR    R12,R15
         USING @@SVC202,R12
         LR    R11,R1           NEED TO RESTORE R1 FOR C
         L     R3,0(R1)         R3 POINTS TO SVC202 PARM LIST
         L     R4,4(R1)         R4 POINTS TO CODE
         L     R5,8(R1)         R5 POINTS TO RETURN CODE
         SR    R6,R6            CLEAR R6
         ST    R6,0(R5)         AND SAVE IN RETURN CODE
         LR    R1,R3
*
         AIF   ('&SYS' EQ 'S390').DOCALL
         SVC   202              ISSUE COMMAND
         DC    AL4(SV202ER)     ERROR
         AGO   .FINCALL
.DOCALL  ANOP
         CMSCALL ERROR=SV202ER
.FINCALL ANOP
*
SV202RT  EQU    *
         LR    R7,R15
         LR    R15,R7
         LR    R1,R11
         RETURN (14,12),RC=(15)
SV202ER  EQU   *
         L     R3,=F'-1'
         ST    R3,0(R5)
         B     SV202RT
         LTORG
*
*
*
**********************************************************************
*
*  @@ATTN@@ - ISSUES AN SVC 202 CALL TO STACK A LINE
*
*  E.G. @@ATTN@@(LINE,LEN,ORDER)
*
* WHERE :-
*
*  LINE IS A POINTER TO LINE TO BE STACKED
*
*  LEN IS THE NUMBER OF CHARACTERS. (<256)
*
*  ORDER IS POINTER TO EITHER FIFO OR LIFO
*
**********************************************************************
         ENTRY @@ATTN@@
@@ATTN@@ EQU *
         SAVE  (14,12),,@@ATTN@@
         LR    R12,R15
         USING @@ATTN@@,R12
         LR    R11,R1           NEED TO RESTORE R1 FOR C
         L     R3,0(R1)         R3 POINTS TO LINE TO STACK
         ST    R3,ATTNLN        SAVE IN 202 PLIST
         L     R4,4(R1)         R4 POINTS TO LENGTH OF LINE
         MVC   ATTNLN,3(R4)     FIDDLE
         L     R5,8(R1)         R5 POINTS TO LIFO OR FIFO
         MVC   ATTNOD,0(R5)
         SR    R6,R6            CLEAR R6
*        ST    R6,0(R5)         AND SAVE IN RETURN CODE
         LA    R1,ATTNPL
         SVC   202              ISSUE COMMAND
         DC    AL4(ATTNER)      ERROR
ATTNRT   EQU    *
         LR     R1,R11
         RETURN (14,12),RC=(15)
ATTNER   EQU    *
*        L      R3,=F'-1'
*        ST     R3,0(R5)
         B      ATTNRT
         LTORG
*
ATTNPL   DS   0D
         DC   CL8'ATTN'
ATTNOD   DC   CL4'XXXX'     WHERE ORDER MAY BE LIFO OR FIFO.
*                            FIFO IS THE DEFAULT
ATTNLN   DC   AL1(0)         LENGTH OF LINE TO BE STACKED
ATTNAD   DC   AL3(ATTNAD)    ADDRESS OF LINE TO BE STACKED
*
*
**********************************************************************
*
*  @@STACKN - RETURNS THE NUMBER OF LINES ON THE CONSOLE STACK
*
*  E.G. @@STACKN(COUNT)
*
* WHERE :-
*
*  COUNT IS A POINTER TO AN INT - NUMBER OF LINES TETURNED
*
*
**********************************************************************
         ENTRY @@STACKN
@@STACKN EQU *
         SAVE  (14,12),,@@STACKN
         LR    R12,R15
         USING @@STACKN,R12
         USING NUCON,R0
         LR    R11,R1           NEED TO RESTORE R1 FOR C
         L     R3,0(R1)         R3 POINTS TO COUNT
         LH    R2,NUMFINRD      R2 HAS COUNT OF LINES ON STACK
         ST    R2,0(R3)         R2 TO COUNT
         LR    R1,R11
         RETURN (14,12),RC=(15)
         LTORG
*
**********************************************************************
*                                                                    *
*  GETCLCK - GET THE VALUE OF THE MVS CLOCK TIMER AND MOVE IT TO AN  *
*  8-BYTE FIELD.  THIS 8-BYTE FIELD DOES NOT NEED TO BE ALIGNED IN   *
*  ANY PARTICULAR WAY.                                               *
*                                                                    *
*  E.G. CALL 'GETCLCK' USING WS-CLOCK1                               *
*                                                                    *
*  THIS FUNCTION ALSO RETURNS THE NUMBER OF SECONDS SINCE 1970-01-01 *
*  BY USING SOME EMPERICALLY-DERIVED MAGIC NUMBERS                   *
*                                                                    *
**********************************************************************
         ENTRY @@GETCLK
@@GETCLK EQU   *
         SAVE  (14,12),,@@GETCLK
         LR    R12,R15
         USING @@GETCLK,R12
*
         L     R2,0(R1)
         STCK  0(R2)
         L     R4,0(R2)
         L     R5,4(R2)
         SRDL  R4,12
         SL    R4,=X'0007D910'
         D     R4,=F'1000000'
         SL    R5,=F'1220'
         LR    R15,R5
*
RETURNGC DS    0H
         RETURN (14,12),RC=(15)
         LTORG
*
*
*
**********************************************************************
*                                                                    *
*  SAVER - SAVE REGISTERS AND PSW INTO ENV_BUF                       *
*                                                                    *
**********************************************************************
         ENTRY @@SAVER
@@SAVER EQU   *
*
         SAVE  (14,12),,@@SAVER    * SAVE REGS AS NORMAL
         LR    R12,R15
         USING @@SAVER,12
         L     R1,0(R1)            * ADDRESS OF ENV TO R1
         L     R2,@@MANSTK         * R2 POINTS TO START OF STACK
         L     R3,@@MANSTK+4       * R3 HAS LENGTH OF STACK
         LR    R5,R3               * AND R5
         LR    R9,R1               * R9 NOW CONTAINS ADDRESS OF ENV
* GET A SAVE AREA
         AIF   ('&SYS' NE 'S370').ANYY
* Can't use "ANY" on VM/370
* Also can't do multiple ANY requests on VM/380 at the moment
         GETMAIN R,LV=(R3),SP=SUBPOOL
         AGO   .ANYE
.ANYY    ANOP
         GETMAIN R,LV=(R3),SP=SUBPOOL,LOC=ANY
.ANYE    ANOP
         ST    R1,0(R9)            * SAVE IT IN FIRST WORK OF ENV
         ST    R5,4(R9)            * SAVE LENGTH IN SECOND WORD OF ENV
         ST    R2,8(R9)            * NOTE WHERE WE GOT IT FROM
         ST    R13,12(R9)          * AND R13
         LR    R4,R1               * AND R4
         MVCL  R4,R2               * COPY SETJMP'S SAVE AREA TO ENV
*        STM   R0,R15,0(R1)               SAVE REGISTERS
*        BALR  R15,0                     GET PSW INTO R15
*        ST    R15,64(R1)                 SAVE PSW
*
RETURNSR DS    0H
         SR    R15,R15              * CLEAR RETURN CODE
         RETURN (14,12),RC=(15)
         ENTRY   @@MANSTK
@@MANSTK DS    2F
         LTORG
*
*
*
**********************************************************************
*                                                                    *
*  LOADR - LOAD REGISTERS AND PSW FROM ENV_BUF                       *
*                                                                    *
**********************************************************************
         ENTRY @@LOADR
@@LOADR EQU   *
*
         BALR  R12,R0
         USING *,12
         L     R1,0(R1)           * R1 POINTS TO ENV
         L     R2,8(R1)           * R2 POINTS TO STACK
         L     R3,4(R1)           * R3 HAS HOW LONG
         LR    R5,R3              * AS DOES R5
         L     R6,24(R1)          * R6 HAS RETURN CODE
         L     R4,0(R1)           * OUR SAVE AREA
         L     R13,12(R1)         * GET OLD STACK POINTER
         MVCL  R2,R4              * AND RESTORE STACK
         ST    R6,24(R1)          * SAVE VAL IN ENV
         L     R6,=F'1'
         ST    R6,20(R1)          * AND SET LONGJ TO 1.
         FREEMAIN R,LV=(R3),A=(R4),SP=SUBPOOL
*        L     R14,16(R1)          * AND RETURN ADDRESS
*        B     RETURNSR            * AND BACK INTO SETJMP
*        L     R15,64(R1)                 RESTORE PSW
*        LM    R0,R15,0(R1)               RESTORE REGISTERS
*        BR    R15                        JUMP TO SAVED PSW
*
RETURNLR DS    0H
         SR    R15,R15            * CLEAR RETURN CODE
         RETURN (14,12),RC=(15)
         LTORG
*
*
*
* S/370 doesn't support switching modes so this code is useless,
* and won't compile anyway because "BSM" is not known.
*
         AIF   ('&SYS' EQ 'S370').NOMODE2 If S/370 we can't switch mode
**********************************************************************
*                                                                    *
*  SETM24 - Set AMODE to 24                                          *
*                                                                    *
**********************************************************************
         DROP  R12
         ENTRY @@SETM24
         USING @@SETM24,R15
@@SETM24 ICM   R14,8,=X'00'       Sure hope caller is below the line
         BSM   0,R14              Return in amode 24
*
**********************************************************************
*                                                                    *
*  SETM31 - Set AMODE to 31                                          *
*                                                                    *
**********************************************************************
         ENTRY @@SETM31
         USING @@SETM31,R15
@@SETM31 ICM   R14,8,=X'80'       Set to switch mode
         BSM   0,R14              Return in amode 31
         LTORG ,
*
.NOMODE2 ANOP  ,                  S/370 doesn't support MODE switching
*
*
*
WORKAREA DSECT
SAVEAREA DS    18F
WORKLEN  EQU   *-WORKAREA
         DCBD  DSORG=PS
         ORG   IHADCB
ZDCBAREA DS    0H
         DS    CL(INDCBLN)
         ORG   IHADCB
         DS    CL(OUTDCBLN)
         DS    0H
EOFR24   DS    CL(EOFRLEN)
JFCBPTR  DS    F
JFCB     DS    0F
*        IEFJFCBN
* z/VM manual says to use 176 characters
         DS    CL176
SAVEADCB DS    18F                Register save area for PUT
         DS    0F
CLOSEMB  DS    CL(CLOSEMLN)
         DS    0F
OPENMB   DS    CL(OPENMLN)
         DS    0F
WOPENMB  DS    CL(WOPENMLN)
RDEOF    DS    1F
ZDCBLEN  EQU   *-ZDCBAREA
RECF     EQU   X'80'                   FIXED RECORD FORMAT
RECV     EQU   X'40'                   VARYING RECORD FORMAT
RECU     EQU   X'C0'                   UNDEFINED RECORD FORMAT
RECUV    EQU   X'40'                   U OR V RECORD FORMAT
RECUF    EQU   X'80'                   U OR F RECORD FORMAT
         NUCON
         END
