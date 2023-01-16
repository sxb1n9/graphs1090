#!/bin/bash

# NOTES =======================================================================

# Install / Uninstall / Update statsV2

# INSTALL
# sudo bash -c "$(curl -L -o - https://github.com/bing281/graphs1090/raw/v2/statsV2-install.sh https://github.com/bing281/graphs1090/raw/v2/statsV2-share.sh)"

# INSTALL MANUAL
# sudo apt-get install -y --no-install-suggests --no-install-recommends git
# sudo git clone --depth 1 --single-branch --branch "v2" "https://github.com/sxb1n9/graphs1090" "/usr/share/statsV2/git"
# sudo /usr/share/statsV2/git/statsV2-install.sh install

# UNINSTALL 
# sudo /usr/share/statsV2/statsV2-install.sh uninstall

# UPDATE
# 

# ARGUMENTS ===================================================================

# ARGUMENT $1 : none(defaults install) | install | uninstall | update
# INSTALL   statsV2-install.sh install
# UPDATE    statsV2-install.sh update
# UNINSTALL statsV2-install.sh uninstall

# IMPORTS =====================================================================

source statsV2-shared.sh

# FUNCTIONS ==================================================================

# aptUpdate
# run apt update and wait for finish (update_done=yes)
function aptUpdate()
{
    echo "aptUpdate $pacakge";

    if [[ $update_done != "yes" ]]; then
        apt update && update_done=yes || true
    fi

    return 1
}

# aptInstall $package
# run apt install for package
function aptInstall()
{
    if [[ -z "$1" ]]; then
        echo "aptInstall needs 1 arguments" 1>&2;
        echo "aptInstall PACKAGE" 1>&2;
        return -1; 
    fi

    package="$1";
    echo "aptInstall $pacakge";
    apt-get install -y --no-install-suggests --no-install-recommends $package

	if ! command -v "$CMD" &>/dev/null; then
		NEED_INSTALL=1
	fi

    return 1
}

# getGIT $REPO $BRANCH $TARGET(dir)
# clones REPO BRANCH to TARGET directory and CD's to that directory
# dependancy: git installed
function getGIT()
{ 
    if [[ -z "$1" ]] || [[ -z "$2" ]] || [[ -z "$3" ]]; then
        echo "getGIT needs 3 arguments" 1>&2;
        echo "getGIT REPO BRANCH TARGET(dir)" 1>&2;
        return -1; 
    fi

    REPO="$1";
    BRANCH="$2";
    TARGET="$3";
    echo "getGIT $1 $2 $3";

    git clone --depth 1 --single-branch --branch "$BRANCH" "$REPO" "$TARGET"
    cd $TARGET

    return 1
}

# UNINSTALL ===================================================================

if [[ "$1" == "uninstall" ]]; then
    echo $LINE_BREAK
    echo "START UNINSTALL STATSV2"
    echo $LINE_BREAK

    systemctl stop collectd
    systemctl disable --now statsV2

    # /usr/share/statsV2/ARCHIVE/gunzip.sh /var/lib/collectd/rrd/localhost

    # rm -f /etc/systemd/system/collectd.service.d/malarky.conf
    rm -f $LIGHTTPD_CONF_AVAILABLE/88-statsV2.conf
    rm -f $LIGHTTPD_CONF_ENABLED/88-statsV2.conf
    rm -f /etc/systemd/system/collectd.service
    mv /etc/collectd/collectd.conf.statsV2 /etc/collectd/collectd.conf &>/dev/null

    lighty-disable-mod statsV2 >/dev/null

    systemctl daemon-reload
    systemctl restart collectd
    rm -r $STATSV2_USR

    rm -rd /usr/share/statsV2

    echo "FINISH UNINSTALL STATSV2"
    echo $LINE_BREAK
    echo "EXITING ..."
    exit 1
fi 

# START =======================================================================

echo $LINE_BREAK
echo "START INSTALL STATSV2"
echo $LINE_BREAK

echo "SET error logging"
set -e
trap 'echo "[ERROR] Error in line $LINENO when executing: $BASH_COMMAND"' ERR
renice 10 $$

aptUpdate
aptInstall git
getGit $REPO $BRANCH $STATSV2_USR/git

echo "exiting"
exit 1 

# DEPENDANCIES ================================================================

echo $LINE_BREAK
echo "INSTALL dependancies"
echo $LINE_BREAK

echo "CHECK commands for packages"
hash -r
for CMD in $COMMANDS; do
	if ! command -v "$CMD" &>/dev/null; then
		NEED_INSTALL=1
	fi
done

echo "CHECK sleep"
if ! [[ -f $SLEEP_PATH ]]; then
    NEED_INSTALL=1
