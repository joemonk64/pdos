/******************************************************************************
 * @file            coff.h
 *
 * Released to the public domain.
 *
 * Anyone and anything may copy, edit, publish, use, compile, sell and
 * distribute this work and all its parts in any form for any purpose,
 * commercial and non-commercial, without any restrictions, without
 * complying with any conditions and by any means.
 *****************************************************************************/
#define IMAGE_DOS_HEADER_PARAGRAPH_SIZE 16

struct IMAGE_DOS_HEADER_internal {

    unsigned char Magic[2]; /* "MZ" */
    unsigned short dummy1;
    unsigned short dummy2;
    unsigned short dummy3;
    unsigned short SizeOfHeaderInParagraphs;
    unsigned char dummy4[50];
    unsigned long OffsetToNewEXEHeader;

};

struct IMAGE_DOS_HEADER_file {

    unsigned char Magic[2];
    unsigned char dummy1[2];
    unsigned char dummy2[2];
    unsigned char dummy3[2];
    unsigned char SizeOfHeaderInParagraphs[2];
    unsigned char dummy4[50];
    unsigned char OffsetToNewEXEHeader[4];

};
    
struct coff_header_internal {

    unsigned short Machine;
    unsigned short NumberOfSections;
    
    unsigned long TimeDateStamp;
    unsigned long PointerToSymbolTable;
    unsigned long NumberOfSymbols;
    
    unsigned short SizeOfOptionalHeader;
    unsigned short Characteristics;

};

struct coff_header_file {

    unsigned char Machine[2];
    unsigned char NumberOfSections[2];
    
    unsigned char TimeDateStamp[4];
    unsigned char PointerToSymbolTable[4];
    unsigned char NumberOfSymbols[4];
    
    unsigned char SizeOfOptionalHeader[2];
    unsigned char Characteristics[2];

};

#define     IMAGE_FILE_MACHINE_AMD64                        0x8664
#define     IMAGE_FILE_MACHINE_I386                         0x014C

#define     IMAGE_FILE_RELOCS_STRIPPED                      0x0001
#define     IMAGE_FILE_EXECUTABLE_IMAGE                     0x0002
#define     IMAGE_FILE_LINE_NUMS_STRIPPED                   0x0004 /* Deprecated, should be 0. */
#define     IMAGE_FILE_LOCAL_SYMS_STRIPPED                  0x0008 /* Deprecated, should be 0. */
#define     IMAGE_FILE_32BIT_MACHINE                        0x0100
#define     IMAGE_FILE_DEBUG_STRIPPED                       0x0200
#define     IMAGE_FILE_DLL                                  0x2000

struct optional_header_internal {

    unsigned short Magic;
    unsigned char MajorLinkerVersion;
    unsigned char MinorLinkerVersion;
    unsigned long SizeOfCode;
    unsigned long SizeOfInitializedData;
    unsigned long SizeOfUninitializedData;
    unsigned long AddressOfEntryPoint;
    unsigned long BaseOfCode;
    unsigned long BaseOfData;

#define DEFAULT_EXE_IMAGE_BASE 0x00400000
#define DEFAULT_DLL_IMAGE_BASE 0x10000000
    unsigned long ImageBase;
#define DEFAULT_SECTION_ALIGNMENT 0x1000
    unsigned long SectionAlignment;
#define DEFAULT_FILE_ALIGNMENT 512
    unsigned long FileAlignment;
    unsigned short MajorOperatingSystemVersion;
    unsigned short MinorOperatingSystemVersion;
    unsigned short MajorImageVersion;
    unsigned short MinorImageVersion;
    unsigned short MajorSubsystemVersion;
    unsigned short MinorSubsystemVersion;
    unsigned long Win32VersionValue; /* Reserved, must be 0. */
    unsigned long SizeOfImage; /* Must be multiple of SectionAlignment. */
    unsigned long SizeOfHeaders; /* Rounded up to FileAlignment. */
    unsigned long CheckSum;
    unsigned short Subsystem;
    unsigned short DllCharacteristics;
    unsigned long SizeOfStackReserve;
    unsigned long SizeOfStackCommit;
    unsigned long SizeOfHeapReserve;
    unsigned long SizeOfHeapCommit;
    unsigned long LoaderFlags; /* Reserved, must be 0. */
    unsigned long NumberOfRvaAndSizes;

};

struct optional_header_file {

    unsigned char Magic[2];
    unsigned char MajorLinkerVersion[1];
    unsigned char MinorLinkerVersion[1];
    unsigned char SizeOfCode[4];
    unsigned char SizeOfInitializedData[4];
    unsigned char SizeOfUninitializedData[4];
    unsigned char AddressOfEntryPoint[4];
    unsigned char BaseOfCode[4];
    unsigned char BaseOfData[4];

