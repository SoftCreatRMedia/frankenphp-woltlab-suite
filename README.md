# WoltLab Suite on FrankenPHP

Production-ready Docker image for WoltLab Suite Core on FrankenPHP and Caddy.

This image is intentionally small in scope:

- FrankenPHP + Caddy in one application container
- MariaDB as a separate service
- SSL, HTTP/1.1, HTTP/2, and HTTP/3 through Caddy
- WoltLab-compatible generic URL rewrites

## Supported Images

| WoltLab Suite | PHP | Default WSC Patch | Tag          |
|---------------|-----|-------------------|--------------|
| 6.2           | 8.4 | 6.2.3             | `6.2-php8.4` |
| 6.1           | 8.3 | 6.1.19            | `6.1-php8.3` |
| 6.0           | 8.3 | 6.0.25            | `6.0-php8.3` |

The WoltLab patch version is a build argument and runtime download variable, so newer patch releases do not require a Dockerfile change.

## Manual Setup

This repository is primarily a Docker package. For administrators who want to set up the same stack directly on a host, see [manual/README.md](manual/README.md).

The `manual/` directory is intentionally excluded from the Docker build context and is not copied into release images.

## Quick Start

Build locally:

```sh
cp .env.example .env
docker compose up -d --build
```

Open:

```text
https://localhost/install.php
```

Database values for the installer:

```text
Host: db
Database: generated in the wsc-secrets Docker volume
User: generated in the wsc-secrets Docker volume
Password: generated in the wsc-secrets Docker volume
```

The compose file exposes these values to the WoltLab installer through `WCFSETUP_DBHOST`, `WCFSETUP_DBNAME_FILE`, `WCFSETUP_DBUSER_FILE`, and `WCFSETUP_DBPASSWORD_FILE`, matching the setup variables used by `wsc-dockerized` while avoiding a plaintext default password in the compose file.

If `MYSQL_DATABASE`, `MYSQL_USER`, or `MYSQL_PASSWORD` are empty or missing, `credential-init` generates random values once and stores them in the `wsc-secrets` Docker volume. To provide fixed values, set them before the first `docker compose up`. Existing MariaDB volumes keep their initial credentials.

## Using Prebuilt GHCR Images

Prebuilt multi-architecture images are published to:

```text
ghcr.io/softcreatrmedia/frankenphp-woltlab-suite
```

Available tags:

| WoltLab Suite | PHP | Tags                          |
|---------------|-----|-------------------------------|
| 6.2           | 8.4 | `6.2-php8.4`, `6.2.3-php8.4`  |
| 6.1           | 8.3 | `6.1-php8.3`, `6.1.19-php8.3` |
| 6.0           | 8.3 | `6.0-php8.3`, `6.0.25-php8.3` |

Use `compose.prebuilt.yaml` to disable local builds and pull from GHCR:

```sh
cp .env.example .env
docker compose -f compose.yaml -f compose.prebuilt.yaml pull
docker compose -f compose.yaml -f compose.prebuilt.yaml up -d
```

Select a different prebuilt variant by changing `WSC_TAG` in `.env`:

```env
WSC_TAG=6.1-php8.3
```

Override `WSC_PREBUILT_IMAGE` only when using a fork or private registry:

```env
WSC_PREBUILT_IMAGE=ghcr.io/your-org/frankenphp-woltlab-suite
```

## Building

Build the default WSC 6.2 / PHP 8.4 image:

```sh
docker build \
  --build-arg PHP_VERSION=8.4 \
  --build-arg WSC_REF=6.2.3 \
  -t frankenphp-woltlab-suite:6.2-php8.4 .
```

Build all supported variants:

```sh
docker buildx bake
```

Build one variant:

```sh
docker buildx bake wsc61_php83
```

## Runtime Configuration

Common environment variables:

