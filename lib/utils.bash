#!/usr/bin/env bash

set -euo pipefail
GH_REPO="https://github.com/balena-io/balena-cli"
TOOL_NAME="balena-cli"
TOOL_TEST="balena"

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
  list_github_tags
}

get_platform() {
  local uname_out
  uname_out="$(uname -s)"
  case "${uname_out}" in
  Linux*) echo "linux" ;;
  Darwin*) echo "macOS" ;;
  CYGWIN* | MINGW* | MSYS*) echo "windows" ;;
  *) echo "unknown" ;;
  esac
}

get_arch() {
  # shellcheck disable=SC2155
  local arch=$(uname -m)
  case "$arch" in
  amd64 | x86_64)
    echo "x64"
    ;;
  arm64 | aarch64)
    echo "arm64"
    ;;
  *)
    echo "i386"
    ;;
  esac
}

download_release() {
  local version="$1"
  local tag="$1"
  local filename="$2"

  # shellcheck disable=SC2155
  local platform=$(get_platform)
  # shellcheck disable=SC2155
  local arch=$(get_arch)

  # HACK: asdf wants numeric version numbers, but most start with a "v"
  # since people usually tag releases in GitHub with a vX.X.X and _not_ X.X.X
  # so need to prefix version based on this fragile logic :-/
  # in case the version is in some other format such as FOOBAR.X.X.X
  if [[ $tag =~ ^[0-9] ]]; then
    tag="v${tag}"
  fi

  local url="$GH_REPO/releases/download/${tag}/balena-cli-v${version}-${platform}-${arch}-standalone.tar.gz"

  echo "* Downloading $TOOL_NAME release $version..."
  curl "${curl_opts[@]}" -o "$filename" -C - "$url" || fail "Could not download $url"
}

install_version() {
  local install_type="$1"
  local version="$2"
  local install_path="${3%/bin}"

  if [ "$install_type" != "version" ]; then
    fail "asdf-$TOOL_NAME supports release installs only"
  fi

  (
    mkdir -p "$install_path"
    cp -r "$ASDF_DOWNLOAD_PATH"/* "$install_path"

    local tool_cmd="$TOOL_TEST"
    "$install_path/bin/$tool_cmd" --help &>/dev/null || fail "Expected $install_path/bin/$tool_cmd --help to succeed"

    echo "$TOOL_NAME $version installation was successful!"
  ) || (
    # rm -rf "$install_path"
    fail "An error occurred while installing $TOOL_NAME $version."
  )
}
