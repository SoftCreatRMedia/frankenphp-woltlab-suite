#!/bin/sh
set -eu

ref="${1:?missing WoltLab/WCF ref}"
output_dir="${2:?missing output directory}"

case "$ref" in
	[0-9]*.[0-9]*.[0-9]* | [0-9]*.[0-9]*.[0-9]*_Alpha_[0-9]* | [0-9]*.[0-9]*.[0-9]*_Beta_[0-9]* | [0-9]*.[0-9]*.[0-9]*_RC_[0-9]* | [0-9]*.[0-9]*.[0-9]*_dev_[0-9]*)
		archive_url="https://codeload.github.com/WoltLab/WCF/tar.gz/refs/tags/${ref}"
		;;
	[0-9]*.[0-9]*)
		archive_url="https://codeload.github.com/WoltLab/WCF/tar.gz/refs/heads/${ref}"
		;;
	*)
		echo "Unsupported WoltLab/WCF ref '${ref}'." >&2
		echo "Use a tag such as 6.2.3 or a branch such as 6.2." >&2
		exit 1
		;;
esac

work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT INT TERM

mkdir -p "$work_dir/src" "$output_dir"

echo "Building WoltLab Suite installer from ${archive_url}"
curl -fsSL "$archive_url" -o "$work_dir/wcf.tar.gz"
tar -xzf "$work_dir/wcf.tar.gz" --strip-components=1 -C "$work_dir/src"

if [ ! -f "$work_dir/src/wcfsetup/install.php" ] || [ ! -d "$work_dir/src/com.woltlab.wcf" ]; then
	echo "The WoltLab/WCF archive does not contain the expected installer structure." >&2
	exit 1
fi

if [ -d "$work_dir/src/com.woltlab.wcf/templates" ]; then
	(
		cd "$work_dir/src/com.woltlab.wcf/templates"
		tar -cf "$work_dir/src/com.woltlab.wcf/templates.tar" *
	)
	rm -rf "$work_dir/src/com.woltlab.wcf/templates"
fi

(
	cd "$work_dir/src/com.woltlab.wcf"
	tar -cf "$work_dir/src/wcfsetup/install/packages/com.woltlab.wcf.tar" *
)

(
	cd "$work_dir/src/wcfsetup"
	tar -czf "$output_dir/WCFSetup.tar.gz" *
)

cp "$work_dir/src/wcfsetup/install.php" "$output_dir/install.php"
cp "$work_dir/src/wcfsetup/test.php" "$output_dir/test.php"
printf '%s\n' "$ref" > "$output_dir/.wsc-ref"

find "$output_dir" -type d -exec chmod 0755 {} +
find "$output_dir" -type f -exec chmod 0644 {} +
