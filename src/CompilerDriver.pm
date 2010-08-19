package CompilerDriver;
use strict;
use warnings;
use 5.010;

use Sub::Exporter -setup => {
    exports => [ qw(compile) ]
};

use Time::HiRes 'time';
use File::Basename;
use autodie ':all';

open ::NIECZA_OUT, ">&", \*STDOUT;

BEGIN {
    use File::Spec;
    unshift @INC, File::Spec->catdir(
        dirname(dirname($INC{'CompilerDriver.pm'})), 'STD_checkout');
    $CursorBase::SET_PERL6LIB = [ File::Spec->curdir ];
}

use Body ();
use Decl ();
use Unit ();
use Op ();
use Optimizer::Beta ();
use ResolveLex ();
use Storable;

use Niecza::Grammar ();
use Niecza::Actions ();

my ($srcdir, $rootdir, $builddir, $libdir);
{
    $srcdir   = dirname($INC{'CompilerDriver.pm'});
    $rootdir  = dirname($srcdir);
    $builddir = File::Spec->catdir($rootdir, "obj");
    $libdir   = File::Spec->catdir($rootdir, "lib");
}
File::Path::make_path($builddir);

sub build_file { File::Spec->catfile($builddir, $_[1]) }

sub metadata_for {
    my ($unit) = @_;
    $unit =~ s/::/./g;

    Storable::retrieve(File::Spec->catfile($builddir, "$unit.store"))
}

sub get_perl6lib {
    $libdir, File::Spec->curdir
}

sub find_module {
    my $module = shift;
    my $issetting = shift;

    my @toks = split '::', $module;
    my $end = pop @toks;

    for my $d (get_perl6lib) {
        for my $ext (qw( .setting .pm6 .pm )) {
            next if ($issetting xor ($ext eq '.setting'));

            my $file = File::Spec->catfile($d, @toks, "$end$ext");
            next unless -f $file;

            if ($ext eq '.pm') {
                local $/;
                open my $pm, "<", $file or next;
                my $pmtx = <$pm>;
                close $pm;
                next if $pmtx =~ /^\s*package\s+\w+\s*;/m; # ignore p5 code
            }

            return $file;
        }
    }

    return;
}



{
    package
        CursorBase;
    no warnings 'redefine';

    sub sys_save_syml {
        my ($self, $all) = @_;
        $::niecza_mod_symbols = $all;
    }

    sub sys_load_modinfo {
        my $self = shift;
        my $module = shift;
        return CompilerDriver::metadata_for($module)->{'syml'};
        #$module =~ s/::/./g;

        #my ($symlfile) = File::Spec->catfile($builddir, "$module.store");
        #my ($modfile) = CompilerDriver::find_module($module, 0) or do {
        #    $self->sorry("Cannot locate module $module");
        #    return undef;
        #};

        #unless (-f $symlfile and -M $modfile > -M $symlfile) {
        #    $self->sys_compile_module($module, $symlfile, $modfile);
        #}
        #return CompilerDriver::metadata_for($symlfile)->{'syml'};
    }

    sub load_lex {
        my $self = shift;
        my $setting = shift;
        my $settingx = $setting;
        $settingx =~ s/::/./g;

        if ($setting eq 'NULL') {
            my $id = "MY:file<NULL.pad>:line(1):pos(0)";
            my $core = Stash->new('!id' => [$id], '!file' => 'NULL.pad',
                '!line' => 1);
            return Stash->new('CORE' => $core, 'MY:file<NULL.pad>' => $core,
                'SETTING' => $core, $id => $core);
        }

        my $astf = File::Spec->catfile($builddir, "$settingx.store");
        if (-e $astf) {
            return Storable::retrieve($astf)->{'syml'};
        }

        $self->sorry("Unable to load setting $setting.");
        return $self->load_lex("NULL");
    }
}

