#!/bin/sh
set -eu

public_dir="${WSC_PUBLIC_DIR:-/app/public}"
source_dir="${WSC_SOURCE_DIR:-/usr/src/woltlab}"
marker_file="${public_dir}/.wsc-ref"

read_env_file() {
	var_name="$1"
	file_var_name="${var_name}_FILE"
	eval "var_value=\${$var_name:-}"
	eval "file_var_value=\${$file_var_name:-}"

	if [ -z "$var_value" ] && [ -n "$file_var_value" ] && [ -f "$file_var_value" ]; then
		export "$var_name=$(cat "$file_var_value")"
	fi
}

is_empty_dir() {
	[ -d "$1" ] || return 0
	[ -z "$(find "$1" -mindepth 1 -maxdepth 1 -print -quit)" ]
}

copy_prebuilt_installer() {
	if [ ! -f "$source_dir/install.php" ] || [ ! -f "$source_dir/WCFSetup.tar.gz" ]; then
		echo "$source_dir does not contain a prebuilt WoltLab Suite installer." >&2
		exit 1
	fi

	mkdir -p "$public_dir"
	cp -a "$source_dir/." "$public_dir/"
	if [ -n "${WSC_REF:-}" ]; then
		printf '%s\n' "$WSC_REF" > "$marker_file"
	fi
	if [ "$(id -u)" = "0" ]; then
		chown -R www-data:www-data "$public_dir"
	fi
}

if is_empty_dir "$public_dir"; then
	copy_prebuilt_installer
elif [ ! -f "$public_dir/install.php" ] && [ ! -f "$public_dir/index.php" ]; then
	echo "$public_dir is not empty and does not look like a WoltLab Suite installation." >&2
	echo "Refusing to modify it automatically." >&2
	exit 1
fi

read_env_file WCFSETUP_DBNAME
read_env_file WCFSETUP_DBUSER
read_env_file WCFSETUP_DBPASSWORD

if command -v docker-php-entrypoint >/dev/null 2>&1; then
	exec docker-php-entrypoint "$@"
fi

exec "$@"
