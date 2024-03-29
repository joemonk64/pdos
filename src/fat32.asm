; fat32.asm - pdos boot sector for fat32
;
; This program written by William Bryan
; Released to the public domain

; This code will be loaded to location 07C00h by the BIOS
; We set the stack at 07C00h and make it grow down

; Registers at entry are:
; CS:IP = 07c00H, probably 0000:7c00
; DL = drive number
; nothing else guaranteed

; We should store the drive number in BPB[25], since
; pload is expecting it there.  pload also expects
; that the CS:IP will have an IP of 0 when it is called.
; It also expects some sort of stack to be set up.

% .model memodel

.code

org 0100h
top:

public start
start proc

;Jump over our BPB
jmp bypass
nop

;Lets make our BPB
; offset 3
OEMName           db 'PDOS x.x'
; offset b (should be considered offset 0 in other code)
BytesPerSector    dw 512   ;512 bytes is normal ;)
; offset d
SectorsPerClustor db 1     ;Sector == cluster
; offset e
ReservedSectors   dw 1     ;Reserve the boot sector
; offset 10
FatCount          db 2     ;2 copies of the fat is standard
; offset 11
RootEntries       dw 224   ;# of root entries
; offset 13
TotalSectors16    dw 0     ;# of sectors on the disk
; offset 15
MediaType         db 0f8h  ;Ignored for most things
; offset 16
FatSize16         dw 0     ;Size of a single fat in sectors
; offset 18
SectorsPerTrack   dw 0     ;Sectors Per Track
; offset 1a
Heads             dw 0     ;Head count
; offset 1c (DOS 3.31+)
HiddenSectorsLow   dw 0    ;Hidden sector count
HiddenSectorsHigh  dw 0    ;Hidden sector count
; offset 20
TotalSectors32Low  dw 0    ;# of sectors, 32-bit!
TotalSectors32High dw 0    ;# of sectors, 32-bit!

;Fat32 section
; offset 24
FatSize32Low        dw 0               ; Size of a single Fat in sectors
FatSize32High       dw 0               ; Size of a single Fat in sectors
; offset 28
ExtFlags            dw 0               ; Used for mirroring, leave this alone
; offset 2a
FSVersion           dw 0               ; Our version is 0.0 :)
; offset 2c
RootClusterLow      dw 2               ; Cluster # of root, normally 2
RootClusterHigh     dw 0
; offset 30
FSInfo              dw 0               ; Sector # of FS Info Block
; offset 32
BkBootSector        dw 0               ; Backup boot sector... unused for us ;)
; offset 34
Reserved1           db 12 dup(0)       ; Reserve 12 bytes
; offset 40
DriveNum            db 0               ;We don't care for this
; offset 41
Reserved2           db 0               ;Reserved
; offset 42
BootSig             db 29h             ;0x29 - next 3 things exist
; offset 43
VolumeID            dd 0                ;Volume's ID, we don't care for it ;)
; offset 47
VolumeLabel         db 'PDOS Volume'    ;11 bytes
; offset 52
FileSystem          db 'FAT32   '      ;File system

; offset Hex 59h, Decimal 89 - Code Start
bypass:
jmp bypass2

; Used to store our boot disk when we first start
; Some software is dependent on the second byte of the boot sector
; to determine the FAT size (ie they see how far the jmp instruction
; goes), so this variable can't come immediately after the BPB.
BootDisk db 0

bypass2:
;Always clear direction bit first, just incase bios leaves it unset
cld
;This should grab our current instruction pointer
call GetIP
GetIP:
pop ax
and ax, 0ff00h
cmp ax, 0100h
je Skip
;Patch DS here if we aren't a com file
mov ax, 07b0h
mov ds, ax
mov ax, 0
mov es, ax
mov es:[07C02h],dl  ; store boot disk in nop
Skip:
xor ax, ax   ;Zeroize ax
mov ss, ax
mov sp, 07c00h

mov  [BootDisk], dl ;Store our boot disk

; get disk geometry from BIOS instead of relying on values
; stored at format time, because the disk may have been moved
; to a different machine with a different faking mechanism
 mov ah, 08h
 mov di, 0
; es should already be 0
; dl is already set
 push es  ; preserve
 int 13h
 jc ignorec   ; if it fails, just use the values at format time

 and cl,3fh
 mov ch, 0
 mov [SectorsPerTrack], cx

