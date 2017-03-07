
use v6;
use NativeCall;

constant ftplib 	= 'ftp';
constant ftphelplib	= %?RESOURCES<ftphelplib>.Str;

sub FtpInit() is native(ftplib) { * }

BEGIN {
	FtpInit();
}

class X::Ftp::Error is Exception {
	has $.msg handles <Str>;

    method message() {
        $!msg;
    }
}

class X::Ftp::EOF is Exception {}

class CStr {
	has CArray[uint8] $.buf;
	has int32 $.len;

	multi method new(Int $len) {
		self.bless(len => int32.new($len))!init();
	}

	multi method new(Blob $blob) {
		self.bless()!copy($blob);
	}

	method !init() {
		$!buf .= new();
		$!buf[$_] = 0 for ^$!len;
		self;
	}

	method !copy(Blob $blob) {
		$!buf .= new();
		$!len = $blob.elems;
		$!buf[$_] = $blob[$_] for ^$!len;
		self;
	}

	method Buf($len = $!len) {
		my $buf = Buf.new;
		$buf[$_] = $!buf[$_] for ^$len;
		$buf;
	}
}

class Ftp {
	has $!netbuf;
	has Str $.host;
	has Str $.user;
	has Str $.pass;
	has     $.passive;
	has 	$.error;

	# my $debug := cglobal(ftplib, 'ftplib_debug', int32);

	sub FtpDebugHelp(bool) is native(ftphelplib) { * }

	sub FtpSite(Str, Pointer) returns int32 is native(ftplib) { * }

	sub FtpLastResponse(Pointer) returns Str is native(ftplib) { * }

	sub FtpSysType(Str, int32, Pointer) returns int32 is native(ftplib) { * }

	sub FtpSize(Str, uint32 is rw, int8, Pointer) returns int32 is native(ftplib) { * }

	# sub FtpSizeLong(Str, uint64 is rw, int8, Pointer) returns int32 is native(ftplib) { * }

	sub FtpSizeHelp(Str, uint64 is rw, int8, Pointer) returns int32 is native(ftphelplib) { * }

	sub FtpModDate(Str, Str, int32, Pointer) returns int32 is native(ftplib) { * }

	# sub FtpSetCallback(CallBackOpt is rw, Pointer) returns int32 is native(ftplib) { * }

	sub FtpCallbackHelp( &cb (Pointer, uint64, Pointer), Pointer, uint32, uint32, Pointer) returns int32 is native(ftphelplib) { * }

	sub FtpClearCallback(Pointer) returns int32 is native(ftplib) { * }

	#| Server Connection

	sub FtpConnect(Str, Pointer is rw) returns int32 is native(ftplib) { * }

	sub FtpLogin(Str, Str, Pointer) returns int32 is native(ftplib) { * }

	sub FtpQuit(Pointer) is native(ftplib) { * }

	sub FtpOptions(int32, int64, Pointer) returns int32 is native(ftplib) { * }

	#| Directory Functions

	sub FtpChdir(Str, Pointer) returns int32 is native(ftplib) { * }

	sub FtpMkdir(Str, Pointer) returns int32 is native(ftplib) { * }

	sub FtpRmdir(Str, Pointer) returns int32 is native(ftplib) { * }

	sub FtpDir(Str, Str, Pointer) returns int32 is native(ftplib) { * }

	sub FtpNlst(Str, Str, Pointer) returns int32 is native(ftplib) { * }

	sub FtpCDUp(Pointer) returns int32 is native(ftplib) { * }

	sub FtpPwd(CArray[uint32], int32, Pointer) returns int32 is native(ftplib) { * }

	#| File to File Transfer

	sub FtpGet(Str, Str, int8, Pointer) returns int32 is native(ftplib) { * }

	sub FtpPut(Str, Str, int8, Pointer) returns int32 is native(ftplib) { * }

	sub FtpDelete(Str, Pointer) returns int32 is native(ftplib) { * }

	sub FtpRename(Str, Str, Pointer) returns int32 is native(ftplib) { * }

	#| File to Program Transfer

	sub FtpAccess(Str, int32, int32, Pointer, Pointer is rw) returns int32 is native(ftplib) { * }

	sub FtpRead(CArray[uint8], int32, Pointer) returns int32 is native(ftplib) { * }

	sub FtpWrite(CArray[uint8], int32, Pointer) returns int32 is native(ftplib) { * }

	sub FtpClose(Pointer) returns int32 is native(ftplib) { * }

	#| for C<&setOption>
	my enum Opt is export (
		CONNMODE		=> 1,
		CALLBACK 		=> 2,
		IDLETIME		=> 3,
		CALLBACKARG		=> 4,
		CALLBACKBYTES	=> 5,
	);

	#| for CONNMODE
	my enum ConnMode is export (
		PASSIVE 	=> 1,
		PORT 		=> 2,
	);

	#| for
	my enum AccessMode is export (
		ASCII	=> 'A',
		IMAGE	=> 'I',
		TEXT	=> 'A',
		BINARY	=> 'I',
	);

