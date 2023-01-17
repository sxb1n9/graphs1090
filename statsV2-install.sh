#!/bin/bash

# NOTES =======================================================================

# INSTALL / UNINSTALL / UPDATE STATSV2

# INSTALL
# sudo apt-get install -y --no-install-suggests --no-install-recommends git
# sudo git clone --depth 1 --single-branch --branch "v2" "https://github.com/sxb1n9/graphs1090" "/usr/share/statsV2/git"
# sudo /usr/share/statsV2/git/statsV2-install.sh install

# UPDATE (NOT CURRENTLY COMPLETE run install)
# sudo /usr/share/statsV2/statsV2-install.sh update

# UNINSTALL 
# sudo /usr/share/statsV2/statsV2-install.sh uninstall

# ARGUMENTS ===================================================================

# ARGUMENT $1 : none(defaults install) | install | uninstall | update
# INSTALL   statsV2-install.sh install
# UPDATE    statsV2-install.sh update
# UNINSTALL statsV2-install.sh uninstall

# ARGUMENT $2 : blank | noupdate
# noupdate  don't run apt update

# IMPORTS =====================================================================

source statsV2-shared.sh

# MAIN $1 =====================================================================
# $1 : install | update | uninstall
# =============================================================================
function MAIN()
{ 
    if [[ -z "$1" ]]; then
        echo "statsV2-install.sh needs 1 argument"
        echo "example: statsV2-install.sh install"
        echo "example: statsV2-install.sh update"
        echo "example: statsV2-install.sh uninstall"
        echo "EXITING ..."
        exit 1
    fi

    echo $LINE_HASH
    echo "START STATSV2-INSTALL.sh $1"
    echo $LINE_HASH

    echo "SET error logging"
    set -e
    trap 'echo "[ERROR] Error in line $LINENO when executing: $BASH_COMMAND"' ERR
    renice 10 $$

    if [[ -z "$1" ]]; then

        echo "statsV2-install.sh needs 1 argument"
        echo "example: statsV2-install.sh install"
        echo "example: statsV2-install.sh update"
        echo "example: statsV2-install.sh uninstall"

    elif [[ $1 == "install" ]]; then

        echo $LINE_DOUBLE
        echo "START INSTALL"
        echo $LINE_DOUBLE

        INSTALL_DEPENDANCIES

        INSTALL_STATSV2

        INSTALL_SYMLINKS

        SETUP_STATSV2

        SETUP_LIGHTTPD

        # SETUP_COLLECTD

        CONTROL_SERVICE restart lighttpd enabled
        # CONTROL_SERVICE restart collectd enabled
        # CONTROL_SERVICE restart statsV2 enabled
        
        echo $LINE_DOUBLE
        echo "FINISH INSTALL"
        echo "Graphs available at http://$(ip route | grep -m1 -o -P 'src \K[0-9,.]*')/statsV2"
        echo "It may take up to 10 minutes until the first data is displayed"
        echo $LINE_DOUBLE

    elif [[ $1 == "update" ]]; then

        echo $LINE_DOUBLE
        echo "START UPDATE"
        echo $LINE_DOUBLE

        GIT_PULL $TARGET

        INSTALL_STATSV2

        echo $LINE_DASH
        echo "GIT DIRECTORY UPDATED"
        echo "RUN sudo /usr/share/statsV2/git/statsv2-install.sh install COMMAND to INSTALL/UPDATE"
        
        echo $LINE_DOUBLE
        echo "FINISH UPDATE"
        echo $LINE_DOUBLE

    elif [[ $1 == "uninstall" ]]; then

        echo $LINE_DOUBLE
        echo "START UNINSTALL"
        echo $LINE_DOUBLE

        UNINSTALL

        echo $LINE_DOUBLE
        echo "FINISH UNINSTALL"
        echo $LINE_DOUBLE

    else

        echo "ERROR: Unknown Argument: $1"

    fi

    echo "EXITING ..."
    exit 1
}

