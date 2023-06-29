; Build with: make

BITS 64
CPU X64

; System call IDs - values from unistd.h - /usr/include/x86_64-linux-gnu/asm/unistd_64.h
%define SYSCALL_WRITE 1
%define SYSCALL_SOCKET 41
%define SYSCALL_EXIT 60

; File descriptors
%define STDIN 0
%define STDOUT 1
%define STDERR 2

; Newline
%define NEWLINE 10

; Socket constants
%define AF_UNIX 1
%define SOCK_STREAM 1

section .text

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

  ; Postamble
  add rsp, 16 ; Restore stack size
  pop rbp ; Restore rbp
  ret

; Create a unix domain socket and connect to the x11 server
; @returns The socket file descriptor
x11_connect_to_server:
static x11_connect_to_server:function ; metadata for strace -k
  ; Preamble
  push rbp
  mov rbp, rsp

  ; Open socket
  mov rax, SYSCALL_SOCKET
  mov rdi, AF_UNIX ; Unix socket
  mov rsi, SOCK_STREAM ; Stream orientated
  mov rdx, 0 ; Automatic protocol
  syscall

  cmp rax, 0
  jle die

  mov rdi, rax ; Store socket fd in rdi for the remainder of the function

  ; Postamble
  pop rbp
  ret

die:
  ; Preamble
  push rbp
  mov rbp, rsp

  ; main
  mov rax, SYSCALL_EXIT
  mov rdi, 1
  syscall

  ; Postamble
  pop rbp
  ret

global _start
_start:
  call print_startup_message

  call x11_connect_to_server

  ; Exit
  mov RAX, SYSCALL_EXIT
  mov rdi, 0
  syscall
