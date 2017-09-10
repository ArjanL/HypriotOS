#!/bin/bash
set +x
set -e
set -o pipefail
export DEBIAN_FRONTEND=noninteractive
#
# This script is for quickly installing X11 support for a Raspberry Pi
# running HypriotOS.
#

## Variables {{{
#
# Config Files {{{
CONFIG_TXT_FILE='/boot/config.txt'
LIGHTDM_CONF_FILE='/etc/lightdm/lightdm.conf'
FBTURBO_SRC_URL='https://github.com/ssvb/xf86-video-fbturbo.git'
# End Config Files }}}
# Variable Functions {{{
sh_c=""
# }}}
# Colors {{{
# Only run `tput` if session is interactive and TTY is assigned
if test -t 1; then
    RED=$(tput setaf 1)
    YELLOW=$(tput setaf 3)
    CYAN=$(tput setaf 6)
    NORMAL=$(tput sgr0)
else
    RED=''
    YELLOW=''
    CYAN=''
    NORMAL=''
fi
# End Colors }}}
# End Variables }}}
## Utility Functions {{{
#

_banner()
{
	echo -n "${CYAN}"
	echo "X11 display for HypriotOS"
	echo -n "${NORMAL}"
}

_greeting()
{
    _banner
    echo '' 
    echo '' 
    echo 'Will setup X11 for the HypriotOS and take up about a'
    echo 'GB of space on the system.'
    echo '' 
    echo '' 
    echo 'If that is not what you want press CTRL+C to exit,' 
    echo -n 'otherwise you may safely ignore this message.  '

    local -a frames=( '/' '-' '\' '|' )
    for x in `seq 1 16`; do 
        echo -ne "${frames[i++ % ${#frames[@]}]}"
        sleep 1
        echo -ne "\b"
    done

    echo ''
    echo ''
    _rule
    echo ''
}

_error()
{
    printf "${RED}[*] Error: ${NORMAL}$1"
    echo ""
}

_warning()
{
    printf "${YELLOW}[*] Warning: ${NORMAL}$1"
    echo ""
}

_info()
{
    printf "${CYAN}[*] Info: ${NORMAL}$1"
    echo ""
}

# Print a horizontal rule
# Only if TTY is set
_rule()
{
    if test -t 1; then
        printf -v _hr "%*s" $(tput cols) && echo ${_hr// /${1--}}
    fi
}


command_exists()
{
    command -v "$@" > /dev/null 2>&1
}
# End Utility Functions }}}
## System Setup Funcitons {{{
_config()
{
	_info "Setting up \`/boot/config.txt\`"
	if [ ! -f ${CONFIG_TXT_FILE} ]; then
		($sh_c 'sleep 3; cat <<- EOF | sudo tee ${CONFIG_TXT_FILE} >/dev/null
		display_rotate=0	# normal HDMI displays
		#lcd_rotate=2		# 7" Touch Screen display from RaspberryPi.Org
		disable_splash=1
		bootcode_delay=2
		EOF')
	fi
	_info "Success"
	_rule
}

_installx()
{
	_info "Installing X11 and LightDM"
	($sh_c 'sleep 3; apt-get update')
	($sh_c 'sleep 3; apt-get install -y --no-install-recommends xserver-xorg xinit xserver-xorg-video-fbdev lxde lxde-common lightdm x11-xserver-utils')
	($sh_c 'sleep 3; apt-get install -y policykit-1 hal')
	_info "Success"
	_rule
}

_xautologin()
{
	_info "Enabling autologin for user $user"
	if [ ! -f ${LIGHTDM_CONF_FILE}.sav ]; then
		# backup original file
		($sh_c 'sleep 3; mv ${LIGHTDM_CONF_FILE} ${LIGHTDM_CONF_FILE}.sav')

		($sh_c 'sleep 3; cat <<- EOF | sudo tee ${LIGHTDM_CONF_FILE} >/dev/null
		[SeatDefaults]
		autologin-user=pirate
		autologin-user-timeout=0
		EOF')
	fi
	_rule
}

_turbodeps()
{
	_info "Installing fbturbo dependencies"
	($sh_c 'sleep 3; apt-get update')
	($sh_c 'sleep 3; apt-get install -y git build-essential xorg-dev xutils-dev x11proto-dri2-dev')
	($sh_c 'sleep 3; apt-get install -y libltdl-dev libtool automake libdrm-dev')
	_info "Success"
	_rule
}

_fbturbo()
{
	_info "Installing fbturbo from source"
	_turbodeps
	git clone ${FBTURBO_SRC_URL}
	cd xf86-video-fbturbo
	autoreconf -vi
	./configure --prefix=/usr
	make
	($sh_c 'sleep 3; make install')
	($sh_c 'sleep 3; cp xorg.conf /etc/X11/xorg.conf')
	_info "Success"
	_rule
}
## End System Setup Functions }}}
## Main {{{
#
install()
{
    _greeting
    user="$(id -un 2>/dev/null || true)"
    sh_c='sh -c'
    if (( $EUID != 0 )); then
        if command_exists sudo; then
            sh_c='sudo sh -c'
        elif command_exists su; then
            sh_c='su -c'
        else
            local message=(
            "[*] Error: Permissions required to install packages."
            "[*] The installer needs the ability to run commands as root."
            "[*] Unable to find either 'sudo' or 'su' for the installation."
            )
            printf '%s\n' "${message[@]}"
            exit 1
        fi
    fi

	_config
	_installx
	_xautologin
	_fbturbo
	_info "Install complete!"
	_rule

    exit 0
}
# End Main }}}

install