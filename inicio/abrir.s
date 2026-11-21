# Punto de entrada x64. Inicia el archivo Iniciar.cmd situado junto al ejecutable,
# aunque Windows use otra carpeta de trabajo. ABI de Windows (32 bytes de shadow space).
.intel_syntax noprefix
.text
.global inicio
inicio:
    sub rsp, 56
    xor ecx, ecx
    lea rdx, [rip + ruta]
    mov r8d, 32768
    call [rip + __imp_GetModuleFileNameW]
    test eax, eax
    jz error
    cmp eax, 32750
    ja error
    lea rdx, [rip + ruta]
buscar:
    dec eax
    js error
    cmp word ptr [rdx + rax*2], 92
    jne buscar
    lea rdx, [rdx + rax*2 + 2]
    lea rcx, [rip + script]
copiar:
    mov ax, word ptr [rcx]
    mov word ptr [rdx], ax
    add rcx, 2
    add rdx, 2
    test ax, ax
    jnz copiar
    xor ecx, ecx
    xor edx, edx
    lea r8, [rip + ruta]
    xor r9d, r9d
    mov qword ptr [rsp+32], 0
    mov qword ptr [rsp+40], 1
    call [rip + __imp_ShellExecuteW]
    cmp rax, 32
    jbe error
    xor ecx, ecx
    call [rip + __imp_ExitProcess]
error:
    xor ecx, ecx
    lea rdx, [rip + mensaje]
    lea r8, [rip + titulo]
    mov r9d, 16
    call [rip + __imp_MessageBoxW]
    mov ecx, 1
    call [rip + __imp_ExitProcess]
.data
script: .short 73,110,105,99,105,97,114,46,99,109,100,0
titulo: .short 82,101,103,105,115,116,114,111,0
mensaje: .short 69,120,116,114,97,105,103,97,32,116,111,100,111,32,101,108,32,90,73,80,32,97,110,116,101,115,32,100,101,32,105,110,105,99,105,97,114,46,0
.bss
.balign 16
ruta: .skip 65536
