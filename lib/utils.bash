#!/usr/bin/env bash

set -euo pipefail

GH_REPO="https://github.com/zyedidia/micro"
TOOL_NAME="micro"
TOOL_TEST="micro -version"

fail() {
	echo -e "asdf-$TOOL_NAME: $*"
	exit 1
}

curl_opts=(-fsSL)

# NOTE: You might want to remove this if <YOUR TOOL> is not hosted on GitHub releases.
if [ -n "${GITHUB_API_TOKEN:-}" ]; then
	curl_opts=("${curl_opts[@]}" -H "Authorization: token $GITHUB_API_TOKEN")
fi

sort_versions() {
	sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z\1/; s/$/.z/; G; s/\n/ /' |
		LC_ALL=C sort -t. -k 1,1 -k 2,2n -k 3,3n -k 4,4n -k 5,5n | awk '{print $2}'
}

list_github_tags() {
	git ls-remote --tags --refs "$GH_REPO" |
		grep -o 'refs/tags/.*' | cut -d/ -f3- |
		sed 's/^v//' # NOTE: You might want to adapt this sed to remove non-version strings from tags
}

list_all_versions() {
	# TODO: Adapt this. By default we simply list the tag names from GitHub releases.
	# Change this function if <YOUR TOOL> has other means of determining installable versions.
	list_github_tags
}

get_arch() {
  local arch=$(uname -m | tr '[:upper:]' '[:lower:]')
  case $arch in
    aarch64)
      arch='arm64'
      ;;
    x86_64)
      arch='64'
      ;;
  esac
  echo "$arch"
}

# Detection nbased on the official install script
get_platform() {
platform=''
machine=$(uname -m)
case "$(uname -s | tr '[:upper:]' '[:lower:]')" in
"linux")
	case "$machine" in
	"arm64"* | "aarch64"* ) platform='linux-arm64' ;;
	"arm"* | "aarch"*) platform='linux-arm' ;;
	*"86") platform='linux32' ;;
	*"64") platform='linux64' ;;
	esac
	;;
"darwin") platform='osx' ;;
*"freebsd"*)
	case "$machine" in
	*"86") platform='freebsd32' ;;
	*"64") platform='freebsd64' ;;
	esac
	;;
"openbsd")
	case "$machine" in
	*"86") platform='openbsd32' ;;
	*"64") platform='openbsd64' ;;
	esac
	;;
"netbsd")
	case "$machine" in
	*"86") platform='netbsd32' ;;
	*"64") platform='netbsd64' ;;
	esac
	;;
esac
echo $platform
}

download_release() {
	local version filename url
	version="$1"
	filename="$2"
	os=$(get_platform)

	url="$GH_REPO/releases/download/v${version}/$TOOL_NAME-${version}-${os}.tar.gz"

	echo "* Downloading $TOOL_NAME release $version..."
	curl "${curl_opts[@]}" -o "$filename" -C - "$url" || fail "Could not download $url"
}

install_version() {
	local install_type="$1"
	local version="$2"
	local install_path="${3%/bin}/bin"

	if [ "$install_type" != "version" ]; then
		fail "asdf-$TOOL_NAME supports release installs only"
	fi

	(
		mkdir -p "$install_path"
		cp -r "$ASDF_DOWNLOAD_PATH"/* "$install_path"

		local tool_cmd
		tool_cmd="$(echo "$TOOL_TEST" | cut -d' ' -f1)"
		test -x "$install_path/$tool_cmd" || fail "Expected $install_path/$tool_cmd to be executable."

		echo "$TOOL_NAME $version installation was successful!"
	) || (
		rm -rf "$install_path"
		fail "An error occurred while installing $TOOL_NAME $version."
	)
}