fi

echo "INSTALL required packages: $PACKAGES"
if [[ $NEED_INSTALL == "1" ]]; then
	if ! apt-get install -y --no-install-suggests --no-install-recommends $PACKAGES; then
        aptUpdate
        if ! apt-get install -y --no-install-suggests --no-install-recommends $PACKAGES; then
            for PACKAGE in $PACKAGES; do
                apt-get install -y --no-install-suggests --no-install-recommends $PACKAGE || true
            done

            echo "CHECK jellyfish update collectd"
            if grep -qs -e 'Jammy Jellyfish' $OS_PATH; then
                apt purge -y collectd || true
                apt purge -y collectd-core || true
                wget -O /tmp/collectd-core.deb $PACKAGE_COLLECTD || true
                dpkg -i /tmp/collectd-core.deb || true
            fi

            echo "CHECK collectd installed"
            if ! command -v collectd &>/dev/null; then
                echo "ERROR: couldn't install collectd, it's probably a ubuntu issue ... try installing it manually then rerun this install script!"
                echo $LINE_BREAK
                echo "EXITING ..."
                exit 1
            fi
        fi
    fi

    hash -r

    echo "CHECK commands for packages"
    NEED_INSTALL=0
    for CMD in $COMMANDS; do
        if ! command -v "$CMD" &>/dev/null; then
            NEED_INSTALL=1
        fi
    done

    if [[ $NEED_INSTALL == 0 ]]; then
		echo "Packages successfully installed!"
	else
		echo "ERROR : Failed to install required packages: $packages"
        echo "try installing it manually then rerun this install script!"
        echo $LINE_BREAK
        echo "EXITING ..."
        exit 1
	fi
fi

echo "CHECK os release for python install"
if grep -E 'stretch|jessie|buster' $OS_PATH -qs; then
    echo "CHECK & INSTALL python 2.7"
	if ! dpkg -s libpython2.7 2>/dev/null | grep 'Status.*installed' &>/dev/null; then
        aptUpdate
		apt-get install --no-install-suggests --no-install-recommends -y 'libpython2.7' || true
	fi
else
    echo "CHECK & INSTALL python 3.9 and 3.10"
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

echo $LINE_BREAK
echo "CLONE git"
echo $LINE_BREAK

if getGIT "$REPO" "$BRANCH" "$STATSV2_USR/git" && cd "$STATSV2_USR/git"; then
    echo "GIT cloned"
else
	echo "ERROR : unable to download files (Maybe try again?)"
    echo $LINE_BREAK
    echo "EXITING ..."
    exit 1
fi

# INSTALL STATSV2 GENERAL =====================================================

echo $LINE_BREAK
echo "INSTALL statsV2 files"
echo $LINE_BREAK

echo "MAKE directories"
mkdir -p $STATSV2_VAR/scatter

echo "INSTALL statsV2 default config for reset"
cp statsV2-default.db $STATSV2_USR

echo "INSTALL statsV2 documents"
cp LICENSE $STATSV2_USR
cp README.md $STATSV2_USR
cp README.JSON.md $STATSV2_USR

echo "INSTALL statsV2 bash scripts"
cp statsV2-install.sh $STATSV2_USR

cp statsV2-run.sh $STATSV2_USR
cp statsV2-service.sh $STATSV2_USR

cp statsV2-graphs.sh $STATSV2_USR
cp statsV2-graphs-scatter.sh $STATSV2_USR