sub compile {
    my %args = @_;

    my ($name, $file, $code, $lang, $safe, $setting) =
        @args{'name', 'file', 'code', 'lang', 'safe', 'setting'};

    $lang //= 'CORE';

    if (defined($name) + defined($file) + defined($code) != 1) {
        Carp::croak("Exactly one of name, file, and code must be used");
    }

    my $path = $file;
    if (defined($name)) {
        $path = find_module($name, $setting);
        if (!defined($path)) {
            Carp::croak("Module $name not found");
        }
    }

    local %::UNITREFS;
    local %::UNITREFSTRANS;
    local %::UNITDEPSTRANS;
    local $::SETTING_RESUME;
    local $::niecza_mod_symbols;
    local $::YOU_WERE_HERE;
    local $::UNITNAME = $name // 'MAIN';
    $::UNITNAME =~ s/::/./g;
    local $::SAFEMODE = $safe;
    $STD::ALL = {};

    $::SETTING_RESUME = metadata_for($lang)->{setting} unless $lang eq 'NULL';
    $::UNITREFS{$lang} = 1 if $lang ne 'NULL';

    if (defined($name)) {
        my $rp = Cwd::realpath($path);
        $::UNITDEPSTRANS{$name} = [ $rp, ((stat $rp)[9]) ];
    }

    my ($m, $a) = defined($path) ? (parsefile => $path) : (parse => $code);

    my $ast;
    my $basename = $::UNITNAME;
    my $csfile = File::Spec->catfile($builddir, "$basename.cs");
    my $outfile = File::Spec->catfile($builddir,
        $basename . ($args{main} ? ".exe" : ".dll"));

    my @phases = (
        [ 'parse', sub {
            $ast = Niecza::Grammar->$m($a, setting => $lang,
                actions => 'Niecza::Actions')->{_ast}; } ],
        [ 'lift_decls', sub {
            $::SETTING_RESUME = undef;
            $ast->lift_decls; } ],
        [ 'beta', sub { Optimizer::Beta::run($ast) } ],
        [ 'extract_scopes', sub { $ast->extract_scopes } ],
        [ 'to_cgop', sub { $ast->to_cgop } ],
        [ 'resolve_lex', sub { ResolveLex::run($ast) } ],
        [ 'to_anf', sub { $ast->to_anf } ],
        [ 'writecs', sub {

            open ::NIECZA_OUT, ">", $csfile;
            binmode ::NIECZA_OUT, ":utf8";
            print ::NIECZA_OUT <<EOH;
using System;
using System.Collections.Generic;
using Niecza;

EOH
            $ast->write;
            close ::NIECZA_OUT;
            if (defined $name) {
                my $blk = { setting => $::SETTING_RESUME,
                            deps    => \%::UNITDEPSTRANS,
                            refs    => \%::UNITREFS,
                            trefs   => \%::UNITREFSTRANS,
                            syml    => $::niecza_mod_symbols };
                store $blk, File::Spec->catfile($builddir, "$basename.store");
            }
            $ast = undef;
        } ],
        [ 'gmcs', sub {
            delete $::UNITREFS{$basename};
            my @args = ("gmcs",
                ($args{main} ? () : ("/target:library")),
                "/lib:$builddir",
                "/r:Kernel.dll", (map { "/r:$_.dll" } sort keys %::UNITREFS),
                "/out:$outfile",
                $csfile);
            print STDERR "@args\n" if $args{stagetime};
            system @args;
        } ],
        [ 'aot', sub {
            system "mono", "--aot", $outfile;
        } ]);

    for my $p (@phases) {
        next if $p->[0] eq 'aot' && !$args{aot};
        my $t1 = time if $args{stagetime};
        $p->[1]->();
        my $t2 = time if $args{stagetime};
        printf "%-20s: %gs\n", "$basename " . $p->[0],
            $t2 - $t1 if $args{stagetime};
        if ($args{stopafter} && $args{stopafter} eq $p->[0]) {
            if ($ast) {
                print STDERR YAML::XS::Dump($ast);
            }
            return;
        }
    }
}

1;
