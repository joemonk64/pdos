/******************************************************************************
 * @file            elf.c
 *
 * Released to the public domain.
 *
 * Anyone and anything may copy, edit, publish, use, compile, sell and
 * distribute this work and all its parts in any form for any purpose,
 * commercial and non-commercial, without any restrictions, without
 * complying with any conditions and by any means.
 *****************************************************************************/
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "ld.h"
#include "bytearray.h"
#include "elf.h"
#include "xmalloc.h"

#define RELOC_SECTION_ALIGNMENT 4

static int generate_section_headers = 1;

/* Only the main ELF header has fixed position,
 * so only it needs to be counted.
 */
static long size_of_headers = sizeof (Elf32_Ehdr);

static Elf32_Word translate_section_flags_to_p_flags (flag_int flags)
{
    Elf32_Word p_flags = 0;

    if (!(flags & SECTION_FLAG_READONLY)) p_flags |= PF_W;

    if (flags & SECTION_FLAG_CODE) p_flags |= PF_X;

    if (!(flags & SECTION_FLAG_NOREAD)) p_flags |= PF_R;

    return p_flags;
}

static Elf32_Word translate_section_flags_to_sh_flags (flag_int flags)
{
    Elf32_Word sh_flags = 0;

    if (!(flags & SECTION_FLAG_READONLY)) sh_flags |= SHF_WRITE;

    if (flags & SECTION_FLAG_ALLOC) sh_flags |= SHF_ALLOC;

    if (flags & SECTION_FLAG_CODE) sh_flags |= SHF_EXECINSTR;

    return sh_flags;
}

static flag_int translate_sh_flags_to_section_flags (Elf32_Word sh_flags)
{
    flag_int flags = 0;

    if (!(sh_flags & SHF_WRITE)) flags |= SECTION_FLAG_READONLY;

    if (sh_flags & SHF_ALLOC) flags |= SECTION_FLAG_ALLOC;

    if (sh_flags & SHF_EXECINSTR) flags |= SECTION_FLAG_CODE;

    return flags;
}

static size_t section_get_num_relocs (struct section *section)
{
    struct section_part *part;
    size_t num_relocs = 0;
    
    for (part = section->first_part; part; part = part->next) {
        size_t i;
        
        for (i = 0; i < part->relocation_count; i++) {
            if (part->relocation_array[i].howto == &reloc_howtos[RELOC_TYPE_32]
                || part->relocation_array[i].howto == &reloc_howtos[RELOC_TYPE_PC32]) {
                num_relocs++;
            }
        }
    }

    return num_relocs;
}

static unsigned char *write_relocs_for_section (unsigned char *file,
                                                unsigned char *pos,
                                                struct section *section,
                                                Elf32_Shdr *shdr_p)
{
    struct section_part *part;
    Elf32_Rel *rel;
    unsigned char *saved_pos = pos;

    pos = file + ALIGN (pos - file, RELOC_SECTION_ALIGNMENT);
    rel = (void *)pos;

    for (part = section->first_part; part; part = part->next) {
        size_t i;
        
        for (i = 0; i < part->relocation_count; i++) {
            unsigned char type;
            
            if (part->relocation_array[i].howto == &reloc_howtos[RELOC_TYPE_IGNORED]) {
                continue;
            } else if (part->relocation_array[i].howto == &reloc_howtos[RELOC_TYPE_32]) {
                type = R_386_32;
            } else if (part->relocation_array[i].howto == &reloc_howtos[RELOC_TYPE_PC32]) {
                type = R_386_PC32;
            } else {
                ld_error ("%s cannot be converted to Elf32 relocation",
                          part->relocation_array[i].howto->name);
                continue;
            }

            rel->r_offset = ld_state->base_address + part->rva + part->relocation_array[i].offset;
            /* Symbol table is not yet supported. */
            rel->r_info = ELF32_R_INFO (0, type);
            rel++;
        }
    }

    if (rel == (void *)pos) return saved_pos;

    shdr_p->sh_type = SHT_REL;
    shdr_p->sh_flags = 0;
    shdr_p->sh_addr = 0;
    shdr_p->sh_offset = pos - file;
    shdr_p->sh_size = (unsigned char *)rel - pos;
    shdr_p->sh_link = 0; /* No symbol table exists. */
    shdr_p->sh_info = section->target_index;
    shdr_p->sh_addralign = RELOC_SECTION_ALIGNMENT;
    shdr_p->sh_entsize = sizeof *rel;
    
    return (unsigned char *)rel;
}

