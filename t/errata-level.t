use strict;
use warnings;
use File::Temp qw(tempdir);
use FindBin qw($Bin);
use Test::More;

do "$Bin/../scripts/errata-level.pl" or die $@ || $!;

# Args:
#   File path.
#   Executable script body.
# Returns:
#   Nothing meaningful.
sub write_executable {
    my ($path, $body) = @_;
    open my $fh, '>', $path or die "write $path: $!";
    print {$fh} $body;
    close $fh or die "close $path: $!";
    chmod 0755, $path or die "chmod $path: $!";
}

ok(kernel_patch("Index: sys/dev/ic/nvme.c\n"), 'Index sys path is kernel erratum');
ok(kernel_patch("--- sys/arch/amd64/pci/acpipci.c\n"), 'diff sys path is kernel erratum');
ok(!kernel_patch("Index: usr.bin/ssh/ssh.c\n"), 'userland path is skipped');

is(
    errata_level('001_a.patch.sig', '007_b.patch.sig', '003_c.patch.sig'),
    '007',
    'highest errata number wins'
);
is(errata_level(), '000', 'empty kernel errata list is 000');

is_deeply(
    [patch_signatures(
        '<a href="002_b.patch.sig">002_b.patch.sig</a><a href="001_a.patch.sig">001_a.patch.sig</a><a href="002_b.patch.sig">002_b.patch.sig</a>'
    )],
    [qw(001_a.patch.sig 002_b.patch.sig)],
    'patch signatures are sorted and de-duplicated'
);

{
    my $dir = tempdir(CLEANUP => 1);
    my $bin = "$dir/bin";
    mkdir $bin or die "mkdir $bin: $!";

    write_executable("$bin/curl", <<'EOF');
#!/usr/bin/env perl
use strict;
use warnings;

if (@ARGV == 2 && $ARGV[0] eq '-fsSL') {
    print '<a href="001_kernel.patch.sig">001_kernel.patch.sig</a><a href="002_userland.patch.sig">002_userland.patch.sig</a>';
    exit 0;
}

if (@ARGV == 4 && $ARGV[0] eq '-fsSL' && $ARGV[1] eq '-o') {
    open my $fh, '>', $ARGV[2] or die "write $ARGV[2]: $!";
    print {$fh} "signature\n";
    close $fh or die "close $ARGV[2]: $!";
    exit 0;
}

die "unexpected curl args: @ARGV\n";
EOF

    write_executable("$bin/signify-openbsd", <<'EOF');
#!/usr/bin/env perl
use strict;
use warnings;

my ($sig_path, $patch_path);
for (my $i = 0; $i < @ARGV; $i++) {
    $sig_path = $ARGV[$i + 1] if $ARGV[$i] eq '-x';
    $patch_path = $ARGV[$i + 1] if $ARGV[$i] eq '-m';
}
die "-x is required\n" unless defined $sig_path;
die "-m is required\n" unless defined $patch_path;

open my $fh, '>', $patch_path or die "write $patch_path: $!";
if ($sig_path =~ /kernel/) {
    print {$fh} "Index: sys/dev/ic/nvme.c\n";
} else {
    print {$fh} "Index: usr.bin/ssh/ssh.c\n";
}
close $fh or die "close $patch_path: $!";
print "Signature Verified\n";
exit 0;
EOF

    local $ENV{PATH} = "$bin:$ENV{PATH}";
    my $stdout_path = "$dir/stdout";
    my ($level, $err);
    {
        open my $oldout, '>&', \*STDOUT or die "dup STDOUT: $!";
        open STDOUT, '>', $stdout_path or die "capture STDOUT: $!";
        $level = eval { discover_errata('https://example.invalid/patches/7.9/common', 'key.pub') };
        $err = $@;
        open STDOUT, '>&', $oldout or die "restore STDOUT: $!";
    }
    die $err if $err;

    is($level, '001', 'only kernel patches count toward errata level');
    open my $captured_fh, '<', $stdout_path or die "read $stdout_path: $!";
    my $captured = do { local $/; <$captured_fh> };
    is($captured, '', 'discover_errata keeps verifier stdout away from caller stdout');
}

done_testing;
