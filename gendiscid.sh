#!/bin/bash

show_help() {
        echo "Generate Discid for MusicBrainz" >&2
        echo "$0 [-h] [-f FIRSTTRACKNUMBER] [-t] -d DEVICE_FILE" >&2
        echo "" >&2
	echo "-f: put first track number. default value is 1" >&2
	echo "-t: generate TOC format for MusicBrainz" >&2
        echo "-h: show this." >&2
}

FIRSTTRACKNUMBER=1

OPTINT=1

TOCMODE=0

DEVICE_FILE=''

while getopts "h?f:td:" opt; do
	case "${opt}" in
		h|\?)
			show_help
			exit 0
			;;
		f)
			FIRSTTRACKNUMBER=${OPTARG}
			;;
		t)
			TOCMODE=1
			;;
		d)
			DEVICE_FILE=${OPTARG}
			;;
	esac
done

shift $((OPTINT-1))


if [ -z ${DEVICE_FILE} ]; then
        show_help
        exit 0
fi

OFFSETS=(`cd-discid --musicbrainz ${DEVICE_FILE}`)

LASTTRACKNUMBER=${OFFSETS[0]}
LEADOUTOFFSETINDEX=$((${#OFFSETS[@]}-1))

# Construction of base data for SHA-1 with binary mode.
#
# 1. Start track number as 1 Byte with HEX uppercase and zero-padding format.
# 2. Last track number as the same above.
# 3. Lead out offset as 4 Bytes with HEX uppercase and zero-padding format.
# 4. Track offest from 1 to 99 as the same above but 0 if the track nonexist.
#
# cd-discid command return following format:
# >	[LAST_TRACK_NUMBER] [FST_TRACK_OFFSET] [SND_TRACK_OFFSET] ... [LEAD_OUT_OFFSET]
# Thus, need to reorganize OFFSET array with remove and insert last LEAD_OUT_OFFSET column between LAST_TRACK_NUMBER and FST_TRACK_OFFSET.
REOFFSETS=(`echo "${OFFSETS[0]} ${OFFSETS[${LEADOUTOFFSETINDEX}]} ${OFFSETS[@]:1:${LASTTRACKNUMBER}}"`)

SHA1BASE=`printf "%02X%02X" ${FIRSTTRACKNUMBER} ${LASTTRACKNUMBER}`

EMPTYOFFSET=0

for INDEX in `seq 1 100`; do
	if [ ${#REOFFSETS[@]} -gt ${INDEX} ]; then
		SHA1BASE=${SHA1BASE}`printf "%08X" ${REOFFSETS[${INDEX}]}`
	else
		SHA1BASE=${SHA1BASE}`printf "%08X" ${EMPTYOFFSET}`
	fi
done

# base data to SHA-1 with 28 characters (not 56 chars) by interpreted as binary expression.
SHA1STRING=`echo -n ${SHA1BASE} | openssl sha1 -binary`
# SHA-1 string to Base64 string with replacing escape characters.
DISCID=`echo -n ${SHA1STRING}  | base64 | sed "s/\+/\./g" | sed "s/\//_/g" | sed "s/=/-/g"`

if [ ${TOCMODE} -eq 1 ]; then

	echo "${FIRSTTRACKNUMBER} ${REOFFSETS[@]}" | sed "s/ /+/g"
else

	echo ${DISCID}
fi


