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
	# Change this function if <YOUR TOOL> has other means of determining installable versions.
	list_github_tags
}

get_os() {
  case "$(uname -s | tr '[:upper:]' '[:lower:]')" in
    "linux") echo "linux" ;;
    "darwin") echo "darwin" ;;
    *"freebsd"*) echo "freebsd" ;;
    "openbsd") echo "openbsd" ;;
    "netbsd") echo "netbsd" ;;
    *) echo "unknown" ;;
  esac
}

get_arch() {
  local machine=$(uname -m | tr '[:upper:]' '[:lower:]')
  case "$machine" in
    "arm64"* | "aarch64"* ) echo "arm64" ;;
    "arm"* | "aarch"*) echo "arm" ;;
    *"86") echo "32" ;;
    *"64") echo "64" ;;
    *) echo "unknown" ;;
  esac
}

# Detection based on the official install script
get_platform() {
  local os=$(get_os)
  local arch=$(get_arch)
  local platform=""

  case "$os" in
    "linux")
      case "$arch" in
        "arm64") platform="linux-arm64" ;;
        "arm") platform="linux-arm" ;;
        "32") platform="linux32" ;;
        "64") platform="linux64" ;;
      esac
      ;;
    "darwin")
      case "$arch" in
        "arm64") platform="osx-arm64" ;;
        *) platform="osx" ;;
      esac
      ;;
    "freebsd")
      case "$arch" in
        "32") platform="freebsd32" ;;
        "64") platform="freebsd64" ;;
      esac
      ;;
    "openbsd")
      case "$arch" in
        "32") platform="openbsd32" ;;
        "64") platform="openbsd64" ;;
      esac
      ;;
    "netbsd")
      case "$arch" in
        "32") platform="netbsd32" ;;
        "64") platform="netbsd64" ;;
      esac
      ;;
  esac

  echo "$platform"
}

download_release() {
	local version filename url
	version="$1"
	filename="$2"
	platform=$(get_platform)

	url="$GH_REPO/releases/download/v${version}/$TOOL_NAME-${version}-${platform}.tar.gz"

	echo "* Downloading $TOOL_NAME release $version for platform ${platform}..."
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
    cp -r "$ASDF_DOWNLOAD_PATH/micro" "$install_path"
    chmod +x "$install_path/$TOOL_NAME"
		local tool_cmd
		tool_cmd="$(echo "$TOOL_TEST" | cut -d' ' -f1)"
		test -x "$install_path/$tool_cmd" || fail "Expected $install_path/$tool_cmd to be executable."

		echo "$TOOL_NAME $version installation was successful!"
	) || (
		rm -rf "$install_path"
		fail "An error occurred while installing $TOOL_NAME $version."
	)
}

