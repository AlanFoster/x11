; Build with: make

BITS 64
CPU X64

; System call IDs - values from unistd.h - /usr/include/x86_64-linux-gnu/asm/unistd_64.h
%define SYSCALL_READ 0
%define SYSCALL_WRITE 1
%define SYSCALL_SOCKET 41
%define SYSCALL_CONNECT 42
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

; From sys/un.h - sizeof(struct sockaddr_un addr)
%define UNIX_PATH_MAX 108
%define SIZEOF_SUN_FAMILY 2
; struct sockaddr_un {
;    sa_family_t sun_family;             /* AF_UNIX */
;    char       sun_path[108];           /* Pathname */
; };
%define SIZEOF_SOCK_ADDR_UN (SIZEOF_SUN_FAMILY + UNIX_PATH_MAX)
%define MAXIMUM_EXPECTED_X11_HANDSHAKE_SIZE (1 << 15) ; From the author, 14kb response so 32kb to safe. This isn't a scalable solution though, as the server could return more.
; typedef struct {
;   u8 order;
;   u8 pad1;
;   u16 major, minor;
;   u16 auth_proto, auth_data;
;   u16 pad2;
; } x11_connection_req_t;
%define SIZEOF_x11_connection_req_t 12 * 8 ; 12 bytes
%define RESPONSE_FAILURE          1
%define RESPONSE_SUCCESS          1
%define RESPONSE_AUTHENTICATION   2

section .rodata
sun_path: db "/tmp/.X11-unix/X0", 0
sun_path_byte_size: equ $ - sun_path
static sun_path:data

message_connect_to_server: db 'connecting to server...', NEWLINE, 0
message_connect_to_server_length: equ $ - message_connect_to_server
static message_connect_to_server:data

message_handshake: db 'starting handshake...', NEWLINE, 0
message_handshake_length: equ $ - message_handshake
static message_handshake:data

section .data
id: dd 0
static id:data

id_base: dd 0
static id_base:data

id_mask: dd 0
static id_mask:data

root_visual_id: dd 0
static root_visual_id:data

section .text

; Simple print message using no args, and the stack for the startup message string
; A more generic print message function is below
print_startup_message:
static print_startup_message:function ; metadata for strace -k
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
  mov rdx, 8 ; Length of string plus new line
  syscall

  ; Postamble
  add rsp, 16 ; Restore stack size
  pop rbp ; Restore rbp
  ret

; Create a unix domain socket and connect to the x11 server
; @param rdi Pointer to the string to print out
; @param rsi String length
; @returns The socket file descriptor
print_message:
static print_message:function ; metadata for strace -k
  ; premable
  push rbp
  mov rbp, rsp

  push rsi ; Temporarily push the string length to the stack, so we can use it as rdi to the syscall_write later
  push rdi ; Temporarily push the param address to the stack, so we can use it as rsi to syscall_write later

  ; Write sys call
  mov rax, SYSCALL_WRITE
  mov rdi, STDOUT ; Write to stdout
  pop rsi ; Pop the previously pushed string param into the sys call rsi
  pop rdx ; Length of string
  syscall

  ; Postamble
  pop rbp
  ret

; Create a unix domain socket and connect to the x11 server
; @returns The socket file descriptor
x11_connect_to_server:
static x11_connect_to_server:function ; metadata for strace -k
  ; Preamble
  push rbp
  mov rbp, rsp
  ; TODO: Use byte align helper
  sub rsp, SIZEOF_SOCK_ADDR_UN + 2 ; Reserve space for sock_addr_un

  lea rdi, [message_connect_to_server]
  mov rsi, message_connect_to_server_length
  call print_message

  ; Open socket
  mov rax, SYSCALL_SOCKET
  mov rdi, AF_UNIX ; Unix socket
  mov rsi, SOCK_STREAM ; Stream orientated
  mov rdx, 0 ; Automatic protocol
  syscall

  cmp rax, 0
  jle die

  mov rdi, rax ; Store socket fd in rdi for the remainder of the function

  ; Connect sys call requires a struct, example for unix sock address:
  ; const sockaddr_un addr = {
  ;   .sun_family = AF_UNIX, ; 1 - unix domain sockets
  ;   .sun_path = "/tmp/.X11-unix/X0"
  ; }
  ; const in res = connect(x11_socket_fd, (const struct sockaddr*) &addr, sizeof(addr));

  mov WORD [rsp], AF_UNIX ; Set sockaddr_un.sun_family to AF_UNIX
  ; Fill sockaddr_un.sun_path with "/tmp/.X11-unix/x0"
  lea rsi, sun_path ; Set source for memcpy
  mov r12, rdi ; Save socket descriptor in `rdi` in `r12`
  lea rdi, [rsp + 2] ; Set the destination for string copy to the stackpointer after the AF_UNIX
  cld ; Clear the DF flag to ensure the copy is done forwards
  mov ecx, sun_path_byte_size ; Length is 19 with the null terminator
  rep movsb ; Rep = Repeat string operation prefix, byte move

  ; int3

  ; Call sys connect: connect(2)
  mov rax, SYSCALL_CONNECT
  mov rdi, r12 ; file descriptor
  lea rsi, [rsp] ; Path to unix socket
  mov rdx, SIZEOF_SOCK_ADDR_UN ; sizeof(addr)
  syscall

  cmp rax, 0
  jne die

  mov rax, rdi ; Set return value to socket fd

  ; Postamble
  add rsp, SIZEOF_SOCK_ADDR_UN + 2 ; Space for sock_addr_un
  pop rbp
  ret

