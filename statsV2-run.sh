#!/bin/bash

source /etc/default/statsV2

STATSV2_INDEX_HTML=/usr/share/statsV2/html/index.html

# LOAD bash sleep builtin if available
[[ -f /usr/lib/bash/sleep ]] && enable -f /usr/lib/bash/sleep sleep || true

# SET color scheme
if [[ $colorscheme == "dark" ]]; then
    sed -i -e 's/href="bootstrap.custom..*.css"/href="bootstrap.custom.dark.css"/' "$STATSV2_INDEX_HTML"
else
    sed -i -e 's/href="bootstrap.custom..*.css"/href="bootstrap.custom.light.css"/' "$STATSV2_INDEX_HTML"
fi

function checkrrd()
{
    if [[ -f "/var/lib/collectd/rrd/localhost/dump1090-localhost/$1" ]] \
        || [[ -f "/var/lib/collectd/rrd/localhost/dump1090-localhost/$1.gz" ]] \
        || [[ -f "/run/collectd/localhost/dump1090-localhost/$1" ]]
    then
        return 0
    else
        return 1
    fi
}

function show()
{
    if grep -qs -e 'style="display:none"> <!-- '$1' -->' "$IHTML"; then
        sed -i -e 's/ style="display:none"> <!-- '$1' -->/> <!-- '$1' -->/' "$IHTML"
    fi
}

function hide()
{
    if ! grep -qs -e 'style="display:none"> <!-- '$1' -->' "$IHTML"; then
        sed -i -e 's/> <!-- '$1' -->/ style="display:none"> <!-- '$1' -->/' "$IHTML"
    fi
}

function show_hide()
{
    if checkrrd "$1"; then
        show "$2"
    else
        hide "$2"
    fi
}

# SHOW / HIDE graphs
show_hide dump1090_messages-messages_978.rrd dump978
show_hide airspy_rssi-max.rrd airspy
show_hide dump1090_misc-gain_db.rrd dump1090-misc

# ENABLE DISABLE all_large
if [[ $all_large == "yes" ]]; then
    if grep -qs -e 'flex: 50%; // all_large' /usr/share/statsV2/html/portal.css; then
        sed -i -e 's?flex: 50%; // all_large?flex: 100%; // all_large?' /usr/share/statsV2/html/portal.css
        sed -i -e 's?display: flex; // all_large2?display: inline; // all_large2?' /usr/share/statsV2/html/portal.css
    fi
else
    if ! grep -qs -e 'flex: 50%; // all_large' /usr/share/statsV2/html/portal.css; then
        sed -i -e 's?flex: 100%; // all_large?flex: 50%; // all_large?' /usr/share/statsV2/html/portal.css
        sed -i -e 's?display: inline; // all_large2?display: flex; // all_large2?' /usr/share/statsV2/html/portal.css
    fi
fi

# EXIT if no graphs
if [[ $1 == "nographs" ]]; then
	exit 0
fi

# SLEEP 5
while ! [[ -d $DB ]] && sleep 5; do
    echo "Sleeping a bit, waiting for database directory / collectd to start."
    true
done

# CREATE all graphs
for i in 24h 8h 2h 48h 7d 14d 30d 90d 180d 365d 730d 1095d 1825d 3650d; do
	/usr/share/statsV2/statsV2-graphs.sh $i $1 &>/dev/null
done
