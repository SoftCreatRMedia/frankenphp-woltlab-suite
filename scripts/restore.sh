#!/bin/sh
set -eu

backup_dir="${1:?Usage: scripts/restore.sh <backup-directory>}"
project="${COMPOSE_PROJECT_NAME:-frankenphp-woltlab-suite}"
compose_args="${COMPOSE_ARGS:-}"

case "$backup_dir" in
	/*) backup_dir_abs="$backup_dir" ;;
	*) backup_dir_abs="$(pwd -P)/$backup_dir" ;;
esac

compose() {
	# shellcheck disable=SC2086
	docker compose $compose_args "$@"
}

for file in database.sql.gz public.tar.gz secrets.tar.gz; do
	if [ ! -f "${backup_dir_abs}/${file}" ]; then
		echo "Missing ${backup_dir_abs}/${file}" >&2
		exit 1
	fi
done

compose down

docker volume create "${project}_wsc-public" >/dev/null
docker volume create "${project}_wsc-secrets" >/dev/null
docker volume create "${project}_db-data" >/dev/null

docker run --rm \
	-v "${project}_wsc-public:/app/public" \
	-v "${project}_wsc-secrets:/run/wsc-secrets" \
	-v "${backup_dir_abs}:/backup:ro" \
	alpine:3.22 \
	sh -c '
		set -eu
		rm -rf /app/public/* /app/public/.[!.]* /app/public/..?* /run/wsc-secrets/* || true
		tar -xzf /backup/public.tar.gz -C /app/public
		tar -xzf /backup/secrets.tar.gz -C /run/wsc-secrets
		chown -R 33:33 /app/public /run/wsc-secrets
		chmod 400 /run/wsc-secrets/db-name /run/wsc-secrets/db-user /run/wsc-secrets/db-password
	'

compose up -d db

docker run --rm \
	--network "${project}_default" \
	-v "${project}_wsc-secrets:/run/wsc-secrets:ro" \
	-v "${backup_dir_abs}:/backup:ro" \
	mariadb:lts \
	sh -c '
		set -eu
		db="$(cat /run/wsc-secrets/db-name)"
		user="$(cat /run/wsc-secrets/db-user)"
		password="$(cat /run/wsc-secrets/db-password)"
		until mariadb-admin ping --host=db --user="$user" --password="$password" --silent; do
			sleep 2
		done
		gzip -dc /backup/database.sql.gz | mariadb --host=db --user="$user" --password="$password" "$db"
	'

compose up -d
