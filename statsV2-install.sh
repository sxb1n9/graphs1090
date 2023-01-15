#!/bin/bash

# ARGUMENTS ===================================================================

# ARGUMENT $1 = test 

# INITIAL SETUP ===============================================================

echo $LINE_1
echo "Starting Install statsV2"
echo $LINE_1

# SET error logging
set -e
trap 'echo "[ERROR] Error in line $LINENO when executing: $BASH_COMMAND"' ERR
renice 10 $$

# PATHS & VARIABLES ===========================================================

# SET paths
REPO="https://github.com/bing281/graphs1090"
BRANCH="master"

# main ipath
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

CRON_CONF=/etc/cron.d
SERVICE_CONF=/lib/systemd/system

OS_PATH=/etc/os-release

SYM978=/usr/share/statsV2/978-symlink
SYM1090=/usr/share/statsV2/data-symlink

FR24FEED_PATH=/usr/lib/fr24/fr24feed_updater.sh

CPU_AIR=/run/collectd/localhost/dump1090-localhost/dump1090_cpu-airspy.rrd

SLEEP_PATH=/usr/lib/bash/sleep

# SET flags
NEED_INSTALL=0
SUCCESS=0
LIGHTTPD=0

# SET variables
COMMANDS="git rrdtool wget unzip collectd"
PACKAGES="git rrdtool wget unzip bash-builtins collectd-core"
PACKAGE_COLLECTD="http://mirrors.kernel.org/ubuntu/pool/universe/c/collectd/collectd-core_5.12.0-11_amd64.deb"

LINE_1="--------------------------------------------------------------------------------"

# FUNCTIONS ==================================================================

# aptUpdate - run apt update and wait for finish (update_done=yes)
function aptUpdate()
{
    if [[ $update_done != "yes" ]]; then
        apt update && update_done=yes || true
    fi
}

# getGIT $REPO $BRANCH $TARGET (directory)
function getGIT()
{ 
    if [[ -z "$1" ]] || [[ -z "$2" ]] || [[ -z "$3" ]]; then
        echo "getGIT wrong usage, check your script or tell the author!" 1>&2; 
        return 1; 
    fi

    REPO="$1";
    BRANCH="$2";
    TARGET="$3";
    pushd .;
    tmp=/tmp/getGIT-tmp.$RANDOM.$RANDOM

    if cd "$TARGET" &>/dev/null && git fetch --depth 1 origin "$BRANCH" && git reset --hard FETCH_HEAD; then 
        popd && return 0; 
    fi
    popd;
    if ! cd /tmp || ! rm -rf "$TARGET"; then
        return 1;
    fi
    if git clone --depth 1 --single-branch --branch "$2" "$1" "$3"; then
        return 0;
    fi
    if wget -O "$tmp" "${REPO%".git"}/archive/$BRANCH.zip" && unzip "$tmp" -d "$tmp.folder"; then
        if mv -fT "$tmp.folder/$(ls $tmp.folder)" "$TARGET"; then 
            rm -rf "$tmp" "$tmp.folder";
            return 0;
        fi
    fi

    rm -rf "$tmp" "$tmp.folder";
    return 1
}

# UNINSTALL ===================================================================

if [[ "$1" == "uninstall" ]]; then
    echo "Uninstalling statsV2"
    echo $LINE_1

    systemctl stop collectd
    systemctl disable --now statsV2

    /usr/share/statsV2/ARCHIVE/gunzip.sh /var/lib/collectd/rrd/localhost

    # rm -f /etc/systemd/system/collectd.service.d/malarky.conf
    rm -f /etc/systemd/system/collectd.service
    mv /etc/collectd/collectd.conf.statsV2 /etc/collectd/collectd.conf &>/dev/null

    lighty-disable-mod statsV2 >/dev/null

    systemctl daemon-reload
    systemctl restart collectd
    rm -r $STATSV2_USR

    echo "Uninstall finished"
    echo "Exiting ..."
    echo $LINE_1
    exit 1
fi 

# DEPENDANCIES ================================================================

echo "Install dependancies"
echo $LINE_1

# MAKE directories
mkdir -p $STATSV2_USR/installed
mkdir -p $STATSV2_VAR/scatter

# CHECK commands for installed
hash -r
for CMD in $COMMANDS; do
	if ! command -v "$CMD" &>/dev/null; then
		NEED_INSTALL=1
	fi
done

# CHECK sleep path
if ! [[ -f $SLEEP_PATH ]]; then
    NEED_INSTALL=1
fi

