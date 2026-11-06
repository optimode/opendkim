# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
The Alpine and OpenDKIM versions of every published Docker image are listed in
the version table in [README.md](README.md).

## [Unreleased]

## [1.0.0] - 2026-11-06

First versioned release. The image is published as
`ghcr.io/optimode/opendkim:2.11.0-alpine`, together with the moving
`2.11-alpine` and `latest-alpine` tags.

### Added

- OpenDKIM `2.11.0` with the `opendkim-utils` key and zone utilities, installed
  from Alpine packages on `alpine:3.24.2`.
- Foreground process layout managed by `supervisor`: `opendkim` runs in the
  foreground (`opendkim -f`) next to `rsyslog`, as recommended for containers.
- `rsyslog` logging: OpenDKIM's syslog output (mail facility) is written to
  `/data/log/mail.log`; mounting `./log:/data/log` keeps the logs on the host.
- `docker-compose.yml` sample for running the image with a mounted OpenDKIM
  configuration and keys, log directory and the milter port `8891`.
- Build-time verification of the planned OpenDKIM version: the image build
  fails loudly if a different OpenDKIM version would be installed. Both
  `opendkim` and `opendkim-utils` are version-pinned (`~=` accepts Alpine
  package rebuilds of the same upstream version) so that a rebuild installs
  the planned OpenDKIM version or fails.
- OCI image labels carrying the build metadata (version, build date, git
  revision, base image, source repository).
- README version table mapping each release to its exact Alpine and OpenDKIM
  versions, build date and Docker image name.

[Unreleased]: https://github.com/optimode/opendkim/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/optimode/opendkim/releases/tag/v1.0.0