| Variable                            | Default                                           | Purpose                                                                                                                                     |
|-------------------------------------|---------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------|
| `SERVER_NAME`                       | `localhost`                                       | Caddy site address. Use your domain in production.                                                                                          |
| `WSC_REF`                           | `6.2.3`                                           | WoltLab/WCF tag or branch used when building the installer.                                                                                 |
| `WCFSETUP_DBHOST`                   | `db`                                              | Database host passed to the WoltLab installer.                                                                                              |
| `WCFSETUP_DBNAME_FILE`              | `/run/wsc-secrets/db-name`                        | File containing the database name for the WoltLab installer.                                                                                |
| `WCFSETUP_DBUSER_FILE`              | `/run/wsc-secrets/db-user`                        | File containing the database user for the WoltLab installer.                                                                                |
| `WCFSETUP_DBPASSWORD_FILE`          | `/run/wsc-secrets/db-password`                    | File containing the database password for the WoltLab installer.                                                                            |
| `MYSQL_INNODB_BUFFER_POOL_SIZE`     | `1G`                                              | MariaDB InnoDB buffer pool size. Lower this only on very small servers.                                                                     |
| `PHP_MEMORY_LIMIT`                  | `512M`                                            | PHP memory limit.                                                                                                                           |
| `PHP_UPLOAD_MAX_FILESIZE`           | `64M`                                             | Maximum upload file size.                                                                                                                   |
| `PHP_POST_MAX_SIZE`                 | `64M`                                             | Maximum POST body size.                                                                                                                     |
| `PHP_DISABLE_FUNCTIONS`             | `exec,passthru,shell_exec,system,proc_open,popen` | PHP functions disabled by default to reduce command-execution risk. Set to an empty value only if a trusted plugin requires one of them.    |
| `PHP_OPCACHE_VALIDATE_TIMESTAMPS`   | `0`                                               | Disable timestamp checks for production performance. Restart `wsc` after package updates that change PHP files.                             |
| `PHP_OPCACHE_MEMORY_CONSUMPTION`    | `256`                                             | OPcache shared memory size in MB.                                                                                                           |
| `PHP_OPCACHE_MAX_ACCELERATED_FILES` | `20000`                                           | Maximum number of cached PHP files.                                                                                                         |
| `FRANKENPHP_NUM_THREADS`            | `1`                                               | FrankenPHP PHP thread count. Keep this at `1` unless you have tested installation, package updates, and style rebuilds with a higher value. |
| `FRANKENPHP_MAX_THREADS`            | `1`                                               | FrankenPHP maximum PHP thread count. Keep this aligned with `FRANKENPHP_NUM_THREADS` by default.                                            |
| `FRANKENPHP_CONFIG`                 | empty                                             | Extra FrankenPHP global config.                                                                                                             |
| `CADDY_GLOBAL_OPTIONS`              | empty                                             | Extra Caddy global options.                                                                                                                 |
| `CADDY_SERVER_EXTRA_DIRECTIVES`     | empty                                             | Extra Caddy site directives, for example a custom `tls` directive.                                                                          |
| `CERTBOT_CERT_NAME`                 | empty                                             | Certificate directory name below `/etc/letsencrypt/live` when using `compose.certbot.yaml`.                                                 |
| `MYSQL_MAX_CONNECTIONS`             | `300`                                             | MariaDB connection limit.                                                                                                                   |
| `MYSQL_TABLE_OPEN_CACHE`            | `4000`                                            | MariaDB table cache size.                                                                                                                   |
| `MYSQL_THREAD_CACHE_SIZE`           | `64`                                              | MariaDB thread cache size.                                                                                                                  |

The application volume is `/app/public`. The image builds a WoltLab installer from the selected `WoltLab/WCF` GitHub tag or branch and stores it in `/usr/src/woltlab`. If `/app/public` is empty, the entrypoint copies that prebuilt installer into the volume.

## Hardened Runtime

The default compose file runs the application container with a hardened profile:

- non-root `www-data` user
- read-only root filesystem
- `no-new-privileges`
- all Linux capabilities dropped except `NET_BIND_SERVICE`
- tmpfs-backed `/tmp` with `noexec,nosuid`
- writable mounts only for `/app/public`, `/data`, and `/config`

