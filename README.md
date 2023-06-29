# x11

Following along with https://gaultier.github.io/blog/x11_x64.html to make an x86-64 assembly by writing a GUI from scratch using X11

## Building / Running

```
# Create main executable
make

# Run the application
./main
strace ./main
```

## Notes

### Sys call conventions

Place the sys call number into register `RAX`. These values are from `unistd.h`, or specifically on linux `/usr/include/x86_64-linux-gnu/asm/unistd_64.h`

For example:

```shell
$ cat /usr/include/x86_64-linux-gnu/asm/unistd_64.h | head
#ifndef _ASM_UNISTD_64_H
#define _ASM_UNISTD_64_H

#define __NR_read 0
#define __NR_write 1
#define __NR_open 2
#define __NR_close 3
#define __NR_stat 4
#define __NR_fstat 5
```

For parameters the calling convention is:
- User space functions: stored the registers `rdi`, `rsi`, `rdx`, `rcx`, `r8`, `r9`, and additional parameters, if any, on the stack.
- Sys call functions:   stored the registers `rdi`, `rsi`, `rdx`, `r10`, `r8`, `r9`, and additional parameters, if any, on the stack.

### Man pages

View man pages such as `sock(2)`:

```
man 2 sock
```

All man pages

```
man -a sock
```