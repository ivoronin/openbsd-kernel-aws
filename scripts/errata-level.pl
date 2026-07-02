#!/usr/bin/env perl
use strict;
use warnings;
use File::Temp qw(tempdir);

sub main {
    die "usage: errata-level.pl ERRATA_URL SIGNIFY_KEY\n" unless @ARGV == 2;
    print discover_errata(@ARGV), "\n";
}

sub discover_errata {
    my ($base, $key) = @_;
    my $tmp = tempdir(CLEANUP => 1);
    my $signify = verifier_command();
    my @kernel;

    for my $sig (patch_signatures(capture('curl', '-fsSL', "$base/"))) {
        my $sig_path = "$tmp/$sig";
        (my $patch_path = $sig_path) =~ s/\.sig$//;

        system('curl', '-fsSL', '-o', $sig_path, "$base/$sig") == 0
            or die "errata-level: failed to download $base/$sig\n";
        run_quiet($signify, '-Vep', $key, '-x', $sig_path, '-m', $patch_path)
            or die "errata-level: signify verification failed for $sig\n";

        open my $patch_fh, '<', $patch_path or die "errata-level: $patch_path: $!\n";
        my $patch = do { local $/; <$patch_fh> };
        push @kernel, $sig if kernel_patch($patch);
    }

    return errata_level(@kernel);
}

sub patch_signatures {
    my ($index) = @_;
    my %seen;
    return sort grep { !$seen{$_}++ } $index =~ /([0-9]{3}_[A-Za-z0-9_]+\.patch\.sig)/g;
}

sub kernel_patch {
    my ($body) = @_;
    return $body =~ m{^(Index: |--- )sys/}m ? 1 : 0;
}

sub errata_level {
    my $level = '000';
    for my $name (@_) {
        $level = $1 if $name =~ /^([0-9]{3})_/ && $1 gt $level;
    }
    return $level;
}

sub capture {
    my (@cmd) = @_;
    open my $fh, '-|', @cmd or die "errata-level: exec @cmd: $!\n";
    local $/;
    my $out = <$fh>;
    close $fh or die "errata-level: @cmd failed\n";
    return defined $out ? $out : '';
}

sub run_quiet {
    my (@cmd) = @_;
    open my $oldout, '>&', \*STDOUT or die "errata-level: dup STDOUT: $!\n";
    open STDOUT, '>', '/dev/null' or die "errata-level: redirect STDOUT: $!\n";
    my $ok = system(@cmd) == 0;
    open STDOUT, '>&', $oldout or die "errata-level: restore STDOUT: $!\n";
    return $ok;
}

sub verifier_command {
    for my $cmd (qw(signify-openbsd signify)) {
        chomp(my $path = capture('sh', '-lc', "command -v $cmd 2>/dev/null || true"));
        return $path if length $path;
    }
    die "errata-level: could not find signify-openbsd or signify\n";
}

main() unless caller;
1;
