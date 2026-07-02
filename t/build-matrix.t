use strict;
use warnings;
use FindBin qw($Bin);
use Test::More;

do "$Bin/../scripts/build-matrix.pl" or die $@ || $!;

chdir "$Bin/.." or die "chdir: $!";

is_deeply([parse_tag('7.9-013-aws14')], ['7.9', '013', '14'], 'tag with errata parses');
is_deeply([parse_tag('8.0-aws1')],      ['8.0', '000', '1'],  'omitted errata defaults to 000');
is_deeply([parse_tag('v7.9-013-aws14')], [], 'v prefix is rejected');
is_deeply([parse_tag('7.9-13-aws1')],    [], 'two-digit errata is rejected');
is_deeply([parse_tag('7.9-aws')],        [], 'missing revision is rejected');
is_deeply([parse_tag('79-aws1')],        [], 'dotless version is rejected');

my @entries = tag_entries('7.9-013-aws14');
is(scalar @entries, 2, 'one entry per arch');
is_deeply(
    $entries[0],
    {build => '79', arch => 'amd64', release => '7.9-013-aws14-amd64', errata => '013'},
    'amd64 entry carries tag errata'
);
is_deeply(
    $entries[1],
    {build => '79', arch => 'arm64', release => '7.9-013-aws14-arm64', errata => '013'},
    'arm64 entry carries tag errata'
);

eval { tag_entries('9.9-aws1') };
like($@, qr/no manifest/, 'tag without a manifest dies');

my @builds = builds();
like($_, qr/^[0-9]+$/, "build $_ is a version prefix") for @builds;
my @smoke  = smoke_entries();
is(scalar @smoke, 2 * @builds, 'one smoke entry per build and arch');
like($_->{release}, qr/-dev$/, "smoke release $_->{release} is -dev") for @smoke;
is($_->{errata}, '000', "smoke release $_->{release} builds errata 000") for @smoke;

my $json = qx(perl scripts/build-matrix.pl 7.9-aws14);
is($? >> 8, 0, 'script exits 0');
like($json, qr/^\{"include":\[\{"arch":"amd64"/, 'prints include JSON');

done_testing();
