; Build with: make

BITS 64
CPU X64

; System call IDs - values from unistd.h - /usr/include/x86_64-linux-gnu/asm/unistd_64.h
%define SYSCALL_WRITE 1
%define SYSCALL_EXIT 60

; File descriptors
%define STDIN 0
%define STDOUT 1
%define STDERR 2

; Newline
%define NEWLINE 10

section .text
global _start

print_startup_message:
  ; Preamble
  push rbp ; Save rbp to restore at the end of the function
  mov rbp, rsp ; set rbp to rsp
  sub rsp, 16 ;  We need less than this, but align to 16 bytes to allow calling additional functions

  ; Main
  mov BYTE [rsp + 0], 's'
  mov BYTE [rsp + 1], 't'
  mov BYTE [rsp + 2], 'a'
  mov BYTE [rsp + 3], 'r'
  mov BYTE [rsp + 4], 't'
  mov BYTE [rsp + 5], 'e'
  mov BYTE [rsp + 6], 'd'
  mov BYTE [rsp + 7], NEWLINE

  ; Write sys call
  mov rax, SYSCALL_WRITE
  mov rdi, STDOUT ; Write to stdout
  lea rsi, [rsp] ; Address on the stack
  mov rdx, 8 ; Length of string
  syscall

  ; Post-amble
  add rsp, 16 ; Restore stack size
  pop rbp ; Restore rbp
  ret

_start:
  call print_startup_message

  mov RAX, SYSCALL_EXIT
  mov rdi, 0
  syscall