static unsigned char *write_sections (unsigned char *file, Elf32_Ehdr *ehdr_p)
{
    unsigned char *pos;
    struct section *section;
    Elf32_Phdr *phdr_p;
    Elf32_Shdr *shdr_p = NULL;

    pos = file + size_of_headers;

    phdr_p = (void *)(file + ehdr_p->e_phoff);
    if (generate_section_headers) {
        shdr_p = (void *)(file + ehdr_p->e_shoff);
        shdr_p->sh_type = SHT_NULL;
        shdr_p->sh_link = SHN_UNDEF;
        shdr_p++;
    }

    for (section = all_sections; section; section = section->next) {
        phdr_p->p_type = PT_LOAD;
        phdr_p->p_paddr = phdr_p->p_vaddr = ld_state->base_address + section->rva;
        phdr_p->p_memsz = section->total_size;

        if (!section->is_bss) {
            phdr_p->p_filesz = section->total_size;
            pos = file + ALIGN (pos - file, section->section_alignment);
            phdr_p->p_offset = pos - file;

            section_write (section, pos);
            pos += section->total_size;
        } else {
            phdr_p->p_filesz = 0;
            phdr_p->p_offset = 0;
        }

        phdr_p->p_flags = translate_section_flags_to_p_flags (section->flags);

        /* Memory alignment and file alignment must be the same
         * (so it is good to have RVA of first section
         *  to be equal to its offset)
         * but neither memory size nor file size need to be rounded.
         */
        phdr_p->p_align = section->section_alignment;

        if (generate_section_headers) {
            shdr_p->sh_type = section->is_bss ? SHT_NOBITS : SHT_PROGBITS;
            shdr_p->sh_flags = translate_section_flags_to_sh_flags (section->flags);
            shdr_p->sh_addr = phdr_p->p_vaddr;
            shdr_p->sh_offset = phdr_p->p_offset;
            shdr_p->sh_size = phdr_p->p_memsz;
            shdr_p->sh_addralign = phdr_p->p_align;
            shdr_p++;

            if (ld_state->emit_relocs) {
                unsigned char *saved_pos = pos;

                pos = write_relocs_for_section (file, pos, section, shdr_p);
                if (pos != saved_pos) {
                    shdr_p++;
                }
            }
        }

        phdr_p++;
    }

    return pos;
}

address_type elf_get_first_section_rva (void)
{
    if (all_sections == NULL) return size_of_headers;

    return ALIGN (size_of_headers, all_sections->section_alignment);
}

static void translate_relocation (struct reloc_entry *reloc,
                                  Elf32_Rel *input_reloc,
                                  struct section_part *part)
{
    /* STN_UNDEF should be treated as absolute symbol with value 0 at index 0. */
    reloc->symbol = part->of->symbol_array + ELF32_R_SYM (input_reloc->r_info);
    reloc->offset = input_reloc->r_offset;

    switch (ELF32_R_TYPE (input_reloc->r_info)) {
        case R_386_32: reloc->howto = &reloc_howtos[RELOC_TYPE_32]; break;

        case R_386_PC32:
            reloc->howto = &reloc_howtos[RELOC_TYPE_PC32];
            reloc->addend += 4; /* ELF should not have the size of the field subtracted. */
            break;

        default:
            ld_internal_error_at_source (__FILE__, __LINE__,
                                         "+++relocation type 0x%02x not supported yet",
                                         ELF32_R_TYPE (input_reloc->r_info));
            break;
    }
}