# INSTALL
if [[ $NEED_INSTALL == "1" ]]
then
	echo "Installing required packages: $PACKAGES"
	echo $LINE_1

	if ! apt-get install -y --no-install-suggests --no-install-recommends $PACKAGES; then
        aptUpdate
        if ! apt-get install -y --no-install-suggests --no-install-recommends $PACKAGES; then
            for PACKAGE in $PACKAGES; do
                apt-get install -y --no-install-suggests --no-install-recommends $PACKAGE || true
            done

            # CHECK jellyfish update collectd
            if grep -qs -e 'Jammy Jellyfish' /etc/os-release; then
                apt purge -y collectd || true
                apt purge -y collectd-core || true
                wget -O /tmp/collectd-core.deb $PACKAGE_COLLECTD || true
                dpkg -i /tmp/collectd-core.deb || true
            fi

            # CHECK collectd installed
            if ! command -v collectd &>/dev/null; then
                echo "ERROR: couldn't install collectd, it's probably a ubuntu issue ... try installing it manually then rerun this install script!"
                echo "Exiting ..."
                echo $LINE_1
                exit 1
            fi
        fi
    fi

    hash -r

    # CHECK commands for installed
    NEED_INSTALL=0
    for CMD in $COMMANDS; do
        if ! command -v "$CMD" &>/dev/null; then
            NEED_INSTALL=1
        fi
    done

    if [[ $NEED_INSTALL == 0 ]]; then
		echo "Packages successfully installed!"
		echo $LINE_1
	else
		echo "Failed to install required packages: $packages"
        echo "try installing it manually then rerun this install script!"
		echo "Exiting ..."
        echo $LINE_1
		exit 1
	fi
fi

# CHECK os release
if grep -E 'stretch|jessie|buster' $OS_PATH -qs; then
    # CHECK & INSTALL python 2.7
	if ! dpkg -s libpython2.7 2>/dev/null | grep 'Status.*installed' &>/dev/null; then
        aptUpdate
		apt-get install --no-install-suggests --no-install-recommends -y 'libpython2.7' || true
	fi
else
    # CHECK & INSTALL python 3.9 and 3.10
    if ! dpkg -s libpython3.9 2>/dev/null | grep 'Status.*installed' &>/dev/null \
        && ! dpkg -s libpython3.10 2>/dev/null | grep 'Status.*installed' &>/dev/null
	then
        aptUpdate
		apt-get install --no-install-suggests --no-install-recommends -y 'libpython3.9' \
		|| apt-get install --no-install-suggests --no-install-recommends -y 'libpython3.10'
	fi
fi

hash -r

# GIT CLONE ===================================================================

echo "Install git clone"
echo $LINE_1

if [[ "$1" == "test" ]]; then
	true
elif getGIT "$REPO" "$BRANCH" "$STATSV2_USR/git" && cd "$STATSV2_USR/git"; then
    true
elif wget --timeout=30 -q -O /tmp/$BRANCH.zip $repo/archive/$BRANCH.zip && unzip -q -o $BRANCH.zip; then
	cd "/tmp/statsV2-$BRANCH"
else
	echo "Unable to download files, exiting! (Maybe try again?)"
    echo "Exiting ..."
    echo $LINE_1
	exit 1
fi

# COLLECTD AIRSPY =============================================================

echo "Install AIRSPY if available"
echo $LINE_1

if [[ -f "$CPU_AIR" ]]; then
    cp "$CPU_AIR" "$COLLECTD_RUN/dump1090_cpu-airspy.rrd"
    rrdtool tune --maximum value:U "$COLLECTD_RUN/dump1090_cpu-airspy.rrd"
    cp -f "$COLLECTD_RUN/dump1090_cpu-airspy.rrd" "$CPU_AIR"
fi

systemctl stop collectd &>/dev/null || true

if [[ -f "$COLLECTD_RRD/localhost/dump1090-localhost/dump1090_cpu-airspy.rrd" ]]; then
    rrdtool tune --maximum value:U "$COLLECTD_RRD/localhost/dump1090-localhost/dump1090_cpu-airspy.rrd"
fi

# INSTALL STATSV2 GENERAL =====================================================

echo "Install of statsV2 files"
echo $LINE_1

cp LICENSE $STATSV2_USR
cp README.md $STATSV2_USR

cp statsV2-install.sh $STATSV2_USR
cp statsV2-uninstall.sh $STATSV2_USR

cp statsV2-run.sh $STATSV2_USR
cp statsV2-service.sh $STATSV2_USR

cp statsV2-graphs.sh $STATSV2_USR
cp statsV2-graphs-scatter.sh $STATSV2_USR

