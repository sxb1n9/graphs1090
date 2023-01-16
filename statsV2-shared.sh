#!/bin/bash

# NOTES =======================================================================

# This is a shared source file for variable sharing and for general functions
# source <path of this file> to use these
# source statsV2-shared.sh

# PATHS & VARIABLES ===========================================================

# REPO and BRANCH
REPO="https://github.com/sxb1n9/graphs1090"
BRANCH="v2"

STATSV2_USR=/usr/share/statsV2
STATSV2_ETC=/etc/default/statsV2
STATSV2_VAR=/var/lib/statsV2

COLLECTD_ETC=/etc/collectd
COLLECTD_PLUGINS=/var/lib/collectd
COLLECTD_RRD=/var/lib/collectd/rrd
COLLECTD_RUN=/run/collectd

LIGHTTPD_CONF=/etc/lighttpd
LIGHTTPD_CONF_ENABLED=/etc/lighttpd/conf-enabled
LIGHTTPD_CONF_AVAILABLE=/etc/lighttpd/conf-available

SERVICE_CONF=/lib/systemd/system

OS_PATH=/etc/os-release

SYM978=/usr/share/statsV2/978-symlink
SYM1090=/usr/share/statsV2/data-symlink

FR24FEED_UPDATER_PATH=/usr/lib/fr24/fr24feed_updater.sh
COLLECTD_CPU_AIRSPY_PATH=/run/collectd/localhost/dump1090-localhost/dump1090_cpu-airspy.rrd
SLEEP_PATH=/usr/lib/bash/sleep

# SET flags
NEED_INSTALL=0

# SET variables
COMMANDS="git rrdtool wget unzip collectd"
PACKAGES="git rrdtool wget unzip bash-builtins collectd-core"
PACKAGE_COLLECTD="http://mirrors.kernel.org/ubuntu/pool/universe/c/collectd/collectd-core_5.12.0-11_amd64.deb"

LINE_BREAK="--------------------------------------------------------------------------------"