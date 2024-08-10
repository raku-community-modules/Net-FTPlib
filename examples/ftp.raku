#!/usr/bin/env raku

use Readline;
use Net::FTPlib;
use Getopt::Kinoko;
use Terminal::Readsecret;
use Getopt::Kinoko::OptionSet;
use Getopt::Kinoko::Exception;

constant FTP_PORT = 21;
constant FTP_USER = %{
	:anonymous('anonymous@host'),
	:anonymous(''),
	:ftp('ftp'),
	:ftp('')
};
constant FTP_TMP = '/tmp/kftp';

BEGIN {
	FTP_TMP.IO.mkdir();
}

class REPL { ... }
class FtpConn { ... }

my $repl = REPL.new(prompt => '>>', data => initFtpConn());

$repl.append(
	name => 'status',
	main => -> @args, $opts {
		my $status = $repl.data.logined ?? '√' !! 'x';
		my $host   = $repl.data.host // 'none';
		note "host: {$host}:{$repl.data.port // FTP_PORT}[{$status}]";
		note "user: {$repl.data.user // 'anonymous'}";
		note "mode: {$repl.data.passive ?? 'passive' !! 'port'}";
		True;
	}
);
$repl.append(
	name => 'exit',
	main => -> @args, $opts {
		$repl.data.logout();
		note "Goodbye!";
		exit(0);
	}
);
$repl.alias('exit', 'quit');
$repl.append(
	name => 'user',
	args-prompt => '<username> [password]',
	main => -> @args, $opts {
		@args.shift;
		if @args.elems == 0 {
			False
		} else {
			my \fc := $repl.data;

			fc.user = @args.shift.value;
			fc.pass = @args.elems == 0 ?? getsecret("password:") !! @args.shift.value;
			fc.login();
			True;
		}
	} 
);
$repl.append(
	name => 'ls',
	args-prompt => '[path]',
	add-option => -> $opts {
		$opts.push-option('l|local=b', comment => 'execute command locally');
		$opts;
	},
	main => -> @args, $opts {
		@args.shift;
		if $opts<l> {
			shell("ls {+@args == 0 ?? '.' !! @args.shift.value}");
		} else {
			my \fc := $repl.data;

			fc.dir(
				+@args == 0 ?? fc.ftp.pwd.decode('UTF8') !! @args.shift.value,
			) if fc.tryLogin();
		}
		True;
	}
);
$repl.append(
	name => 'pwd',
	add-option => -> $opts {
		$opts.push-option('l|local=b', comment => 'execute command locally');
		$opts;
	},
	main => -> @args, $opts {
		if $opts<l> {
			shell("pwd");
		} else {
			@args.shift;
			my \fc := $repl.data;

			say fc.ftp.pwd.decode('UTF8') if fc.tryLogin();
		}
		True;
	}
);
$repl.append(
	name => 'cd',
	args-prompt => '<path>',
	add-option => -> $opts {
		$opts.push-option('l|local=b', comment => 'execute command locally');
		$opts;
	},
	main => -> @args, $opts {
		@args.shift;
		if +@args == 0 {
			False;
		} else {
			if $opts<l> {
				shell("cd {@args.shift.value}");
			} else {
				my \fc := $repl.data;

				fc.cd(@args.shift.value) if fc.tryLogin();
			}
			True;
		}
	}
);
$repl.append(
	name => 'mkdir',
	args-prompt => '<path>',
	main => -> @args, $opts {
		@args.shift;
		if +@args == 0 {
			False
		} else {
			my \fc := $repl.data;

			fc.mkdir(@args.shift.value) if fc.tryLogin();
			True;
		}
	}
);
$repl.append(
	name => 'rmdir',
	args-prompt => '<path>',
	main => -> @args, $opts {
		@args.shift;
		if +@args == 0 {
			False
		} else {
			my \fc := $repl.data;

			fc.rmdir(@args.shift.value) if fc.tryLogin();
			True;
		}
	}
);
$repl.append(
	name => 'pasv',
	main => -> @args, $opts {
		my \fc := $repl.data;

		if fc.logined {
			note "Ftp already logined!";
		} else {
			fc.passive = True;
			say "Change to passivde mode!";
		}
		True;
	}
);
$repl.append(
	name => 'port',
	main => -> @args, $opts {
		my \fc := $repl.data;

		if fc.logined {
			note "Ftp already logined!";
		} else {
			fc.passive = False;
			say "Change to port mode!";
		}
		True;
	}
);
$repl.append(
	name => 'get',
	args-prompt => '<file>',
	add-option => -> $opts {
		$opts.push-option('a|ascii=b', comment => 'use ascii mode [default is binary]');
		$opts.push-option('o|output=s', comment => 'specifies local file path [default is same as remote file]');
		$opts;
	},
	main => -> @args, $opts {
		@args.shift;
		if +@args == 0 {
			False;
		} else {
			my ($remote, $local) = (@args.shift.value);

			if $opts.has-value('o') {
				my $o = $opts<o>.IO;

				if $o ~~ :d {
					$local = $o.abspath ~ '/' ~ $remote.IO.basename;
				} else {
					$local = $opts<o>;
				}
			} else {
				$local = $remote.IO.basename;
			}

			$repl.data.get($remote, $local, binary => !$opts<a>) if $repl.data.tryLogin();

			True;
		}
	}
);
$repl.append(
	name => 'put',
	args-prompt => '<local-file>',
	add-option => -> $opts {
		$opts.push-option('a|ascii=b', comment => 'use ascii mode [default is binary]');
		$opts.push-option('o|output=s', comment => 'specifies remote file path [default is same as remote file]');
		$opts;
	},
	main => -> @args, $opts {
		@args.shift;
		if +@args == 0 {
			False;
		} else {
			my ($local, $remote) = (@args.shift.value);

			if $opts.has-value('o') {
				if $opts<o> ~~ /\/$/ {
					$remote = $opts<o> ~ $local.IO.basename;
				} else {
					$remote = $opts<o>;
				}
			} else {
				$remote = $local.IO.basename;
			}

			$repl.data.put($remote, $local, binary => !$opts<a>) if $repl.data.tryLogin();

			True;
		}
	}
);
$repl.append(
	name => 'mv',
	args-prompt => ' <src> <dest> ',
	main => -> @args, $opts {
		my \fc := $repl.data;

		@args.shift;
		if +@args == 0 || +@args != 2 {
			False;
		} else {
			fc.mv(@args[0].value, @args[1].value) if fc.tryLogin();
			True;
		}
	}
);
$repl.append(
	name => 'rm',
	main => -> @args, $opts {
		my \fc := $repl.data;

		@args.shift;
		if +@args == 0 || +@args != 1 {
			False;
		} else {
			fc.rm(@args[0].value) if fc.tryLogin();
			True;
		}
	}
);
$repl.main-loop();

