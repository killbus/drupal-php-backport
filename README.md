# Drupal PHP 7.4 Security Backport

This repository builds a narrowly scoped mitigation image for
`CVE-2026-109618` and `CVE-2026-109619` on top of
`wodby/drupal-php:7.4`.

PHP 7.4 is end-of-life. This image does not restore upstream support and is
not a substitute for migrating to a supported PHP release.

## Pinned inputs

- Base image index:
  `wodby/drupal-php@sha256:a97a10f209006fdd5ead19b4ccb47ae6a53044ba48942c1597b505eb84d5c55a`
- PHP 7.4 baseline:
  `004cb827501d1ddaf98daacb185a53e0816f78a7`
- Official mitigation:
  `712e60f9edfd03f0960fc4fc3c2c375f42b90aa2`
- Patch SHA-256:
  `de1b914a84b25196b82ede7d8c0031d43be72f232b259b984e7ef72507b10631`

The image rebuilds PHP CLI and PHP-FPM from the pinned PHP baseline with the
official mitigation patch. It preserves the Wodby image's entrypoint, command,
runtime user, configuration, and existing extension set.

The PHP 7.4 mitigation intentionally disables session upload progress. That
behavior comes from the official EOL backport and is not altered here.

## Published image

Release tag `v7.4.34-cve-2026-109618-109619.1` maps to the same GHCR image
tag after the release workflow completes:

```sh
docker pull ghcr.io/killbus/drupal-php-backport:v7.4.34-cve-2026-109618-109619.1
```

The release tag is human-readable and may only identify a successfully
completed release. For deployment pinning, use the immutable digest recorded
in that GitHub Release's `release-evidence.txt`:

```sh
docker pull ghcr.io/killbus/drupal-php-backport@sha256:<64-hex-digest>
```

The separator is significant: `:tag` selects a mutable registry tag, while
`@sha256:digest` selects immutable content. A value such as
`:sha256-<digest>` is only an ordinary tag and is not a digest reference.

Each release also publishes `sha-<full-git-commit>` as a traceability tag. It
is not a replacement for the release tag or immutable digest.

## Trust boundaries

The verification workflow checks:

1. The patch hash.
2. The mitigation commit's exact parent.
3. Exact binary-diff equivalence with the official 17-file commit.
4. Builds on both architectures exposed by the pinned base-image index.
5. PHP version, PHP-FPM configuration, extension parity, runtime user,
   entrypoint, command, and container startup.

Pull requests and ordinary branch pushes never publish an image. Release
publishing is limited to version tags or an explicit workflow dispatch. The
release workflow reruns verification, publishes to GHCR, emits SBOM and
provenance attestations, signs the immutable digest with keyless Cosign, and
attaches release evidence. Native `linux/amd64` and `linux/arm64` images are
built independently and merged only after both pass. The workflow then rejects
the final manifest unless it contains both expected platforms.

## Local verification

Local execution requires Docker:

```sh
sh scripts/verify-provenance.sh
docker build -t drupal-php-backport:test .
sh scripts/test-image.sh
```
