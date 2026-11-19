#!/bin/sh
set -eu

php_version="$(php -n -r 'echo PHP_MAJOR_VERSION, ".", PHP_MINOR_VERSION, ".", PHP_RELEASE_VERSION;')"
php_series="${php_version%.*}"

# First PHP releases that fix CVE-2026-109618 and CVE-2026-109619.
case "$php_series" in
	8.2) minimum=8.2.35 ;;
	8.3) minimum=8.3.36 ;;
	8.4) minimum=8.4.27 ;;
	8.5) minimum=8.5.12 ;;
	*)
		printf 'Unsupported PHP version %s. Select PHP 8.2, 8.3, 8.4, or 8.5.\n' "$php_version" >&2
		exit 1
		;;
esac

if ! dpkg --compare-versions "$php_version" ge "$minimum"; then
	printf 'PHP %s is below the PHP %s security minimum of %s.\n' "$php_version" "$php_series" "$minimum" >&2
	exit 1
fi

wsc_ref="$1"
wsc_series="$(printf '%s' "$wsc_ref" | grep -Eo '^[0-9]+\.[0-9]+' || true)"
if [ -n "$wsc_series" ] && dpkg --compare-versions "$wsc_series" ge 6.3; then
	case "$php_series" in
		8.4|8.5) ;;
		*)
			printf 'WoltLab Suite %s requires PHP 8.4.27+ within 8.4 or PHP 8.5.12+ within 8.5. Found PHP %s.\n' "$wsc_ref" "$php_version" >&2
			exit 1
			;;
	esac
fi
