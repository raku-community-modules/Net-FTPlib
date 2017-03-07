#!/usr/bin/env perl6

use v6;
use Net::ftplib;

my $ftp = Ftp.new(host => "192.168.0.106:21", user => "ftptest138", pass => "123456", :passive);

$ftp.login();

my $fdc = $ftp.access("ftp.pl2", AccessType::FILE_WRITE);

note "OPENED:?";

my $file = "/sakuya/github/Net-ftplib/META6.json".IO.open(:r);

note "OPENED:?";
while $file.read(128) -> $blob {
    try {
        say $blob.decode('UTF8');
        $fdc.write($blob);
        CATCH {
            when X::Ftp::EOF {
                "End of file".say;
                last;
            }
            default {
                .message.say;
                ...
            }
        }
    }
}
$fdc.close();
$ftp.quit();

dd $ftp;
