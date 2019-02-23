/*********************************************************************/
/*                                                                   */
/*  This Program Written by Alica Okano.                             */
/*  Released to the Public Domain as discussed here:                 */
/*  http://creativecommons.org/publicdomain/zero/1.0/                */
/*                                                                   */
/*********************************************************************/
/*********************************************************************/
/*                                                                   */
/*  exeload.h - functions for loading executables                    */
/*                                                                   */
/*********************************************************************/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "exeload.h"
#include "support.h"
#include "a_out.h"
#include "elf.h"

static int exeloadLoadAOUT(EXELOAD *exeload, FILE *fp);
static int exeloadLoadELF(EXELOAD *exeload, FILE *fp);
static int exeloadLoadMZ(EXELOAD *exeload, FILE *fp);

int exeloadDoload(EXELOAD *exeload, char *prog)
{
    FILE *fp;
    int ret;

    exeload->memStart = 0;
    fp = fopen(prog, "rb");
    /* Tries to load the executable as different formats.
     * Returned 0 means the executable was loaded successfully.
     * 1 means it is not the format the function loads.
     * 2 means correct format, but error occured. */
    ret = exeloadLoadAOUT(exeload, fp);
    if (ret == 1) ret = exeloadLoadELF(exeload, fp);
    if (ret == 1) ret = exeloadLoadMZ(exeload, fp);
    if (ret != 0)
    {
        if (exeload->memStart) free(exeload->memStart);
        fclose(fp);
        return (1);
    }

    return (0);
}

static int exeloadLoadAOUT(EXELOAD *exeload, FILE *fp)
{
    int doing_zmagic = 0;
    int doing_nmagic = 0;
    struct exec firstbit;
    unsigned int headerLen;
    unsigned char *header = NULL;
    unsigned long exeLen;
    unsigned char *exeStart;
    unsigned int sp;
    unsigned char *bss;

    rewind(fp);
    if (fread(&firstbit, 1, sizeof(firstbit), fp) != sizeof(firstbit))
    {
        return (1);
    }
    if ((firstbit.a_info & 0xffff) == ZMAGIC)
    {
        doing_zmagic = 1;
    }
    else if ((firstbit.a_info & 0xffff) == NMAGIC)
    {
        doing_nmagic = 1;
    }
    else if ((firstbit.a_info & 0xffff) == QMAGIC)
    {
        printf("a.out QMAGIC is not supported\n");
        return (2);
    }
    else if ((firstbit.a_info & 0xffff) != OMAGIC)
    {
        /* The file is not A.OUT. */
        return (1);
    }
    if (doing_zmagic)
    {
        headerLen = N_TXTOFF(firstbit);
        header = malloc(headerLen);
        memcpy(header, &firstbit, sizeof firstbit);
        fread(header + sizeof firstbit, 1, headerLen - sizeof firstbit, fp);
    }

    if (doing_zmagic || doing_nmagic)
    {
        exeLen = N_BSSADDR(firstbit) - N_TXTADDR(firstbit) + firstbit.a_bss;
    }
    else
    {
        exeLen = firstbit.a_text + firstbit.a_data + firstbit.a_bss;
    }
    /* Allocates memory for the control structures and the process. */
    exeload->memStart = malloc(exeLen
                               + exeload->extra_memory_before
                               + exeload->extra_memory_after);
    exeload->exeStart = exeload->memStart + exeload->extra_memory_before;
    exeStart = exeload->exeStart;

    fread(exeStart, 1, firstbit.a_text, fp);
    if (doing_zmagic || doing_nmagic)
    {
        fread(exeStart + N_DATADDR(firstbit) - N_TXTADDR(firstbit), 1,
              firstbit.a_data, fp);
    }
    else
    {
        fread(exeStart + firstbit.a_text, 1, firstbit.a_data, fp);
    }
    /* Closes the file for ZMAGIC and NMAGIC as there is no need for it now. */
    if (doing_zmagic || doing_nmagic) fclose(fp);
    if (doing_zmagic) free(header);

    /* initialise BSS */
    if (doing_zmagic || doing_nmagic)
    {
        bss = exeStart + N_BSSADDR(firstbit);
    }
    else
    {
        bss = exeStart + firstbit.a_text + firstbit.a_data;
    }
    memset(bss, '\0', firstbit.a_bss);
    if (doing_zmagic || doing_nmagic)
    {
        sp = N_BSSADDR(firstbit) + firstbit.a_bss + 0x8000;
    }
    else
    {
        sp = (unsigned int)bss + firstbit.a_bss + exeload->stack_size;
    }
    /* Relocations. */
    if (!doing_zmagic && !doing_nmagic)
    {
        unsigned int *corrections;
        unsigned int i;
        unsigned int offs;
        unsigned int type;
        unsigned int zapdata;
        unsigned char *zap;

        zap = exeStart;
        zapdata = (unsigned int)ADDR2ABS(zap);
        if (firstbit.a_trsize != 0)
        {
            corrections = malloc(firstbit.a_trsize);
            if (corrections == NULL)
            {
                printf("insufficient memory %lu\n", firstbit.a_trsize);
                return (2);
            }
            fread(corrections, 1, firstbit.a_trsize, fp);
            for (i = 0; i < firstbit.a_trsize / 4; i += 2)
            {
                offs = corrections[i];
                type = corrections[i + 1];
                if (((type >> 24) & 0xff) != 0x04)
                {
                    continue;
                }
                *(unsigned int *)(zap + offs) += zapdata;
            }
            free(corrections);
        }
        if (firstbit.a_drsize != 0)
        {
            corrections = malloc(firstbit.a_drsize);
            if (corrections == NULL)
            {
                printf("insufficient memory %lu\n", firstbit.a_drsize);
                return (2);
            }
            fread(corrections, 1, firstbit.a_drsize, fp);
            zap = exeStart + firstbit.a_text;
            for (i = 0; i < firstbit.a_drsize / 4; i += 2)
            {
                offs = corrections[i];
                type = corrections[i + 1];
                if (((type >> 24) & 0xff) != 0x04)
                {
                    continue;
                }
                *(unsigned int *)(zap + offs) += zapdata;
            }
            free(corrections);
        }
        firstbit.a_entry += (unsigned long)ADDR2ABS(exeStart);
        fclose(fp);
    }

    if (doing_zmagic || doing_nmagic)
    {
        /* a.out ZMAGIC and NMAGIC must be loaded at 0x10000. */
        exeStart = exeStart - 0x10000;
        exeStart = ADDR2ABS(exeStart);
        exeload->entry_point = firstbit.a_entry;
        exeload->sp = sp;
        exeload->cs_address = (unsigned long)exeStart;
        exeload->ds_address = (unsigned long)exeStart;
    }
    else
    {
        /* a.out OMAGIC can be loaded anywhere. */
        sp = (unsigned int)ADDR2ABS(sp);
        exeload->entry_point = firstbit.a_entry;
        exeload->sp = sp;
        exeload->cs_address = 0;
        exeload->ds_address = 0;
    }

    return (0);
}

