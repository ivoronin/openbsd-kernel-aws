#!/usr/bin/env perl
# Print the CI build matrix as JSON.
#
# With a tag argument: builds for the tag's OpenBSD version, both
# architectures, errata level pinned from the tag.
# Without arguments: all manifests, both architectures, -dev release
# names and errata 000 (smoke builds).
use strict;
use warnings;
use JSON::PP;

sub main {
    die "usage: build-matrix.pl [tag]\n" if @ARGV > 1;
    my @entries = @ARGV ? tag_entries($ARGV[0]) : smoke_entries();
    print JSON::PP->new->canonical->encode({include => \@entries}), "\n";
}

sub tag_entries {
    my ($tag) = @_;
    my ($version, $errata) = parse_tag($tag)
        or die "build-matrix: unparseable tag: $tag\n";
    (my $build = $version) =~ s/\.//;
    -f "builds/$build.mk"
        or die "build-matrix: no manifest builds/$build.mk for tag $tag\n";
    return map { entry($build, $_, "$tag-$_", $errata) } archs();
}

sub smoke_entries {
    return map {
        my $build = $_;
        map { entry($build, $_, "$build-$_-dev", '000') } archs();
    } builds();
}

sub parse_tag {
    my ($tag) = @_;
    return unless $tag =~ /^([0-9]+\.[0-9]+)(?:-([0-9]{3}))?-aws([0-9]+)$/;
    return ($1, $2 // '000', $3);
}

sub archs { return qw(amd64 arm64) }

sub builds { return sort map { m{^builds/(.+)\.mk$} ? $1 : () } glob 'builds/*.mk' }

sub entry {
    my ($build, $arch, $release, $errata) = @_;
    return {build => $build, arch => $arch, release => $release, errata => $errata};
}

main() unless caller;
1;
