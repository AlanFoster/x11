; Build with: make

BITS 64
CPU X64

; System call IDs - values from unistd.h - /usr/include/x86_64-linux-gnu/asm/unistd_64.h
%define SYSCALL_EXIT 60

section .text
global _start

_start:
  mov RAX, SYSCALL_EXIT
  mov rdi, 0
  syscall