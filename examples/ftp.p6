#!/usr/bin/env perl6

use v6;
use Readline;
use Net::FTPlib;
use Getopt::Kinoko;
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
	getopt($optset);
	if $optset<h> {
		note "Usage:\n {$*PROGRAM-NAME} {$optset.usage()}\n";
		note "{@$_.join("")}\n" for $optset.comment(4);
	} else {
		my FtpConn $fc .= new();

		$fc.ftp.host = $optset<host> if $optset.has-value('host');
		$fc.ftp.user = $optset<user> if $optset.has-value('user');
		$fc.ftp.port = $optset<port> if $optset.has-value('port');
		$fc.ftp.pass = $optset<pass> if $optset.has-value('pass');

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
					if @args == 0 {
						note @cmds.join(" ");
					} else {
						note &!help('help', $!getopt{@args.shift}, %!command<help>[0]);
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
					&main(@args, $opts) if &main;
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
	has $.ftp = Ftp.new();
	has $.binary is rw = False;
	has $.logined is rw = False;
}




