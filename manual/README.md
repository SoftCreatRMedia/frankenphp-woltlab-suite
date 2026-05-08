# Manual WoltLab Suite Setup with FrankenPHP and Caddy

This guide mirrors the Docker image defaults for administrators who want to install WoltLab Suite Core directly on a server.

It assumes Debian 13, or Ubuntu 24.04 (other distros or versions might work as well), FrankenPHP with Caddy, MariaDB, PHP 8.4 for WSC 6.2, and a public DNS name. IP-address certificates work when your CA supports them, but a normal DNS name is simpler and better supported.

The `manual/` directory is documentation only. It is excluded from the Docker build context and is not included in the Docker image.

## Target Layout

Recommended paths:

```text
/var/www/woltlab/public        WoltLab document root
/etc/caddy/Caddyfile           Caddy configuration
/etc/php/woltlab.ini           PHP runtime overrides
/var/backups/woltlab           local backup staging directory
```

Use a dedicated system user for file ownership:

```sh
adduser --system --group --home /var/www/woltlab woltlab
install -d -o woltlab -g woltlab /var/www/woltlab/public
install -d -m 0750 /var/backups/woltlab
```

## Packages

Install MariaDB, Certbot, and build/runtime dependencies:

```sh
apt-get update
apt-get install -y --no-install-recommends \
  ca-certificates \
  curl \
  git \
  mariadb-server \
  tar \
  unzip \
  zip
```

Install FrankenPHP using the current upstream installation method for your host. For production, use a systemd-managed binary or package, not a shell session. Confirm that the binary has the needed PHP extensions:

```sh
frankenphp php-cli -m | sort
```

Required or strongly recommended extensions for WoltLab Suite:

```text
exif
gd
gmp
imagick
intl
mysqli
PDO
pdo_mysql
Zend OPcache
zip
```

## PHP Runtime

Create `/etc/php/woltlab.ini`:

```ini
expose_php = Off
memory_limit = 512M
upload_max_filesize = 64M
post_max_size = 64M
max_execution_time = 120
max_input_vars = 10000

opcache.enable = 1
opcache.enable_cli = 0
opcache.memory_consumption = 256
opcache.interned_strings_buffer = 32
opcache.max_accelerated_files = 20000
opcache.validate_timestamps = 0
opcache.revalidate_freq = 0
opcache.jit = 0

session.cookie_httponly = 1
session.cookie_samesite = Lax
session.use_strict_mode = 1

realpath_cache_size = 4096K
realpath_cache_ttl = 600
```

Load this file through your FrankenPHP service environment. With the official FrankenPHP container this is handled by PHP scan dirs; on a host install, use the mechanism provided by your FrankenPHP package or service wrapper.

When `opcache.validate_timestamps=0`, restart FrankenPHP after WoltLab package updates that change PHP files.

## Database

Generate a random database name, user, and password:

```sh
db_name="wsc_$(openssl rand -hex 8)"
db_user="wscu_$(openssl rand -hex 8)"
db_pass="$(openssl rand -base64 36 | tr -d '\n')"

printf 'Database: %s\nUser: %s\nPassword: %s\n' "$db_name" "$db_user" "$db_pass"
```

Create the database and user:

```sh
mariadb <<SQL
CREATE DATABASE \`${db_name}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER '${db_user}'@'localhost' IDENTIFIED BY '${db_pass}';
GRANT ALL PRIVILEGES ON \`${db_name}\`.* TO '${db_user}'@'localhost';
FLUSH PRIVILEGES;
SQL
```

Recommended MariaDB settings for `/etc/mysql/mariadb.conf.d/99-woltlab.cnf`:

```ini
[mysqld]
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci
innodb_buffer_pool_size = 1G
innodb_file_per_table = 1
innodb_flush_log_at_trx_commit = 1
max_connections = 300
skip_name_resolve = 1
table_open_cache = 4000
thread_cache_size = 64
```

Restart MariaDB:

```sh
systemctl restart mariadb
```

Tune `innodb_buffer_pool_size` to available memory and workload. WoltLab's system check requires at least 128 MiB; this template uses 1 GiB as a stronger default.

## WoltLab Installer

For WSC 6.2, download the official installer:

```sh
curl -fL -o /tmp/woltlab-suite.zip https://assets.woltlab.com/release/woltlab-suite-6.2.3.zip
unzip /tmp/woltlab-suite.zip -d /var/www/woltlab/public
chown -R woltlab:woltlab /var/www/woltlab/public
```

