; nasm -f bin hello_uefi.asm -o BOOTX64.efi
; Then copy BOOTX64.efi to \EFI\BOOT\BOOTX64.efi on a FAT32 formatted media

bits 64

SECTION_ALIGNMENT   equ 0x1000
FILE_ALIGNMENT      equ 0x200

section .headers
DOS_HEADER:
    db "MZ"                     ; Magic number
    times 29 dw 0               ; Obsolete portion of the DOS Header
    dd 0x00000040               ; File offset of PE signature
    
SIGNATURE:
    db "PE", 0, 0               ; PE Signature
    
FILE_HEADER:
    dw 0x8664                   ; x64 Machine type
    dw 1                        ; Number of sections
    dd 0x66c1f45a               ; Time/Date Stamp
    dd 0                        ; Deprecated
    dd 0                        ; Deprecated
    dw OPTIONAL_HEADER_SIZE     ; Size of Optional Header
    dw 0x22e                    ; Executable, line numbers stripped, local symbols stripped, can handle >2gb addresses, Debugging info stripped

OPTIONAL_HEADER_BEGIN:
OPTIONAL_HEADER:
    dw 0x20b                    ; PE32+ Executable (64-bit)
    db 0                        ; No linker used
    db 0                        ; No linker used
    dd CODE_SIZE                ; Size of code (.text section)
    dd 0                        ; Size of initialized data (.data section)
    dd 0                        ; Size of uninitialized data (.bss section)
    dd ENTRY_RVA                ; Entry-point address, relative to image base
    dd ENTRY_RVA                ; Base of code
    
OPTION_HEADER_WINDOWS_FIELDS:
    dq 0x140000000              ; Image Base
    dd SECTION_ALIGNMENT        ; Section Alignment
    dd FILE_ALIGNMENT           ; File Alignment
    dw 0                        ; OS Version Major
    dw 0                        ; OS Version Minor
    dw 100                      ; Image Version Major
    dw 0                        ; Image Version Minor
    dw 1                        ; Subsystem Version Major
    dw 1                        ; Subsystem Version Minor
    dd 0                        ; Win32 Version
    dd IMAGE_SIZE               ; Image Size (Must be a multiple of SECTION_ALIGNMENT)
    dd HEADERS_SIZE             ; Size of Headers (DOS + PE + Section Headers rounded up to multiple of FILE_ALIGNMENT)
    dd 0                        ; Checksum (apparently not necessary in UEFI?)
    dw 0x000a                   ; Subsystem - EFI Application
    dw 0x0160                   ; Can handle a high entropy 64-bit virtual address space, DLL can move, Image is NX compatible
    dq 0x100000                 ; Size of stack reserve
    dq 0x1000                   ; Size of stack commit
    dq 0x100000                 ; Size of heap reserve
    dq 0x1000                   ; Size of heap commit
    dd 0                        ; Loader flags
    dd 0                        ; Data-Directory Entries   
OPTIONAL_HEADER_END:
OPTIONAL_HEADER_SIZE equ OPTIONAL_HEADER_END - OPTIONAL_HEADER_BEGIN

SECTION_HEADER_TEXT:
    db ".text", 0, 0, 0         ; Name
    dd CODE_SIZE                ; Virtual Size
    dd CODE_RVA                 ; Virtual Address
    dd CODE_PADDED_SIZE         ; Raw Size
    dd CODE_RVA                 ; Raw Address
    dd 0                        ; Relocations Ptr (0 for executables)
    dd 0                        ; Deprecated
    dw 0                        ; Number of Relocations (0 for executables)
    dw 0                        ; Deprecated
    dd 0x60000020               ; Contains executable code, can be executed as code, can be read
    
HEADERS_SIZE equ ((($-$$) / FILE_ALIGNMENT) + 1) * FILE_ALIGNMENT
times HEADERS_SIZE - ($-$$) db 0    ; Padding
    
section .text follows=.headers

    %define EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL     64  ; Offset of ConOut from the EFI_SYSTEM_TABLE
    %define OUTPUTSTRING                        8   ; Offset of OutputString function within EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL
    
    %define EFI_HANDLE          r10 + 0
    %define EFI_SYSTEM_TABLE    r10 + 1

    ; All variables are stored on the stack and referenced relative to r10 to avoid having relocations
    push    rcx                    ; EFI_HANDLE
    mov     r10, rsp               ; r10 is the base from which to reference all of our local variables
    push    rdx                    ; EFI_SYSTEM_TABLE
    
    sub rsp, 40
	mov rcx, [rdx + EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL]         
	lea rdx, [rel hello]
	call     [rcx + OUTPUTSTRING]		
    jmp $
    
	add rsp, 40
	ret
    hello: 
        db __utf16__ `hello world!\n\r\0`

CODE_SIZE equ $ - $$
times ((($-$$) / FILE_ALIGNMENT) + 1) * FILE_ALIGNMENT - ($-$$) db 0 ; Pad to File Alignment
CODE_PADDED_SIZE equ $ - $$
CODE_RVA  equ HEADERS_SIZE
ENTRY_RVA equ HEADERS_SIZE  ; Assuming the code starts at the very beginning of section .text, the Entry-point address is the distance of the .text section from the beginning of the file
IMAGE_SIZE equ (((HEADERS_SIZE + CODE_SIZE) / SECTION_ALIGNMENT) + 1) * SECTION_ALIGNMENT   ; Image Size rounded up to the nearest 64K

IMAGE_PADDING:
    times IMAGE_SIZE - (HEADERS_SIZE + CODE_SIZE) db 0

;------------------------------- DEBUG ---------------
%assign headers_sz HEADERS_SIZE
%warning Headers Size: headers_sz

%assign code_sz CODE_SIZE
%warning Code Size: code_sz

%assign codep_sz CODE_PADDED_SIZE
%warning Code Padded Size: codep_sz

%assign img_sz IMAGE_SIZE
%warning Image Size: img_sz 
;-----------------------------------------------------
