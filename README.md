# openbsd-kernel-aws

OpenBSD kernel bundle for AWS Nitro. Kernels are built from a trimmed `AWS`
config (see `config/`): GENERIC with drivers and options that make no sense
on Nitro instances disabled.

It adds the Amazon ENA network driver and the OpenBSD kernel changes needed on Nitro:
- Amazon PCI product IDs
- MSI on Amazon host bridges
- NVMe queue sizing capped to controller limits
- com(4) attachment for the EC2 PCI serial device, so the EC2 serial console works

The image assembly layer lives in [ivoronin/openbsd-cloudimg](https://github.com/ivoronin/openbsd-cloudimg).

Versioning: releases are cut by pushing a git tag.

```text
{openbsd-version}[-{errata}]-aws{revision}
```

`7.9-013-aws14` is OpenBSD 7.9 with kernel errata up to 013 and revision 14
of the AWS patchset; the errata field is omitted while the level is 000
(e.g. `8.0-aws1`).

Bump `aws{revision}` when the patchset changes; when new kernel errata come out,
put the new level in the errata field of the next tag - CI passes it to the build,
which fails if there is no kernel erratum at exactly that level.
The revision counter should restart on every new OpenBSD version.

The running kernel carries this identity as its build counter: `sysctl kern.version`
shows `OpenBSD 7.9 (AWS.MP) #14013`, where the counter is `revision * 1000 + errata`
(so `#14013` is revision 14, errata 013). It increments on every release - an errata
respin and a patchset bump both move it - which makes it the one place a booted instance
advertises its kernel errata level, since custom kernels carry no syspatch.

Each tag publishes one immutable GitHub release with `{tag}-{arch}.tgz` bundles for both
architectures. Local builds default to `ERRATA=000`; override with `make build ERRATA=013`.

```sh
make errata BUILD=79              # print current upstream kernel errata level
make build BUILD=79 ARCH=amd64    # local build -> output/bundles/79-amd64-dev.tgz
make build BUILD=79 ARCH=arm64 SP=n   # skip single-processor kernel build
```

Consume this through `openbsd-cloudimg`; this repo only owns the kernel bundle.
