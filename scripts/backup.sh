#!/bin/sh
set -eu

project="${COMPOSE_PROJECT_NAME:-frankenphp-woltlab-suite}"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
backup_dir="${BACKUP_DIR:-./backups/${timestamp}}"

case "$backup_dir" in
	/*) backup_dir_abs="$backup_dir" ;;
	*) backup_dir_abs="$(pwd -P)/$backup_dir" ;;
esac

mkdir -p "$backup_dir_abs"

docker run --rm \
	--network "${project}_default" \
	-v "${project}_wsc-secrets:/run/wsc-secrets:ro" \
	-v "${backup_dir_abs}:/backup" \
	mariadb:lts \
	sh -c '
		set -eu
		db="$(cat /run/wsc-secrets/db-name)"
		user="$(cat /run/wsc-secrets/db-user)"
		password="$(cat /run/wsc-secrets/db-password)"
		mariadb-dump \
			--host=db \
			--user="$user" \
			--password="$password" \
			--single-transaction \
			--quick \
			--routines \
			--events \
			"$db" \
			| gzip -9 > /backup/database.sql.gz
	'

docker run --rm \
	-v "${project}_wsc-public:/app/public:ro" \
	-v "${project}_wsc-secrets:/run/wsc-secrets:ro" \
	-v "${backup_dir_abs}:/backup" \
	alpine:3.22 \
	sh -c '
		set -eu
		tar -czf /backup/public.tar.gz -C /app/public .
		tar -czf /backup/secrets.tar.gz -C /run/wsc-secrets .
	'

printf 'Backup written to %s\n' "$backup_dir_abs"