echo "SET statsV2 permissions bash scripts"
chmod u+x $STATSV2_USR/*.sh

echo "INSTALL statsV2 python scripts"
cp statsV2-dump978.py $STATSV2_USR
cp statsV2-dump1090.py $STATSV2_USR
cp statsV2-system.py $STATSV2_USR

echo "INSTALL statsV2 collectd DB"
cp statsV2-collectd.db $STATSV2_USR

echo "INSTALL statsV2 html"
cp -r html $STATSV2_USR

# SETUP COLLECTD ==============================================================

echo $LINE_BREAK
echo "SETUP collectd conf"
echo $LINE_BREAK

echo "STOP collectd"
systemctl stop collectd &>/dev/null || true

echo "BACKUP /etc/collectd/collectd.conf to /etc/collectd/collectd.conf.statsV2"
cp "$COLLECTD_ETC/collectd.conf" "$COLLECTD_ETC/collectd.conf.statsV2" &>/dev/null || true

echo "CHECK CPU AIRSPY exists in RUN copy and tune"
if [[ -f "$COLLECTD_CPU_AIRSPY_PATH" ]]; then
    cp "$COLLECTD_CPU_AIRSPY_PATH" "$COLLECTD_RUN/dump1090_cpu-airspy.rrd"
    rrdtool tune --maximum value:U "$COLLECTD_RUN/dump1090_cpu-airspy.rrd"
    cp -f "$COLLECTD_RUN/dump1090_cpu-airspy.rrd" "$CPU_AIR"
fi

echo "CHECK CPU AIRSPY exists in RRD copy and tune"
if [[ -f "$COLLECTD_RRD/localhost/dump1090-localhost/dump1090_cpu-airspy.rrd" ]]; then
    rrdtool tune --maximum value:U "$COLLECTD_RRD/localhost/dump1090-localhost/dump1090_cpu-airspy.rrd"
fi

echo "INSTALL collectd.conf"
if grep -e 'system_stats' -qs /etc/collectd/collectd.conf &>/dev/null; then
	echo "graphs1090 already installed"

    if grep -e 'statsV2-system' -qs /etc/collectd/collectd.conf &>/dev/null; then
        echo "statsV2 already installed - no update"
        echo $LINE_BREAK
    else
        echo "statsV2 NOT installed - using collectd conf which includes graphs1090 so they can run in parrallel"
        echo $LINE_BREAK
        cp statsV2-collectd-graphs1090.conf /etc/collectd/collectd.conf
    fi
else
    echo "graphs1090 NOT installed - using collectd conf for only statsV2"

    if grep -e 'statsV2-system' -qs /etc/collectd/collectd.conf &>/dev/null; then
        echo "statsV2 already installed - no update"
        echo $LINE_BREAK
    else
        echo "statsV2 NOT installed - using collectd conf for only statsV2"
        echo $LINE_BREAK
        cp statsV2-collectd.conf /etc/collectd/collectd.conf
    fi
fi

echo "CHECK & SET unlisted interfaces on collectd.conf"
for path in /sys/class/net/*
do
    iface=$(basename $path)
    # no action on existing interfaces
    fgrep -q 'Interface "'$iface'"' /etc/collectd/collectd.conf && continue
    # only add interface starting with et en and wl
    case $iface in
        et*|en*|wl*)
sed -ie '/<Plugin "interface">/{a\
    Interface "'$iface'"
}' /etc/collectd/collectd.conf
        ;;
    esac
done

# SETUP SYMLINKS COLLECTD =====================================================

echo $LINE_BREAK
echo "SETUP SYMLINKS collectd"
echo $LINE_BREAK

echo "SETUP SYMLINK 1090"
mkdir -p $SYM1090

if [ -f /run/dump1090-fa/stats.json ]; then
    echo "select dump1090-fa"
    ln -snf /run/dump1090-fa $SYM1090/data
    sed -i -e 's?URL_DUMP1090 .*?URL_DUMP1090 "file:///usr/share/statsV2/data-symlink"?' /etc/collectd/collectd.conf
elif [ -f /run/readsb/stats.json ]; then
    echo "select readsb"
    ln -snf /run/readsb $SYM1090/data
    sed -i -e 's?URL_DUMP1090 .*?URL_DUMP1090 "file:///usr/share/statsV2/data-symlink"?' /etc/collectd/collectd.conf
elif [ -f /run/adsbexchange-feed/stats.json ]; then
    echo "select adsbexchange"
    ln -snf /run/adsbexchange-feed $SYM1090/data
    sed -i -e 's?URL_DUMP1090 .*?URL_DUMP1090 "file:///usr/share/statsV2/data-symlink"?' /etc/collectd/collectd.conf
elif [ -f /run/dump1090/stats.json ]; then
    echo "select dump1090"
    ln -snf /run/dump1090 $SYM1090/data
    sed -i -e 's?URL_DUMP1090 .*?URL_DUMP1090 "file:///usr/share/statsV2/data-symlink"?' /etc/collectd/collectd.conf
elif [ -f /run/dump1090-mutability/stats.json ]; then
    echo "select dump1090-mutability"
    ln -snf /run/dump1090-mutability $SYM1090/data
    sed -i -e 's?URL_DUMP1090 .*?URL_DUMP1090 "file:///usr/share/statsV2/data-symlink"?' /etc/collectd/collectd.conf
else
	echo "Can't find any 1090 instances, please check you already have a version of dump1090 installed"
fi

echo $LINE_BREAK
echo "SETUP SYMLINK 978"
mkdir -p $SYM978

if [ -f /run/skyaware978/aircraft.json ]; then
    echo "select skyaware978"
    ln -snf /run/skyaware978 $SYM978/data
    sed -i -e 's?URL_DUMP978 .*?URL_DUMP978 "file:///usr/share/statsV2/978-symlink"?' /etc/collectd/collectd.conf
elif [ -f /run/adsbexchange-978/aircraft.json ]; then
    echo "select adsbexchange-978"
    ln -snf /run/adsbexchange-978 $SYM978/data
    sed -i -e 's?URL_DUMP978 .*?URL_DUMP978 "file:///usr/share/statsV2/978-symlink"?' /etc/collectd/collectd.conf
else
	echo "Can't find any 978 instances, please check you already have a version of dump978 installed"
fi

# SETUP STATSV2 ===============================================================

echo $LINE_BREAK
echo "SETUP STATSV2"
echo $LINE_BREAK

echo "CHECK os release jessi"
if grep jessie $OS_PATH >/dev/null
then
	echo "Some features are not available on jessie! modifying statsV2-graphs.sh"
	sed -i -e 's/ADDNAN/+/' -e 's/TRENDNAN/TREND/' -e 's/MAXNAN/MAX/' -e 's/MINNAN/MIN/' $STATSV2_USR/statsV2-graphs.sh
	sed -i -e '/axis-format/d' $STATSV2_USR/statsV2-graphs.sh
fi

echo "FIX readonly remount logic in fr24feed update script"
sed -i -e 's?$(mount | grep " on / " | grep rw)?{ mount | grep " on / " | grep rw; }?' $FR24FEED_UPDATER_PATH &>/dev/null || true

echo "INSTALL statsV2 default conf"
cp -n statsV2.default $STATSV2_ETC
cp statsV2.default $STATSV2_USR/default-statsV2.conf

echo "INSTALL service default conf"
cp statsV2.service $SERVICE_CONF/statsV2.service

echo $LINE_BREAK

# SETUP LIGHTTPD ==============================================================

echo $LINE_BREAK
echo "SETUP lighttpd"
echo $LINE_BREAK

echo "INSTALL lighttpd make conf-enabled make conf-available"
if [ -d $LIGHTTPD_CONF/conf.d/ ] && ! [ -d $LIGHTTPD_CONF_ENABLED ] && ! [ -d $LIGHTTPD_CONF_AVAILABLE] && command -v lighttpd &>/dev/null; then
    ln -snf /etc/lighttpd/conf.d $LIGHTTPD_CONF_ENABLED
    mkdir -p $LIGHTTPD_CONF_AVAILABLE
fi

echo "INSTALL lighttpd conf-available configs"
if [ -d $LIGHTTPD_CONF_ENABLED ] && [ -d $LIGHTTPD_CONF_AVAILABLE ] && command -v lighttpd &>/dev/null; then
    cp statsV2-lighttpd.conf $LIGHTTPD_CONF_AVAILABLE/88-statsV2.conf
    ln -snf $STATSV2_USR/88-statsV2.conf $LIGHTTPD_CONF_ENABLED/88-statsV2.conf
fi

# START =======================================================================

echo $LINE_BREAK
echo "START ALL"
echo $LINE_BREAK

echo "RESTART lighttpd"
systemctl enable lighttpd &>/dev/null
systemctl restart lighttpd

echo "START collectd"
systemctl enable collectd &>/dev/null
systemctl start collectd &>/dev/null || true

echo "CHECK collectd"
if ! systemctl status collectd &>/dev/null; then
    echo "ERROR : collectd isn't working, trying to install various libpython versions to work around the issue."
    aptUpdate
    apt-get install --no-install-suggests --no-install-recommends -y 'libpython2.7' || true
    apt-get install --no-install-suggests --no-install-recommends -y 'libpython3.10' || \
    apt-get install --no-install-suggests --no-install-recommends -y 'libpython3.9' || \
    apt-get install --no-install-suggests --no-install-recommends -y 'libpython3.8' || \
    apt-get install --no-install-suggests --no-install-recommends -y 'libpython3.7' || true

    echo "RESTART collectd"
    systemctl restart collectd || true

    if ! systemctl status collectd &>/dev/null; then
        echo "INFO : Showing the log for collectd using this command: journalctl --no-pager -u collectd | tail -n40"
        echo $LINE_BREAK
        journalctl --no-pager -u collectd | tail -n40
        echo $LINE_BREAK
        echo "ERROR : collectd still isn't working, you can try and rerun the install script at some other time."
        echo "or report this issue with the full 40 lines above."
    fi
fi

echo "START statsV2"
systemctl enable statsV2
systemctl restart statsV2

echo $LINE_BREAK
echo $LINE_BREAK
echo "FINISHED INSTALL statsV2"
echo "Graphs available at http://$(ip route | grep -m1 -o -P 'src \K[0-9,.]*')/statsV2"
echo "It may take up to 10 minutes until the first data is displayed"
echo $LINE_BREAK
echo $LINE_BREAK
echo "EXITING ..."
exit 1
