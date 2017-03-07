
use LibraryMake;

class Build {
    method build($workdir) {
        my $source      = "{$workdir}/src";
        my $resources   = "{$workdir}/resources";
        my $library     = "{$resources}/libraries";
        my %vars        = get-vars($source);
        my $current     = $*CWD;
        
        %vars<ftplibhelp> = $*VM.platform-library-name('ftplibhelp'.IO);
        mkdir $resources unless $resources.IO.e;
        mkdir $library   unless $library.IO.e;
        process-makefile($source, %vars);
        chdir($source);
        shell(%vars<MAKE>);
        chdir($current);
    }

    method isa($what) {
        return True if $what.^name eq 'Panda::Builder';
        callsame;
    }
}