chmod u+x $STATSV2_USR/*.sh

cp statsV2-dump1090.db $STATSV2_USR

cp statsV2-dump978.py $STATSV2_USR
cp statsV2-dump1090.py $STATSV2_USR
cp statsV2-system.py $STATSV2_USR

echo "exit this far nothing has happened"
echo $LINE_1
exit 1

# SETUP COLLECTD ==============================================================

echo "Setup collectd conf"
echo $LINE_1

echo "BACKUP /etc/collectd/collectd.conf to /etc/collectd/collectd.conf.statsV2"
echo $LINE_1
cp /etc/collectd/collectd.conf /etc/collectd/collectd.conf.statsV2 &>/dev/null || true

# INSTALL collectd.conf
if grep -e 'system-stats' -qs /etc/collectd/collectd.conf &>/dev/null; then
	echo "graphs1090 already installed"

    if grep -e 'statsV2-system' -qs /etc/collectd/collectd.conf &>/dev/null; then
        echo "statsV2 already installed - no update"
        echo $LINE_1
    else
        echo "statsV2 NOT installed - using collectd conf which includes graphs1090 so they can run in parrallel"
        echo $LINE_1
        cp statsV2-collectd-graphs1090.conf /etc/collectd/collectd.conf
    fi
else
    echo "graphs1090 NOT installed - using collectd conf for only statsV2"

    if grep -e 'statsV2-system' -qs /etc/collectd/collectd.conf &>/dev/null; then
        echo "statsV2 already installed - no update"
        echo $LINE_1
    else
        echo "statsV2 NOT installed - using collectd conf for only statsV2"
        echo $LINE_1
        cp statsV2-collectd.conf /etc/collectd/collectd.conf
    fi
fi

# CHECK & SET unlisted interfaces
for path in /sys/class/net/*
do
    iface=$(basename $path)
    # no action on existing interfaces
    fgrep -q 'Interface "'$iface'"' /etc/collectd/collectd.conf && continue
    # only add interface starting with et en and wl
    case $iface in et*|en*|wl*)
        sed -ie '/<Plugin "interface">/{a\Interface "'$iface'"}' /etc/collectd/collectd.conf;
    esac
done

# SETUP CONFIG ================================================================

echo "Setup conf"
echo $LINE_1

# INSTALL html
cp -r html $STATSV2_USR

# INSTALL statsV2 default conf
cp -n statsV2.default $STATSV2_ETC
cp statsV2.default $STATSV2_USR/default-statsV2.conf

# INSTALL collectd default conf
cp statsV2-collectd.conf $STATSV2_USR/default-collectd.conf

# INSTALL service conf
cp statsV2.service $SERVICE_CONF/statsV2.service

# SETUP LIGHTTPD ==============================================================

echo "Setup lighttpd"
echo $LINE_1

# INSTALL lighttpd conf to conf-enabled make conf-available
if [ -d /etc/lighttpd/conf.d/ ] && ! [ -d /etc/lighttpd/conf-enabled/ ] && ! [ -d /etc/lighttpd/conf-available ] && command -v lighttpd &>/dev/null; then
    ln -snf /etc/lighttpd/conf.d $LIGHTTPD_CONF_ENABLED
    mkdir -p $LIGHTTPD_CONF_AVAILABLE
fi

# INSTALL lighttpd conf-available configs
if [ -d /etc/lighttpd/conf-enabled/ ] && [ -d /etc/lighttpd/conf-available ] && command -v lighttpd &>/dev/null; then
    lighttpd=1
    cp statsV2-lighttpd.conf $LIGHTTPD_CONF_AVAILABLE/88-statsV2.conf
    ln -snf LIGHTTPD_CONF_AVAILABLE/88-statsV2.conf $LIGHTTPD_CONF_ENABLED/88-statsV2.conf
fi

# SETUP SYMLINKS COLLECTD =====================================================

echo "Setup SYMLINKS 1090"
echo $LINE_1

SYM=/usr/share/statsV2/data-symlink
mkdir -p $SYM
if [ -f /run/dump1090-fa/stats.json ]; then
    ln -snf /run/dump1090-fa $SYM/data
    sed -i -e 's?URL_DUMP1090 .*?URL_DUMP1090 "file:///usr/share/statsV2/data-symlink"?' /etc/collectd/collectd.conf
elif [ -f /run/readsb/stats.json ]; then
    ln -snf /run/readsb $SYM/data
    sed -i -e 's?URL_DUMP1090 .*?URL_DUMP1090 "file:///usr/share/statsV2/data-symlink"?' /etc/collectd/collectd.conf
elif [ -f /run/adsbexchange-feed/stats.json ]; then
    ln -snf /run/adsbexchange-feed $SYM/data
    sed -i -e 's?URL_DUMP1090 .*?URL_DUMP1090 "file:///usr/share/statsV2/data-symlink"?' /etc/collectd/collectd.conf
elif [ -f /run/dump1090/stats.json ]; then
    ln -snf /run/dump1090 $SYM/data
    sed -i -e 's?URL_DUMP1090 .*?URL_DUMP1090 "file:///usr/share/statsV2/data-symlink"?' /etc/collectd/collectd.conf
elif [ -f /run/dump1090-mutability/stats.json ]; then
    ln -snf /run/dump1090-mutability $SYM/data
    sed -i -e 's?URL_DUMP1090 .*?URL_DUMP1090 "file:///usr/share/statsV2/data-symlink"?' /etc/collectd/collectd.conf
elif [ -f /run/readsb/stats.json ]; then
    ln -snf /run/readsb $SYM/data
    sed -i -e 's?URL_DUMP1090 .*?URL_DUMP1090 "file:///usr/share/statsV2/data-symlink"?' /etc/collectd/collectd.conf
else
	echo "Can't find any 1090 instances, please check you already have dump1090 installed"
    echo $LINE_1
fi

echo "Setup SYMLINKS 978"
echo $LINE_1

# INSTALL symlinks 978 to collectd.conf
SYM=/usr/share/statsV2/978-symlink
mkdir -p $SYM
if [ -f /run/skyaware978/aircraft.json ]; then
    ln -snf /run/skyaware978 $SYM/data
    sed -i -e 's?URL_DUMP978 .*?URL_DUMP978 "file:///usr/share/statsV2/978-symlink"?' /etc/collectd/collectd.conf
elif [ -f /run/adsbexchange-978/aircraft.json ]; then
    ln -snf /run/adsbexchange-978 $SYM/data
    sed -i -e 's?URL_DUMP978 .*?URL_DUMP978 "file:///usr/share/statsV2/978-symlink"?' /etc/collectd/collectd.conf
else
	echo "Can't find any 978 instances, please check you already have dump978 installed"
    echo $LINE_1
fi

# SETUP STATSV2 ===============================================================

echo "Setup statsV2"
echo $LINE_1

# CHECK os release jessi
if grep jessie /etc/os-release >/dev/null
then
	echo "Some features are not available on jessie! modifying statsV2-graphs.sh"
	echo $LINE_1
	sed -i -e 's/ADDNAN/+/' -e 's/TRENDNAN/TREND/' -e 's/MAXNAN/MAX/' -e 's/MINNAN/MIN/' $STATSV2_USR/statsV2-graphs.sh
	sed -i -e '/axis-format/d' $STATSV2_USR/statsV2-graphs.sh
fi

echo "Fix fr24feed_updater"
echo $LINE_1

# FIX readonly remount logic in fr24feed update script
sed -i -e 's?$(mount | grep " on / " | grep rw)?{ mount | grep " on / " | grep rw; }?' /usr/lib/fr24/fr24feed_updater.sh &>/dev/null || true

# START =======================================================================

echo "Start lighttpd"
echo $LINE_1

# RESTART lighttpd
if [[ $lighttpd == yes ]]; then
    systemctl restart lighttpd
fi

echo "Start collectd"
echo $LINE_1

# START collectd
systemctl enable collectd &>/dev/null
systemctl restart collectd &>/dev/null || true

echo "Check collectd"
echo $LINE_1

# CHECK collectd
if ! systemctl status collectd &>/dev/null; then
    echo "collectd isn't working, trying to install various libpython versions to work around the issue."
    echo $LINE_1
    aptUpdate
    apt-get install --no-install-suggests --no-install-recommends -y 'libpython2.7' || true
    apt-get install --no-install-suggests --no-install-recommends -y 'libpython3.10' || \
    apt-get install --no-install-suggests --no-install-recommends -y 'libpython3.9' || \
    apt-get install --no-install-suggests --no-install-recommends -y 'libpython3.8' || \
    apt-get install --no-install-suggests --no-install-recommends -y 'libpython3.7' || true

    systemctl restart collectd || true
    if ! systemctl status collectd &>/dev/null; then
        echo "Showing the log for collectd using this command: journalctl --no-pager -u collectd | tail -n40"
        echo $LINE_1
        journalctl --no-pager -u collectd | tail -n40
        echo $LINE_1
        echo "collectd still isn't working, you can try and rerun the install script at some other time."
        echo "or report this issue with the full 40 lines above."
        echo $LINE_1
    fi
fi

echo "Start statsV2"
echo $LINE_1

# START statsV2
systemctl enable statsV2
systemctl restart statsV2

echo $LINE_1
echo $LINE_1
echo "All done! Graphs available at http://$(ip route | grep -m1 -o -P 'src \K[0-9,.]*')/statsV2"
echo "It may take up to 10 minutes until the first data is displayed"
echo $LINE_1
echo $LINE_1
