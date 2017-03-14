#!/usr/bin/env perl6

use v6;
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

class REPL { ... }
class FtpConn { ... }

my $repl = REPL.new(prompt => '>>', data => initFtpConn());

$repl.append(
	name => 'status',
	main => -> @args, $opts {
		my $status = $repl.data.logined ?? '√' !! 'x';
		my $host   = $repl.data.ftp.host // 'none';
		note "host: {$host}:{$repl.data.ftp.port // FTP_PORT}[{$status}]";
		note "user: {$repl.data.ftp.user // 'anonymous'}";
		note "mode: {$repl.data.ftp.passive ?? 'passive' !! 'port'}";
		note "flag: {$repl.data.binary ?? 'binary' !! 'ascii'}";
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
	main => -> @args, $opts {
		@args.shift;
		my \fc := $repl.data;

		fc.tryLogin();
		if @args.elems == 0 {
			fc.ftp.dir(fc.ftp.pwd.decode('UTF8'));
		} else {
			fc.ftp.dir(@args.shift.value);
		}
		True;
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
		$!getopt = Getopt.new;
		for %!command.keys -> $name {
			my ($ap, &add-option, &main) = %!command{$name};
			my $opts = &!optset();

			$opts.insert-front(&!front($name));
			$opts.insert-all(-> @args, $opts {
				if $opts<h> {
					&!help($name, $opts, $ap);
				} else {
					unless &main && &main(@args, $opts) != False {
						&!help($name, $opts, $ap);
					}
				}
			});
			$!getopt.push($name, &add-option ?? &add-option($opts) !! $opts);
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
	has $.binary is rw = False;
	has $.logined is rw = False;
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
			$!ftp = Ftp.new(:$!host, :$!port, :$user, :$pass);
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
			$!ftp = Ftp.new(:$!host, :$!port, :$!user, :$!pass);
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
		if $!logined {
			return;
		} else {
			?$!user ?? self.login() !! self.loginAsAnonymous();
		}
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
}