# UNINSTALL ===================================================================
#
# =============================================================================
function UNINSTALL()
{ 
    cd $TARGET

    echo "STOP STATSV2"
    systemctl stop statsV2

    echo "DISABLE STATSV2"
    systemctl disable --now statsV2

    echo "STOP COLLECTD"
    systemctl stop collectd

    echo "BACKUP COLLECTD (DISBLED)"
    # /usr/share/statsV2/ARCHIVE/gunzip.sh /var/lib/collectd/rrd/localhost

    echo "STOP LIGHTTPD"
    systemctl stop lighttpd

    echo "REMOVE LIGHTTPD CONF"
    rm -f $LIGHTTPD_CONF_AVAILABLE/88-statsV2.conf
    rm -f $LIGHTTPD_CONF_ENABLED/88-statsV2.conf

    echo "REMOVE COLLECTD.SERVICE"
    rm -f /etc/systemd/system/collectd.service
    # rm -f /etc/systemd/system/collectd.service.d/malarky.conf
    echo "RESTORE COLLECTD.CONF BACKUP"
    mv /etc/collectd/collectd.conf.statsV2 /etc/collectd/collectd.conf &>/dev/null

    echo "DISABLE LIGHTY STATSV2"
    lighty-disable-mod statsV2 >/dev/null
    systemctl daemon-reload

    echo "RESTART COLLECTD"
    systemctl restart collectd

    echo "REMOVE STATSV2 FOLDER"
    rm -rd $STATSV2_USR
}

# INSTALL_DEPENDANCIES --------------------------------------------------------
# checks and installs dependancies
# dependancy: $PACKAGES $COMMANDS
# -----------------------------------------------------------------------------
function INSTALL_DEPENDANCIES()
{ 
    echo $LINE_BREAK
    echo "INSTALL_DEPENDANCIES"
    echo $LINE_BREAK

    hash -r
    APT_UPDATE

    echo $LINE_DASH
    echo "CHECK PACKAGES $PACKAGES"
    MISSING=$(dpkg --get-selections $PACKAGESs 2>&1 | grep -v 'install$' | awk '{ print $6 }')

    for PKG in $MISSING; do
        echo "$PKG not installed"
        APT_INSTALL $PKG
    done

    echo $LINE_DASH
    echo "CHECK OS RELEASE Jammy Jellyfish UPDATE collectd to collectd-core 5.12"
    if grep -qs -e 'Jammy Jellyfish' $OS_PATH; then
        echo "Jammy Jellyfish UPDATE to 5.12"
        apt purge -y collectd || true
        apt purge -y collectd-core || true
        wget -O /tmp/collectd-core.deb $PACKAGE_COLLECTD || true
        dpkg -i /tmp/collectd-core.deb || true

        echo $LINE_DASH
        echo "CHECK INSTALL collectd"
        if ! command -v collectd &>/dev/null; then
            echo "ERROR: couldn't install collectd.core, it's probably a ubuntu issue..."
            echo "try installing it manually then rerun this install script!"
            echo $LINE_BREAK
            echo "EXITING ..."
            exit 1
        else
            echo "collectd installed"
        fi
    else
        echo "NOT Jammy Jellyfish no action"
    fi

    echo $LINE_DASH
    echo "CHECK OS RELEASE stretch,jessis,buster for PYTHON INSTALL"
    if grep -qs -E 'stretch|jessie|buster' $OS_PATH; then
        echo "OS is stretch, jessie, buster"
        echo $LINE_DASH
        echo "CHECK & INSTALL python 2.7"
        if ! dpkg -s libpython2.7 2>/dev/null | grep 'Status.*installed' &>/dev/null; then
            echo "PYTHON 2.7 is not installed, trying to install"
            apt-get install --no-install-suggests --no-install-recommends -y 'libpython2.7' || true
        else 
            echo "PYTHON 2.7 installed no action"
        fi
    else
        echo "OS is not stretch, jessie, buster"
        echo $LINE_DASH
        echo "CHECK & INSTALL PYTHON 3.9 and PYTHON 3.10"
        if ! dpkg -s libpython3.9 2>/dev/null | grep 'Status.*installed' &>/dev/null \
        && ! dpkg -s libpython3.10 2>/dev/null | grep 'Status.*installed' &>/dev/null; then
            echo "PYTHON 3.9 or 3.10 is not installed, trying to install"
            apt-get install --no-install-suggests --no-install-recommends -y 'libpython3.9' \
            || apt-get install --no-install-suggests --no-install-recommends -y 'libpython3.10'
        else
            echo "PYTHON 3.9 or 3.10 installed no action"
        fi
    fi

    hash -r
}

