#!/bin/sh
# Reproduce el iniciador con GNU binutils x86-64 (as, objcopy y ld con i386pep).
set -eu
src=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cd "$tmp"
for dll in kernel32 shell32 user32; do
    case "$dll" in
        kernel32) funciones="GetModuleFileNameW ExitProcess";;
        shell32) funciones=ShellExecuteW;;
        user32) funciones=MessageBoxW;;
    esac
    echo "LIBRARY $dll.dll" > "$dll.def"
    echo EXPORTS >> "$dll.def"
    for f in $funciones; do
        echo "$f" >> "$dll.def"
        echo ".global $f" >> "$dll.s"
        echo "$f: ret" >> "$dll.s"
    done
    as --64 "$dll.s" -o "$dll.o"
    objcopy -O pe-x86-64 "$dll.o" "$dll.obj"
    ld -mi386pep --shared -e 0 "$dll.obj" "$dll.def" --out-implib "lib$dll.a" -o "$dll.dll"
done
python3 "$src/ensamblar.py" "$src/abrir.s" abrir.obj
ld -mi386pep --subsystem windows -e inicio -o "$src/../RegistroTrabajadores.exe" abrir.obj -L. -lkernel32 -lshell32 -luser32