; Send the x11 handshake to the X11 server, and read the returned system information
; @param rdi The socket file descriptor
; @returns The window root id (uint32_t) in rax
x11_send_handshake:
static x11_send_handshake:function
  ; Preamble
  push rbp
  mov rbp, rsp
  sub rsp, MAXIMUM_EXPECTED_X11_HANDSHAKE_SIZE

  ; Request out:
  ; x11_connection_req_t req = { .order = 'l', .major = 11 };
  mov BYTE [rsp + 0], 'l' ; u8 Order = 'l'
  mov WORD [rsp + 2], 11 ; u16 major = 11

  ; Send the handshake with write(2)
  mov rax, SYSCALL_WRITE
  mov rdi, rdi ; file descriptor
  lea rsi, [rsp] ; pointer to request struct
  mov rdx, SIZEOF_x11_connection_req_t ; write size of struct
  syscall

  cmp rax, SIZEOF_x11_connection_req_t ; Assert all request bytes are written successfully
  jnz die

  ; Read the server response with read(2)
  ; Read onto the stackbuffer; the first byte is an enum for success or failure

  mov rax, SYSCALL_READ
  mov rdi, rdi ; file descriptor
  lea rsi, [rsp] ; Write to stackpointer
  mov rdx, 8 ; Read size of initial enum
  syscall

  cmp rax, 8 ; Ensure 8 bytes read
  jnz die

  cmp BYTE [rsp], RESPONSE_SUCCESS ; Check the server sent 'success', first byte is 1
  jnz die

  ; Since we've succeeded, the server will return a custom success struct
  mov rax, SYSCALL_READ
  mov rdi, rdi ; file descriptor
  lea rsi, [rsp] ; Read into stack pointer
  mov rdx, MAXIMUM_EXPECTED_X11_HANDSHAKE_SIZE ; Read size
  syscall

  cmp rax, 0 ; Check that the server replied with something
  jle die

  ; Set id_base globally
  mov edx, DWORD [rsp + 4]
  mov DWORD [id_base], edx

  ; Set id_mask globally
  mov edx, DWORD [rsp + 8]
  mov DWORD [id_mask], edx

  ; Read the information information we need, skip over teh rest
  lea rdi, [rsp] ; Pointer that will skip over data

  mov cx, WORD [rsp + 16] ; Vendor length (v)
  movzx rcx, cx ; TODO: Try to write this as a single movzx rcx, WORD [ rsp + 16 ]

  mov al, BYTE [rsp + 21] ; Number of formats (n)
  movzx rax, al ; Fill the rest of the register with zeroes to avoid garbage values
  imul rax, 8 ; sizeof(format) == 8

  add rdi, 32 ; Skip connection setup
  add rdi, rcx ; Skip over vendor information

  ; Skip over padding
  add rdi, 3
  and rdi, -4

  add rdi, rax ; Skip over the format information (n * 8)

  mov eax, DWORD [rdi] ; Store and return the window root id

  ; Set the root_visual_id globally
  mov edx, DWORD [rdi + 32]
  mov DWORD [root_visual_id], edx

  ; Postamble
  add rsp, MAXIMUM_EXPECTED_X11_HANDSHAKE_SIZE
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
  call x11_send_handshake

  ; Exit
  mov RAX, SYSCALL_EXIT
  mov rdi, 0
  syscall