### SSL / Certbot Certificate

The default Caddy behavior is usually enough for public DNS names: set `SERVER_NAME` to the domain and Caddy will request and renew the certificate itself. Use Certbot only if you want the host to manage certificates, or if you need a certificate type that Caddy cannot request for you.

To request a new certificate on the host, stop anything that is using ports 80 or 443 and run Certbot in standalone mode:

```sh
apt-get update
apt-get install -y certbot

docker compose -f compose.yaml down
certbot certonly --standalone -d example.com
```

Then copy the host-managed certificate into a Docker volume at startup and tell Caddy to use it:

```env
SERVER_NAME=example.com
CERTBOT_CERT_NAME=example.com
CADDY_SERVER_EXTRA_DIRECTIVES=tls /certs/fullchain.pem /certs/privkey.pem
```

```sh
docker compose -f compose.yaml -f compose.certbot.yaml up -d --build
```

When using GHCR images, include `compose.prebuilt.yaml` and omit `--build`:

```sh
docker compose -f compose.yaml -f compose.prebuilt.yaml -f compose.certbot.yaml up -d
```

For an IP address certificate, set both `SERVER_NAME` and `CERTBOT_CERT_NAME` to the IP address. Set `CADDY_GLOBAL_OPTIONS` to `default_sni <ip-address>` as well, because many clients omit SNI when connecting directly to an IP address.

After Certbot renews a host-managed certificate, refresh the Docker copy and restart Caddy:

```sh
docker compose -f compose.yaml -f compose.certbot.yaml run --rm certbot-cert-init
docker compose -f compose.yaml -f compose.certbot.yaml restart wsc
```

## HTTP/3

Expose UDP 443 as well as TCP 443:

```yaml
ports:
  - "443:443/tcp"
  - "443:443/udp"
```

Caddy will advertise HTTP/3 automatically when TLS is active.

## URL Rewrites

The Caddyfile implements the common WoltLab rewrite pattern:

```text
/app/path -> /app/index.php?path if /app/index.php exists
/foo/bar  -> /index.php?foo/bar
```

Existing files and directories are served directly.

After installation, enable WoltLab's matching application setting in:

```text
ACP -> Configuration -> Options -> General -> Enable URL rewrite
```

You can validate the ACP system check and rewritten ACP routes with:

```sh
WSC_BASE_URL=https://example.com \
WSC_ADMIN_USER=admin \
WSC_ADMIN_PASSWORD='change-me' \
WSC_ENABLE_URL_REWRITE=1 \
npm run verify:production
```

## Security Notes

The bundled Caddyfile:

- hides the `Server` header
- disables `expose_php`
- denies dotfiles except `/.well-known/*`
- denies common archive, backup, config, SQL, key, certificate, shell, and template files
- denies direct access to `/vendor/*`
- denies direct access to selected non-public PHP paths
- sends long-lived immutable cache headers for static assets

Worker mode is not enabled. WoltLab Suite has not been audited for a persistent PHP worker lifecycle, and classic request isolation is the safer production default.

## Backups

Create a database, application volume, and generated-secrets backup:

```sh
scripts/backup.sh
```

Restore on a clean deployment:

```sh
scripts/restore.sh backups/<timestamp>
```

If you restore a deployment that uses additional compose overlays, pass the same compose files through `COMPOSE_ARGS`:

```sh
COMPOSE_ARGS="-f compose.yaml -f compose.certbot.yaml" \
scripts/restore.sh backups/<timestamp>
```

## Updating WoltLab

Use WoltLab's built-in package updater for installed communities. The image bootstraps new installations only; it does not overwrite an existing `/app/public` volume.

For new images on a newer patch release:

```sh
WSC_REF=6.2.4 docker compose up -d --build
```

`WSC_REF` accepts a tag such as `6.2.3` or a branch such as `6.2`.