    unsigned char ImageBase[4];
    unsigned char SectionAlignment[4];
    unsigned char FileAlignment[4];
    unsigned char MajorOperatingSystemVersion[2];
    unsigned char MinorOperatingSystemVersion[2];
    unsigned char MajorImageVersion[2];
    unsigned char MinorImageVersion[2];
    unsigned char MajorSubsystemVersion[2];
    unsigned char MinorSubsystemVersion[2];
    unsigned char Win32VersionValue[4];
    unsigned char SizeOfImage[4];
    unsigned char SizeOfHeaders[4];
    unsigned char CheckSum[4];
    unsigned char Subsystem[2];
    unsigned char DllCharacteristics[2];
    unsigned char SizeOfStackReserve[4];
    unsigned char SizeOfStackCommit[4];
    unsigned char SizeOfHeapReserve[4];
    unsigned char SizeOfHeapCommit[4];
    unsigned char LoaderFlags[4];
    unsigned char NumberOfRvaAndSizes[4];

};

#define IMAGE_NT_OPTIONAL_HDR32_MAGIC 0x10b /* PE32 */
#define PE32_PLUS_MAGIC 0x20b

#define IMAGE_SUBSYSTEM_UNKNOWN 0
#define IMAGE_SUBSYSTEM_NATIVE 1
#define IMAGE_SUBSYSTEM_WINDOWS_GUI 2
#define IMAGE_SUBSYSTEM_WINDOWS_CUI 3

#define IMAGE_DLLCHARACTERISTICS_DYNAMIC_BASE 0x0040
#define IMAGE_DLLCHARACTERISTICS_NX_COMPAT 0x0100

struct IMAGE_DATA_DIRECTORY_internal {
    
    unsigned long VirtualAddress;
    unsigned long Size;
    
};

struct IMAGE_DATA_DIRECTORY_file {
    
    unsigned char VirtualAddress[4];
    unsigned char Size[4];
    
};

struct section_table_entry_internal {

    char Name[8];
    
    unsigned long VirtualSize;
    unsigned long VirtualAddress;
    
    unsigned long SizeOfRawData;
    unsigned long PointerToRawData;
    unsigned long PointerToRelocations;
    unsigned long PointerToLinenumbers;
    
    unsigned short NumberOfRelocations;
    unsigned short NumberOfLinenumbers;
    
    unsigned long Characteristics;

};

struct section_table_entry_file {

    char Name[8];
    
    unsigned char VirtualSize[4];
    unsigned char VirtualAddress[4];
    
    unsigned char SizeOfRawData[4];
    unsigned char PointerToRawData[4];
    unsigned char PointerToRelocations[4];
    unsigned char PointerToLinenumbers[4];
    
    unsigned char NumberOfRelocations[2];
    unsigned char NumberOfLinenumbers[2];
    
    unsigned char Characteristics[4];

};

#define     IMAGE_SCN_TYPE_NOLOAD                           0x00000002
#define     IMAGE_SCN_TYPE_NO_PAD                           0x00000008 /* Obsolete, means the same as IMAGE_SCN_ALIGN_1BYTES. */
#define     IMAGE_SCN_CNT_CODE                              0x00000020
#define     IMAGE_SCN_CNT_INITIALIZED_DATA                  0x00000040
#define     IMAGE_SCN_CNT_UNINITIALIZED_DATA                0x00000080
#define     IMAGE_SCN_LNK_INFO                              0x00000200
#define     IMAGE_SCN_LNK_REMOVE                            0x00000800
#define     IMAGE_SCN_LNK_COMDAT                            0x00001000
#define     IMAGE_SCN_ALIGN_1BYTES                          0x00100000
#define     IMAGE_SCN_ALIGN_2BYTES                          0x00200000
#define     IMAGE_SCN_ALIGN_4BYTES                          0x00300000
#define     IMAGE_SCN_ALIGN_8BYTES                          0x00400000
#define     IMAGE_SCN_ALIGN_16BYTES                         0x00500000
#define     IMAGE_SCN_ALIGN_32BYTES                         0x00600000
#define     IMAGE_SCN_ALIGN_64BYTES                         0x00700000
#define     IMAGE_SCN_ALIGN_128BYTES                        0x00800000
#define     IMAGE_SCN_ALIGN_256BYTES                        0x00900000
#define     IMAGE_SCN_ALIGN_512BYTES                        0x00A00000
#define     IMAGE_SCN_ALIGN_1024BYTES                       0x00B00000
#define     IMAGE_SCN_ALIGN_2048BYTES                       0x00C00000
#define     IMAGE_SCN_ALIGN_4096BYTES                       0x00D00000
#define     IMAGE_SCN_ALIGN_8192BYTES                       0x00E00000
#define     IMAGE_SCN_MEM_SHARED                            0x10000000
#define     IMAGE_SCN_MEM_EXECUTE                           0x20000000
#define     IMAGE_SCN_MEM_READ                              0x40000000
#define     IMAGE_SCN_MEM_WRITE                             0x80000000

struct relocation_entry_internal {

    unsigned long VirtualAddress;
    unsigned long SymbolTableIndex;
    
    unsigned short Type;

};

struct relocation_entry_file {

    unsigned char VirtualAddress[4];
    unsigned char SymbolTableIndex[4];
    
    unsigned char Type[2];

};