If you need other WSC releases that WoltLab no longer publishes as zip files, build the installer from the WCF source tag in the same shape as this repository's `docker/build-wsc-installer.sh` script.

Open:

```text
https://example.com/install.php
```

Use these database values:

```text
Host: localhost
Database: generated db_name
User: generated db_user
Password: generated db_pass
```

Do not append `dev=1` for production installs. Remove `install.php` after installation if WoltLab did not remove it automatically.

## Caddy Configuration

Use this Caddyfile as a host-install equivalent of the Docker image:

```caddyfile
{
	frankenphp
	order php_server before file_server
}

example.com {
	root * /var/www/woltlab/public
	encode zstd br gzip

	header {
		-Server
		X-Content-Type-Options "nosniff"
		X-Frame-Options "SAMEORIGIN"
		Referrer-Policy "strict-origin-when-cross-origin"
	}

	@hiddenFiles {
		path /.*
		not path /.well-known/*
	}
	respond @hiddenFiles 404

	@sensitiveFiles {
		path *.7z *.bak *.br *.bz2 *.conf *.crt *.csv *.dist *.env *.gz *.inc *.ini *.key *.log *.orig *.pem *.phar *.rar *.save *.sh *.sql *.sqlite *.swp *.tar *.tar.bz2 *.tar.gz *.tar.xz *.tgz *.tpl *.twig *.xz *.yml *.yaml *.zip *.zst
		path /composer.json /composer.lock /package.xml /README* /Read* /Lies*
		path /config.inc.php /options.inc.php
		path /files.tar /acptemplates.tar /WCFSetup.tar.gz
		path /vendor/*
	}
	respond @sensitiveFiles 404

	@nonPublicPhp {
		path /lib/*.php /lib/*/*.php /templates/*.php /templates/*/*.php
	}
	respond @nonPublicPhp 404

	@staticAssets {
		path *.avif *.css *.eot *.gif *.ico *.jpg *.jpeg *.js *.json *.map *.otf *.pdf *.png *.svg *.ttf *.webmanifest *.webp *.woff *.woff2
	}
	header @staticAssets Cache-Control "public, max-age=31536000, immutable"

	@woltlabAppRewrite {
		not file {path} {path}/
		path_regexp woltlabApp ^/([^/]+)/(.*)$
		file /{re.woltlabApp.1}/index.php
	}
	rewrite @woltlabAppRewrite /{re.woltlabApp.1}/index.php?{re.woltlabApp.2}

	@woltlabRootRewrite {
		not file {path} {path}/
		path_regexp woltlabRoot ^/(.*)$
	}
	rewrite @woltlabRootRewrite /index.php?{re.woltlabRoot.1}

	php_server
}
```

Replace `example.com` with the final domain. Caddy will request and renew certificates automatically for normal DNS names. Keep TCP 80, TCP 443, and UDP 443 reachable for HTTP/3.

Validate and restart:

```sh
caddy validate --config /etc/caddy/Caddyfile
systemctl restart caddy
```

## Systemd Service Notes

Run FrankenPHP/Caddy as an unprivileged service where possible. If binding directly to ports 80 and 443, grant only the low-port bind capability to the binary:

```sh
setcap cap_net_bind_service=+ep /usr/local/bin/frankenphp
```

Use a dedicated service user, a restricted working directory, and normal systemd hardening such as:

```ini
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ReadWritePaths=/var/www/woltlab /var/lib/caddy /var/log/caddy
```

Adjust paths to match the package you install.

## Post-Install Checks

In the ACP:

```text
ACP -> Configuration -> Options -> General -> Enable URL rewrite
ACP -> System -> System Check
```

Verify from the shell:

```sh
curl -I https://example.com/
curl -I https://example.com/acp/system-check/
```

The second request should redirect to ACP login when not authenticated. It should not be a webserver-level 404.

Check that sensitive files are denied:

```sh
curl -I https://example.com/options.inc.php
curl -I https://example.com/vendor/autoload.php
```

Both should return 404.

## Backups

Back up both the database and the document root:

```sh
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
backup_dir="/var/backups/woltlab/${timestamp}"
install -d -m 0750 "$backup_dir"

mariadb-dump \
  --single-transaction \
  --quick \
  --routines \
  --events \
  "$db_name" \
  | gzip -9 > "${backup_dir}/database.sql.gz"

tar -czf "${backup_dir}/public.tar.gz" -C /var/www/woltlab/public .
```

Move backups off the server and test restores periodically.