	#| for
	my enum AccessType is export (
		DIR 		=> 1,
		DIR_VERBOSE	=> 2,
		FILE_READ	=> 3,
		FILE_WRITE	=> 4,
	);

	method !__handle_exception($ret, $good, $msg, &cb) {
		if $ret != $good {
			note $ret;
			&cb andthen &cb();
			$!error = $ret;
			X::Ftp::Error.new(:$msg).throw();
		}
	}

	method !__handle_exception_0($ret, $msg = "", &cb = Block) returns Ftp {
		self!__handle_exception($ret, 1, $msg, &cb);
		self;
	}

	method !__handle_exception_1($ret, $msg = "", &cb = Block) returns Ftp {
		self!__handle_exception($ret, 0, $msg, &cb);
		self;
	}

	method login() {
		$!netbuf = Pointer.new(0);
		self!__handle_exception_0(FtpConnect($!host, $!netbuf), {
			$!netbuf = Pointer;
		});
		self!__handle_exception_0(FtpLogin($!user, $!pass, $!netbuf));
		self.setOption(Opt::CONNMODE, ConnMode::PASSIVE) if $!passive;
		self;
	}

	method quit() {
		if $!netbuf {
			FtpQuit($!netbuf);
			$!netbuf = Pointer;
		}
		self;
	}

	method setOption(Opt $opt, ConnMode $cm) {
		self!__handle_exception_0(FtpOptions(int32.new($opt.Int), long.new($cm.Int), $!netbuf));
	}

	method chdir(Str $path) {
		self!__handle_exception_0(FtpChdir($path, $!netbuf));
	}

	method cdup() {
		self!__handle_exception_0(FtpCDUp($!netbuf));
	}

	method mkdir(Str $path) {
		self!__handle_exception_0(FtpMkdir($path, $!netbuf));
	}

	method rmdir(Str $path) {
		self!__handle_exception_0(FtpRmdir($path, $!netbuf));
	}

	method pwd(Int $len = 256) returns Buf {
		my CStr $cstr .= new($len);
		self!__handle_exception_0(FtpPwd($cstr.buf, $cstr.len, $!netbuf));
		$cstr.Buf();
	}

	method dir(Str $path, Str $outputfile = Str) {
		self!__handle_exception_0(FtpDir($outputfile, $path, $!netbuf));
	}

	method nlst(Str $path, Str $outputfile = Str) {
		self!__handle_exception_0(FtpNlst($outputfile, $path, $!netbuf));
	}

	method get(Str $path, Str $outputfile = Str, AccessMode :$mode = AccessMode::ASCII) {
		self!__handle_exception_0(FtpGet($outputfile, $path, int8.new($mode.value.ord()), $!netbuf));
	}

	method put(Str $path, Str $inputfile = Str, AccessMode :$mode = AccessMode::ASCII) {
		self!__handle_exception_0(FtpPut($inputfile, $path, int8.new($mode.value.ord()), $!netbuf));
	}

	method delete(Str $path) {
		self!__handle_exception_0(FtpDelete($path, $!netbuf));
	}

	method rename(Str $src, Str $dst) {
		self!__handle_exception_0(FtpRename($src, $dst, $!netbuf));
	}

	my class FtpDataConn {
		has $.netbuf;
		has $.error;
		has $.mode;

		method !__check_mode($mode) {
			if $!mode ne $mode {
				X::Ftp::Error.new(msg => "Can do a {$mode} in {$!mode} mode.").throw();
			}
		}

		method read(int $size) {
			self!__check_mode('read');
			my CStr $cstr .= new($size);
			my $ret = FtpRead($cstr.buf, $cstr.len, $!netbuf);
			if $ret == -1 {
				$!error = $ret;
				X::Ftp::Error.new(msg => "Read file error.").throw();
			}
			elsif $ret == 0 {
				X::Ftp::EOF.new().throw();
			}
			return $cstr.Buf($ret);
		}

		method write(Blob $blob) {
			self!__check_mode('write');
			my CStr $cstr .= new($blob);
			my $ret = FtpWrite($cstr.buf, $cstr.len, $!netbuf);
			if $ret == -1 {
				$!error = $ret;
				X::Ftp::Error.new(msg => "Read file error.").throw();
			}
			return $ret;
		}

		method close() {
			FtpClose($!netbuf);
		}
	}

	method access(Str $path, AccessType $type, AccessMode :$mode = AccessMode::ASCII) {
		my $netbuf = Pointer.new(0);
		self!__handle_exception_0(FtpAccess($path, int32.new($type.value), int32.new(
			$mode.value.ord()), $!netbuf, $netbuf));
		return FtpDataConn.new(:$netbuf, mode => ($type == AccessType::FILE_WRITE ?? 'write' !! 'read'));
	}

	method site(Str $command) {
		self!__handle_exception_0(FtpSite($command, $!netbuf));
	}

	method lastResponse() {
		FtpLastResponse($!netbuf);
	}

	method systype(Int $size) {
		my CStr $cstr .= new($size);
		self!__handle_exception_0(FtpSysType($cstr.buf, $cstr.len, $!netbuf));
		return $cstr.Buf;
	}
}