sub initFtpConn {
	my $optset = OptionSet.new();

	$optset.insert-normal("|help=b");
	$optset.set-comment('help', 'print this help message');
	$optset.push-option('h|host=s', :comment('set ftp host ip'));
	$optset.push-option('p|port=i', FTP_PORT, :comment("set ftp host port [{FTP_PORT}]"));
	$optset.push-option('u|user=s', :comment("set ftp username [anonymous]"));
	$optset.push-option(' |pass=s', :comment("set ftp password"));
	$optset.push-option('pp|pass-prompt=b', :comment("set ftp password"));
	getopt($optset);
	if $optset<help> {
		note "Usage:\n {$*PROGRAM-NAME} {$optset.usage()}\n";
		note "{@$_.join("")}\n" for $optset.comment(4);
		exit (0);
	} else {
		my FtpConn $fc .= new();

		$fc.host = $optset<host> if $optset.has-value('host');
		$fc.user = $optset<user> if $optset.has-value('user');
		$fc.port = $optset<port> if $optset.has-value('port');
		$fc.pass = $optset<pass> if $optset.has-value('pass');
		$fc.pass = getsecret('password:') if $optset<pp>;

		return $fc;
	}
}

class REPL {
	has $.prompt;
	has &.main;
	has &.front;
	has &.help;
	has &.optset;
	has %.command;
	has $.getopt;
	has $.generate-help;
	has $.data;
	has $!readline;
	
	sub default_main(Getopt $getopt, Str $line) {
		$getopt.parse($line.split(/\s+/, :skip-empty));
	}

	sub check_name($name) {
		return sub ($arg) {
			X::Kinoko::Fail.new.throw if $arg.value ne $name; 
		}
	}

	sub print_help($name, $opts, $args-prompt = "") {
		note "Usage:\n {$name} {$opts.usage()} {$args-prompt}\n";
		note "{@$_.join("")}\n" for $opts.comment(4);
	}

	sub make_optset() {
		state $optset = OptionSet.new().insert-normal("h|help=b");
		$optset.set-comment('h', 'print this help message');
		$optset.deep-clone();
	}

	method new(
		:$prompt = "",
		:&main = &default_main,
		:&front = &check_name,
		:&help = &print_help,
		:&optset = &make_optset,
		:$generate-help = True,
		:$data = Nil) {
		self.bless(:$prompt, :&main, :&front, :&help, :&optset, 
			:$generate-help, :$data)!__do_init();
	}

