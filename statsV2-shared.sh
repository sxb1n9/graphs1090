#!/bin/bash

# NOTES =======================================================================

# This is a shared source file for variable sharing and for general functions
# source <path of this file> to use these
# source statsV2-shared.sh

# PATHS & VARIABLES ===========================================================

# ECHO's
LINE_HASH="################################################################################"
LINE_DOUBLE="================================================================================"
LINE_BREAK="--------------------------------------------------------------------------------"
LINE_DASH=" - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"


# REPO BRANCH TARGET
REPO="https://github.com/sxb1n9/graphs1090"
BRANCH="v2"
TARGET="/usr/share/statsV2/git"

# STATSV2
STATSV2_MAIN="/usr/share/statsV2"

STATSV2_USR=/usr/share/statsV2
STATSV2_ETC=/etc/default/statsV2
STATSV2_VAR=/var/lib/statsV2

SYM0978=/usr/share/statsV2/978-symlink
SYM1090=/usr/share/statsV2/data-symlink

# COLLECTD
COLLECTD_ETC=/etc/collectd
COLLECTD_PLUGINS=/var/lib/collectd
COLLECTD_RRD=/var/lib/collectd/rrd
COLLECTD_RUN=/run/collectd

COLLECTD_CPU_AIRSPY_PATH=/run/collectd/localhost/dump1090-localhost/dump1090_cpu-airspy.rrd

# LIGHTTPD
LIGHTTPD_CONF=/etc/lighttpd
LIGHTTPD_CONF_ENABLED=/etc/lighttpd/conf-enabled
LIGHTTPD_CONF_AVAILABLE=/etc/lighttpd/conf-available

# SERVICE
SERVICE_CONF=/lib/systemd/system

# OS
OS_PATH=/etc/os-release

# DEPENDANCIES
PACKAGESs="git rrdtool wget unzip bash-builtins collectd-core collectd"
PACKAGE_COLLECTD="http://mirrors.kernel.org/ubuntu/pool/universe/c/collectd/collectd-core_5.12.0-11_amd64.deb"

# OTHER
FR24FEED_UPDATER_PATH=/usr/lib/fr24/fr24feed_updater.sh
SLEEP_PATH=/usr/lib/bash/sleep

# ERROR
ERROR=""

# FUNCTIONS ===================================================================

# APT_UPDATE ------------------------------------------------------------------
# run apt update and wait for finish (update_done=yes)
# -----------------------------------------------------------------------------
function APT_UPDATE()
{
    echo "RUN APT_UPDATE";

    if [[ $update_done != "yes" ]]; then
        apt update && update_done=yes || true
    fi
}

# APT_INSTALL $PKG ------------------------------------------------------------
# run apt install for package
# -----------------------------------------------------------------------------
function APT_INSTALL()
{
    if [[ -z "$1" ]]; then
        echo "APT_INSTALL needs 1 arguments" 1>&2;
        echo "APT_INSTALL PACKAGE" 1>&2;
        return 0; 
    fi

    package="$1";
    echo "RUN APT_INSTALL $pacakge";

    apt-get install -y --no-install-suggests --no-install-recommends $package

	if ! command -v "$CMD" &>/dev/null; then
		NEED_INSTALL=1
	fi
}

# GIT_CLONE $REPO $BRANCH $TARGET(dir) ----------------------------------------
# clones REPO BRANCH to TARGET directory and CD's to that directory
# dependancy: git installed
# -----------------------------------------------------------------------------
function GIT_CLONE()
{ 
    if [[ -z "$1" ]] || [[ -z "$2" ]] || [[ -z "$3" ]]; then
        echo "GIT_CLONE needs 3 arguments" 1>&2;
        echo "GIT_CLONE REPO BRANCH TARGET(dir)" 1>&2;
        return 0; 
    fi

    REPO="$1";
    BRANCH="$2";
    TRGT="$3";
    echo "GIT_CLONE $REPO $BRANCH $TRGT";

    git clone --depth 1 --single-branch --branch "$BRANCH" "$REPO" "$TRGT"
    cd $TARGET
}

# GIT_CLONE $REPO $BRANCH $TARGET(dir) ----------------------------------------
# clones REPO BRANCH to TARGET directory and CD's to that directory
# dependancy: git installed
# -----------------------------------------------------------------------------
function GIT_PULL()
{ 
    if [[ -z "$1" ]]; then
        echo "GIT_PULL needs 1 argument" 1>&2;
        echo "GIT_PULL TARGET(dir)" 1>&2;
        return 0; 
    fi

    echo "GIT_PULL $1";
    cd $1
    git pull
}

# CONTROL_SERVICE -------------------------------------------------------------
# $1 = start, stop, restart, status
# $2 = lighttpd, collectd, statsV2
# $3 = (optional) enable
# CHECK if start or restart
# -----------------------------------------------------------------------------
function CONTROL_SERVICE()
{ 
    if [[ -z "$1" ]] || [[ -z "$2" ]]; then
        echo "CONTROL_SERVICE needs at least 2 arguments";
        echo "CONTROL_SERVICE CMD APP";
        return 0; 
    fi

    CMD=$1
    APP=$2

    echo $LINE_BREAK
    if [[ -z "$3" ]] then
        echo "ENABLE $APP"
        systemctl enable $APP &>/dev/null
    fi

    echo "$CMD $APP"
    systemctl $CMD $APP
    echo $LINE_BREAK

    if [[ $CMD == "start" ]] || [[ $CMD == "restart" ]]; then
        if ! systemctl status $APP &>/dev/null; then
            echo $LINE_DASH
            echo "ERROR: $APP is not running displaying log below"
            echo $LINE_DASH
            journalctl --no-pager -u collectd | tail -n40
        fi
    fi
}