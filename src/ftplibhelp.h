
#ifndef FTP_LIB_HELP_H
#define FTP_LIB_HELP_H

#ifdef _WIN32
#define FTPLIB_HAPI __declspec(dllexport)
#else
#define FTPLIB_HAPI 
#endif

#include <stdio.h>
#include <stdbool.h>
#include <ftplib.h>

#ifdef __cplusplus
extern "C" {
#endif

FTPLIB_HAPI void FtpDebugHelp(bool);

FTPLIB_HAPI int  FtpCallbackHelp(FtpCallback, void*, unsigned int, unsigned int, netbuf *);

FTPLIB_HAPI int  FtpSizeHelp(const char*, uint64_t *, char, netbuf *);

#ifdef __cplusplus
}
#endif

#endif