; dh currently has maximum head number, which are counted
; from 0, so the number of heads is 1 more than that, and
; may overflow a single byte
 mov dl,dh
 mov dh,0
 add dx,1
 mov [Heads], dx

ignorec:
 pop es

call CalculateLocation ; Gets our data sector into dx:ax

; Store our calculation
mov [DataStartLow], ax
mov [DataStartHigh], dx

mov bx, 7c00h + 512    ; Load this right after us for now
call ReadSingleSector  ; Read the first DataEntry of our root directory so we can determine our first file location...

;Cluster high = 0x14 (20)
;Cluster low = 0x1A (26)
mov si, word ptr es:[7c00h + 512 + 14h]   ; Store high word of cluster in si
mov di, word ptr es:[7c00h + 512 + 1Ah]   ; Store low word of cluster in di

mov bl, byte ptr es:[7c00h + 512 + 0bh] ; file attribute
and bl, 08h
jz already

; previous entry was a volume label. let's hope this is the real deal instead
mov si, word ptr es:[7c00h + 512 + 20h + 14h]   ; Store high word of cluster in si
mov di, word ptr es:[7c00h + 512 + 20h + 1Ah]   ; Store low word of cluster in di

already:

call CalculateCluster ; Take our cluster # stored in si:di, and return sector in dx:ax

; If you are doing debugging (with dumpbuf/dumplong), you will need
; to load more sectors than this, and may as well do the maximum of 58
; Microsoft C 6.0 bumped the requirement up to 19
; I suspect it is because pload is making use of
; routines in dossupa.asm. Needs to be investigated
ifdef MSC6
mov cx, 19
else
mov cx, 9 ; Load 9 sectors (was 55, was 58, was 3)
endif
; I dropped down to 55 in case we have a cdrom with 2048 byte
; sectors of which just the first 512 bytes are populated
mov bx, 0700h ;Loaded to es:bx (0x00:0x0700)
call ReadSectors ;Read the actual sectors

; pload is expecting the boot disk in dx
; Maybe it should be pushed onto the stack instead
mov  dx, 0
mov  dl, [BootDisk]

ifdef MSC6
mov  ax, 0071h
else
mov  ax, 0070h
endif
push ax
mov  ax, 0
push ax
retf
start endp

;Calculate the location of a cluster on our disk
;Inputs:
; si:di - Cluster we we want
;Outputs:
; dx:ax - sector to load
CalculateCluster proc

push di
push si
sub di, [RootClusterLow]       ; Subtract the root cluster number
sbb si, [RootClusterHigh]      ; Borrow if necessary

xor dx, dx
mov ax, dx

push cx
mov cl, [SectorsPerClustor]
; Multiply cluster by sectors per cluster
repeat_loop:
add ax, di
adc dx, si
dec cl
jnz repeat_loop

pop cx

; Add the start of our data location in
add ax, [DataStartLow]
adc dx, [DataStartHigh]

pop si
pop di

ret
CalculateCluster endp

;Calculates the location of our Data Entry table (after Fat, after hidden sectors, etc)
;Inputs:
; (None)
;Outputs:
; dx:ax - sector to load
CalculateLocation proc
push cx                    ; Save this value so we don't mess it up
xor dx, dx                 ; Zeroize dx
mov ax, dx                 ; Zeroize ax
mov cl, [FatCount]         ; # of copies of the FAT

repeat_loop2:              ; FatSize32 * FatCount = total size of our fat table(s)
add ax, [FatSize32Low]     ; Low word
adc dx, [FatSize32High]    ; High word
dec cl
jnz repeat_loop2           ; When cl is zero we are done

pop cx

add ax, [HiddenSectorsLow]     ; Add the low word of hidden sectors (partition start)
adc dx, [HiddenSectorsHigh]    ; Add the high word of hidden sectors (partition start)
add ax, [ReservedSectors]
adc dx, 0                      ; Add our carry if one happened

ret
CalculateLocation endp

