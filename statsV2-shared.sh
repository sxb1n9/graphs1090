#!/bin/bash

# NOTES =======================================================================

# This is a shared source file for variable sharing and for general functions
# source <path of this file> to use these
# source statsV2-shared.sh

# PATHS & VARIABLES ===========================================================

# ECHO's
LINE_BREAK="--------------------------------------------------------------------------------"

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
PACKAGES=("git" "wget" "rrdtool" "bash-builtins" "collectd-core")
PACKAGE_COLLECTD="http://mirrors.kernel.org/ubuntu/pool/universe/c/collectd/collectd-core_5.12.0-11_amd64.deb"

# OTHER
FR24FEED_UPDATER_PATH=/usr/lib/fr24/fr24feed_updater.sh
SLEEP_PATH=/usr/lib/bash/sleep