void elf_write (const char *filename)
{
    FILE *outfile;
    unsigned char *file;
    size_t file_size;
    unsigned char *pos;

    Elf32_Ehdr ehdr;

    struct section *section;

    if (!(outfile = fopen (filename, "wb"))) {
        ld_error ("cannot open '%s' for writing", filename);
        return;
    }

    /* Relocations exist only in sections. */
    if (ld_state->emit_relocs) generate_section_headers = 1;

    memset (&ehdr, 0, sizeof (ehdr));
    
    ehdr.e_ident[EI_MAG0] = ELFMAG0;
    ehdr.e_ident[EI_MAG1] = ELFMAG1;
    ehdr.e_ident[EI_MAG2] = ELFMAG2;
    ehdr.e_ident[EI_MAG3] = ELFMAG3;
    ehdr.e_ident[EI_CLASS] = ELFCLASS32;
    ehdr.e_ident[EI_DATA] = ELFDATA2LSB;
    ehdr.e_ident[EI_VERSION] = EV_CURRENT;

    ehdr.e_type = ET_EXEC;
    ehdr.e_machine = EM_386;
    ehdr.e_version = EV_CURRENT;
    ehdr.e_entry = ld_state->entry_point + ld_state->base_address;
    ehdr.e_ehsize = sizeof (ehdr);

    {
        /* Current layout of executable is:
         * Elf32_Ehdr
         * Content of sections (including section name string table)
         * Elf32_Phdr table (aligned just for readability)
         * Elf32_Shdr table (aligned just for readability)
         */
        file_size = size_of_headers;

        for (section = all_sections; section; section = section->next) {
            if (!section->is_bss) {
                file_size = ALIGN (file_size, section->section_alignment);
                file_size += section->total_size;
            }

            if (ld_state->emit_relocs) {
                size_t relocs_needed = section_get_num_relocs (section);

                if (relocs_needed) {
                    file_size = ALIGN (file_size, RELOC_SECTION_ALIGNMENT);
                    file_size += relocs_needed * sizeof (Elf32_Rel);
                }
            }
        }

        if (generate_section_headers) {
            size_t shstrtab_size;
            shstrtab_size = 1 + sizeof (".shstrtab");

            for (section = all_sections; section; section = section->next) {
                if (ld_state->emit_relocs && section_get_num_relocs (section)) {
                    shstrtab_size += sizeof (".rel") - 1;
                }
                shstrtab_size += strlen (section->name) + 1;
            }

            file_size += shstrtab_size;
        }

        file_size = ALIGN (file_size, sizeof (Elf32_Phdr));
        ehdr.e_phoff = file_size;
        ehdr.e_phentsize = sizeof (Elf32_Phdr);
        ehdr.e_phnum = 0;
        for (section = all_sections; section; section = section->next) {
            ehdr.e_phnum++;
        }
        file_size += ehdr.e_phnum * sizeof (Elf32_Phdr);

        if (generate_section_headers) {
            file_size = ALIGN (file_size, sizeof (Elf32_Shdr));
            ehdr.e_shoff = file_size;
            ehdr.e_shentsize = sizeof (Elf32_Shdr);
            ehdr.e_shnum = 1;
            for (section = all_sections; section; section = section->next) {
                section->target_index = ehdr.e_shnum++;
                if (ld_state->emit_relocs && section_get_num_relocs (section)) {
                    ehdr.e_shnum++;
                }
            }
            ehdr.e_shstrndx = ehdr.e_shnum++;
            
            file_size += ehdr.e_shnum * sizeof (Elf32_Shdr);
        }
    }

    file = xmalloc (file_size);
    memset (file, 0, file_size);

    pos = write_sections (file, &ehdr);

    if (generate_section_headers) {
        unsigned char *saved_pos;
        Elf32_Shdr *shdr_p, *shstrshdr_p;

        shdr_p = (void *)(file + ehdr.e_shoff);
        shstrshdr_p = shdr_p + ehdr.e_shstrndx;
        shdr_p++;
        saved_pos = pos;
        
        shstrshdr_p->sh_name = 1;
        shstrshdr_p->sh_type = SHT_STRTAB;
        shstrshdr_p->sh_offset = saved_pos - file;
        shstrshdr_p->sh_addralign = 1;

        *pos = '\0';
        pos++;
        memcpy (pos, ".shstrtab", sizeof (".shstrtab"));
        pos += sizeof (".shstrtab");

        for (section = all_sections; section; section = section->next) {
            int has_relocs = ld_state->emit_relocs && section_get_num_relocs (section);
            size_t name_len = strlen (section->name);

            if (has_relocs) {
                memcpy (pos, ".rel", sizeof (".rel") - 1);
                pos += sizeof (".rel") - 1;
            }
            shdr_p->sh_name = pos - saved_pos;
            if (has_relocs) {
                shdr_p++;
                shdr_p->sh_name = pos - saved_pos - (sizeof (".rel") - 1);
            }

            memcpy (pos, section->name, name_len);
            pos[name_len] = '\0';
            pos += name_len + 1;

            shdr_p++;
        }

        shstrshdr_p->sh_size = pos - saved_pos;
    }

    pos = file;

    memcpy (pos, &ehdr, sizeof (ehdr));

    if (fwrite (file, file_size, 1, outfile) != 1) {
        ld_error ("writing '%s' file failed", filename);
    }
    
    free (file);
    fclose (outfile);
}