static int exeloadLoadELF(EXELOAD *exeload, FILE *fp)
{
    int doing_elf_rel = 0;
    int doing_elf_exec = 0;
    Elf32_Ehdr *elfHdr;
    Elf32_Phdr *program_table = NULL;
    Elf32_Phdr *segment;
    Elf32_Shdr *section_table = NULL;
    Elf32_Shdr *section;
    unsigned char *elf_other_sections;
    Elf32_Addr lowest_p_vaddr = 0;
    Elf32_Word lowest_segment_align = 0;
    unsigned char *exeStart;
    unsigned char *bss;
    unsigned int sp;
    unsigned long exeLen;
    unsigned char firstbit[4];

    rewind(fp);
    if ((fread(firstbit, 1, sizeof(firstbit), fp) != sizeof(firstbit))
        || (memcmp((&firstbit), "\x7f""ELF", 4) != 0))
    {
        return (1);
    }
    {
        int elf_invalid = 0;

        /* Loads entire ELF header into memory. */
        elfHdr = malloc(sizeof(Elf32_Ehdr));
        if (elfHdr == NULL)
        {
            printf("Insufficient memory for ELF header\n");
            return (2);
        }
        rewind(fp);
        if (fread(elfHdr, 1,
                  sizeof(Elf32_Ehdr), fp)
            != sizeof(Elf32_Ehdr))
        {
            printf("Error occured while reading ELF header\n");
            free(elfHdr);
            return (2);
        }

        /* Checks e_ident if the program can be used on PDOS-32. */
        if (elfHdr->e_ident[EI_CLASS] != ELFCLASS32)
        {
            if (elfHdr->e_ident[EI_CLASS] == ELFCLASS64)
            {
                printf("64-bit ELF is not supported\n");
            }
            else if (elfHdr->e_ident[EI_CLASS] == ELFCLASSNONE)
            {
                printf("Invalid ELF class\n");
            }
            else
            {
                printf("Unknown ELF class: %u\n", elfHdr->e_ident[EI_CLASS]);
            }
            elf_invalid = 1;
        }
        if (elfHdr->e_ident[EI_DATA] != ELFDATA2LSB)
        {
            if (elfHdr->e_ident[EI_DATA] == ELFDATA2MSB)
            {
                printf("Big-endian ELF encoding is not supported\n");
            }
            else if (elfHdr->e_ident[EI_DATA] == ELFDATANONE)
            {
                printf("Invalid ELF data encoding\n");
            }
            else
            {
                printf("Unknown ELF data encoding: %u\n",
                       elfHdr->e_ident[EI_DATA]);
            }
            elf_invalid = 1;
        }
        if (elfHdr->e_ident[EI_OSABI] != ELFOSABI_NONE)
        {
            printf("No OS or ABI specific extensions for ELF supported\n");
            elf_invalid = 1;
        }
        /* Checks other parts of the header if the file can be loaded. */
        if (elfHdr->e_type == ET_REL)
        {
            doing_elf_rel = 1;
        }
        else if (elfHdr->e_type == ET_EXEC)
        {
            doing_elf_exec = 1;
        }
        else
        {
            printf("Only ELF relocatable and executable "
                   "files are supported\n");
            elf_invalid = 1;
        }
        if (elfHdr->e_machine != EM_386)
        {
            printf("Only Intel 386 architecture is supported\n");
            elf_invalid = 1;
        }
        if (doing_elf_exec)
        {
            if (elfHdr->e_phoff == 0 || elfHdr->e_phnum == 0)
            {
                printf("Executable file is missing Program Header Table\n");
                elf_invalid = 1;
            }
            if (elfHdr->e_phnum >= SHN_LORESERVE)
            {
                printf("Reserved indexes for e_phnum are not supported\n");
                printf("e_phnum is %04x\n", elfHdr->e_phnum);
                elf_invalid = 1;
            }
            if (elfHdr->e_phentsize != sizeof(Elf32_Phdr))
            {
                printf("Program Header Table entries have unsupported size\n");
                printf("e_phentsize: %u supported size: %lu\n",
                       elfHdr->e_phentsize, sizeof(Elf32_Phdr));
                elf_invalid = 1;
            }
        }
        else if (doing_elf_rel)
        {
            if (elfHdr->e_shoff == 0 || elfHdr->e_shnum == 0)
            {
                printf("Relocatable file is missing Section Header Table\n");
                elf_invalid = 1;
            }
            if (elfHdr->e_shnum >= SHN_LORESERVE)
            {
                printf("Reserved indexes for e_shnum are not supported\n");
                printf("e_shnum is %04x\n", elfHdr->e_shnum);
                elf_invalid = 1;
            }
            if (elfHdr->e_shentsize != sizeof(Elf32_Shdr))
            {
                printf("Section Header Table entries have unsupported size\n");
                printf("e_shentsize: %u supported size: %lu\n",
                       elfHdr->e_shentsize, sizeof(Elf32_Shdr));
                elf_invalid = 1;
            }
        }
        if (elf_invalid)
        {
            /* All problems with ELF header are reported
             * and loading is stopped. */
            printf("This ELF file cannot be loaded\n");
            free(elfHdr);
            return (2);
        }
        /* Loads Program Header Table if it is present. */
        if (!(elfHdr->e_phoff == 0 || elfHdr->e_phnum == 0))
        {
            program_table = malloc(elfHdr->e_phnum * elfHdr->e_phentsize);
            if (program_table == NULL)
            {
                printf("Insufficient memory for ELF Program Header Table\n");
                free(elfHdr);
                return (2);
            }
            fseek(fp, elfHdr->e_phoff, SEEK_SET);
            if (fread(program_table, 1,
                      elfHdr->e_phnum * elfHdr->e_phentsize, fp)
                != (elfHdr->e_phnum * elfHdr->e_phentsize))
            {
                printf("Error occured while reading "
                       "ELF Program Header Table\n");
                free(elfHdr);
                free(program_table);
                return (2);
            }
        }
        /* Loads Section Header Table if it is present. */
        if (!(elfHdr->e_shoff == 0 || elfHdr->e_shnum == 0))
        {
            section_table = malloc(elfHdr->e_shnum * elfHdr->e_shentsize);
            if (section_table == NULL)
            {
                printf("Insufficient memory for ELF Section Header Table\n");
                free(elfHdr);
                return (2);
            }
            fseek(fp, elfHdr->e_shoff, SEEK_SET);
            if (fread(section_table, 1,
                      elfHdr->e_shnum * elfHdr->e_shentsize, fp)
                != (elfHdr->e_shnum * elfHdr->e_shentsize))
            {
                printf("Error occured while reading "
                       "ELF Section Header Table\n");
                free(elfHdr);
                free(section_table);
                return (2);
            }
        }
    }

    if (doing_elf_rel || doing_elf_exec)
    {
        /* Calculates how much memory is needed
         * and allocates memory for sections used only for loading. */
        unsigned long otherLen = 0;

        exeLen = 0;
        if (doing_elf_exec)
        {
            Elf32_Addr highest_p_vaddr = 0;
            Elf32_Word highest_segment_memsz = 0;

            for (segment = program_table;
                 segment < program_table + elfHdr->e_phnum;
                 segment++)
            {
                if (segment->p_type == PT_LOAD)
                {
                    if (!lowest_p_vaddr || lowest_p_vaddr > segment->p_vaddr)
                    {
                        lowest_p_vaddr = segment->p_vaddr;
                        lowest_segment_align = segment->p_align;
                    }
                    if (highest_p_vaddr < segment->p_vaddr)
                    {
                        highest_p_vaddr = segment->p_vaddr;
                        highest_segment_memsz = segment->p_memsz;
                    }
                }
            }
            exeLen = highest_p_vaddr - lowest_p_vaddr + highest_segment_memsz;
            if (lowest_segment_align > 1)
            {
                /* Ensures alignment of the lowest segment.
                 * 0 and 1 mean no alignment restrictions. */
                exeLen += lowest_segment_align;
            }
        }
        if (section_table)
        {
            for (section = section_table;
                 section < section_table + elfHdr->e_shnum;
                 section++)
            {
                unsigned long section_size = section->sh_size;
                if (section->sh_addralign > 1)
                {
                    /* Some sections must be aligned
                     * on sh_addralign byte boundaries.
                     * 0 and 1 mean no alignment restrictions. */
                    section_size += section->sh_addralign;
                }
                if (section->sh_flags & SHF_ALLOC)
                {
                    /* Section is needed while the program is running,
                     * but if we are loading an executable file,
                     * the memory is already counted
                     * using Program Header Table. */
                    if (doing_elf_exec) continue;
                    exeLen += section_size;
                }
                else
                {
                    /* Section is used only for loading. */
                   otherLen += section_size;
                }
            }
            elf_other_sections = malloc(otherLen);
            if (elf_other_sections == NULL)
            {
                printf("Insufficient memory to load ELF sections\n");
                free(elfHdr);
                free(section_table);
                return (2);
            }
        }
    }
    /* Allocates memory for the control structures and the process. */
    exeload->memStart = malloc(exeLen
                               + exeload->extra_memory_before
                               + exeload->extra_memory_after);
    exeload->exeStart = exeload->memStart + exeload->extra_memory_before;
    exeStart = exeload->exeStart;

    if (doing_elf_rel || doing_elf_exec)
    {
        /* Loads all sections of ELF file with proper alignment,
         * clears all SHT_NOBITS sections and stores the addresses
         * in sh_addr of each section.
         * bss and sp are set now too. */
        unsigned char *exe_addr = exeStart;
        unsigned char *other_addr = elf_other_sections;

        bss = 0;
        if (doing_elf_exec)
        {
            /* Aligns the exeStart on lowest segment alignment boundary. */
            /*exeStart = (unsigned char *)((((unsigned long)exeStart
                                           / lowest_segment_align) + 1)
                                         * lowest_segment_align);*/
            /* +++Enable aligning. */
            for (segment = program_table;
                 segment < program_table + elfHdr->e_phnum;
                 segment++)
            {
                if (segment->p_type == PT_LOAD)
                {
                    exe_addr = exeStart + (segment->p_vaddr - lowest_p_vaddr);

                    fseek(fp, segment->p_offset, SEEK_SET);
                    if (fread(exe_addr, 1, segment->p_filesz, fp)
                        != (segment->p_filesz))
                    {
                        printf("Error occured while reading ELF segment\n");
                        free(program_table);
                        if (section_table)
                        {
                            free(section_table);
                            free(elf_other_sections);
                        }
                        return (2);
                    }
                    
                    /* Bytes that are not present in file,
                     * but must be present in memory must be set to 0. */
                    if (segment->p_filesz < segment->p_memsz)
                    {
                        bss = exe_addr + (segment->p_filesz);
                        memset(bss, '\0',
                               segment->p_memsz - segment->p_filesz);
                    }
                }
            }
        }
        
        for (section = section_table;
             section < section_table + elfHdr->e_shnum;
             section++)
        {
            if (section->sh_flags & SHF_ALLOC)
            {
                /* If we are loading executable file,
                 * SHF_ALLOC sections are already loaded in segments. */
                if (doing_elf_exec) continue;
                if (section->sh_addralign > 1)
                {
                    exe_addr = (void *)((((unsigned long)exe_addr
                                          / (section->sh_addralign)) + 1)
                                        * (section->sh_addralign));
                }
                if (section->sh_type != SHT_NOBITS)
                {
                    fseek(fp, section->sh_offset, SEEK_SET);
                    if (fread(exe_addr, 1, section->sh_size, fp)
                        != (section->sh_size))
                    {
                        printf("Error occured while reading ELF section\n");
                        free(elfHdr);
                        if (program_table) free(program_table);
                        free(section_table);
                        free(elf_other_sections);
                        return (2);
                    }
                }
                else
                {
                    /* The section is probably BSS. */
                    if (bss != 0)
                    {
                        printf("Multiple SHT_NOBITS with SHF_ALLOC "
                               "present in ELF file\n");
                    }
                    bss = exe_addr;
                    /* All SHT_NOBITS should be cleared to 0. */
                    memset(bss, '\0', section->sh_size);
                }
                /* sh_addr is 0 in relocatable files,
                 * so we can use it to store the real address. */
                section->sh_addr = (Elf32_Addr)exe_addr;
                exe_addr += section->sh_size;
            }
            else
            {
                if (section->sh_addralign > 1)
                {
                    other_addr = (void *)((((unsigned long)other_addr
                                            / (section->sh_addralign)) + 1)
                                          * (section->sh_addralign));
                }
                if (section->sh_type != SHT_NOBITS)
                {
                    fseek(fp, section->sh_offset, SEEK_SET);
                    if (fread(other_addr, 1, section->sh_size, fp)
                        != (section->sh_size))
                    {
                        printf("Error occured while reading ELF section\n");
                        free(elfHdr);
                        if (program_table) free(program_table);
                        free(section_table);
                        free(elf_other_sections);
                        return (2);
                    }
                }
                else
                {
                    /* All SHT_NOBITS should be cleared to 0. */
                    memset(other_addr, '\0', section->sh_size);
                }
                /* sh_addr is 0 in relocatable files,
                 * so we can use it to store the real address. */
                section->sh_addr = (Elf32_Addr)other_addr;
                other_addr += section->sh_size;
            }
        }
        /* Sets the stack pointer. */
        if (doing_elf_exec)
        {
            sp = (unsigned long)exeStart + exeLen + exeload->stack_size;
        }
        else
        {
            sp = (unsigned long)exe_addr + exeload->stack_size;
        }
    }
    /* Program was successfully loaded from the file,
     * no more errors can occur. */
    fclose(fp);

    /* Relocations. */
    if (doing_elf_rel)
    {
        for (section = section_table;
             section < section_table + elfHdr->e_shnum;
             section++)
        {
            if (section->sh_type == SHT_RELA)
            {
                printf("ELF Relocations with explicit addend "
                       "are not supported\n");
            }
            else if (section->sh_type == SHT_REL)
            {
                /* sh_link specifies the symbol table
                 * and sh_info section being modified. */
                Elf32_Sym *sym_table = (Elf32_Sym *)(section_table
                                        + (section->sh_link))->sh_addr;
                unsigned char *target_base = (unsigned char *)(section_table
                                             + (section->sh_info))->sh_addr;
                Elf32_Rel *startrel = (Elf32_Rel *)section->sh_addr;
                Elf32_Rel *currel;

                if (section->sh_entsize != sizeof(Elf32_Rel))
                {
                    printf("Invalid size of relocation entries in ELF file\n");
                    continue;
                }

                for (currel = startrel;
                     currel < (startrel
                               + ((section->sh_size) / (section->sh_entsize)));
                     currel++)
                {
                    long *target = (long *)(target_base + currel->r_offset);
                    Elf32_Sym *symbol = (sym_table
                                         + ELF32_R_SYM(currel->r_info));
                    Elf32_Addr sym_value = 0;

                    if (ELF32_R_SYM(currel->r_info) != STN_UNDEF)
                    {
                        if (symbol->st_shndx == SHN_ABS)
                        {
                            /* Absolute symbol, stores absolute value. */
                            sym_value = symbol->st_value;
                        }
                        else if (symbol->st_shndx == SHN_UNDEF)
                        {
                            /* Dynamic linker should fill this symbol. */
                            printf("Undefined symbol in ELF file\n");
                            continue;
                        }
                        else if (symbol->st_shndx == SHN_XINDEX)
                        {
                            printf("Unsupported value in ELF symbol\n");
                            printf("symbol->st_shndx: %x\n", symbol->st_shndx);
                            continue;
                        }
                        else
                        {
                            /* Internal symbol. Must be converted
                             * to absolute symbol.*/
                            sym_value = symbol->st_value;
                            /* Adds the address of the related section
                             * so the symbol stores absolute address. */
                            sym_value += ((section_table
                                           + symbol->st_shndx)->sh_addr);
                        }
                    }
                    switch (ELF32_R_TYPE(currel->r_info))
                    {
                        case R_386_NONE:
                            break;
                        case R_386_32:
                            /* Symbol value + offset. */
                            *target = sym_value + *target;
                            break;
                        case R_386_PC32:
                            /* Symbol value + offset - absolute address
                             * of the modified field. */
                            *target = (sym_value + (*target)
                                       - (unsigned long)target);
                            break;
                        default:
                            printf("Unknown relocation type in ELF file\n");
                    }
                }
            }
        }
    }
    else if (doing_elf_exec)
    {
        /* +++Implement relocations for ELF Executables. */
        ;
    }

    if (doing_elf_rel)
    {
        unsigned long entry_point = elfHdr->e_entry;

        /* ELF Relocatable files can be loaded anywhere. */
        sp = (unsigned int)ADDR2ABS(sp);
        /* Frees memory not needed by the process. */
        free(elfHdr);
        if (program_table) free(program_table);
        free(section_table);
        free(elf_other_sections);
        exeload->entry_point = (unsigned long)exeStart + entry_point;
        exeload->sp = sp;
        exeload->cs_address = 0;
        exeload->ds_address = 0;
    }
    else if (doing_elf_exec)
    {
        unsigned long entry_point = elfHdr->e_entry;

        /* ELF Executable files are loaded at the lowest p_vaddr. */
        exeStart -= lowest_p_vaddr;
        if (entry_point == 0) entry_point = lowest_p_vaddr;
        sp += lowest_p_vaddr;
        exeStart = ADDR2ABS(exeStart);
        /* Frees memory not needed by the process. */
        free(elfHdr);
        free(program_table);
        if (section_table)
        {
            free(section_table);
            free(elf_other_sections);
        }
        exeload->entry_point = entry_point;
        exeload->sp = sp;
        exeload->cs_address = (unsigned long)exeStart;
        exeload->ds_address = (unsigned long)exeStart;
    }
    
    return (0);
}

static int exeloadLoadMZ(EXELOAD *exeload, FILE *fp)
{
    unsigned long exeLen;
    unsigned char *exeStart;
    unsigned int sp;
    unsigned char *bss;
    unsigned char firstbit[2];

    rewind(fp);
    if ((fread(&firstbit, 1, sizeof(firstbit), fp) != 2)
        || (memcmp(firstbit, "MZ", 2) != 0
            && memcmp(&firstbit, "ZM", 2) != 0))
    {
        return (1);
    }

    printf("MZ, NE, LE and PE format is not supported\n");
    
    return (2);
}