#define     IMAGE_REL_I386_ABSOLUTE                         0x0000
#define     IMAGE_REL_I386_DIR16                            0x0001
#define     IMAGE_REL_I386_REL16                            0x0002
#define     IMAGE_REL_I386_DIR32                            0x0006
#define     IMAGE_REL_I386_DIR32NB                          0x0007
#define     IMAGE_REL_I386_REL32                            0x0014

struct symbol_table_entry_internal {

    char Name[8];
    unsigned long Value;
    
    signed short SectionNumber;
    unsigned short Type;
    
    unsigned char StorageClass;
    unsigned char NumberOfAuxSymbols;

};

struct symbol_table_entry_file {

    char Name[8];
    unsigned char Value[4];
    
    unsigned char SectionNumber[2];
    unsigned char Type[2];
    
    unsigned char StorageClass[1];
    unsigned char NumberOfAuxSymbols[1];

};

#define     IMAGE_SYM_UNDEFINED                             0
#define     IMAGE_SYM_ABSOLUTE                              -1
#define     IMAGE_SYM_DEBUG                                 -2

#define     IMAGE_SYM_TYPE_NULL                             0
#define     IMAGE_SYM_DTYPE_NULL                            0

#define     IMAGE_SYM_CLASS_EXTERNAL                        2
#define     IMAGE_SYM_CLASS_STATIC                          3
#define     IMAGE_SYM_CLASS_LABEL                           6
#define     IMAGE_SYM_CLASS_FILE                            103

struct string_table_header_internal {

    unsigned long StringTableSize;

};

struct string_table_header_file {

    unsigned char StringTableSize[4]; /* Including the size of the header itself. */

};

struct IMAGE_EXPORT_DIRECTORY_internal {

    unsigned long ExportFlags; /* Reserved, must be 0. */
    unsigned long TimeDateStamp;
    unsigned short MajorVersion;
    unsigned short MinorVersion;
    unsigned long NameRVA;
    unsigned long OrdinalBase; /* Usually set to 1. */
    unsigned long AddressTableEntries;
    unsigned long NumberOfNamePointers;
    unsigned long ExportAddressTableRVA;
    unsigned long NamePointerRVA;
    unsigned long OrdinalTableRVA;

};

struct IMAGE_EXPORT_DIRECTORY_file {

    unsigned char ExportFlags[4];
    unsigned char TimeDateStamp[4];
    unsigned char MajorVersion[2];
    unsigned char MinorVersion[2];
    unsigned char NameRVA[4];
    unsigned char OrdinalBase[4];
    unsigned char AddressTableEntries[4];
    unsigned char NumberOfNamePointers[4];
    unsigned char ExportAddressTableRVA[4];
    unsigned char NamePointerRVA[4];
    unsigned char OrdinalTableRVA[4];

};

struct EXPORT_Address_Table_internal {
    unsigned long FunctionRVA;
};

struct EXPORT_Address_Table_file {
    unsigned char FunctionRVA[4];
};

struct EXPORT_Name_Pointer_Table_internal {
    unsigned long FunctionNameRVA;
};

struct EXPORT_Name_Pointer_Table_file {
    unsigned char FunctionNameRVA[4];
};

struct EXPORT_Ordinal_Table_internal {
    unsigned short FunctionOrdinal;
};

struct EXPORT_Ordinal_Table_file {
    unsigned char FunctionOrdinal[2];
};

struct IMPORT_Directory_Table_internal {

    unsigned long ImportNameTableRVA;
    unsigned long TimeDateStamp;
    unsigned long ForwarderChain;
    unsigned long NameRVA;
    unsigned long ImportAddressTableRVA;

};

struct IMPORT_Directory_Table_file {

    unsigned char ImportNameTableRVA[4];
    unsigned char TimeDateStamp[4];
    unsigned char ForwarderChain[4];
    unsigned char NameRVA[4];
    unsigned char ImportAddressTableRVA[4];

};

struct IMAGE_BASE_RELOCATION_internal {

    unsigned long RVAOfBlock;
    unsigned long SizeOfBlock;

};

struct IMAGE_BASE_RELOCATION_file {

    unsigned char RVAOfBlock[4];
    unsigned char SizeOfBlock[4];

};

#define BASE_RELOCATION_PAGE_SIZE 4096

/* Base relocation WORD:
 *  high 4 bits = Relocation type
 *  remaining 12 bits = Page offset
 */

#define IMAGE_REL_BASED_ABSOLUTE 0
#define IMAGE_REL_BASED_HIGH 1
#define IMAGE_REL_BASED_LOW 2
#define IMAGE_REL_BASED_HIGHLOW 3

#define IMAGE_ARCHIVE_START "!<arch>\n"

struct IMAGE_ARCHIVE_MEMBER_HEADER_internal {

    char Name[16];
    char Date[12];
    char UserID[6];
    char GroupID[6];
    char Mode[8];
    char Size[10];
    char EndOfHeader[2];

};

struct IMAGE_ARCHIVE_MEMBER_HEADER_file {

    char Name[16];
    char Date[12];
    char UserID[6];
    char GroupID[6];
    char Mode[8];
    char Size[10];
    char EndOfHeader[2];

};

#define IMAGE_ARCHIVE_LINKER_MEMBER_Name "/"