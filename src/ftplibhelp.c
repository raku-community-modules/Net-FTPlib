
#include "ftplibhelp.h"

void FtpDebugHelp(bool flag)
{
    ftplib_debug = flag ? 1 : 0;
}

int  FtpCallbackHelp(FtpCallback cb, void* arg, unsigned int bx, unsigned int it, netbuf *nb)
{
    int ret = 0;

    FtpCallbackOptions fco = {
        .cbFunc      = cb,
        .cbArg       = arg,
        .bytesXferred= bx,
        .idleTime    = it,
    };

    ret = FtpSetCallback(&fco, nb);

    return ret;
}

int  FtpSizeHelp(const char* path, uint64_t *size, char mode, netbuf *nb)
{
    int     ret = 0;

#ifdef __UINT64_MAX
    fsz_t   ret_size = 0L;
    ret = FtpSizeLong(path, &ret_size, mode, nb);
    *size = ret_size;
#else
    ret = 0;
#endif
    
    return ret;
}