name = libftplibhelp.so
destlib = /home/sakuya/sakuya/github/Net-ftplib/src/../resources/libraries/libftplibhelp.so
all: ${destlib}

.PHONY:clean

clean:
	rm -f ${destlib}

${destlib}: ftplibhelp.c
	gcc -shared -fPIC -Wdeclaration-after-statement -Werror=declaration-after-statement -O3 -DNDEBUG  -D_REENTRANT -D_FILE_OFFSET_BITS=64 -fPIC -o ${destlib} ftplibhelp.c 