	method !__do_init() {
		$!readline = Readline.new;
		$!readline.using-history();
		if $!generate-help {
			self.append(
				name => 'help',
				args-prompt => '[operator]',
				main  => -> @args, $opts {
					my @cmds = $!getopt.keys();

					@args.shift;
					if @args.elems == 0 {
						note @cmds.join(" ");
					} else {
						&!help( 'help', $!getopt{@args.shift.value}, %!command<help>[0]);
					}
					True;
				}
			);
		}
		self;
	}

	method set-data($data) {
		$!data = $data;
	}

	method append(:$name, :&main = Block, :&add-option = Block, :$args-prompt = "") {
		%!command{$name} = [$args-prompt, &add-option, &main];
	}

	method alias(Str $from, Str $to) {
		%!command{$to} := %!command{$from};
	}

	method !__make_getopt() {
		$!getopt = Getopt.new(:gnu-style);
		for %!command.keys -> $name {
			my ($ap, &add-option, &main) = %!command{$name};
			my $opts = &!optset();

			$opts.insert-front(&!front($name));
			$opts.insert-all(-> @args, $opts {
				if $opts<h> {
					&!help($name, $opts, $ap);
				} else {
					unless ?&main && &main(@args, $opts) {
						&!help($name, $opts, $ap);
					}
				}
			});
			$!getopt.push($name, ?&add-option ?? &add-option($opts) !! $opts);
		}
		$!getopt;
	}

	method main-loop() {
		my $flag = True;

		while $flag {
			if $!readline.readline($!prompt) -> $line {
				if $line.trim -> $line {
					$!readline.add-history($line);
					try {
						&!main(self!__make_getopt(), $line);
						CATCH {
							default {
								note "Unrecongnize command: {$line}.";
								.message.note;
								...
							}
						}
					}
				}
			}
		}
	}
}

class FtpConn {
	has $.ftp;
	has $.logined = False;
	has $.passive is rw = True;
	has $.host is rw;
	has $.port is rw;
	has $.user is rw;
	has $.pass is rw;

	method loginAsAnonymous() {
		my %__anonymous = 
			anonymous 	=> "anonymous\@{$!host}",
			anonymous 	=> '',
			ftp 		=> 'ftp',
			ftp 		=> '',
		;	

		for %__anonymous.kv -> ($user, $pass) {
			$!ftp = Ftp.new(:$!host, :$!port, :$user, :$pass, :$!passive);
			try {
				$!ftp.login();
				$!logined = True;
				last;
				CATCH {
					default {		
					}
				}
			}
		}
		note "Login failed!" unless $!logined;
	}

	method login() {
		if $!logined {
			note "Already logined!";
		} else {
			unless ?$!host {
				note "Ftp host not set!";
				return;
			}
			$!ftp = Ftp.new(:$!host, :$!port, :$!user, :$!pass, :$!passive);
			try {
				$!ftp.login();
				$!logined = True;
				CATCH {
					default {
						note "Login failed!";
					}
				}
			}
		}
	}

	method tryLogin() {
		unless $!logined {
			?$!user ?? self.login() !! self.loginAsAnonymous();
		}
		return $!logined;
	}

	method logout() {
		if !$!logined {
			note "Not logined!";
		} else {
			try {
				$!ftp.quit();
				$!logined = False;
				CATCH {
					default {
						note "Logout failed!";
					}
				}
			}
		}
	}

	method dir(Str $path) {
		try {
			$!ftp.dir($path);
			CATCH {
				default {
					note "List file failed!";
				}
			}
		}
	}

	method cd(Str $path) {
		try {
			$!ftp.chdir($path);
			CATCH {
				default {
					note "Change directory failed!";
				}
			}
		}
	}

	method mkdir(Str $path) {
		try {
			$!ftp.mkdir($path);
			CATCH {
				default {
					note "Make directory failed!";
				}
			}
		}
	}

	method rmdir(Str $path) {
		try {
			$!ftp.rmdir($path);
			CATCH {
				default {
					note "Remove directory failed!";
				}
			}
		}
	}

	method get(Str $path, Str $outpath, :$binary) {
		try {
			$!ftp.get($path, $outpath, mode => ($binary ?? (AccessMode::BINARY) !! (AccessMode::ASCII)));
			CATCH {
				default {
					note "Get file failed!";
				}
			}
		}
	}

	method put(Str $path, Str $inpath, :$binary) {
		try {
			$!ftp.put($path, $inpath, mode => $binary ?? (AccessMode::BINARY) !! (AccessMode::ASCII));
			CATCH {
				default {
					note "Put file failed!";
				}
			}
		}
	}

	method mv(Str $s, Str $d) {
		try {
			$!ftp.rename($s, $d);
			CATCH {
				default {
					note "Move file failed!";
				}
			}
		}
	}

	method rm(Str $path) {
		try {
			$!ftp.delete($path);
			CATCH {
				default {
					note "Remove file failed!";
				}
			}
		}
	}
}




