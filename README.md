# Prusa Connect: unofficial container images

> **Unofficial.** These images are built from the public sources of
> [prusa3d/prusa-connect](https://github.com/prusa3d/prusa-connect) by
> **Prusa Research a.s.** This repository is not affiliated with or endorsed by Prusa Research.
> Report problems with the software upstream, problems with the image here.

Multi-arch images (`linux/amd64`, `linux/arm64`) built with GitHub Actions:

| Registry | Image |
|---|---|
| GitHub Container Registry | `ghcr.io/rockordier/prusa-connect-unofficial` |
| Docker Hub | `docker.io/rockordier/prusa-connect-unofficial` |

## Tags

| Upstream | Image tags |
|---|---|
| release tag `v0.2.0` | `0.2.0`, and `latest` for the highest stable release (no pre-release part) |
| branch `main` | `main`, `main-<commit>` |
| any other branch `feat/foo` | `feat-foo`, `feat-foo-<commit>` |

There is no `latest` until upstream publishes a stable release. Use a version tag, or `main` for the newest
development state.

## How the images are built

`.github/workflows/build.yml` runs every day, on a push to `main` of this repository and on demand
(Actions → build → Run workflow, optionally for one ref and with *force*).

1. **plan** lists the branches and `v*` tags of upstream and compares each with the image already pushed
   (labels `org.opencontainers.image.revision` and `prusa-connect-unofficial.recipe`). A branch is rebuilt when
   its commit or the build recipe changed, a release tag is built once. Nothing changed, nothing is built.
2. **build** checks out upstream at the planned commit, applies `scripts/patch-dockerfile.sh` and builds
   upstream's `docker/server/Dockerfile`, one job per platform on a native runner (`ubuntu-24.04`,
   `ubuntu-24.04-arm`). Each job pushes its image by digest.
3. **publish** joins the digests into one manifest list and tags it in GHCR and on Docker Hub.

The only change to the upstream Dockerfile (`scripts/patch-dockerfile.sh`) copies the licence to
`/usr/share/licenses/prusa-connect/LICENSE`.

There is no `linux/arm/v7` image. The server itself builds for 32-bit ARM, but every bundled extension is built
for 64-bit platforms only (see their `module.yaml`), and `parts` does not compile on 32-bit.

Build arguments: `BUILD_VERSION` as upstream's `scripts/build-version.sh` prints it, and
`EXTRA_BUILD_TAGS=observability postgres`, so the image carries the PostgreSQL driver and the metrics
listener like the upstream release binaries.

Pull requests build `main` for amd64 only and push nothing.

## Setup of this repository

| Kind | Name | Value |
|---|---|---|
| Variable | `DOCKERHUB_USERNAME` | Docker Hub user that pushes. Without it, only GHCR is published |
| Variable | `DOCKERHUB_NAMESPACE` | optional, Docker Hub organisation; default is `DOCKERHUB_USERNAME` |
| Secret | `DOCKERHUB_TOKEN` | Docker Hub access token with *Read & Write* |
| Variable | `BRANCH_INCLUDE` / `BRANCH_EXCLUDE` | optional, extended regex of upstream branches; default all except `cla-signatures` |
| Variable | `UPGRADE_PUBLIC_KEYS` | optional, Ed25519 keys stamped into the binary for in-app upgrades; empty by default |

The GHCR package is created by the first run. Set its visibility to *public* once under
Packages → prusa-connect-unofficial → Package settings.

## Running it

See upstream's `docker/server/server.yml` and the
[container documentation](https://github.com/prusa3d/prusa-connect/blob/main/docs/src/content/docs/container.md).
In short:

```bash
docker run -d --name prusa_connect -p 8080:8080 \
    -v prusa_connect_config:/config/config.d \
    -v prusa_connect_storage:/storage \
    ghcr.io/rockordier/prusa-connect-unofficial:main
docker logs prusa_connect   # shows the setup code for the first run
```

## Licence

Prusa Connect is created by Prusa Research a.s. (https://www.prusa3d.com) and licensed under
**OCL v1.1 + Micro v1 + NoSaaS v1 + SWAtt v1** (Open Community License v1.1 with the add-on conditions Micro
Business v1, Software Specific Use v1 and Software Attribution v1). The full text is in upstream's
[LICENSE](https://github.com/prusa3d/prusa-connect/blob/main/LICENSE) and inside every image at
`/usr/share/licenses/prusa-connect/LICENSE`. Among other things it restricts commercial use and running the
software as a service for third parties. Read it before you use these images.
