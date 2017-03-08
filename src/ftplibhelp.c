
#include "ftplibhelp.h"

void FtpDebugHelp(bool flag)
{
    ftplib_debug = flag ? 1 : 0;
}

int FtpHasUINT64MAX(void)
{
    #ifdef __UINT64_MAX
        return 1;
    #else
        return 0;
    #endif
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
