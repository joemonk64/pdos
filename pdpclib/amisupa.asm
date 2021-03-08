***********************************************************************
*                                                                     *
*  This program written by Paul Edwards.                              *
*  Released to the public domain                                      *
*                                                                     *
***********************************************************************
***********************************************************************
*                                                                     *
*  amistart - startup code for AmigaOS.                               *
*                                                                     *
*  This uses the Motorola syntax                                      *
*                                                                     *
*  It puts the standard AmigaOS registers containing the command      *
*  length (d0) and command buffer (a0) as well as the AmigaPDOS       *
*  extension register (only visible if running AmigaPDOS) a6,         *
*  containing an alternative SysBase to use (only if d0 is greater    *
*  than or equal to 2 GiB, and in which case, 2 GiB should be         *
*  subtracted from d0 before use) on the stack.                       *
*                                                                     *
*  All this manipulation is left for the C startup code to handle.    *
*                                                                     *
***********************************************************************
*
        section "CODE",code
        xdef ___setj
        xdef ___longj

___amistart:
        movem.l d0/a0/a6,-(sp)
        jsr ___start
        rts

* These need to be implemented

___setj:
        rts

___longj:
        rts


* The below code was automatically generated by fd2pragma so should
* be public domain.

	SECTION	".text",CODE
	XREF	_DOSBase

	XDEF	_Read
_Read:
	XDEF	Read
Read:
	MOVEM.L	D2/D3/A6,-(A7)
	MOVEA.L	_DOSBase,A6
	MOVEM.L	16(A7),D1/D2/D3
	JSR	-042(A6)
	MOVEM.L	(A7)+,D2/D3/A6
	RTS


	SECTION	".text",CODE
	XREF	_DOSBase

	XDEF	_Write
_Write:
	XDEF	Write
Write:
	MOVEM.L	D2/D3/A6,-(A7)
	MOVEA.L	_DOSBase,A6
	MOVEM.L	16(A7),D1/D2/D3
	JSR	-048(A6)
	MOVEM.L	(A7)+,D2/D3/A6
	RTS
