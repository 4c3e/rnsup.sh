#!/bin/bash

################################################################
# Colors                                                       #
################################################################
# Reset
Off='\033[0m' # Text Reset

# Regular Colors
Red='\033[0;31m'    # Red
Green='\033[0;32m'  # Green
Yellow='\033[0;33m' # Yellow
Purple='\033[0;35m' # Purple
White='\033[0;37m'  # White

# Background
On_Black='\033[40m' # Black

OkBullet="${Green}${On_Black}:: ${White}${On_Black}"
WarnBullet="${Yellow}${On_Black}:: ${White}${On_Black}"
ErrBullet="${Red}${On_Black}:: ${White}${On_Black}"
Ok="${Green}${On_Black} ok.${Off}"
Fail="${Red}${On_Black} failed!${Off}"
Nok="${Yellow}${On_Black} nok.${Off}"
Stat="${Purple}${On_Black}"
StatInfo="${White}${On_Black}"

################################################################
# Vars                                                         #
################################################################
VERSION="v0.1.0"
RNSUP_INSTALL_CMD="sudo bash -c \"\$(curl  -sLSf https://paul.lc/rnsup.sh)\""
RNSUP_DIR="/opt/rnsup.sh"
RNSUP_LOG_FILE="/tmp/rnsup.sh-$(date +%Y%m%d-%H%M%S).log"
DEPENDENCIES="curl python3-pip"

################################################################
# Functions                                                    #
################################################################

header() {
    echo -e "${Red}${On_Black}                                 _     "
    echo -e "                                | |    "
    echo -e " _ __ _ __  ___ _   _ _ __   ___| |__  "
    echo -e "| '__| '_ \/ __| | | | '_ \ / __| '_ \ "
    echo -e "| |  | | | \__ \ |_| | |_) |\__ \ | | |"
    echo -e "|_|  |_| |_|___/\__,_| .__(_)___/_| |_|"
    echo -e "                     | |               "
    echo -e "Version ${VERSION}       |_| \n${Off}"
}

detect_root() {
    echo -ne "${OkBullet}Checking root... ${Off}"
    if [[ $EUID -ne 0 ]]; then
        echo -e "${Fail}"
        echo -e "${ErrBullet}You need to run this script as root (UID=0).${Off}"
        exit 1
    fi
    echo -e "${Ok}"
}

detect_pipe() {
    echo -ne "${OkBullet}Checking script execution... ${Off}"
    if [ -p /dev/stdin ]; then
        echo -e "${Fail}"
        echo -e "${ErrBullet}This script can't be piped! Instead, use the command: ${RNSUP_INSTALL_CMD}${Off}"
        exit 1
    fi
    echo -e "${Ok}"
}

check_return() {
    if [ "$1" -ne 0 ]; then
        echo -e "${Fail}"
        echo -e "${ErrBullet}Installation failed. Check the logs in ${RNSUP_LOG_FILE}${Off}"
        exit "$1"
    fi
}

check_deps() {
    echo -ne "${OkBullet}Checking and installing dependencies... ${Off}"
    # shellcheck disable=SC2068
    for pkg in ${DEPENDENCIES[@]}; do
        if ! command -v "${pkg}" >>"${RNSUP_LOG_FILE}" 2>&1; then
            install_pkg "${pkg}"
            check_return $?
        fi
    done
    echo -e "${Ok}"
}

install_pkg() {
    # This detects both ubuntu and debian
    if grep -q "debian" /etc/os-release; then
        apt-get update >>"${RNSUP_LOG_FILE}" 2>&1
        apt-get install -y "$1" >>"${RNSUP_LOG_FILE}" 2>&1
    elif grep -q "fedora" /etc/os-release || grep -q "centos" /etc/os-release; then
        dnf install -y "$1" >>"${RNSUP_LOG_FILE}" 2>&1
    else
        echo -e "${ErrBullet}Cannot detect your distribution package manager.${Off}"
        exit 1
    fi
}

detect_pip3() {
    echo -ne "${OkBullet}Checking pip3... ${Off}"
    if pip3 --version >>"${RNSUP_LOG_FILE}" 2>&1; then
        echo -e "${Ok}"
    else
        echo -e "${Nok}"
        echo -e "${ErrBullet}Please install pip3 first.${Off}"
        exit 1
    fi
}

detect_rnsd() {
    echo -ne "${OkBullet}Checking rnsd... ${Off}"
    if rnsd --version >>"${RNSUP_LOG_FILE}" 2>&1; then
        echo -e "${Ok}"
    else
        echo -e "${Nok}"
        echo -e "TODODODODODO"
        exit 1
    fi
}

install_i2pd() {
    # Official i2pd install script
    source /etc/os-release

    function get_release {
        DIST=$ID
        case $ID in
            debian|ubuntu|raspbian)
                if [[ -n $DEBIAN_CODENAME ]]; then
                    VERSION_CODENAME=$DEBIAN_CODENAME
                fi

                if [[ -n $UBUNTU_CODENAME ]]; then
                    VERSION_CODENAME=$UBUNTU_CODENAME
                fi

                if [[ -z $VERSION_CODENAME ]]; then
                    echo "Couldn't find VERSION_CODENAME in your /etc/os-release file. Did your system supported? Please report issue to me by writing to email: 'r4sas <at> i2pd.xyz'"
                    exit 1
                fi
                RELEASE=$VERSION_CODENAME
            ;;
            *)
                if [[ -z $ID_LIKE || "$ID_LIKE" != "debian" && "$ID_LIKE" != "ubuntu" ]]; then
                    echo "Your system is not supported by this script. Currently it supports debian-like and ubuntu-like systems."
                    exit 1
                else
                    DIST=$ID_LIKE
                    case $ID_LIKE in
                        debian)
                            if [[ "$ID" == "kali" ]]; then
                                if [[ "$VERSION" == "2020.2" ]]; then
                                    RELEASE="buster"
                                fi
                            else
                                RELEASE=$DEBIAN_CODENAME
                            fi
                        ;;
                        ubuntu)
                            RELEASE=$UBUNTU_CODENAME
                        ;;
                    esac
                fi
            ;;
        esac
        if [[ -z $RELEASE ]]; then
            echo "Couldn't detect your system release. Please report issue to me by writing to email: 'r4sas <at> i2pd.xyz'"
            exit 1
        fi
    }

    get_release

    echo "Importing signing key"
    wget -q -O - https://repo.i2pd.xyz/r4sas.gpg | apt-key --keyring /etc/apt/trusted.gpg.d/i2pd.gpg add -

    echo "Adding APT repository"
    echo "deb https://repo.i2pd.xyz/$DIST $RELEASE main" > /etc/apt/sources.list.d/i2pd.list
    echo "deb-src https://repo.i2pd.xyz/$DIST $RELEASE main" >> /etc/apt/sources.list.d/i2pd.list
    apt-get update
    apt-get install -y i2pd
}

detect_i2pd() {
    echo -ne "${OkBullet}Checking i2pd... ${Off}"
    if i2pd --version >>"${RNSUP_LOG_FILE}" 2>&1; then
        echo -e "${Ok}"
    else
        echo -e "${Nok}"
        install_i2pd
        exit 1
    fi
}


header
detect_root
detect_pipe
check_deps
detect_pip3
detect_rnsd
detect_i2pd