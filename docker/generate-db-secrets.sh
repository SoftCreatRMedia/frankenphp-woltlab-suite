#!/bin/sh
set -eu

secret_dir="${WSC_SECRET_DIR:-/run/wsc-secrets}"
mkdir -p "$secret_dir"
umask 077

write_secret_once() {
	name="$1"
	value="$2"
	path="${secret_dir}/${name}"

	if [ ! -f "$path" ]; then
		printf '%s' "$value" > "$path"
	fi
}

random_password() {
	dd if=/dev/urandom bs=48 count=1 2>/dev/null \
		| base64 \
		| tr -dc 'A-Za-z0-9' \
		| cut -c1-32
}

random_identifier() {
	prefix="$1"
	suffix="$(od -An -N8 -tx1 /dev/urandom | tr -d ' \n')"
	printf '%s_%s' "$prefix" "$suffix"
}

write_secret_once db-name "${MYSQL_DATABASE:-$(random_identifier wsc)}"
write_secret_once db-user "${MYSQL_USER:-$(random_identifier wscu)}"
write_secret_once db-password "${MYSQL_PASSWORD:-$(random_password)}"

chown 33:33 "${secret_dir}/db-name" "${secret_dir}/db-user" "${secret_dir}/db-password"
chmod 400 "${secret_dir}/db-name" "${secret_dir}/db-user" "${secret_dir}/db-password"
