/*****************************************************
 * This code was written by Alica Okano and is       *
 * released to the public domain as discussed here:  *
 * http://creativecommons.org/publicdomain/zero/1.0/ *
 *****************************************************/

/* Utility bin2hex in ozpd was used to generate the hex values
   from the .com files */

#include <stdio.h>
#include <string.h>
#include <ctype.h>

#include <pos.h>

int main(int argc, char **argv)
{
    static unsigned char pbootsec[512] = {
    "\xEB\x3D\x90\x50\x44\x4F\x53\x20\x78\x2E\x78\x00\x02\x01\x01\x00"
    "\x02\xE0\x00\x00\x00\xF8\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
    "\x00\x00\x00\x00\x00\x00\x29\x00\x00\x00\x00\x50\x44\x4F\x53\x20"
    "\x56\x6F\x6C\x75\x6D\x65\x46\x41\x54\x20\x20\x20\x20\x20\x00\xFC"
    "\xE8\x00\x00\x58\x25\x00\xFF\x3D\x00\x01\x74\x0F\xB8\xB0\x07\x8E"
    "\xD8\xB8\x00\x00\x8E\xC0\x26\x88\x16\x02\x7C\x33\xC0\x8E\xD0\xBC"
    "\x00\x7C\x88\x16\x3E\x01\xB4\x08\xBF\x00\x00\x06\xCD\x13\x72\x14"
    "\x80\xE1\x3F\xB5\x00\x89\x0E\x18\x01\x8A\xD6\xB6\x00\x83\xC2\x01"
    "\x89\x16\x1A\x01\x07\xE8\x12\x00\xB9\x37\x00\xBB\x00\x07\xE8\x92"
    "\x00\xB8\x70\x00\x50\xB8\x00\x00\x50\xCB\x53\x51\xA1\x16\x01\x33"
    "\xD2\x33\xC9\x8A\x0E\x10\x01\xF7\xE1\x50\x52\x33\xD2\xA1\x11\x01"
    "\xB9\x20\x00\xF7\xE1\xF7\x36\x0B\x01\x5A\x5B\x33\xC9\x03\xC3\x13"
    "\xD1\x03\x06\x0E\x01\x13\xD1\x03\x06\x1C\x01\x13\x16\x1E\x01\x59"
    "\x5B\xC3\xF7\x36\x18\x01\xB5\x00\x8A\xCA\xFE\xC1\x33\xD2\xF7\x36"
    "\x1A\x01\x8A\xF2\x52\x8A\xF0\xB0\x00\x51\xB1\x02\xD3\xE8\x59\x8A"
    "\xE6\x5A\x0B\xC8\xC3\x50\x52\x8A\x16\x3E\x01\xB8\x00\x00\xCD\x13"
    "\x72\xF5\x5A\x58\xC3\x50\x53\x51\x52\x06\xE8\xC5\xFF\x8A\x16\x3E"
    "\x01\xB8\x01\x02\xCD\x13\x73\x05\xE8\xDA\xFF\xEB\xF0\x07\x5A\x59"
    "\x5B\x58\xC3\x50\x53\xE8\xDD\xFF\x03\x1E\x0B\x01\x83\xC0\x01\x83"
    "\xD2\x00\xE2\xF1\x5B\x58\xC3\x50\x53\x8A\xC5\xE8\x0D\x00\x8A\xC1"
    "\xE8\x08\x00\xB0\x20\xE8\x18\x00\x5B\x58\xC3\x8A\xD8\x51\xB1\x04"
    "\xD2\xE8\x59\xE8\x02\x00\x8A\xC3\x24\x0F\x04\x90\x27\x14\x40\x27"
    "\x53\xBB\x00\x00\xB4\x0E\xCD\x10\x5B\xC3\x00\x00\x00\x00\x00\x00"
    "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
    "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
    "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
    "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
    "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
    "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
    "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
    "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
    "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x55\xAA"
    };
    static unsigned char fat32bootsec[512] = {
    "\xEB\x59\x90\x50\x44\x4F\x53\x20\x78\x2E\x78\x00\x02\x01\x01\x00"
    "\x02\xE0\x00\x00\x00\xF8\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
    "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x00\x00"
    "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
    "\x00\x00\x29\x00\x00\x00\x00\x50\x44\x4F\x53\x20\x56\x6F\x6C\x75"
    "\x6D\x65\x46\x41\x54\x33\x32\x20\x20\x20\x00\xFC\xE8\x00\x00\x58"
    "\x25\x00\xFF\x3D\x00\x01\x74\x0F\xB8\xB0\x07\x8E\xD8\xB8\x00\x00"
    "\x8E\xC0\x26\x88\x16\x02\x7C\x33\xC0\x8E\xD0\xBC\x00\x7C\x88\x16"
    "\x5A\x01\xB4\x08\xBF\x00\x00\x06\xCD\x13\x72\x14\x80\xE1\x3F\xB5"
    "\x00\x89\x0E\x18\x01\x8A\xD6\xB6\x00\x83\xC2\x01\x89\x16\x1A\x01"
    "\x07\xE8\x67\x00\xA3\x81\x02\x89\x16\x83\x02\xBB\x00\x7E\xE8\x90"
    "\x00\x26\x8B\x36\x14\x7E\x26\x8B\x3E\x1A\x7E\x26\x8A\x1E\x0B\x7E"
    "\x80\xE3\x08\x74\x0A\x26\x8B\x36\x34\x7E\x26\x8B\x3E\x3A\x7E\xE8"
    "\x12\x00\xB9\x37\x00\xBB\x00\x07\xE8\x94\x00\xB8\x70\x00\x50\xB8"
    "\x00\x00\x50\xCB\x57\x56\x2B\x3E\x2C\x01\x1B\x36\x2E\x01\x33\xD2"
    "\x8B\xC2\x51\x8A\x0E\x0D\x01\x03\xC7\x13\xD6\xFE\xC9\x75\xF8\x59"
    "\x03\x06\x81\x02\x13\x16\x83\x02\x5E\x5F\xC3\x51\x33\xD2\x8B\xC2"
    "\x8A\x0E\x10\x01\x03\x06\x24\x01\x13\x16\x26\x01\xFE\xC9\x75\xF4"
    "\x59\x03\x06\x1C\x01\x13\x16\x1E\x01\x03\x06\x0E\x01\x83\xD2\x00"
    "\xC3\x50\x52\x8A\x16\x5A\x01\xB8\x00\x00\xCD\x13\x72\xF5\x5A\x58"
    "\xC3\x50\x53\x51\x52\x06\x56\x89\x16\xF2\x02\xA3\xF0\x02\x89\x1E"
    "\xEC\x02\x8C\x06\xEE\x02\xB4\x42\xBE\xE8\x02\x8A\x16\x5A\x01\xCD"
    "\x13\x73\x05\xE8\xCB\xFF\xEB\xDF\x5E\x07\x5A\x59\x5B\x58\xC3\x50"
    "\x53\xE8\xCD\xFF\x03\x1E\x0B\x01\x40\x73\x01\x42\xE2\xF3\x5B\x58"
    "\xC3\x00\x00\x00\x00\x50\x53\x8A\xC5\xE8\x0D\x00\x8A\xC1\xE8\x08"
    "\x00\xB0\x20\xE8\x18\x00\x5B\x58\xC3\x8A\xD8\x51\xB1\x04\xD2\xE8"
    "\x59\xE8\x02\x00\x8A\xC3\x24\x0F\x04\x90\x27\x14\x40\x27\x53\xBB"
    "\x00\x00\xB4\x0E\xCD\x10\x5B\xC3\x00\x00\x00\x00\x00\x00\x00\x00"
    "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
    "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
    "\x00\x00\x00\x00\x00\x00\x00\x00\x10\x00\x01\x00\x00\x00\x00\x00"
    "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x55\xAA"
    };
    FILE *fsrc;
    FILE *fdest;
    unsigned char buf[512];
    unsigned char src_path[260];
    unsigned char dest_path[260];
    unsigned char *src_end;
    int i;
    int bytes_read = 0;
    unsigned long sectors_per_disk;
    unsigned int sectors_per_cluster;
    unsigned int backup_sector = 0;
    
    if (argc < 2)
    {
        printf("Usage: SYS [(optional) source path] [drive:]\n");
        printf("Does not set file attributes for the files.\n");
        return (0);
    }
    if (argc == 3)
    {
        /* User provided both source path anddestination drive. */
        /* Checks if user provided drive ("[letter]:") as destination. */
        if (strlen(*(argv + 2)) != 2 || (*(argv + 2))[1] != ':')
        {
            printf("Entered drive is not in valid format ([letter]:)\n");
            return (0);
        }
        strcpy(src_path, *(argv + 1));
        src_end = strchr(src_path, '\0');
        /* If source path does end in '\' or '/' '\' is added. */
        if ((src_end - 1)[0] != '\\' && (src_end - 1)[0] != '/')
        {
            *src_end++ = '\\';
            *src_end = '\0';
        }
        strcpy(dest_path, *(argv + 2));
        dest_path[0] = toupper(dest_path[0]);
    }
    else
    {
        /* User provided only destination drive. */
        /* Checks if user provided drive as destination. */
        if (strlen(*(argv + 1)) != 2 || (*(argv + 1))[1] != ':')
        {
            printf("Entered drive is not in valid format ([letter]:)\n");
            return (0);
        }
        strcpy(dest_path, *(argv + 1));
        dest_path[0] = toupper(dest_path[0]);
        /* Source path is generated. It is root of the current drive. */
        src_path[0] = PosGetDefaultDrive() + 'A';
        src_path[1] = ':';
        src_path[2] = '\\';
        src_path[3] = '\0';
        src_end = src_path + 3;
    }
    /* IO.SYS is copied first. */
    strcat(src_path, "IO.SYS");
    strcat(dest_path, "\\IO.SYS");
    for (i = 0; i < 3; i++)
    {
        if (i == 1)
        {
            /* MSDOS.SYS second. */
            src_end[0] = '\0';
            strcat(src_path, "MSDOS.SYS");
            dest_path[3] = '\0';
            strcat(dest_path, "MSDOS.SYS");
        }
        else if (i == 2)
        {
            /* COMMAND.EXE last. */
            src_end[0] = '\0';
            strcat(src_path, "COMMAND.EXE");
            dest_path[3] = '\0';
            strcat(dest_path, "COMMAND.EXE");
        }
        fsrc = fopen(src_path, "rb");
        if (fsrc != NULL)
        {
            fdest = fopen(dest_path, "wb");

            if (fdest != NULL)
            {
                while((bytes_read = fread(buf, 1, sizeof(buf), fsrc)) != 0)
                {
                    fwrite(buf, 1, bytes_read, fdest);
                }
                fclose(fdest);
            }
            else
            {
                printf("Unable to write system files to destination\n");
                return (0);
            }
            fclose(fsrc);
        }
        else
        {
            if (argc == 2) printf("System files not found on default drive\n");
            else printf("System files not found or invalid path\n");
            return (0);
        }
    }
    PosAbsoluteDiskRead(dest_path[0] - 'A', 0, 1, buf);
    /* Obtains some information from BPB to know what type of FAT is it. */
    sectors_per_cluster = buf[13];
    /* Total sectors on the volume. If 0, checks offset 32. */
    sectors_per_disk = buf[19] | ((unsigned int)buf[20] << 8);
    if (sectors_per_disk == 0)
    {
        sectors_per_disk =
            buf[32]
            | ((unsigned long)buf[33] << 8)
            | ((unsigned long)buf[34] << 16)
            | ((unsigned long)buf[35] << 24);
    }
    /* Decides which boot sector to use depending on the file system. */
    if ((sectors_per_disk / sectors_per_cluster) < 65527)
    {
        /* Copies jump code and OEM info. */
        memcpy(buf, pbootsec, 11);
        /* FAT-12/16 have boot code at offset 62. */
        memcpy(buf + 62, pbootsec + 62, 512 - 62);
    }
    else if ((sectors_per_disk / sectors_per_cluster) < 268435457)
    {
        /* Copies jump code and OEM info. */
        memcpy(buf, fat32bootsec, 11);
        /* FAT-32 has boot code at offset 90. */
        memcpy(buf + 90, fat32bootsec + 90, 512 - 90);
        /* We should change the backup boot sector,
         * which location can be known from offset 50-51. */
        backup_sector = buf[50] | ((unsigned int)buf[51] << 8);
    }
    else
    {
        printf("Unknown filesystem on drive %c:\n", dest_path[0]);
        return (0);
    }
    /* We also set the boot signatute. */
    buf[510] = 0x55;
    buf[511] = 0xAA;
    /* Writes the modified sector 0 back to the drive. */
    PosAbsoluteDiskWrite(dest_path[0] - 'A', 0, 1, buf);
    /* Also rewrites backup boot sector. */
    if (backup_sector)
    {
        PosAbsoluteDiskWrite(dest_path[0] - 'A', backup_sector, 1, buf);
    }
    printf("System installed on drive %c:\n", dest_path[0]);
    return (0);
}