#define CHECK_READ(memory_position, size_to_read) \
    do { if (((memory_position) - file + (size_to_read) > file_size) \
             || (memory_position) < file) ld_fatal_error ("corrupted input file"); } while (0)

static int read_elf_object (unsigned char *file, size_t file_size, const char *filename)
{
    Elf32_Ehdr ehdr;
    Elf32_Shdr *shdr_p;

    const char *section_name_string_table = NULL;
    Elf32_Word section_name_string_table_size;

    unsigned char *pos;

    struct object_file *of;
    struct section_part **part_p_array;
    Elf32_Half i;

    struct section *bss_section = NULL;
    long bss_section_number = 0;

    pos = file;
    CHECK_READ (pos, sizeof (ehdr));
    ehdr = *(Elf32_Ehdr *)pos;

    if (ehdr.e_ident[EI_CLASS] != ELFCLASS32) {
        ld_error ("%s: Unsupported ELF file class", filename);
        return 1;
    }

    if (ehdr.e_ident[EI_DATA] != ELFDATA2LSB) {
        ld_error ("%s: Unsupported ELF data encoding", filename);
        return 1;
    }

    if (ehdr.e_ident[EI_VERSION] != EV_CURRENT) {
        ld_error ("%s: Unsupported ELF version", filename);
        return 1;
    }

    if (ehdr.e_type != ET_REL) {
        ld_error ("%s: e_type is not ET_REL", filename);
        return 1;
    }

    if (ehdr.e_machine != EM_386) {
        ld_error ("%s: e_machine is not EM_386", filename);
        return 1;
    }

    if (ehdr.e_version != EV_CURRENT) {
        ld_error ("%s: e_version is not EV_CURRENT", filename);
        return 1;
    }

    if (ehdr.e_ehsize < sizeof (ehdr)) {
        ld_error ("%s: e_ehsize is too small", filename);
        return 1;
    }

    if (ehdr.e_shoff == 0 || ehdr.e_shentsize == 0 || ehdr.e_shnum == 0) {
        ld_error ("%s: missing section header table", filename);
        return 1;
    }

    if (ehdr.e_shentsize < sizeof (Elf32_Shdr)) {
        ld_error ("%s: e_shentsize is too small", filename);
        return 1;
    }

    if (ehdr.e_shstrndx == 0 || ehdr.e_shstrndx >= ehdr.e_shnum) {
        ld_error ("%s: missing section name string table", filename);
        return 1;
    }

    pos = file + ehdr.e_shoff;
    CHECK_READ (pos, ehdr.e_shentsize * ehdr.e_shnum);

    pos += ehdr.e_shentsize * ehdr.e_shstrndx;
    shdr_p = (void *)pos;

    if (shdr_p->sh_type != SHT_STRTAB) {
        ld_error ("section name string table does not have SHT_STRTAB type");
        return 1;
    }

    section_name_string_table_size = shdr_p->sh_size;
    pos = file + shdr_p->sh_offset;
    CHECK_READ (pos, section_name_string_table_size);
    section_name_string_table = (char *)pos;

    part_p_array = xmalloc (sizeof (*part_p_array) * (ehdr.e_shnum + 1));
    of = NULL;

    for (i = 1; i < ehdr.e_shnum; i++) {
        pos = file + ehdr.e_shoff + i * ehdr.e_shentsize;
        shdr_p = (void *)pos;

        if (shdr_p->sh_type != SHT_SYMTAB) continue;

        if (of) ld_fatal_error ("more than 1 symbol table per object file");

        of = object_file_make (shdr_p->sh_size / shdr_p->sh_entsize, filename);
    }

    if (!of) of = object_file_make (1, filename);

    for (i = 1; i < ehdr.e_shnum; i++) {
        pos = file + ehdr.e_shoff + i * ehdr.e_shentsize;
        shdr_p = (void *)pos;

        {
            struct section *section;

            {
                char *section_name;
                
                if (shdr_p->sh_name < section_name_string_table_size) {
                    section_name = xstrdup (section_name_string_table + shdr_p->sh_name);
                } else ld_fatal_error ("invalid offset into string table");

                if (shdr_p->sh_type != SHT_PROGBITS
                    && shdr_p->sh_type != SHT_NOBITS) {
                    part_p_array[i] = NULL;
                    free (section_name);
                    continue;
                }

                section = section_find_or_make (section_name);
                if (shdr_p->sh_addralign > section->section_alignment) {
                    section->section_alignment = shdr_p->sh_addralign;
                }
                section->flags = translate_sh_flags_to_section_flags (shdr_p->sh_flags);

                if (shdr_p->sh_type == SHT_NOBITS) {
                    section->is_bss = 1;
                }

                free (section_name);
            }

            {
                struct section_part *part = section_part_new (section, of);

                part->alignment = shdr_p->sh_addralign;

                part->content_size = shdr_p->sh_size;
                if (shdr_p->sh_type != SHT_NOBITS) {
                    pos = file + shdr_p->sh_offset;
                    part->content = xmalloc (part->content_size);

                    CHECK_READ (pos, part->content_size);
                    memcpy (part->content, pos, part->content_size);
                }

                if (section->is_bss) {
                    bss_section_number = i;
                    bss_section = section;
                }
                
                section_append_section_part (section, part);

                part_p_array[i] = part;
            }
        }
    }

    for (i = 1; i < ehdr.e_shnum; i++) {
        const char *sym_strtab;
        Elf32_Word sym_strtab_size;
        Elf32_Word j;
        
        pos = file + ehdr.e_shoff + i * ehdr.e_shentsize;
        shdr_p = (void *)pos;

        if (shdr_p->sh_type != SHT_SYMTAB) continue;

        if (shdr_p->sh_link == 0 || shdr_p->sh_link >= ehdr.e_shnum) {
            ld_fatal_error ("symtab has invalid sh_link");
        }
        
        pos = file + ehdr.e_shoff + shdr_p->sh_link * ehdr.e_shentsize;
        {
            const Elf32_Shdr *strtabhdr_p = (void *)pos;

            if (strtabhdr_p->sh_type != SHT_STRTAB) {
                ld_fatal_error ("symbol name string table does not have SHT_STRTAB type");
            }

            sym_strtab_size = strtabhdr_p->sh_size;
            pos = file + strtabhdr_p->sh_offset;
            CHECK_READ (pos, sym_strtab_size);
            sym_strtab = (char *)pos;
        }

        pos = file + shdr_p->sh_offset;
        CHECK_READ (pos, shdr_p->sh_size);

        if (shdr_p->sh_entsize < sizeof (Elf32_Sym)) {
            ld_fatal_error ("symbol table sh_entsize is too small");
        }

        for (j = 1; j < shdr_p->sh_size / shdr_p->sh_entsize; j++) {
            Elf32_Sym *elf_symbol;
            struct symbol *symbol = of->symbol_array + j;
            
            pos = file + shdr_p->sh_offset + j * shdr_p->sh_entsize;
            elf_symbol = (void *)pos;

            if (elf_symbol->st_name < sym_strtab_size) {
                symbol->name = xstrdup (sym_strtab + elf_symbol->st_name);
            } else ld_fatal_error ("invalid offset into string table");

            symbol->value = elf_symbol->st_value;
            symbol->size = elf_symbol->st_size;
            symbol->section_number = elf_symbol->st_shndx;

            if (elf_symbol->st_shndx == SHN_UNDEF) {
                symbol->section_number = UNDEFINED_SECTION_NUMBER;
                symbol->part = NULL;
            } else if (elf_symbol->st_shndx == SHN_ABS) {
                symbol->section_number = ABSOLUTE_SECTION_NUMBER;
                symbol->part = NULL;
            } else if (elf_symbol->st_shndx == SHN_COMMON) {
                if (symbol->size) {
                    struct symbol *old_symbol = symbol_find (symbol->name);

                    if (ELF32_ST_BIND (elf_symbol->st_info) != STB_GLOBAL) {
                        ld_fatal_error ("non-global common symbol");
                    }

                    if (!old_symbol || symbol_is_undefined (old_symbol)) {
                        struct section_part *bss_part;
                        
                        if (bss_section == NULL) {
                            bss_section = section_find_or_make (".bss");

                            bss_section->section_alignment = 4;
                            bss_section->flags = translate_sh_flags_to_section_flags (SHF_WRITE | SHF_ALLOC);
                            bss_section->is_bss = 1;
                            bss_section_number = ehdr.e_shnum ? ehdr.e_shnum : 1;
                        }
                        
                        bss_part = section_part_new (bss_section, of);
                        section_append_section_part (bss_section, bss_part);

                        bss_part->content_size = symbol->size;
                        bss_part->alignment = symbol->value;
                        symbol->part = bss_part;
                        symbol->value = 0;
                        symbol->section_number = bss_section_number;
                    } else {
                        if (symbol->size > old_symbol->size) {
                            old_symbol->part->content_size = old_symbol->size = symbol->size;
                        }
                        if (symbol->value > old_symbol->part->alignment) {
                            old_symbol->part->alignment = symbol->value;
                        }
                        
                        symbol->value = 0;
                        symbol->section_number = UNDEFINED_SECTION_NUMBER;
                        symbol->part = NULL;
                    }
                } else {
                    symbol->section_number = UNDEFINED_SECTION_NUMBER;
                    symbol->part = NULL;
                }
            } else if (elf_symbol->st_shndx >= SHN_LORESERVE
                       && elf_symbol->st_shndx <= SHN_HIRESERVE) {
                ld_internal_error_at_source (__FILE__, __LINE__,
                                             "+++not yet supported symbol st_shndx: %hu",
                                             elf_symbol->st_shndx);
            } else if (elf_symbol->st_shndx >= ehdr.e_shnum) {
                ld_error ("invalid symbol st_shndx: %hu", elf_symbol->st_shndx);
                symbol->part = NULL;
            } else {
                symbol->part = part_p_array[elf_symbol->st_shndx];
            }

            switch (ELF32_ST_BIND (elf_symbol->st_info)) {
                case STB_LOCAL:
                    /* Do nothing */
                    break;
                
                case STB_GLOBAL:
                    symbol_record_external_symbol (symbol);
                    break;
                
                default:
                    ld_internal_error_at_source (__FILE__, __LINE__,
                                                 "+++not yet supported symbol ELF32_ST_BIND: %u",
                                                 ELF32_ST_BIND (elf_symbol->st_info));
                    break;
            }
        }
    }

    for (i = 1; i < ehdr.e_shnum; i++) {
        struct section_part *part;
        size_t j;
        
        pos = file + ehdr.e_shoff + i * ehdr.e_shentsize;
        shdr_p = (void *)pos;

        if (shdr_p->sh_type != SHT_REL || shdr_p->sh_size == 0) continue;

        part = part_p_array[shdr_p->sh_info];
        if (!part) ld_fatal_error ("relocation section has invalid sh_info");

        if (shdr_p->sh_entsize != sizeof (Elf32_Rel)) {
            ld_internal_error_at_source (__FILE__, __LINE__,
                                         "+++relocation shdr_p->sh_entsize not yet supported");
        }

        pos = file + shdr_p->sh_offset;
        CHECK_READ (pos, shdr_p->sh_size);

        part->relocation_count = shdr_p->sh_size / shdr_p->sh_entsize;
        part->relocation_array = xcalloc (part->relocation_count, sizeof *part->relocation_array);

        for (j = 0; j < part->relocation_count; j++) {
            translate_relocation (part->relocation_array + j,
                                  (Elf32_Rel *)(pos + shdr_p->sh_entsize * j),
                                  part);
        }
    }

    free (part_p_array);

    return 0;
}

int elf_read (unsigned char *file, size_t file_size, const char *filename)
{

    CHECK_READ (file, 4);

    if (file[EI_MAG0] == ELFMAG0
        && file[EI_MAG1] == ELFMAG1
        && file[EI_MAG2] == ELFMAG2
        && file[EI_MAG3] == ELFMAG3) {
        read_elf_object (file, file_size, filename);
        return INPUT_FILE_FINISHED;
    }

    return INPUT_FILE_UNRECOGNIZED;
}
