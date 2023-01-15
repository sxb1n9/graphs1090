# JSON output formats

dump1090 generates several json files with informaton about the receiver itself, currently known aircraft,
and general statistics. These are used by the webmap, but could also be used by other things
e.g. [this collectd plugin](https://github.com/mutability/dump1090-tools/tree/master/collectd) feeds stats
about dump1090's operation to collectd for later graphing.

## Reading the json files

dump1090-fa writes json files periodically to the location specified by the `--write-json` command line option.
These json files can then be exposed via a separate standalone webserver e.g. lighttpd.

The files are written periodically; for aircraft, typically once a second, for stats, once a minute.
The interval between file updates can be controlled by the `--write-json-every` and `--json-stats-every` options.
As these files are frequently updated, it's a good idea to put them in RAM rather than on disk. Package installs
default to putting the file under `/run`, which is in RAM.

New versions of each file are written to a temporary file, then atomically renamed to the right path, so you should never see partial copies.

Each file contains a single JSON object. The file formats are:

## receiver.json

This file has general metadata about dump1090. It does not change often and you probably just want to read it once at startup.
The keys are:

 * version: the version of dump1090 in use
 * refresh: how often aircraft.json is updated (for the file version), in milliseconds. the webmap uses this to control its refresh interval.
 * history: the current number of valid history files (see below)
 * lat: the latitude of the receiver in decimal degrees. Optional, may not be present.
 * lon: the longitude of the receiver in decimal degrees. Optional, may not be present.

## aircraft.json

This file contains dump1090's list of recently seen aircraft. The keys are:

 * now: the time this file was generated, in seconds since Jan 1 1970 00:00:00 GMT (the Unix epoch).
 * messages: the total number of Mode S messages processed since dump1090 started.
 * aircraft: an array of JSON objects, one per known aircraft. Each aircraft has the following keys. Keys will be omitted if data is not available.
   * hex: the 24-bit ICAO identifier of the aircraft, as 6 hex digits. The identifier may start with '~', this means that the address is a non-ICAO address (e.g. from TIS-B).
   * type: type of underlying message, one of:
     * adsb_icao: messages from a Mode S or ADS-B transponder, using a 24-bit ICAO address
     * adsb_icao_nt: messages from an ADS-B equipped "non-transponder" emitter e.g. a ground vehicle, using a 24-bit ICAO address
     * adsr_icao: rebroadcast of ADS-B messages originally sent via another data link e.g. UAT, using a 24-bit ICAO address
     * tisb_icao: traffic information about a non-ADS-B target identified by a 24-bit ICAO address, e.g. a Mode S target tracked by secondary radar
     * adsb_other: messages from an ADS-B transponder using a non-ICAO address, e.g. anonymized address
     * adsr_other: rebroadcast of ADS-B messages originally sent via another data link e.g. UAT, using a non-ICAO address
     * tisb_other: traffic information about a non-ADS-B target using a non-ICAO address
     * tisb_trackfile: traffic information about a non-ADS-B target using a track/file identifier, typically from primary or Mode A/C radar
   * flight: callsign, the flight name or aircraft registration as 8 chars (2.2.8.2.6)
   * alt_baro: the aircraft barometric altitude in feet
   * alt_geom: geometric (GNSS / INS) altitude in feet referenced to the WGS84 ellipsoid
   * gs: ground speed in knots
   * ias: indicated air speed in knots
   * tas: true air speed in knots
   * mach: Mach number
   * track: true track over ground in degrees (0-359)
   * track_rate: Rate of change of track, degrees/second
   * roll: Roll, degrees, negative is left roll
   * mag_heading: Heading, degrees clockwise from magnetic north
   * true_heading: Heading, degrees clockwise from true north
   * baro_rate: Rate of change of barometric altitude, feet/minute
   * geom_rate: Rate of change of geometric (GNSS / INS) altitude, feet/minute
   * squawk: Mode A code (Squawk), encoded as 4 octal digits
   * emergency: ADS-B emergency/priority status, a superset of the 7x00 squawks (2.2.3.2.7.8.1.1)
   * category: emitter category to identify particular aircraft or vehicle classes (values A0 - D7) (2.2.3.2.5.2)
   * nav_qnh: altimeter setting (QFE or QNH/QNE), hPa
   * nav_altitude_mcp: selected altitude from the Mode Control Panel / Flight Control Unit (MCP/FCU) or equivalent equipment
   * nav_altitude_fms: selected altitude from the Flight Manaagement System (FMS) (2.2.3.2.7.1.3.3)
   * nav_heading: selected heading (True or Magnetic is not defined in DO-260B, mostly Magnetic as that is the de facto standard) (2.2.3.2.7.1.3.7)
   * nav_modes: set of engaged automation modes: 'autopilot', 'vnav', 'althold', 'approach', 'lnav', 'tcas'
   * lat, lon: the aircraft position in decimal degrees
   * nic: Navigation Integrity Category (2.2.3.2.7.2.6)
   * rc: Radius of Containment, meters; a measure of position integrity derived from NIC & supplementary bits. (2.2.3.2.7.2.6, Table 2-69)
   * seen_pos: how long ago (in seconds before "now") the position was last updated
   * version: ADS-B Version Number 0, 1, 2 (3-7 are reserved) (2.2.3.2.7.5)
   * nic_baro: Navigation Integrity Category for Barometric Altitude (2.2.5.1.35)
   * nac_p: Navigation Accuracy for Position (2.2.5.1.35)
   * nac_v: Navigation Accuracy for Velocity (2.2.5.1.19)
   * sil: Source Integity Level (2.2.5.1.40)
   * sil_type: interpretation of SIL: unknown, perhour, persample
   * gva: Geometric Vertical Accuracy  (2.2.3.2.7.2.8)
   * sda: System Design Assurance (2.2.3.2.7.2.4.6)
   * modea: true if we seem to be also receiving Mode A responses from this aircraft
   * modec: true if we seem to be also receiving Mode C responses from this aircraft
   * mlat: list of fields derived from MLAT data
   * tisb: list of fields derived from TIS-B data
   * messages: total number of Mode S messages received from this aircraft
   * seen: how long ago (in seconds before "now") a message was last received from this aircraft
   * rssi: recent average RSSI (signal power), in dbFS; this will always be negative.

Section references (2.2.xyz) refer to DO-260B.

## history_0.json, history_1.json, ..., history_119.json

These files are historical copies of aircraft.json at (by default) 30 second intervals. They follow exactly the
same format as aircraft.json. To know how many are valid, see receiver.json ("history" value). They are written in
a cycle, with history_0 being overwritten after history_119 is generated, so history_0.json is not necessarily the
oldest history entry. To load history, you should:

 * read "history" from receiver.json.
 * load that many history_N.json files
 * sort the resulting files by their "now" values
 * process the files in order
 
## stats.json

This file contains statistics about dump1090's operations.

There are 5 top level keys: "latest", "last1min", "last5min", "last15min", "total". Each key has statistics for a different period, defined by the "start" and "end" subkeys:

 * "total" covers the entire period from when dump1090 was started up to the current time
 * "last1min" covers a recent 1-minute period. This may be up to 1 minute out of date (i.e. "end" may be up to 1 minute old).
 * "last5min" covers a recent 5-minute period. As above, this may be up to 1 minute out of date.
 * "last15min" covers a recent 15-minute period. As above, this may be up to 1 minute out of date.
 * "latest" covers the time between the end of the "last1min" period and the current time.

Internally, live stats are collected into "latest". Once a minute, "latest" is copied to "last1min" and "latest" is reset. Then "last5min" and "last15min" are recalculated from a history of the last 5 or 15 1-minute periods.

Each period has the following subkeys:

 * start: the start time (in seconds-since-1-Jan-1970) of this statistics collection period.
 * end: the end time (in seconds-since-1-Jan-1970) of this statistics collection period.
 * local: statistics about messages received from a local SDR dongle. Not present in --net-only mode. Has subkeys:
   * samples_processed: number of samples processed
   * samples_dropped: number of samples dropped before processing. A nonzero value means CPU overload.
   * modeac: number of Mode A / C messages decoded
   * modes: number of Mode S preambles received. This is *not* the number of valid messages!
   * bad: number of Mode S preambles that didn't result in a valid message
   * unknown_icao: number of Mode S preambles which looked like they might be valid but we didn't recognize the ICAO address and it was one of the message types where we can't be sure it's valid in this case.
   * accepted: array. Index N has the number of valid Mode S messages accepted with N-bit errors corrected.
   * signal: mean signal power of successfully received messages, in dbFS; always negative.
   * noise: mean noise power of non-message samples, in dbFS; always negative.
   * peak_signal: peak signal power of a successfully received message, in dbFS; always negative.
   * strong_signals: number of messages received that had a signal power above -3dBFS.
   * gain_db: the current SDR gain, floating-point dB. Might be absent depending on SDR type.
 * remote: statistics about messages received from remote clients. Only present in --net or --net-only mode. Has subkeys:
   * modeac: number of Mode A / C messages received.
   * modes: number of Mode S messages received.
   * bad: number of Mode S messages that had bad CRC or were otherwise invalid.
   * unknown_icao: number of Mode S messages which looked like they might be valid but we didn't recognize the ICAO address and it was one of the message types where we can't be sure it's valid in this case.
   * accepted: array. Index N has the number of valid Mode S messages accepted with N-bit errors corrected.
 * cpu: statistics about CPU use. Has subkeys:
   * demod: milliseconds spent doing demodulation and decoding in response to data from a SDR dongle
   * reader: milliseconds spent reading sample data over USB from a SDR dongle
   * background: milliseconds spent doing network I/O, processing received network messages, and periodic tasks.
 * cpr: statistics about Compact Position Report message decoding. Has subkeys:
   * surface: total number of surface CPR messages received
   * airborne: total number of airborne CPR messages received
   * global_ok: global positions successfuly derived
   * global_bad: global positions that were rejected because they were inconsistent
     * global_range: global positions that were rejected because they exceeded the receiver max range
     * global_speed: global positions that were rejected because they failed the inter-position speed check
   * global_skipped: global position attempts skipped because we did not have the right data (e.g. even/odd messages crossed a zone boundary)
   * local_ok: local (relative) positions successfully found
     * local_aircraft_relative: local positions found relative to a previous aircraft position
     * local_receiver_relative: local positions found relative to the receiver position
   * local_skipped: local (relative) positions not used because we did not have the right data
     * local_range: local positions not used because they exceeded the receiver max range or fell into the ambiguous part of the receiver range
     * local_speed: local positions not used because they failed the inter-position speed check
   * filtered: number of CPR messages ignored because they matched one of the heuristics for faulty transponder output
 * tracks: statistics on aircraft tracks. Each track represents a unique aircraft and persists for up to 5 minutes after the last message
   from the aircraft is heard. If messages from the same aircraft are subsequently heard after the 5 minute period, this will be counted
   as a new track.
   * all: total tracks created
   * single_message: tracks consisting of only a single message. These are usually due to message decoding errors that produce a bad aircraft address.
   * unreliable: tracks that were never marked as reliable. These are also usually due to message decoding errors.
 * messages: total number of messages accepted by dump1090 from any source
 * messages_by_df: an array of integers where entry N (0..31) is the total number of messages accepted with downlink format (DF) = N.
 * adaptive: statistics on adaptive gain. Only present if adaptive gain is enabled
   * gain_db: latest SDR gain (legacy; prefer to use `local.gain_db` instead)
   * dynamic_range_limit_db: latest dynamic-range-controlled upper gain limit, dB
   * gain_changes: number of gain changes made in this stats period
   * loud_undecoded: number of undecodable loud probably-a-valid-message bursts seen
   * loud_decoded: number of correctly decoded mesaages with a high signal level
   * noise_dbfs: adaptive gain noise floor estimate, dBFS
   * gain_seconds: object, keyed by integer gain step, values are an array of [floating point gain in dB, number of seconds spent at this gain setting]

# Downlink Format

DF	Type
0	Short air-air surveillance (ACAS)
1 - 3	Reserved
4	Surveillance, altitude reply
5	Surveillance, identify reply
6 - 10	Reserved
11	All-call reply
12-15	Reserved
16	Long air-air surveillance (ACAS)
17	Extended squitter
18	Extended squitter / non transponder
19	Military extended squitter
20	Comm-B, altitude reply
21	Comm-B, identify reply
22	Reserved for military use
23	Reserved
24	Reserved Comm-D (ELM)

# PIAWARE 8.2 EXAMPLES
## RECEIVER.JSON EXAMPLE
{ "version" : "8.2~bpo10+1", "refresh" : 1000, "history" : 120, "lat" : 33.444700, "lon" : -112.069060 }
## STATS.JSON EXAMPLE
{
"latest":{"start":1673798819.7,"end":1673798819.7,"local":{"samples_processed":0,"samples_dropped":0,"modeac":0,"modes":0,"bad":0,"unknown_icao":0,"accepted":[0,0],"strong_signals":0,"gain_db":38.6},"remote":{"modeac":0,"modes":0,"bad":0,"unknown_icao":0,"accepted":[0,0]},"cpr":{"surface":0,"airborne":0,"global_ok":0,"global_bad":0,"global_range":0,"global_speed":0,"global_skipped":0,"local_ok":0,"local_aircraft_relative":0,"local_receiver_relative":0,"local_skipped":0,"local_range":0,"local_speed":0,"filtered":0},"altitude_suppressed":0,"cpu":{"demod":0,"reader":0,"background":0},"tracks":{"all":0,"single_message":0,"unreliable":0},"messages":0,"messages_by_df":[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]},
"last1min":{"start":1673798759.8,"end":1673798819.7,"local":{"samples_processed":143917056,"samples_dropped":0,"modeac":0,"modes":922271,"bad":1999869,"unknown_icao":392273,"accepted":[22387,1305],"signal":-11.2,"noise":-23.6,"peak_signal":-1.1,"strong_signals":834,"gain_db":38.6},"remote":{"modeac":0,"modes":38,"bad":0,"unknown_icao":0,"accepted":[38,0]},"cpr":{"surface":238,"airborne":4013,"global_ok":4169,"global_bad":0,"global_range":0,"global_speed":0,"global_skipped":0,"local_ok":68,"local_aircraft_relative":0,"local_receiver_relative":0,"local_skipped":14,"local_range":0,"local_speed":0,"filtered":0},"altitude_suppressed":0,"cpu":{"demod":6540,"reader":1297,"background":519},"tracks":{"all":6,"single_message":5,"unreliable":5},"messages":23730,"messages_by_df":[5204,0,0,0,1054,70,0,0,0,0,0,5437,0,0,0,0,396,11503,42,0,20,4,0,0,0,0,0,0,0,0,0,0]},
"last5min":{"start":1673798519.7,"end":1673798819.7,"local":{"samples_processed":719978496,"samples_dropped":0,"modeac":0,"modes":4623380,"bad":10035820,"unknown_icao":1972272,"accepted":[112823,6662],"signal":-11.3,"noise":-24.0,"peak_signal":-0.8,"strong_signals":5149,"gain_db":38.6},"remote":{"modeac":0,"modes":309,"bad":0,"unknown_icao":0,"accepted":[309,0]},"cpr":{"surface":648,"airborne":20426,"global_ok":20669,"global_bad":3,"global_range":3,"global_speed":0,"global_skipped":6,"local_ok":283,"local_aircraft_relative":0,"local_receiver_relative":0,"local_skipped":119,"local_range":0,"local_speed":1,"filtered":0},"altitude_suppressed":0,"cpu":{"demod":33712,"reader":6666,"background":2633},"tracks":{"all":47,"single_message":17,"unreliable":20},"messages":119794,"messages_by_df":[25853,0,0,0,5408,332,0,0,0,0,0,28234,0,0,0,0,1981,57566,326,0,73,21,0,0,0,0,0,0,0,0,0,0]},
"last15min":{"start":1673797919.8,"end":1673798819.7,"local":{"samples_processed":2159935488,"samples_dropped":0,"modeac":0,"modes":13855025,"bad":30104290,"unknown_icao":5928370,"accepted":[313762,19858],"signal":-11.7,"noise":-24.9,"peak_signal":-0.7,"strong_signals":11765,"gain_db":38.6},"remote":{"modeac":0,"modes":682,"bad":0,"unknown_icao":0,"accepted":[682,0]},"cpr":{"surface":1794,"airborne":57875,"global_ok":58263,"global_bad":8,"global_range":6,"global_speed":1,"global_skipped":26,"local_ok":997,"local_aircraft_relative":0,"local_receiver_relative":0,"local_skipped":401,"local_range":1,"local_speed":6,"filtered":0},"altitude_suppressed":0,"cpu":{"demod":101691,"reader":20175,"background":7937},"tracks":{"all":114,"single_message":51,"unreliable":56},"messages":334302,"messages_by_df":[69339,0,0,0,14885,873,0,0,0,0,0,79033,0,0,0,0,5591,163569,736,0,215,61,0,0,0,0,0,0,0,0,0,0]},
"total":{"start":1673733239.6,"end":1673798819.7,"local":{"samples_processed":157391912960,"samples_dropped":0,"modeac":0,"modes":991094737,"bad":2162689692,"unknown_icao":430431750,"accepted":[14036181,1011808],"signal":-10.7,"noise":-25.9,"peak_signal":-0.4,"strong_signals":765270,"gain_db":38.6},"remote":{"modeac":0,"modes":65540,"bad":0,"unknown_icao":0,"accepted":[65540,0]},"cpr":{"surface":59579,"airborne":2849703,"global_ok":2832743,"global_bad":139,"global_range":58,"global_speed":44,"global_skipped":1812,"local_ok":55600,"local_aircraft_relative":0,"local_receiver_relative":0,"local_skipped":20800,"local_range":9,"local_speed":266,"filtered":0},"altitude_suppressed":0,"cpu":{"demod":6942358,"reader":1447497,"background":555605},"tracks":{"all":6582,"single_message":2869,"unreliable":3291},"messages":15113529,"messages_by_df":[2540128,0,0,0,678101,42708,0,0,0,0,0,3643633,0,0,0,0,188503,7911953,92776,0,13717,2010,0,0,0,0,0,0,0,0,0,0]}
}
## AIRCRAFT.JSON
{ "now" : 1673799021.7,
  "messages" : 15203237,
  "aircraft" : [
    {"hex":"a46304","alt_baro":38025,"alt_geom":37800,"gs":420.8,"track":216.1,"baro_rate":-64,"nav_qnh":1013.6,"nav_altitude_mcp":38016,"nav_heading":207.4,"lat":36.096791,"lon":-114.281538,"nic":8,"rc":186,"seen_pos":0.1,"version":0,"nic_baro":1,"nac_p":8,"nac_v":1,"sil":2,"sil_type":"unknown","mlat":[],"tisb":[],"messages":48,"seen":0.1,"rssi":-29.3},
    {"hex":"a3f500","flight":"AAL632  ","alt_baro":29325,"alt_geom":29300,"gs":326.7,"track":245.4,"baro_rate":-1024,"squawk":"6770","emergency":"none","category":"A3","nav_qnh":1013.6,"nav_altitude_mcp":4000,"nav_heading":244.7,"lat":34.541519,"lon":-110.301781,"nic":8,"rc":186,"seen_pos":0.8,"version":2,"nic_baro":1,"nac_p":9,"nac_v":1,"sil":3,"sil_type":"perhour","gva":2,"sda":2,"mlat":[],"tisb":[],"messages":139,"seen":0.4,"rssi":-26.8},
    {"hex":"aba1c9","flight":"FDX3901 ","alt_baro":39025,"alt_geom":38975,"gs":560.0,"track":65.9,"baro_rate":0,"category":"A5","nav_qnh":1012.8,"nav_altitude_mcp":39008,"nav_heading":45.0,"lat":35.756029,"lon":-115.437966,"nic":8,"rc":186,"seen_pos":22.5,"version":2,"nic_baro":1,"nac_p":10,"nac_v":2,"sil":3,"sil_type":"perhour","gva":2,"sda":2,"mlat":[],"tisb":[],"messages":59,"seen":0.2,"rssi":-31.6},
    {"hex":"ad8935","alt_baro":24000,"lat":32.156936,"lon":-109.002760,"nic":8,"rc":186,"seen_pos":41.8,"version":0,"nac_p":8,"sil":2,"sil_type":"unknown","mlat":[],"tisb":[],"messages":5,"seen":41.8,"rssi":-32.8},
    {"hex":"a63bf4","flight":"SWA2284 ","alt_baro":"ground","gs":11.8,"track":165.9,"true_heading":90.0,"squawk":"1663","emergency":"none","category":"A3","lat":33.432152,"lon":-111.997334,"nic":8,"rc":186,"seen_pos":4.0,"version":2,"nac_p":9,"nac_v":1,"sil":3,"sil_type":"perhour","sda":2,"mlat":[],"tisb":[],"messages":35,"seen":0.3,"rssi":-9.8},
    {"hex":"a693aa","alt_baro":38000,"nav_qnh":1013.6,"nav_altitude_mcp":38016,"nav_heading":234.1,"version":0,"nic_baro":1,"nac_p":10,"sil":3,"sil_type":"unknown","mlat":[],"tisb":[],"messages":8,"seen":54.5,"rssi":-31.9},
    {"hex":"a32a88","flight":"ASA512  ","alt_baro":39000,"alt_geom":39375,"gs":555.9,"track":115.9,"baro_rate":0,"squawk":"3665","emergency":"none","category":"A3","lat":34.027638,"lon":-115.448284,"nic":8,"rc":186,"seen_pos":0.1,"version":2,"nic_baro":1,"nac_p":9,"nac_v":1,"sil":3,"sil_type":"perhour","gva":2,"sda":2,"mlat":[],"tisb":[],"messages":577,"seen":0.1,"rssi":-25.6},
    {"hex":"a2615e","version":2,"sil_type":"perhour","mlat":[],"tisb":[],"messages":38,"seen":82.0,"rssi":-30.6},
    {"hex":"abb19c","flight":"SWA1017 ","alt_baro":35950,"alt_geom":36050,"gs":350.7,"track":273.6,"baro_rate":0,"squawk":"2313","emergency":"none","category":"A3","nav_qnh":1013.6,"nav_altitude_mcp":36000,"nav_heading":265.1,"lat":33.922348,"lon":-108.520147,"nic":8,"rc":186,"seen_pos":0.3,"version":2,"nic_baro":1,"nac_p":8,"nac_v":1,"sil":3,"sil_type":"perhour","gva":1,"sda":2,"mlat":[],"tisb":[],"messages":688,"seen":0.1,"rssi":-30.5},
    {"hex":"a7debf","flight":"NKS1289 ","alt_baro":"ground","gs":0.0,"true_heading":92.8,"squawk":"1675","emergency":"none","category":"A3","version":2,"nac_p":10,"nac_v":4,"sil":3,"sil_type":"perhour","sda":2,"mlat":[],"tisb":[],"messages":61,"seen":2.4,"rssi":-6.9},
    {"hex":"a12625","flight":"AAL476  ","alt_baro":30375,"alt_geom":30300,"gs":322.2,"track":245.4,"baro_rate":-960,"category":"A3","nav_altitude_mcp":4000,"nav_heading":0.0,"lat":34.491670,"lon":-110.433941,"nic":8,"rc":186,"seen_pos":19.4,"version":2,"nic_baro":1,"nac_p":9,"nac_v":1,"sil":3,"sil_type":"perhour","gva":2,"sda":2,"mlat":[],"tisb":[],"messages":230,"seen":15.4,"rssi":-26.3},
    {"hex":"a5cbf3","flight":"UAL2664 ","alt_baro":35000,"alt_geom":35150,"gs":547.4,"track":75.5,"baro_rate":-64,"squawk":"2063","emergency":"none","category":"A3","nav_qnh":1013.6,"nav_altitude_mcp":35008,"nav_heading":59.8,"lat":33.674469,"lon":-110.109969,"nic":8,"rc":186,"seen_pos":0.0,"version":2,"nic_baro":1,"nac_p":10,"nac_v":2,"sil":3,"sil_type":"perhour","gva":2,"sda":2,"mlat":[],"tisb":[],"messages":486,"seen":0.0,"rssi":-19.4},
    {"hex":"abb8ea","flight":"SWA1914 ","alt_baro":35025,"alt_geom":35525,"gs":546.1,"track":90.9,"baro_rate":-64,"squawk":"7347","emergency":"none","category":"A3","nav_qnh":1013.6,"nav_altitude_mcp":35008,"nav_heading":73.1,"lat":33.488004,"lon":-116.144714,"nic":8,"rc":186,"seen_pos":0.3,"version":2,"nic_baro":1,"nac_p":8,"nac_v":1,"sil":3,"sil_type":"perhour","gva":1,"sda":2,"mlat":[],"tisb":[],"messages":1476,"seen":0.0,"rssi":-26.6},
    {"hex":"a4c37e","category":"A2","version":2,"sil_type":"perhour","mlat":[],"tisb":[],"messages":191,"seen":107.4,"rssi":-28.7},
    {"hex":"a1acce","category":"A2","version":2,"sil_type":"perhour","mlat":[],"tisb":[],"messages":270,"seen":97.5,"rssi":-24.0},
    {"hex":"abb271","category":"A3","version":2,"sil_type":"perhour","mlat":[],"tisb":[],"messages":174,"seen":90.4,"rssi":-33.3},
    {"hex":"a7f75f","flight":"N612NG  ","alt_baro":20000,"alt_geom":19825,"gs":222.8,"track":220.3,"baro_rate":-64,"squawk":"0664","emergency":"none","category":"A1","nav_qnh":1013.6,"nav_altitude_mcp":11008,"nav_heading":223.6,"nav_modes":["autopilot","althold","lnav"],"lat":34.811371,"lon":-111.049861,"nic":8,"rc":186,"seen_pos":1.2,"version":2,"nic_baro":1,"nac_p":10,"nac_v":2,"sil":3,"sil_type":"perhour","gva":2,"sda":2,"mlat":[],"tisb":[],"messages":656,"seen":0.1,"rssi":-28.8},
    {"hex":"add376","flight":"JBU288  ","alt_baro":29000,"alt_geom":29125,"gs":555.0,"track":75.4,"baro_rate":64,"squawk":"6735","emergency":"none","category":"A3","nav_qnh":1013.6,"nav_altitude_mcp":28992,"nav_heading":0.0,"lat":34.315155,"lon":-114.488189,"nic":8,"rc":186,"seen_pos":1.0,"version":2,"nic_baro":1,"nac_p":9,"nac_v":1,"sil":3,"sil_type":"perhour","gva":2,"sda":2,"mlat":[],"tisb":[],"messages":931,"seen":0.1,"rssi":-21.3},
    {"hex":"ac08f5","category":"A3","version":2,"sil_type":"perhour","mlat":[],"tisb":[],"messages":93,"seen":179.1,"rssi":-30.2},
    {"hex":"a4c6af","flight":"AAL1861 ","alt_baro":25450,"alt_geom":25775,"gs":289.1,"track":283.6,"baro_rate":-64,"category":"A3","nav_qnh":1012.8,"nav_altitude_mcp":4000,"lat":32.370145,"lon":-110.221290,"nic":8,"rc":186,"seen_pos":0.5,"version":2,"nic_baro":1,"nac_p":9,"nac_v":1,"sil":3,"sil_type":"perhour","mlat":[],"tisb":[],"messages":456,"seen":0.5,"rssi":-26.4},
    {"hex":"ab6449","flight":"N833JB  ","alt_baro":44700,"alt_geom":45075,"gs":503.0,"track":107.0,"baro_rate":704,"squawk":"2003","emergency":"none","category":"A2","nav_qnh":1013.6,"nav_altitude_mcp":45024,"nav_modes":["autopilot","tcas"],"lat":33.680870,"lon":-115.091515,"nic":8,"rc":186,"seen_pos":1.8,"version":2,"nic_baro":1,"nac_p":10,"nac_v":2,"sil":3,"sil_type":"perhour","gva":2,"sda":2,"mlat":[],"tisb":[],"messages":575,"seen":1.1,"rssi":-23.4},
    {"hex":"c058dd","flight":"ACA784  ","alt_baro":40975,"alt_geom":41325,"gs":554.0,"track":72.0,"geom_rate":0,"squawk":"6775","emergency":"none","category":"A5","nav_qnh":1012.8,"nav_altitude_mcp":40992,"nav_heading":52.7,"nav_modes":["autopilot","vnav","lnav","tcas"],"lat":33.914748,"lon":-115.377216,"nic":8,"rc":186,"seen_pos":0.4,"version":2,"nic_baro":1,"nac_p":9,"nac_v":1,"sil":3,"sil_type":"perhour","gva":2,"sda":2,"mlat":[],"tisb":[],"messages":480,"seen":0.0,"rssi":-22.2},
    {"hex":"aab09a","alt_baro":2625,"alt_geom":2450,"gs":146.0,"track":270.0,"baro_rate":0,"squawk":"4103","category":"A3","nav_qnh":1009.6,"nav_altitude_mcp":8000,"nav_heading":258.0,"lat":33.431076,"lon":-112.003638,"nic":8,"rc":186,"seen_pos":66.6,"version":2,"nic_baro":1,"nac_p":8,"nac_v":1,"sil":3,"sil_type":"perhour","mlat":[],"tisb":[],"messages":381,"seen":13.3,"rssi":-2.6},
    {"hex":"abd4e7","flight":"SWA310  ","alt_baro":35000,"alt_geom":35300,"gs":568.9,"track":105.2,"baro_rate":192,"squawk":"3257","emergency":"none","category":"A3","nav_qnh":1013.6,"nav_altitude_mcp":35008,"nav_heading":89.3,"lat":34.003143,"lon":-114.604442,"nic":8,"rc":186,"seen_pos":0.1,"version":2,"nic_baro":1,"nac_p":9,"nac_v":1,"sil":3,"sil_type":"perhour","gva":2,"sda":2,"mlat":[],"tisb":[],"messages":3099,"seen":0.1,"rssi":-21.0},
    {"hex":"a1fd03","flight":"SWA393  ","alt_baro":29475,"alt_geom":29450,"gs":318.4,"track":243.9,"baro_rate":-1024,"squawk":"1647","emergency":"none","category":"A3","nav_qnh":1013.6,"nav_altitude_mcp":4000,"nav_heading":239.8,"lat":34.364319,"lon":-110.768756,"nic":8,"rc":186,"seen_pos":8.3,"version":2,"nic_baro":1,"nac_p":8,"nac_v":1,"sil":3,"sil_type":"perhour","gva":1,"sda":2,"mlat":[],"tisb":[],"messages":1018,"seen":7.8,"rssi":-27.3},
    {"hex":"ac0048","flight":"SWA1941 ","alt_baro":5800,"alt_geom":5600,"gs":216.1,"track":271.9,"baro_rate":4096,"squawk":"4273","emergency":"none","category":"A3","nav_qnh":1009.6,"nav_altitude_mcp":20992,"nav_heading":258.0,"lat":33.433411,"lon":-112.137341,"nic":8,"rc":186,"seen_pos":0.2,"version":2,"nic_baro":1,"nac_p":10,"nac_v":2,"sil":3,"sil_type":"perhour","gva":2,"sda":2,"mlat":[],"tisb":[],"messages":662,"seen":0.2,"rssi":-1.9},
    {"hex":"a45f8e","flight":"FFT754  ","alt_baro":"ground","gs":85.0,"track":48.0,"true_heading":270.0,"baro_rate":64,"squawk":"1552","emergency":"none","category":"A3","lat":33.431047,"lon":-111.998581,"nic":8,"rc":186,"seen_pos":6.1,"version":2,"nac_p":10,"nac_v":4,"sil":3,"sil_type":"perhour","sda":3,"mlat":["track","baro_rate"],"tisb":[],"messages":477,"seen":0.1,"rssi":-2.9},
    {"hex":"a0cfbd","flight":"AAL1651 ","alt_baro":26875,"alt_geom":27025,"gs":548.3,"track":86.0,"baro_rate":1216,"squawk":"6725","emergency":"none","category":"A3","nav_qnh":1013.6,"nav_altitude_mcp":31008,"lat":32.746536,"lon":-114.986975,"nic":8,"rc":186,"seen_pos":24.5,"version":2,"nic_baro":1,"nac_p":9,"nac_v":1,"sil":3,"sil_type":"perhour","gva":2,"sda":2,"mlat":[],"tisb":[],"messages":1566,"seen":21.4,"rssi":-28.4},
    {"hex":"ac9f5f","flight":"ASI402  ","alt_baro":4400,"alt_geom":4250,"gs":72.6,"track":150.3,"geom_rate":-256,"squawk":"4364","emergency":"none","category":"A1","lat":33.720840,"lon":-112.039471,"nic":9,"rc":75,"seen_pos":0.1,"version":2,"nic_baro":0,"nac_p":10,"nac_v":2,"sil":3,"sil_type":"perhour","gva":2,"sda":2,"mlat":[],"tisb":[],"messages":985,"seen":0.1,"rssi":-18.7},
    {"hex":"ad10ec","flight":"AAL554  ","alt_baro":1200,"category":"A3","version":2,"sil_type":"perhour","mlat":[],"tisb":[],"messages":58,"seen":1.3,"rssi":-3.8},
    {"hex":"aa1368","version":0,"sil_type":"unknown","mlat":[],"tisb":[],"messages":28,"seen":124.9,"rssi":-21.8},
    {"hex":"a5617a","flight":"LXJ446  ","alt_baro":41325,"alt_geom":41525,"gs":484.4,"track":131.8,"geom_rate":1088,"squawk":"7224","emergency":"none","category":"A2","nav_qnh":1012.8,"nav_altitude_mcp":43008,"nav_heading":137.1,"lat":34.516983,"lon":-115.019120,"nic":8,"rc":186,"seen_pos":1.0,"version":2,"nic_baro":1,"nac_p":10,"nac_v":1,"sil":3,"sil_type":"perhour","gva":2,"sda":2,"mlat":[],"tisb":[],"messages":2147,"seen":0.3,"rssi":-23.1},
    {"hex":"a89eb9","alt_baro":2100,"alt_geom":1725,"gs":70.0,"track":31.0,"geom_rate":448,"category":"A1","lat":33.286835,"lon":-111.804895,"nic":9,"rc":75,"seen_pos":1.8,"version":2,"nic_baro":0,"nac_p":10,"nac_v":2,"sil":3,"sil_type":"perhour","gva":2,"sda":2,"mlat":[],"tisb":[],"messages":155,"seen":1.8,"rssi":-17.3},
    {"hex":"a7e62d","category":"A3","version":2,"sil_type":"perhour","mlat":[],"tisb":[],"messages":902,"seen":162.1,"rssi":-28.4},
    {"hex":"a97797","flight":"SKW9901 ","alt_baro":"ground","gs":5.2,"track":333.4,"true_heading":289.7,"baro_rate":-64,"category":"A2","lat":33.439808,"lon":-112.010738,"nic":8,"rc":186,"seen_pos":24.6,"version":2,"nac_p":10,"nac_v":1,"sil":3,"sil_type":"perhour","sda":2,"mlat":["altitude","track","baro_rate"],"tisb":[],"messages":213,"seen":16.4,"rssi":-6.1},
    {"hex":"a5ce40","flight":"SWA2370 ","alt_baro":10875,"alt_geom":10700,"gs":247.3,"track":279.3,"baro_rate":1024,"squawk":"1533","emergency":"none","category":"A3","nav_qnh":1008.8,"nav_altitude_mcp":20992,"nav_heading":267.2,"lat":33.400160,"lon":-112.260375,"nic":8,"rc":186,"seen_pos":0.5,"version":2,"nic_baro":1,"nac_p":8,"nac_v":1,"sil":3,"sil_type":"perhour","gva":1,"sda":2,"mlat":[],"tisb":[],"messages":1185,"seen":0.1,"rssi":-2.7},
    {"hex":"a72ca2","flight":"SWA3016 ","alt_baro":11150,"alt_geom":11025,"gs":379.9,"track":19.5,"baro_rate":2048,"squawk":"0723","emergency":"none","category":"A3","nav_qnh":1009.6,"nav_altitude_mcp":20992,"nav_heading":357.9,"lat":33.584198,"lon":-112.154828,"nic":8,"rc":186,"seen_pos":0.3,"version":2,"nic_baro":1,"nac_p":8,"nac_v":1,"sil":3,"sil_type":"perhour","gva":1,"sda":2,"mlat":[],"tisb":[],"messages":2218,"seen":0.1,"rssi":-2.9},
    {"hex":"a0275c","flight":"AAL2    ","alt_baro":29000,"alt_geom":29300,"gs":542.1,"track":76.9,"baro_rate":64,"squawk":"2001","emergency":"none","category":"A3","nav_altitude_mcp":28992,"nav_heading":0.0,"lat":34.007620,"lon":-114.671917,"nic":8,"rc":186,"seen_pos":0.1,"version":2,"nic_baro":1,"nac_p":9,"nac_v":1,"sil":3,"sil_type":"perhour","gva":2,"sda":2,"mlat":[],"tisb":[],"messages":2179,"seen":0.1,"rssi":-22.5},
    {"hex":"abf8e0","flight":"SWA991  ","alt_baro":27075,"alt_geom":27175,"gs":314.9,"track":227.2,"baro_rate":-2304,"squawk":"1435","emergency":"none","category":"A3","nav_qnh":1013.6,"nav_altitude_mcp":4000,"nav_heading":227.8,"lat":34.227219,"lon":-110.959504,"nic":8,"rc":186,"seen_pos":0.5,"version":2,"nic_baro":1,"nac_p":10,"nac_v":2,"sil":3,"sil_type":"perhour","gva":2,"sda":2,"mlat":[],"tisb":[],"messages":1573,"seen":0.5,"rssi":-24.2},
    {"hex":"a4c861","flight":"N407TX  ","alt_baro":1400,"alt_geom":1275,"gs":131.2,"track":246.2,"geom_rate":0,"squawk":"0100","emergency":"none","category":"A7","lat":33.388149,"lon":-112.490583,"nic":8,"rc":186,"seen_pos":0.2,"version":2,"nic_baro":0,"nac_p":9,"nac_v":2,"sil":3,"sil_type":"perhour","gva":2,"sda":2,"mlat":[],"tisb":[],"messages":1573,"seen":0.2,"rssi":-11.0},
    {"hex":"a696d5","flight":"GTI3665 ","alt_baro":30275,"alt_geom":30400,"gs":346.4,"track":235.9,"baro_rate":-2368,"squawk":"1703","emergency":"none","category":"A3","nav_qnh":1013.6,"nav_altitude_mcp":30016,"nav_heading":239.1,"lat":34.820801,"lon":-114.080910,"nic":8,"rc":186,"seen_pos":0.3,"version":2,"nic_baro":1,"nac_p":10,"nac_v":1,"sil":3,"sil_type":"perhour","gva":2,"sda":2,"mlat":[],"tisb":[],"messages":1659,"seen":0.1,"rssi":-25.3},
    {"hex":"a0b31c","flight":"N144S   ","alt_baro":15675,"alt_geom":13825,"gs":400.7,"track":132.2,"baro_rate":1280,"squawk":"2670","emergency":"none","category":"A3","nav_qnh":1010.4,"nav_altitude_mcp":21024,"nav_modes":["autopilot","tcas"],"lat":33.686410,"lon":-111.683292,"nic":8,"rc":186,"seen_pos":13.2,"version":2,"nic_baro":1,"nac_p":10,"nac_v":2,"sil":3,"sil_type":"perhour","gva":2,"sda":2,"mlat":[],"tisb":[],"messages":2278,"seen":0.4,"rssi":-17.0},
    {"hex":"a4493f","flight":"UAL2387 ","alt_baro":34000,"alt_geom":33950,"gs":351.1,"track":271.6,"baro_rate":0,"squawk":"4167","emergency":"none","category":"A3","nav_qnh":1013.6,"nav_altitude_mcp":34016,"nav_heading":265.1,"lat":34.487155,"lon":-111.177807,"nic":8,"rc":186,"seen_pos":0.1,"version":2,"nic_baro":1,"nac_p":10,"nac_v":2,"sil":3,"sil_type":"perhour","gva":2,"sda":2,"mlat":[],"tisb":[],"messages":1241,"seen":0.1,"rssi":-21.7},
    {"hex":"abd17b","flight":"SWA1318 ","alt_baro":37000,"alt_geom":37500,"gs":557.5,"track":99.4,"baro_rate":64,"squawk":"2002","emergency":"none","category":"A3","nav_qnh":1013.6,"nav_altitude_mcp":36992,"nav_heading":80.2,"lat":33.342109,"lon":-114.958303,"nic":8,"rc":186,"seen_pos":0.0,"version":2,"nic_baro":1,"nac_p":9,"nac_v":1,"sil":3,"sil_type":"perhour","gva":2,"sda":2,"mlat":[],"tisb":[],"messages":5140,"seen":0.0,"rssi":-18.5},
    {"hex":"ac30b6","flight":"LYM3101 ","alt_baro":24125,"alt_geom":23975,"gs":169.1,"track":226.7,"geom_rate":-320,"squawk":"3776","emergency":"none","category":"A1","lat":34.941039,"lon":-110.995045,"nic":9,"rc":75,"seen_pos":1.0,"version":2,"nic_baro":1,"nac_p":10,"nac_v":2,"sil":3,"sil_type":"perhour","gva":2,"sda":2,"mlat":[],"tisb":[],"messages":1944,"seen":1.0,"rssi":-24.7},
    {"hex":"ab2729","flight":"AAL1681 ","alt_baro":18275,"alt_geom":18225,"gs":326.8,"track":226.7,"baro_rate":-2368,"squawk":"1662","emergency":"none","category":"A3","nav_qnh":1010.4,"nav_altitude_mcp":4000,"lat":34.090250,"lon":-111.135006,"nic":8,"rc":186,"seen_pos":0.7,"version":2,"nic_baro":1,"nac_p":9,"nac_v":1,"sil":3,"sil_type":"perhour","gva":2,"sda":2,"mlat":[],"tisb":[],"messages":2986,"seen":0.2,"rssi":-20.2},
    {"hex":"a2ecf3","category":"A3","version":2,"sil_type":"perhour","mlat":[],"tisb":[],"messages":1750,"seen":252.4,"rssi":-29.9},
    {"hex":"ad9edf","flight":"AAL669  ","alt_baro":38000,"alt_geom":37750,"gs":368.8,"track":248.0,"baro_rate":0,"squawk":"6504","emergency":"none","category":"A3","nav_qnh":1013.6,"nav_altitude_mcp":38016,"nav_heading":232.0,"lat":35.893824,"lon":-112.363840,"nic":8,"rc":186,"seen_pos":19.8,"version":2,"nic_baro":1,"nac_p":9,"nac_v":1,"sil":3,"sil_type":"perhour","gva":2,"sda":2,"mlat":[],"tisb":[],"messages":1537,"seen":11.4,"rssi":-30.7},
    {"hex":"ab7a33","category":"A1","version":2,"sil_type":"perhour","mlat":[],"tisb":[],"messages":413,"seen":263.1,"rssi":-28.7},
    {"hex":"a517a1","flight":"SWA866  ","alt_baro":31000,"alt_geom":31250,"gs":279.7,"track":282.6,"baro_rate":1728,"squawk":"2645","emergency":"none","category":"A3","nav_qnh":1013.6,"nav_altitude_mcp":32000,"nav_heading":263.7,"lat":33.481300,"lon":-112.953522,"nic":8,"rc":186,"seen_pos":0.3,"version":2,"nic_baro":1,"nac_p":8,"nac_v":1,"sil":3,"sil_type":"perhour","gva":1,"sda":2,"mlat":[],"tisb":[],"messages":4738,"seen":0.1,"rssi":-8.2},
    {"hex":"abd77e","flight":"AAL2005 ","alt_baro":15425,"alt_geom":15325,"gs":265.2,"track":226.4,"baro_rate":-1280,"squawk":"1146","emergency":"none","category":"A3","nav_qnh":1009.6,"nav_altitude_mcp":4000,"nav_heading":220.8,"lat":33.944169,"lon":-111.323261,"nic":8,"rc":186,"seen_pos":1.6,"version":2,"nic_baro":1,"nac_p":9,"nac_v":1,"sil":3,"sil_type":"perhour","gva":2,"sda":2,"mlat":[],"tisb":[],"messages":4924,"seen":0.7,"rssi":-18.3},
    {"hex":"a7c2d8","flight":"JAS67   ","alt_baro":45000,"alt_geom":45325,"gs":458.4,"track":293.0,"baro_rate":-64,"squawk":"2731","emergency":"none","category":"A3","nav_qnh":1013.6,"nav_altitude_mcp":45024,"nav_modes":["autopilot","althold","tcas"],"lat":33.607224,"lon":-113.255253,"nic":8,"rc":186,"seen_pos":0.3,"version":2,"nic_baro":1,"nac_p":10,"nac_v":2,"sil":3,"sil_type":"perhour","gva":2,"sda":2,"mlat":[],"tisb":[],"messages":3809,"seen":0.0,"rssi":-9.5},
    {"hex":"ac8217","flight":"DAL2921 ","alt_baro":34000,"alt_geom":33875,"gs":350.3,"track":254.8,"baro_rate":0,"squawk":"5615","emergency":"none","category":"A3","nav_qnh":1013.6,"nav_altitude_mcp":34016,"nav_heading":248.9,"lat":34.900026,"lon":-111.611824,"nic":8,"rc":186,"seen_pos":1.0,"version":2,"nic_baro":1,"nac_p":10,"nac_v":2,"sil":3,"sil_type":"perhour","gva":2,"sda":2,"mlat":[],"tisb":[],"messages":8156,"seen":0.0,"rssi":-14.8},
    {"hex":"ab5f6a","flight":"SWA1763 ","alt_baro":25025,"alt_geom":25200,"gs":330.1,"track":271.0,"baro_rate":192,"squawk":"2604","emergency":"none","category":"A3","nav_qnh":1013.6,"nav_altitude_mcp":30016,"nav_heading":263.0,"lat":33.452159,"lon":-112.745231,"nic":8,"rc":186,"seen_pos":0.4,"version":2,"nic_baro":1,"nac_p":9,"nac_v":1,"sil":3,"sil_type":"perhour","gva":2,"sda":2,"mlat":[],"tisb":[],"messages":4165,"seen":0.1,"rssi":-4.2},
    {"hex":"ad4870","flight":"NKS2710 ","alt_baro":35050,"alt_geom":34825,"gs":551.2,"track":93.8,"baro_rate":0,"squawk":"6715","emergency":"none","category":"A3","nav_qnh":1012.8,"nav_altitude_mcp":35008,"lat":35.557068,"lon":-110.236130,"nic":8,"rc":186,"seen_pos":1.4,"version":2,"nic_baro":1,"nac_p":10,"nac_v":4,"sil":3,"sil_type":"perhour","gva":2,"sda":3,"mlat":[],"tisb":[],"messages":3827,"seen":1.2,"rssi":-24.0},
    {"hex":"a31533","category":"A3","version":2,"sil_type":"perhour","mlat":[],"tisb":[],"messages":1470,"seen":297.5,"rssi":-33.0},
    {"hex":"a569c4","flight":"EJM448  ","alt_baro":41000,"alt_geom":41275,"gs":561.0,"track":143.3,"geom_rate":64,"squawk":"1067","emergency":"none","category":"A2","lat":33.710943,"lon":-112.319870,"nic":8,"rc":186,"seen_pos":13.8,"version":2,"nic_baro":1,"nac_p":10,"nac_v":2,"sil":3,"sil_type":"perhour","gva":2,"sda":2,"mlat":[],"tisb":[],"messages":4683,"seen":5.3,"rssi":-19.7},
    {"hex":"a78daf","flight":"N586RF  ","alt_baro":6850,"alt_geom":6700,"gs":167.0,"track":299.0,"baro_rate":0,"squawk":"1557","emergency":"none","category":"A1","nav_qnh":1009.6,"nav_altitude_mcp":6496,"nav_modes":["althold"],"lat":33.011169,"lon":-112.792621,"nic":9,"rc":75,"seen_pos":2.2,"version":2,"nic_baro":1,"nac_p":10,"nac_v":2,"sil":3,"sil_type":"perhour","gva":2,"sda":2,"mlat":[],"tisb":[],"messages":1115,"seen":0.9,"rssi":-28.9},
    {"hex":"a47e59","flight":"N389SR  ","alt_baro":34975,"alt_geom":35375,"gs":569.0,"track":101.8,"geom_rate":64,"squawk":"6752","emergency":"none","category":"A2","nav_qnh":1012.8,"nav_altitude_mcp":35008,"nav_heading":92.8,"lat":33.216139,"lon":-113.082612,"nic":8,"rc":186,"seen_pos":0.2,"version":2,"nic_baro":1,"nac_p":10,"nac_v":1,"sil":3,"sil_type":"perhour","gva":2,"sda":2,"mlat":[],"tisb":[],"messages":7495,"seen":0.1,"rssi":-22.5},
    {"hex":"ad7828","alt_baro":21750,"category":"A3","version":2,"nic_baro":1,"nac_p":8,"sil":3,"sil_type":"perhour","gva":1,"sda":2,"mlat":[],"tisb":[],"messages":1674,"seen":2.4,"rssi":-10.8},
    {"hex":"a090a6","flight":"JSX470  ","alt_baro":19375,"alt_geom":19325,"gs":423.6,"track":44.5,"baro_rate":1024,"squawk":"0734","emergency":"none","category":"A2","nav_qnh":1013.6,"nav_altitude_mcp":28992,"lat":33.905717,"lon":-111.714821,"nic":8,"rc":186,"seen_pos":0.2,"version":2,"nic_baro":1,"nac_p":10,"nac_v":2,"sil":3,"sil_type":"perhour","gva":2,"sda":2,"mlat":[],"tisb":[],"messages":4507,"seen":0.2,"rssi":-11.5},
    {"hex":"a54d04","flight":"OXF3670 ","alt_baro":5050,"alt_geom":4850,"gs":90.4,"track":190.2,"baro_rate":-128,"squawk":"4672","category":"A1","lat":33.182144,"lon":-111.821649,"nic":9,"rc":75,"seen_pos":10.8,"version":2,"nic_baro":1,"nac_p":10,"nac_v":2,"sil":3,"sil_type":"perhour","gva":2,"sda":2,"mlat":[],"tisb":[],"messages":1770,"seen":10.8,"rssi":-11.7},
    {"hex":"a0a91e","flight":"UAL1407 ","alt_baro":30000,"alt_geom":29650,"gs":347.6,"track":273.3,"baro_rate":0,"squawk":"7470","emergency":"none","category":"A4","nav_qnh":1013.6,"nav_altitude_mcp":30016,"nav_heading":260.2,"lat":35.457303,"lon":-111.859930,"nic":8,"rc":186,"seen_pos":0.3,"version":2,"nic_baro":1,"nac_p":9,"nac_v":1,"sil":3,"sil_type":"perhour","gva":2,"sda":2,"mlat":[],"tisb":[],"messages":4741,"seen":0.2,"rssi":-28.1},
    {"hex":"abaf30","flight":"VAR452  ","alt_baro":4075,"alt_geom":3900,"gs":129.5,"track":329.9,"baro_rate":-64,"squawk":"2636","emergency":"none","category":"A1","nav_qnh":1011.2,"nav_altitude_mcp":2912,"lat":33.245636,"lon":-112.523730,"nic":9,"rc":75,"seen_pos":0.4,"version":2,"nic_baro":1,"nac_p":10,"nac_v":2,"sil":3,"sil_type":"perhour","gva":2,"sda":2,"mlat":[],"tisb":[],"messages":4124,"seen":0.3,"rssi":-8.8},
    {"hex":"a0e1b6","flight":"N156NS  ","alt_baro":25200,"alt_geom":25350,"gs":408.1,"track":66.8,"geom_rate":2304,"squawk":"1752","emergency":"none","category":"A2","nav_qnh":1012.8,"nav_altitude_mcp":31008,"nav_heading":47.8,"lat":33.731873,"lon":-111.143917,"nic":8,"rc":186,"seen_pos":43.4,"version":2,"nic_baro":1,"nac_p":10,"nac_v":1,"sil":3,"sil_type":"perhour","gva":2,"sda":2,"mlat":[],"tisb":[],"messages":3613,"seen":23.4,"rssi":-26.1},
    {"hex":"a287a4","alt_baro":35000,"alt_geom":35000,"gs":547.3,"track":91.9,"baro_rate":0,"category":"A3","lat":34.761115,"lon":-112.838287,"nic":8,"rc":186,"seen_pos":59.2,"version":2,"nac_v":2,"sil_type":"perhour","mlat":[],"tisb":[],"messages":2332,"seen":58.2,"rssi":-29.1},
    {"hex":"ad2573","flight":"SWA329  ","alt_baro":37000,"alt_geom":37425,"gs":571.3,"track":97.0,"baro_rate":128,"squawk":"2035","emergency":"none","category":"A3","nav_qnh":1013.6,"nav_altitude_mcp":39008,"nav_heading":80.9,"lat":33.084595,"lon":-113.791827,"nic":8,"rc":186,"seen_pos":1.0,"version":2,"nic_baro":1,"nac_p":8,"nac_v":1,"sil":3,"sil_type":"perhour","gva":1,"sda":2,"mlat":[],"tisb":[],"messages":8578,"seen":0.2,"rssi":-21.5},
    {"hex":"a6d5e2","flight":"N54DD   ","alt_baro":5100,"alt_geom":4850,"gs":231.8,"track":307.5,"baro_rate":-256,"squawk":"4253","emergency":"none","category":"A2","lat":33.228336,"lon":-111.945415,"nic":9,"rc":75,"seen_pos":2.8,"version":2,"nic_baro":1,"nac_p":10,"nac_v":2,"sil":3,"sil_type":"perhour","gva":2,"sda":2,"mlat":[],"tisb":[],"messages":955,"seen":2.8,"rssi":-11.4},
    {"hex":"a562e8","flight":"SWA2131 ","alt_baro":32775,"alt_geom":32875,"gs":327.9,"track":319.9,"baro_rate":832,"squawk":"0716","emergency":"none","category":"A3","nav_qnh":1013.6,"nav_altitude_mcp":36000,"nav_heading":298.1,"lat":34.285025,"lon":-112.593899,"nic":8,"rc":186,"seen_pos":0.2,"version":2,"nic_baro":1,"nac_p":8,"nac_v":1,"sil":3,"sil_type":"perhour","gva":1,"sda":2,"mlat":[],"tisb":[],"messages":5556,"seen":0.2,"rssi":-18.3},
    {"hex":"a42e3f","flight":"SIS369  ","alt_baro":47000,"alt_geom":47450,"gs":371.5,"track":305.4,"baro_rate":128,"squawk":"4301","emergency":"none","category":"A2","nav_qnh":1013.6,"nav_altitude_mcp":47008,"nav_modes":["autopilot","althold","tcas"],"lat":31.781204,"lon":-114.181842,"nic":8,"rc":186,"seen_pos":0.3,"version":2,"nic_baro":1,"nac_p":10,"nac_v":2,"sil":3,"sil_type":"perhour","gva":2,"sda":2,"mlat":[],"tisb":[],"messages":2964,"seen":0.3,"rssi":-21.6},
    {"hex":"a1ff46","category":"A3","version":2,"sil_type":"perhour","mlat":[],"tisb":[],"messages":4862,"seen":188.8,"rssi":-31.9},
    {"hex":"acd675","alt_baro":7825,"alt_geom":7700,"gs":205.9,"track":215.3,"baro_rate":-1216,"squawk":"6556","emergency":"none","category":"A3","nav_qnh":1009.6,"nav_altitude_mcp":4000,"nav_heading":210.9,"lat":33.574870,"lon":-111.665440,"nic":8,"rc":186,"seen_pos":10.5,"version":2,"nic_baro":1,"nac_p":8,"nac_v":1,"sil":3,"sil_type":"perhour","gva":1,"sda":2,"mlat":[],"tisb":[],"messages":3778,"seen":9.2,"rssi":-17.7},
    {"hex":"a043ec","flight":"N116QS  ","alt_baro":36725,"alt_geom":37100,"gs":341.4,"track":267.1,"geom_rate":1792,"squawk":"4146","emergency":"none","category":"A3","nav_qnh":1012.8,"nav_altitude_mcp":40000,"nav_heading":260.9,"lat":33.700980,"lon":-113.214169,"nic":8,"rc":186,"seen_pos":0.1,"version":2,"nic_baro":1,"nac_p":11,"nac_v":1,"sil":3,"sil_type":"perhour","gva":2,"sda":2,"mlat":[],"tisb":[],"messages":8264,"seen":0.0,"rssi":-17.8},
    {"hex":"a82a75","flight":"SWQ3523 ","alt_baro":21150,"alt_geom":21225,"gs":308.2,"track":271.9,"baro_rate":-512,"squawk":"2516","emergency":"none","category":"A3","nav_qnh":1013.6,"nav_altitude_mcp":16000,"nav_heading":263.0,"lat":32.792267,"lon":-112.810968,"nic":8,"rc":186,"seen_pos":0.3,"version":2,"nic_baro":1,"nac_p":9,"nac_v":2,"sil":3,"sil_type":"perhour","gva":2,"sda":2,"mlat":[],"tisb":[],"messages":2795,"seen":0.2,"rssi":-12.2},
    {"hex":"abec6c","flight":"SWA1285 ","alt_baro":30000,"alt_geom":29700,"gs":344.0,"track":278.7,"baro_rate":0,"squawk":"0721","emergency":"none","category":"A3","nav_qnh":1013.6,"nav_altitude_mcp":30016,"nav_heading":265.8,"lat":35.483512,"lon":-112.080357,"nic":8,"rc":186,"seen_pos":0.1,"version":2,"nic_baro":1,"nac_p":9,"nac_v":1,"sil":3,"sil_type":"perhour","gva":2,"sda":2,"mlat":[],"tisb":[],"messages":6758,"seen":0.1,"rssi":-26.5},
    {"hex":"a4acae","alt_baro":"ground","gs":0.0,"true_heading":267.2,"squawk":"2765","emergency":"none","category":"A3","lat":33.436890,"lon":-112.001481,"nic":8,"rc":186,"seen_pos":3.6,"version":2,"sil_type":"perhour","mlat":[],"tisb":[],"messages":69,"seen":3.6,"rssi":-15.9},
    {"hex":"a43bcc","alt_baro":45000,"category":"A2","lat":35.007706,"lon":-112.988836,"nic":8,"rc":186,"seen_pos":35.2,"version":2,"sil_type":"perhour","mlat":[],"tisb":[],"messages":5112,"seen":21.4,"rssi":-29.1},
    {"hex":"abad94","flight":"SWA2322 ","alt_baro":31000,"alt_geom":30875,"gs":554.4,"track":74.4,"baro_rate":0,"squawk":"6756","emergency":"none","category":"A3","nav_qnh":1013.6,"nav_altitude_mcp":31008,"nav_heading":54.1,"lat":34.812057,"lon":-112.001523,"nic":8,"rc":186,"seen_pos":0.9,"version":2,"nic_baro":1,"nac_p":8,"nac_v":1,"sil":3,"sil_type":"perhour","gva":1,"sda":2,"mlat":[],"tisb":[],"messages":7131,"seen":0.5,"rssi":-19.4},
    {"hex":"abdd09","flight":"SWA1535 ","alt_baro":32025,"alt_geom":32375,"gs":336.6,"track":261.6,"baro_rate":0,"squawk":"2615","emergency":"none","category":"A3","nav_qnh":1013.6,"nav_altitude_mcp":32000,"nav_heading":260.2,"lat":33.090634,"lon":-113.125436,"nic":8,"rc":186,"seen_pos":0.4,"version":2,"nic_baro":1,"nac_p":9,"nac_v":1,"sil":3,"sil_type":"perhour","gva":2,"sda":2,"mlat":[],"tisb":[],"messages":6308,"seen":0.0,"rssi":-23.1},
    {"hex":"ac712d","flight":"SWA400  ","alt_baro":9725,"alt_geom":9600,"gs":336.9,"track":83.9,"baro_rate":-1536,"squawk":"6766","emergency":"none","category":"A3","nav_qnh":1009.6,"nav_altitude_mcp":7008,"nav_heading":4.2,"lat":33.338013,"lon":-112.201227,"nic":8,"rc":186,"seen_pos":0.3,"version":2,"nic_baro":1,"nac_p":8,"nac_v":1,"sil":3,"sil_type":"perhour","gva":1,"sda":2,"mlat":[],"tisb":[],"messages":8842,"seen":0.1,"rssi":-2.7},
    {"hex":"a67399","flight":"GTI3645 ","alt_baro":36300,"alt_geom":36650,"gs":318.1,"track":274.9,"baro_rate":-1088,"squawk":"7321","emergency":"none","category":"A3","nav_qnh":1013.6,"nav_altitude_mcp":30016,"nav_heading":269.3,"lat":33.712830,"lon":-113.416237,"nic":8,"rc":186,"seen_pos":0.3,"version":2,"nic_baro":1,"nac_p":10,"nac_v":1,"sil":3,"sil_type":"perhour","gva":2,"sda":2,"mlat":[],"tisb":[],"messages":5643,"seen":0.1,"rssi":-16.0},
    {"hex":"a359bc","flight":"DAL1556 ","alt_baro":33075,"alt_geom":33025,"gs":562.9,"track":81.0,"baro_rate":896,"squawk":"6703","emergency":"none","category":"A3","nav_altitude_mcp":35008,"nav_heading":0.0,"lat":34.363678,"lon":-111.048459,"nic":8,"rc":186,"seen_pos":0.3,"version":2,"nic_baro":1,"nac_p":9,"nac_v":1,"sil":3,"sil_type":"perhour","gva":2,"sda":2,"mlat":[],"tisb":[],"messages":11632,"seen":0.3,"rssi":-17.2},
    {"hex":"a66f82","flight":"N5134K  ","alt_baro":36350,"alt_geom":1750,"gs":71.6,"track":26.6,"geom_rate":-576,"squawk":"1200","emergency":"none","category":"A1","lat":33.244720,"lon":-111.841095,"nic":9,"rc":75,"seen_pos":49.5,"version":2,"nic_baro":0,"nac_p":9,"nac_v":1,"sil":3,"sil_type":"perhour","gva":2,"sda":2,"mlat":[],"tisb":[],"messages":935,"seen":4.1,"rssi":-20.2},
    {"hex":"ac101f","flight":"SWA2723 ","alt_baro":37000,"alt_geom":37450,"gs":548.4,"track":96.4,"baro_rate":128,"squawk":"7237","emergency":"none","category":"A3","nav_qnh":1013.6,"nav_altitude_mcp":36992,"nav_heading":80.9,"lat":32.731567,"lon":-111.882678,"nic":8,"rc":186,"seen_pos":0.1,"version":2,"nic_baro":1,"nac_p":10,"nac_v":2,"sil":3,"sil_type":"perhour","gva":2,"sda":2,"mlat":[],"tisb":[],"messages":9691,"seen":0.1,"rssi":-19.2},
    {"hex":"a36898","flight":"DAL708  ","alt_baro":33050,"alt_geom":32900,"gs":548.2,"track":75.2,"baro_rate":-64,"squawk":"6743","emergency":"none","category":"A3","nav_altitude_mcp":32992,"nav_heading":0.0,"lat":35.017105,"lon":-111.081448,"nic":8,"rc":186,"seen_pos":0.3,"version":2,"nic_baro":1,"nac_p":9,"nac_v":1,"sil":3,"sil_type":"perhour","gva":2,"sda":2,"mlat":[],"tisb":[],"messages":11516,"seen":0.1,"rssi":-20.4},
    {"hex":"a01c37","flight":"AAL171  ","alt_baro":36000,"alt_geom":35975,"gs":345.6,"track":261.7,"baro_rate":0,"squawk":"1762","emergency":"none","category":"A3","nav_altitude_mcp":36000,"nav_heading":0.0,"lat":34.649156,"lon":-112.932072,"nic":8,"rc":186,"seen_pos":0.1,"version":2,"nic_baro":1,"nac_p":9,"nac_v":1,"sil":3,"sil_type":"perhour","gva":2,"sda":2,"mlat":[],"tisb":[],"messages":11684,"seen":0.1,"rssi":-22.4},
    {"hex":"a67d17","flight":"SKW3107 ","alt_baro":38000,"alt_geom":38025,"gs":338.1,"track":262.2,"baro_rate":-64,"squawk":"2321","emergency":"none","category":"A3","nav_qnh":1013.6,"nav_altitude_mcp":38016,"nav_modes":["autopilot","vnav","tcas"],"lat":34.703436,"lon":-112.474365,"nic":8,"rc":186,"seen_pos":28.1,"version":2,"nic_baro":1,"nac_p":10,"nac_v":2,"sil":3,"sil_type":"perhour","gva":2,"sda":2,"mlat":[],"tisb":[],"messages":10353,"seen":15.2,"rssi":-26.8},
    {"hex":"a1d93b","category":"A3","version":2,"sil_type":"perhour","mlat":[],"tisb":[],"messages":3080,"seen":182.0,"rssi":-15.3},
    {"hex":"a35dfc","flight":"N316K   ","alt_baro":41000,"alt_geom":40925,"gs":530.9,"track":73.5,"geom_rate":128,"squawk":"7210","emergency":"none","category":"A2","nav_qnh":1012.8,"nav_altitude_mcp":40992,"nav_heading":104.8,"lat":35.449296,"lon":-110.748733,"nic":8,"rc":186,"seen_pos":0.8,"version":2,"nic_baro":1,"nac_p":10,"nac_v":1,"sil":3,"sil_type":"perhour","gva":2,"sda":2,"mlat":[],"tisb":[],"messages":10362,"seen":0.3,"rssi":-24.4},
    {"hex":"a5d007","flight":"ASA637  ","alt_baro":34000,"alt_geom":33750,"gs":380.9,"track":337.1,"baro_rate":0,"squawk":"4120","emergency":"none","category":"A3","nav_qnh":1013.6,"nav_altitude_mcp":34016,"nav_heading":315.7,"lat":35.421924,"lon":-112.160651,"nic":8,"rc":186,"seen_pos":0.4,"version":2,"nic_baro":1,"nac_p":9,"nac_v":1,"sil":3,"sil_type":"perhour","gva":2,"sda":2,"mlat":[],"tisb":[],"messages":10404,"seen":0.4,"rssi":-30.6},
    {"hex":"a33222","flight":"ENY3835 ","alt_baro":"ground","gs":20.5,"true_heading":90.0,"category":"A3","lat":33.429955,"lon":-112.016451,"nic":8,"rc":186,"seen_pos":40.8,"version":2,"sil_type":"perhour","mlat":[],"tisb":[],"messages":2563,"seen":26.5,"rssi":-2.5},
    {"hex":"add3dc","flight":"AAL2599 ","alt_baro":35000,"alt_geom":34850,"gs":542.0,"track":89.5,"baro_rate":-64,"squawk":"1371","emergency":"none","category":"A3","nav_qnh":1013.6,"nav_altitude_mcp":35008,"nav_heading":64.7,"lat":34.964813,"lon":-110.490062,"nic":8,"rc":186,"seen_pos":0.4,"version":2,"nic_baro":1,"nac_p":9,"nac_v":1,"sil":3,"sil_type":"perhour","gva":2,"sda":2,"mlat":[],"tisb":[],"messages":8921,"seen":0.0,"rssi":-23.5},
    {"hex":"a4d7e4","alt_baro":24975,"category":"A3","lat":32.766444,"lon":-111.050926,"nic":8,"rc":186,"seen_pos":12.5,"version":2,"sil_type":"perhour","mlat":[],"tisb":[],"messages":9387,"seen":12.5,"rssi":-24.7},
    {"hex":"aa77c0","flight":"SWA2624 ","alt_baro":1200,"gs":11.2,"track":227.8,"true_heading":112.5,"category":"A3","version":2,"nac_p":8,"nac_v":1,"sil":3,"sil_type":"perhour","sda":2,"mlat":[],"tisb":[],"messages":3635,"seen":5.2,"rssi":-3.8},
    {"hex":"a9854e","flight":"AAL2570 ","alt_baro":37975,"alt_geom":38250,"gs":342.1,"track":291.6,"baro_rate":64,"squawk":"2420","emergency":"none","category":"A3","nav_qnh":1012.8,"nav_altitude_mcp":38016,"lat":33.371577,"lon":-112.952962,"nic":8,"rc":186,"seen_pos":0.2,"version":2,"nic_baro":1,"nac_p":9,"nac_v":1,"sil":3,"sil_type":"perhour","gva":2,"sda":2,"mlat":[],"tisb":[],"messages":4647,"seen":0.2,"rssi":-5.8},
    {"hex":"aa9bc1","flight":"ABX800  ","alt_baro":40000,"alt_geom":40150,"gs":364.7,"track":240.1,"baro_rate":128,"squawk":"6751","emergency":"none","category":"A5","nav_qnh":1013.6,"nav_altitude_mcp":40000,"nav_heading":239.1,"lat":34.788208,"lon":-114.680674,"nic":8,"rc":186,"seen_pos":0.1,"version":2,"nic_baro":1,"nac_p":10,"nac_v":2,"sil":3,"sil_type":"perhour","gva":2,"sda":3,"mlat":[],"tisb":[],"messages":3920,"seen":0.0,"rssi":-25.3},
    {"hex":"a86ddf","flight":"NKS1783 ","alt_baro":36975,"alt_geom":36900,"gs":529.6,"track":68.9,"baro_rate":64,"squawk":"1361","emergency":"none","category":"A3","nav_qnh":1012.8,"nav_altitude_mcp":36992,"lat":35.226791,"lon":-110.872510,"nic":8,"rc":186,"seen_pos":0.7,"version":2,"nic_baro":1,"nac_p":10,"nac_v":4,"sil":3,"sil_type":"perhour","gva":2,"sda":2,"mlat":[],"tisb":[],"messages":11202,"seen":0.1,"rssi":-28.3},
    {"hex":"ac984c","alt_baro":"ground","squawk":"1640","emergency":"none","category":"A2","version":2,"nac_p":10,"nac_v":2,"sil":3,"sil_type":"perhour","sda":2,"mlat":[],"tisb":[],"messages":250,"seen":20.0,"rssi":-30.2},
    {"hex":"abf2c2","category":"A3","version":2,"sil_type":"perhour","mlat":[],"tisb":[],"messages":13401,"seen":227.7,"rssi":-28.0},
    {"hex":"abef79","alt_baro":"ground","gs":5.8,"track":165.9,"true_heading":16.9,"squawk":"2054","emergency":"none","category":"A3","lat":33.433177,"lon":-112.002448,"nic":8,"rc":186,"seen_pos":4.7,"version":2,"nac_p":9,"nac_v":1,"sil":3,"sil_type":"perhour","sda":2,"mlat":[],"tisb":[],"messages":4047,"seen":4.7,"rssi":-12.3},
    {"hex":"a22839","flight":"SWA599  ","alt_baro":31600,"alt_geom":32025,"gs":342.1,"track":271.5,"baro_rate":-896,"squawk":"2706","emergency":"none","category":"A3","nav_qnh":1013.6,"nav_altitude_mcp":24000,"nav_heading":270.0,"lat":32.876450,"lon":-114.613495,"nic":8,"rc":186,"seen_pos":0.2,"version":2,"nic_baro":1,"nac_p":8,"nac_v":1,"sil":3,"sil_type":"perhour","gva":1,"sda":2,"mlat":[],"tisb":[],"messages":10352,"seen":0.0,"rssi":-21.7},
    {"hex":"aa28f2","category":"A5","version":2,"sil_type":"perhour","mlat":[],"tisb":[],"messages":11142,"seen":84.0,"rssi":-30.1},
    {"hex":"a542d7","alt_baro":1150,"alt_geom":1000,"gs":133.0,"track":270.4,"baro_rate":-128,"squawk":"3363","emergency":"none","category":"A3","nav_qnh":1009.6,"nav_altitude_mcp":0,"nav_heading":258.0,"lat":33.428883,"lon":-112.007017,"nic":8,"rc":186,"seen_pos":6.1,"version":2,"nic_baro":1,"nac_p":8,"nac_v":1,"sil":3,"sil_type":"perhour","gva":1,"sda":2,"mlat":[],"tisb":[],"messages":10973,"seen":0.3,"rssi":-2.3},
    {"hex":"a8754d","flight":"NKS721  ","alt_baro":"ground","gs":0.1,"true_heading":270.0,"squawk":"7411","emergency":"none","category":"A3","lat":33.432884,"lon":-112.006439,"nic":8,"rc":186,"seen_pos":4.4,"version":2,"nac_p":10,"nac_v":4,"sil":3,"sil_type":"perhour","sda":2,"mlat":[],"tisb":[],"messages":4969,"seen":0.7,"rssi":-8.9},
    {"hex":"adc8e7","category":"A3","version":2,"sil_type":"perhour","mlat":[],"tisb":[],"messages":14838,"seen":262.6,"rssi":-22.1},
    {"hex":"a280fe","flight":"SWA3040 ","alt_baro":32600,"alt_geom":32500,"gs":467.4,"track":32.8,"baro_rate":704,"squawk":"2623","emergency":"none","category":"A3","nav_qnh":1013.6,"nav_altitude_mcp":32992,"nav_heading":258.0,"lat":34.569040,"lon":-111.162472,"nic":8,"rc":186,"seen_pos":0.9,"version":2,"nic_baro":1,"nac_p":10,"nac_v":2,"sil":3,"sil_type":"perhour","gva":2,"sda":2,"mlat":[],"tisb":[],"messages":8427,"seen":0.1,"rssi":-18.0},
    {"hex":"ac2813","category":"A3","version":2,"sil_type":"perhour","mlat":[],"tisb":[],"messages":15249,"seen":178.5,"rssi":-28.5},
    {"hex":"adca6c","flight":"TWY201  ","alt_baro":30000,"alt_geom":30325,"gs":347.5,"track":276.9,"geom_rate":64,"category":"A2","nav_qnh":1012.8,"nav_altitude_mcp":30016,"nav_heading":269.3,"lat":33.830795,"lon":-115.070128,"nic":8,"rc":186,"seen_pos":48.0,"version":2,"nic_baro":1,"nac_p":10,"nac_v":1,"sil":3,"sil_type":"perhour","mlat":[],"tisb":[],"messages":16114,"seen":1.6,"rssi":-32.5},
    {"hex":"a3dfeb","flight":"DAL1216 ","alt_baro":38000,"alt_geom":38275,"gs":333.8,"track":281.6,"baro_rate":0,"squawk":"7315","emergency":"none","category":"A3","nav_qnh":1013.6,"nav_altitude_mcp":38016,"nav_heading":0.0,"lat":33.937454,"lon":-114.300525,"nic":8,"rc":186,"seen_pos":0.8,"version":2,"nic_baro":1,"nac_p":9,"nac_v":1,"sil":3,"sil_type":"perhour","gva":2,"sda":2,"mlat":[],"tisb":[],"messages":11817,"seen":0.1,"rssi":-13.3},
    {"hex":"aaf0c6","category":"A5","version":2,"sil_type":"perhour","mlat":[],"tisb":[],"messages":14243,"seen":112.6,"rssi":-30.0},
    {"hex":"ad3c1f","category":"A3","version":2,"sil_type":"perhour","mlat":[],"tisb":[],"messages":10428,"seen":75.4,"rssi":-30.8},
    {"hex":"a73f35","flight":"SWA2476 ","alt_baro":"ground","gs":0.5,"true_heading":90.0,"squawk":"1377","emergency":"none","category":"A3","lat":33.432153,"lon":-112.001607,"nic":8,"rc":186,"seen_pos":21.5,"version":2,"nac_p":8,"nac_v":1,"sil":3,"sil_type":"perhour","sda":2,"mlat":[],"tisb":[],"messages":15812,"seen":1.9,"rssi":-7.9},
    {"hex":"a36218","alt_baro":1600,"alt_geom":1375,"gs":69.2,"track":85.9,"geom_rate":0,"squawk":"1200","emergency":"none","category":"A1","version":2,"nac_v":2,"sil_type":"perhour","mlat":[],"tisb":[],"messages":4729,"seen":5.5,"rssi":-30.5},
    {"hex":"a0cbd6","flight":"SKW5264 ","alt_baro":38000,"alt_geom":38350,"gs":291.5,"track":292.2,"baro_rate":320,"squawk":"4111","emergency":"none","category":"A3","nav_qnh":1013.6,"nav_altitude_mcp":38016,"nav_modes":["autopilot","vnav","tcas"],"lat":34.104961,"lon":-115.181522,"nic":8,"rc":186,"seen_pos":0.7,"version":2,"nic_baro":1,"nac_p":10,"nac_v":2,"sil":3,"sil_type":"perhour","gva":2,"sda":2,"mlat":[],"tisb":[],"messages":21313,"seen":0.0,"rssi":-26.8},
    {"hex":"a13972","flight":"N1781T  ","alt_baro":2600,"alt_geom":2425,"gs":86.4,"track":132.2,"baro_rate":-512,"squawk":"7421","category":"A1","nav_qnh":1010.4,"nav_altitude_mcp":2592,"lat":33.316133,"lon":-111.639423,"nic":9,"rc":75,"seen_pos":42.0,"version":2,"nic_baro":1,"nac_p":10,"nac_v":2,"sil":3,"sil_type":"perhour","mlat":[],"tisb":[],"messages":1398,"seen":1.5,"rssi":-16.5},
    {"hex":"a037b9","category":"A3","version":2,"sil_type":"perhour","mlat":[],"tisb":[],"messages":16656,"seen":76.2,"rssi":-32.7},
    {"hex":"a85caa","category":"A3","version":2,"sil_type":"perhour","mlat":[],"tisb":[],"messages":15667,"seen":108.0,"rssi":-33.2},
    {"hex":"adfbdd","type":"adsb_icao_nt","flight":"TEST1234","category":"C0","version":0,"mlat":[],"tisb":[],"messages":13559,"seen":7.9,"rssi":-2.0}
  ]
}