;Convert LBA -> CHS
;Inputs:
; dx:ax - sector (32-bit value)
;Outputs:
; Standard CHS format for use by int 13h
; INT 13h allows 256 heads, 1024 cylinders, and 63 sectors max
; Cylinder = LBA / (Heads_Per_Cylinder * Sectors_Per_Track)
; Temp = LBA % (Heads_Per_Cylinder * Sectors_Per_Track)
; Heads = Temp / Sectors_Per_Track
; Sector = Temp % Sectors_Per_Track + 1
; CH = Cylinder (Lowest 8-bits)
; CL = Lowest 6 bits contain Sector. Highest 2 bits are highest
;      2 bits of cylinder number
; DH = Head
; Div = Dx:AX / value
;  AX = Quotient (Result)
;  DX = Remainder (Leftover, Modulus)
Lba2Chs proc
 div  word ptr [SectorsPerTrack]
; AX = DX:AX / SectorsPerTrack (Temp)
; DX = DX:AX % SectorsPerTrack (Sector)
 mov  ch, 0
 mov  cl,  dl     ;Sector #
 inc  cl ;Add one since sector starts at 1, not zero
 xor  dx, dx       ;Zero out dx, so now we are just working on AX
 div  word ptr [Heads]
; AX = AX / Heads ( = Cylinder)
; DX = AX % Heads ( = Head)
 mov  dh,  dl     ;Mov dl into dh (dh=head)
 push dx
 mov  dh, al ; save lower 8 bits of cylinder number
 mov  al, 0  ; clear lower 8 bits of cylinder number
;Have to save cx because 8086 needs it to be able to shr!
 push cx
 mov  cl, 2
 shr  ax, cl
 pop  cx
 mov  ah, dh
 pop  dx
 or   cx, ax
 ret
Lba2Chs endp



;Used to reset our drive before we use it
;Inputs:
; (None)
;Outputs:
; (None)
ResetDrive proc
 push ax
 push dx
 RetryReset:
  mov  dl, [BootDisk]
  mov  ax,  0
  int  013h
  jc  RetryReset    ;Didn't reset, lets try again
 pop  dx
 pop  ax
 ret
ResetDrive endp

;Read a single sector from a floppy disk
;Inputs:
; dx:ax - sector to read
; es:bx - dest
;Outputs:
; (None)
ReadSingleSector proc
 push ax
 push bx
 push cx
 push dx
 push es
 call Lba2Chs     ;Grab our CHS
 RetryRead:
  mov  dl, [BootDisk]  ;Grab our boot disk
  mov  ax, 0201h   ;Read function, one sector
  int  13h
  jnc  fin
 call ResetDrive   ;Get drive ready..
 jmp   RetryRead
fin:
 pop es
 pop dx
 pop cx
 pop bx
 pop ax
 ret
ReadSingleSector endp

;Read multiple sectors
;Inputs:
; dx:ax - sector to read
; es:bx - dest
; cx - # of sectors
;Outputs:
; (None)
ReadSectors proc
 push ax
 push bx
 ReadNextSector:
  call ReadSingleSector
  add  bx,  [BytesPerSector] ;Next sector
  inc  ax                    ;Next LBA
  jnc SkipInc                ;If no overflow, don't increment dx
   inc dx                    ;If we had a carry, we must increment dx
SkipInc:
  loop ReadNextSector        ;Until cx = 0
 pop  bx
 pop  ax
 ret
ReadSectors endp

DataStartLow dw 0
DataStartHigh dw 0


; routine copied from public domain mon86 and modified
dumpcx proc
;Print out 16-bit value in CX in hex

OUT16:
push ax
push bx
	MOV	AL,CH		;High-order byte first
	CALL	HEX
	MOV	AL,CL		;Then low-order byte
        CALL    HEX
	MOV	AL," "
	CALL	OUT2
pop bx
pop ax
        RET

;Output byte in AL as two hex digits

HEX:
	MOV	BL,AL		;Save for second digit
;Shift high digit into low 4 bits
	PUSH	CX
	MOV	CL,4
	SHR	AL,CL
	POP	CX

	CALL	DIGIT		;Output first digit
HIDIG:
	MOV	AL,BL		;Now do digit saved in BL
DIGIT:
	AND	AL,0FH		;Mask to 4 bits
;Trick 6-byte hex conversion works on 8086 too.
	ADD	AL,90H
	DAA
	ADC	AL,40H
	DAA

;Console output of character in AL

OUT2:
push bx
mov bx, 0

mov ah, 0eh
int 10h
pop bx
ret

dumpcx endp


org 02feh
lastword dw 0aa55h

end top
