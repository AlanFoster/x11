all:
	nasm -f elf64 -g main.nasm && ld main.o -static -o main

clean:
	rm main *.o