# INSTALL_STATSV2 -------------------------------------------------------------
# Moves the files from the git directory to the run directory
# -----------------------------------------------------------------------------
function INSTALL_STATSV2()
{ 
    echo $LINE_BREAK
    echo "INSTALL_STATSV2"
    echo $LINE_BREAK

    cd $TARGET

    echo "INSTALL STATSV2 directories"
    mkdir -p $STATSV2_VAR/scatter

    echo "INSTALL STATSV2 default config for reset"
    cp statsV2.default $STATSV2_USR

    echo "INSTALL STATSV2 documents"
    cp LICENSE $STATSV2_USR
    cp README.md $STATSV2_USR
    cp README.JSON.md $STATSV2_USR
    cp README.CONFIG.md $STATSV2_USR

    echo "INSTALL STATSV2 bash scripts"
    cp statsV2-shared.sh $STATSV2_USR
    cp statsV2-install.sh $STATSV2_USR

    cp statsV2-run.sh $STATSV2_USR
    cp statsV2-service.sh $STATSV2_USR

    cp statsV2-graphs.sh $STATSV2_USR
    cp statsV2-graphs-scatter.sh $STATSV2_USR

    echo "INSTALL STATSV2 python scripts"
    cp statsV2-dump978.py $STATSV2_USR
    cp statsV2-dump1090.py $STATSV2_USR
    cp statsV2-system.py $STATSV2_USR

    echo "INSTALL STATSV2 collectd DB"
    cp statsV2-collectd.db $STATSV2_USR

    echo "INSTALL STATSV2 html"
    cp -r html $STATSV2_USR

    echo "SET STATSV2 permissions on files"
    chmod u+x $STATSV2_USR/*.sh
    chmod u+x $STATSV2_USR/*.py
    chmod u+x $STATSV2_USR/*.db
    chmod u+x $STATSV2_USR/*.md
    
}

# SETUP_STATSV2 ---------------------------------------------------------------
# move configs and changes based on OS
# -----------------------------------------------------------------------------
function SETUP_STATSV2()
{ 
    echo $LINE_BREAK
    echo "SETUP_STATSV2"
    echo $LINE_BREAK

    cd $TARGET

    echo "CHECK OS RELEASE jessi"
    if grep jessie $OS_PATH >/dev/null; then
        echo "FOUND jessi"
        echo "Some features are not available on jessie! modifying statsV2-graphs.sh"
        sed -i -e 's/ADDNAN/+/' -e 's/TRENDNAN/TREND/' -e 's/MAXNAN/MAX/' -e 's/MINNAN/MIN/' $STATSV2_USR/statsV2-graphs.sh
        sed -i -e '/axis-format/d' $STATSV2_USR/statsV2-graphs.sh
    else
        echo "NOT jessi no actions"
    fi

    echo "FIX readonly remount logic in fr24feed update script"
    sed -i -e 's?$(mount | grep " on / " | grep rw)?{ mount | grep " on / " | grep rw; }?' $FR24FEED_UPDATER_PATH &>/dev/null || true

    echo "INSTALL STATSV2 default conf to ETC folder"
    cp -n statsV2.default $STATSV2_ETC
    cp statsV2.default $STATSV2_USR/default-statsV2.conf

    echo "INSTALL STATSV2 service conf"
    cp statsV2.service $SERVICE_CONF/statsV2.service
}

# INSTALL_SYMLINKS ------------------------------------------------------------
# Moves the files from the git directory to the run directory
# -----------------------------------------------------------------------------
function INSTALL_SYMLINKS()
{ 
    echo $LINE_BREAK
    echo "INSTALL_SYMLINKS"
    echo $LINE_BREAK

    echo "SETUP SYMLINK 1090"
    mkdir -p $SYM1090

    if [ -f /run/dump1090-fa/stats.json ]; then
        echo "INSTALL SYMLINK 1090 for dump1090-fa"
        ln -snf /run/dump1090-fa $SYM1090/data
        sed -i -e 's?URL_DUMP1090 .*?URL_DUMP1090 "file:///usr/share/statsV2/data-symlink"?' /etc/collectd/collectd.conf
    elif [ -f /run/readsb/stats.json ]; then
        echo "INSTALL SYMLINK 1090 for readsb"
        ln -snf /run/readsb $SYM1090/data
        sed -i -e 's?URL_DUMP1090 .*?URL_DUMP1090 "file:///usr/share/statsV2/data-symlink"?' /etc/collectd/collectd.conf
    elif [ -f /run/adsbexchange-feed/stats.json ]; then
        echo "INSTALL SYMLINK 1090 for adsbexchange"
        ln -snf /run/adsbexchange-feed $SYM1090/data
        sed -i -e 's?URL_DUMP1090 .*?URL_DUMP1090 "file:///usr/share/statsV2/data-symlink"?' /etc/collectd/collectd.conf
    elif [ -f /run/dump1090/stats.json ]; then
        echo "INSTALL SYMLINK 1090 for dump1090"
        ln -snf /run/dump1090 $SYM1090/data
        sed -i -e 's?URL_DUMP1090 .*?URL_DUMP1090 "file:///usr/share/statsV2/data-symlink"?' /etc/collectd/collectd.conf
    elif [ -f /run/dump1090-mutability/stats.json ]; then
        echo "INSTALL SYMLINK 1090 for dump1090-mutability"
        ln -snf /run/dump1090-mutability $SYM1090/data
        sed -i -e 's?URL_DUMP1090 .*?URL_DUMP1090 "file:///usr/share/statsV2/data-symlink"?' /etc/collectd/collectd.conf
    else
        echo "ERROR: Can't find any 1090 instances, please check you already have a version of dump1090 installed"
    fi

    echo $LINE_DASH
    echo "SETUP SYMLINK 978"
    mkdir -p $SYM0978

    if [ -f /run/skyaware978/aircraft.json ]; then
        echo "INSTALL SYMLINK 978 for skyaware978"
        ln -snf /run/skyaware978 $SYM0978/data
        sed -i -e 's?URL_DUMP978 .*?URL_DUMP978 "file:///usr/share/statsV2/978-symlink"?' /etc/collectd/collectd.conf
    elif [ -f /run/adsbexchange-978/aircraft.json ]; then
        echo "INSTALL SYMLINK 978 for adsbexchange-978"
        ln -snf /run/adsbexchange-978 $SYM0978/data
        sed -i -e 's?URL_DUMP978 .*?URL_DUMP978 "file:///usr/share/statsV2/978-symlink"?' /etc/collectd/collectd.conf
    else
        echo "ERROR: Can't find any 978 instances, please check you already have a version of dump978 installed"
    fi
}

# SETUP_LIGHTTPD --------------------------------------------------------------
# setup available and enabled if needed
# copy STATSV2 conf to available and set enabled
# -----------------------------------------------------------------------------
function SETUP_LIGHTTPD()
{ 
    echo $LINE_BREAK
    echo "SETUP_LIGHTTPD"
    echo $LINE_BREAK

    echo "SETUP LIGHTTPD conf-enabled and conf-available directories if conf.d is there"
    if [ -d $LIGHTTPD_CONF/conf.d/ ] && ! [ -d $LIGHTTPD_CONF_ENABLED ] && ! [ -d $LIGHTTPD_CONF_AVAILABLE] && command -v lighttpd &>/dev/null; then
        echo "LIGHTTPD enabled and available SETUP"
        ln -snf $LIGHTTPD_CONF/conf.d $LIGHTTPD_CONF_ENABLED
        mkdir -p $LIGHTTPD_CONF_AVAILABLE
    else
        echo "LIGHTTPD enabled and available already exist no actions"
    fi

    echo "SETUP LIGHTTPD STATSV2 conf to conf-available and conf-enabled"
    if [ -d $LIGHTTPD_CONF_ENABLED ] && [ -d $LIGHTTPD_CONF_AVAILABLE ] && command -v lighttpd &>/dev/null; then
        echo "LIGHTTPD STATSV2 to available and set enabled"
        cp statsV2-lighttpd.conf $LIGHTTPD_CONF_AVAILABLE/88-statsV2.conf
        ln -snf $LIGHTTPD_CONF_AVAILABLE/88-statsV2.conf $LIGHTTPD_CONF_ENABLED/88-statsV2.conf
    else
        echo "ERROR: LIGHTTPD enabled and available not setup correctly"
    fi
}

# SETUP_COLLECTD --------------------------------------------------------------
# backup collectd
# setup airspy if needed
# -----------------------------------------------------------------------------
function SETUP_COLLECTD()
{ 
    echo $LINE_BREAK
    echo "SETUP_COLLECTD"
    echo $LINE_BREAK

    echo "STOP COLLECTD"
    CONTROL_SERVICE stop collectd

    echo "BACKUP /etc/collectd/collectd.conf to /etc/collectd/collectd.conf.statsV2"
    cp "$COLLECTD_ETC/collectd.conf" "$COLLECTD_ETC/collectd.conf.statsV2" &>/dev/null || true

    echo $LINE_DASH
    echo "CHECK CPU AIRSPY exists in RUN copy and tune"
    if [[ -f "$COLLECTD_CPU_AIRSPY_PATH" ]]; then
        echo "COPY CPU AIRSPY found in RRD to RUN, tune and COPY back"
        cp "$COLLECTD_CPU_AIRSPY_PATH" "$COLLECTD_RUN/dump1090_cpu-airspy.rrd"
        rrdtool tune --maximum value:U "$COLLECTD_RUN/dump1090_cpu-airspy.rrd"
        cp -f "$COLLECTD_RUN/dump1090_cpu-airspy.rrd" "$COLLECTD_CPU_AIRSPY_PATH"
    else
        echo "CPU AIRSPY DNE in RRD no actions"
    fi

    echo "CHECK CPU AIRSPY exists in RRD copy and tune"
    if [[ -f "$COLLECTD_RRD/localhost/dump1090-localhost/dump1090_cpu-airspy.rrd" ]]; then
        echo "TUNE CPU AIRSPY found in RUN"
        rrdtool tune --maximum value:U "$COLLECTD_RRD/localhost/dump1090-localhost/dump1090_cpu-airspy.rrd"
    else
        echo "CPU AIRSPY DNE in RUN no actions"
    fi

    echo $LINE_DASH
    echo "INSTALL collectd.conf"
    echo "CHECK GRAPHS1090 installed"
    if grep -e 'system_stats' -qs /etc/collectd/collectd.conf &>/dev/null; then
        echo "GRAPHS1090 installed"
        echo "CHECK STATSV2 installed"
        if grep -e 'statsV2-system' -qs /etc/collectd/collectd.conf &>/dev/null; then
            echo "STATSV2 installed - no update"
            echo $LINE_DASH
        else
            echo "STATSV2 NOT installed - using collectd conf which includes graphs1090 so they can run in parrallel"
            echo $LINE_DASH
            cp statsV2-collectd-graphs1090.conf /etc/collectd/collectd.conf
        fi
    else
        echo "GRAPHS1090 NOT installed - using collectd conf for only statsV2"
        echo "CHECK STATSV2 installed"
        if grep -e 'statsV2-system' -qs /etc/collectd/collectd.conf &>/dev/null; then
            echo "STATSV2 installed - no update"
            echo $LINE_DASH
        else
            echo "STATSV2 NOT installed - using collectd conf for only statsV2"
            echo $LINE_DASH
            cp statsV2-collectd.conf /etc/collectd/collectd.conf
        fi
    fi

    echo "CHECK & SET unlisted interfaces on collectd.conf"
    for path in /sys/class/net/*
    do
        iface=$(basename $path)
        fgrep -q 'Interface "'$iface'"' /etc/collectd/collectd.conf && continue
        # no action on existing interfaces only add interface starting with et en and wl
        case $iface in
            et*|en*|wl*)
            echo "ADD $iface"
    sed -ie '/<Plugin "interface">/{a\
        Interface "'$iface'"
    }' /etc/collectd/collectd.conf
            ;;
        esac
    done
} 

# CALL MAIN ===================================================================
MAIN $1 $2
