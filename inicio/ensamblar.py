"""Ensambla el inicio nativo con el escritor COFF x64 de LLVM 19."""
import ctypes as c
from pathlib import Path
import sys

llvm = c.CDLL("libLLVM-19.so")
ptr = c.c_void_p
string = c.c_char_p


def llamar(nombre, tipo, tipos, *argumentos):
    funcion = getattr(llvm, nombre)
    funcion.restype = tipo
    funcion.argtypes = tipos
    return funcion(*argumentos)


for componente in ("TargetInfo", "Target", "TargetMC", "AsmParser", "AsmPrinter"):
    llamar("LLVMInitializeX86" + componente, None, [])
triple = b"x86_64-pc-windows-msvc"
target, error = ptr(), string()
if llamar("LLVMGetTargetFromTriple", c.c_int, [string, ptr, ptr], triple, c.byref(target), c.byref(error)):
    raise SystemExit(error.value)
maquina = llamar("LLVMCreateTargetMachine", ptr, [ptr,string,string,string,c.c_int,c.c_int,c.c_int],
                 target,triple,b"generic",b"",2,0,0)
modulo = llamar("LLVMModuleCreateWithName", ptr, [string], b"inicio")
llamar("LLVMSetTarget", None, [ptr,string], modulo,triple)
fuente = Path(sys.argv[1]).read_bytes()
llamar("LLVMSetModuleInlineAsm2", None, [ptr,string,c.c_size_t], modulo,fuente,len(fuente))
if llamar("LLVMTargetMachineEmitToFile", c.c_int, [ptr,ptr,string,c.c_int,ptr],
          maquina,modulo,sys.argv[2].encode(),1,c.byref(error)):
    raise SystemExit(error.value)
