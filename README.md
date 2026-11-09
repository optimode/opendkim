# docker-opendkim

Alpine-based [OpenDKIM](http://www.opendkim.org/) Docker image — a DKIM
signing and verifying milter for MTAs such as
[Postfix](https://www.postfix.org/).

The container is managed by runit (PID 1: `runsvdir`) and supervises two
services: OpenDKIM (as `opendkim -f`) and rsyslog. Configuration and DKIM
keys are mounted at `/etc/opendkim`, logs go to `/data/log` where rsyslog
writes and rotates them, and the milter endpoint listens on port `8891`.

## Versions

This project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html) for
its git tags (e.g. `v1.0.0`); every release is tagged in git. The table shows
exactly which Alpine and OpenDKIM versions each Docker image has and when it was
built.

| Git tag | Alpine | OpenDKIM | Build date | Docker image |
|---|---|---|---|---|
| `v1.0.0` | 3.24.2 | 2.11.0 | 2026-11-06 | `ghcr.io/optimode/opendkim:2.11.0-alpine` |
| `v1.1.0` | 3.24.2 | 2.11.0 | 2026-11-09 | `ghcr.io/optimode/opendkim:2.11.0-alpine` |

Notes:

- The Docker image tag reflects the OpenDKIM version, not the git tag:
  every release rebuilds the same `2.11.0-alpine` tag (v1.0.0 with the
  supervisor-managed layout, v1.1.0 with runit, see
  [CHANGELOG.md](CHANGELOG.md)).
- Besides the exact version tag (e.g. `2.11.0-alpine`) each build produces two
  moving tags: `2.11-alpine` (latest patch level of OpenDKIM 2.11) and
  `latest-alpine`. For reproducible deployments use the exact version tag.

## Usage

```sh
docker run -d --name opendkim \
  -e TZ=Europe/Budapest \
  -p 8891:8891 \
  -v ./etc:/etc/opendkim \
  -v ./log:/data/log \
  ghcr.io/optimode/opendkim:2.11.0-alpine
```

See [docker-compose.yml](docker-compose.yml) for a commented compose sample.

### Configuration notes

- **Configuration** is expected at `/etc/opendkim` — mount your configuration
  directory there. Alpine's OpenDKIM reads `/etc/opendkim/opendkim.conf`; the
  usual files (`KeyTable`, `SigningTable`, `TrustedHosts`) and the DKIM keys
  live in the same directory. The mount replaces the `example.com` sample
  configuration that ships with the Alpine package.
- **Milter socket**: the image exposes port `8891`. For the MTA to reach the
  milter from another container or from the host, set
  `Socket inet:8891@0.0.0.0` in `opendkim.conf` — the Alpine sample binds to
  `127.0.0.1` only.
- **Permissions**: OpenDKIM refuses to start otherwise —
  - the configuration directory must be owned by root and not writeable by
    others: `chown -R root:root ./etc`
  - the private keys must not be readable by group or others:
    `chmod 600 ./etc/*.private`

  The key utilities (`opendkim-genkey`, `opendkim-testkey`, …) from
  `opendkim-utils` are included in the image.
- **Logging**: `rsyslog` writes OpenDKIM's syslog output (mail facility) to
  `/data/log/mail.log` and rotates every log stream at 50 MiB, keeping 7
  gzip-compressed archives. Each runit service additionally keeps its own
  stderr in `/data/log/<service>/` (`opendkim`, `rsyslog`) via svlogd with
  built-in size-based rotation. Mount `./log:/data/log` to keep the logs on
  the host.
- **Timezone**: the `tzdata` package is included, so both the `TZ`
  environment variable (e.g. `TZ=Europe/Budapest`) and a mounted
  `/etc/localtime` are honoured; log timestamps are written in local time.
- **Working directory**: OpenDKIM's `BaseDirectory` (`/run/opendkim`) is
  created at container start.
- **Postfix integration**: point Postfix at the milter, e.g.
  `smtpd_milters = inet:opendkim:8891` together with
  `milter_default_action = accept`.

### Services

runit supervises one directory per service under `rootfs/etc/service/`:
`opendkim` (the milter) and `rsyslog` (logging). There are no startup
switches — opendkim is the point of this image and always starts.

The entrypoint reports a missing or invalid `/etc/opendkim/opendkim.conf`
at startup (visible in `docker logs`); the service itself checks the
config with `opendkim -n` and fails visibly in its own service log
(`/data/log/opendkim`) instead of crash-looping silently. Services can be
controlled at runtime with `sv`:

```sh
docker exec opendkim sv status /etc/service/*
docker exec opendkim sv restart /etc/service/opendkim
docker exec opendkim sv down /etc/service/rsyslog
```

Container shutdown is graceful: `docker stop` stops `runsvdir` first and
then the services one by one via `sv exit` — rsyslog last, so the shutdown
messages of the other services still reach the log files.

## Building

```sh
make build                      # build with the default versions
make build push                 # build and push all tags
make build OPENDKIM_VERSION=2.11.1 ALPINE_VERSION=3.24.3
make help                       # list targets and variables
```

The build is reproducible by design:

- `ALPINE_VERSION` selects the exact Alpine base image (default: `3.24.2`).
- `OPENDKIM_VERSION` (default: `2.11.0`) is pinned in the Dockerfile for both
  OpenDKIM packages (`opendkim`, `opendkim-utils`). The `~=` pin accepts
  Alpine package rebuilds of the same upstream version (`2.11.0-rX`) but
  rejects any other version.
- A build-time check fails the build loudly if the planned OpenDKIM version was
  not installed.

### Image metadata

The image carries [OCI](https://github.com/opencontainers/image-spec/blob/master/annotations.md)
labels with the build metadata:

| Label | Content |
|---|---|
| `org.opencontainers.image.version` | OpenDKIM version (e.g. `2.11.0`) |
| `org.opencontainers.image.created` | build date (RFC 3339) |
| `org.opencontainers.image.revision` | git revision the image was built from |
| `org.opencontainers.image.base.name` | base image (e.g. `alpine:3.24.2`) |
| `org.opencontainers.image.url`, `.source` | project and source repository |
| `org.opencontainers.image.authors`, `.vendor`, `.licenses` | authors, vendor, license |

Inspect them with:

```sh
docker inspect ghcr.io/optimode/opendkim:2.11.0-alpine \
  --format '{{json .Config.Labels}}' | python3 -m json.tool
```

## License

MIT — see [LICENSE](LICENSE).