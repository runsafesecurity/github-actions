#!/bin/bash

set -e

SCRIPT_DIR=$(CDPATH='' cd -- "$( dirname -- "$0" )" && pwd -P)
ROOT_DIR=${SCRIPT_DIR}/../
PKG_DIR=${ROOT_DIR}/packages

deb_distros="bionic:bionic,focal,buster,bullseye jammy:bookworm,jammy,noble,trixie"

multilib=false

while [[ "$#" -gt 0 ]]; do
  case "$1" in
  -v|--vxworks)
    multilib=true
    shift
    ;;
  esac
done

. /etc/os-release
if [ "${ID}" = "debian" ] || [ "${ID_LIKE}" = "debian" ]; then
  distro_type="debian"
elif [ "${ID_LIKE}" = "rhel centos fedora" ]; then
  distro_type="redhat"
elif [ "${ID_LIKE}" = "rhel fedora" ]; then
  distro_type="redhat"
elif [ "${ID_LIKE}" = "fedora" ]; then
  distro_type="redhat"
elif [ "${ID_LIKE}" = "suse" ]; then
  distro_type="suse"
else
  echo "Unsupported OS!"
  exit 1
fi

ARCH=$(uname -m)

if [ "$(id -u)" -ne 0 ]; then
  echo "Adding sudo prefix"
  sudo_prefix="sudo "
fi

case "${distro_type}" in
debian)
  echo "Installing RunSafe SBOM tool for Debian-based systems"

  if [ "${multilib}" = true ]; then
    # for multilib support (i.e., vxworks), multiple pkg_arch libraries will be installed
    pkg_arch=
  else
    case "${ARCH}" in
      i386) pkg_arch="${ARCH}" ;;
      i686) pkg_arch="i386" ;;
      x86_64) pkg_arch="amd64" ;;
    esac
  fi

  ${sudo_prefix} dpkg -i "${PKG_DIR}"/*"${pkg_version}"*"${pkg_arch}".deb
  ;;
redhat)
  pkgs_list=$(ls "${PKG_DIR}"/*"${ARCH}".rpm)
  pkgs_to_install=""
  for pkg in ${pkgs_list}; do
    is_installed=$(rpm -i --nosignature --test "${pkg}" 2>&1 || true)
    case "${is_installed}" in
    *"already installed"*) 
	;;
    *) 
	pkgs_to_install="${pkgs_to_install} ${pkg}"
	;;
    esac
  done
  echo "Installing RunSafe SBOM tool for RHEL-based systems"
  if [ -n "${pkgs_to_install}" ]; then
    ${sudo_prefix} rpm -iv ${pkgs_to_install}
  fi
  ;;
suse)
  ${sudo_prefix} ln -s /lib64/libssl.so.1.0.0 /lib64/libssl.so.10
  ${sudo_prefix} ln -s /lib64/libcrypto.so.1.0.0 /lib64/libcrypto.so.10

  echo "Installing RunSafe SBOM tool for RHEL-based systems"
  ${sudo_prefix} rpm -iv "${PKG_DIR}/runsafe-sbom-*.${ARCH}.rpm"
  ;;
esac
