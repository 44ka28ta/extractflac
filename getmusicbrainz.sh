#!/bin/bash

show_help() {
        echo "Get Disk Infomation from MusicBrainz" >&2
        echo "$0 [-h] [-f FIRSTTRACKNUMBER] -c TARGET_CUE_PATH -d DEVICE_FILE" >&2
        echo "" >&2
	echo "-f: put first track number. default value is 1" >&2
	echo "-d: device file" >&2
	echo "-c: target CUE sheet path" >&2
        echo "-h: show this." >&2
}

get_element_with_xpath() {
	local ELEMENTSTR=$(xmllint --shell $1 <<EOF
setrootns http://musicbrainz.org/ns/mmd-2.0#
cat $2
bye
EOF
)

	local ELEMENTSTR=`echo "${ELEMENTSTR}" | grep -E "$3" | sed -E "s/^.*$3(.*)$4.*$/\1/"`

	# Fifth argument is defined return value.
	local -n ELEMENTS=$5


	while read LINE; do

		ELEMENTS+=("`echo "${LINE}" | sed 's/\&amp\;/\&/g; s/\&lt\;/\</g; s/\&gt\;/\>/g; s/\&quot\;/\"/g; s/\&apos\;/'\''/g'`")

	done <<< ${ELEMENTSTR}

}

FIRSTTRACKNUMBER=1

OPTINT=1

DEVICE_FILE=''
TARGET_CUE_PATH=''

while getopts "h?f:d:c:" opt; do
	case "${opt}" in
		h|\?)
			show_help
			exit 0
			;;
		f)
			FIRSTTRACKNUMBER=${OPTARG}
			;;
		d)
			DEVICE_FILE=${OPTARG}
			;;
		c)
			TARGET_CUE_PATH=${OPTARG}
			;;
	esac
done

shift $((OPTINT-1))

SCRIPT_PARENT=`dirname ${0}`

if [ -z "${DEVICE_FILE}" ]; then
        show_help
        exit 0
fi

if [ -z "${TARGET_CUE_PATH}" ]; then
	show_help
	exit 0
fi

if [ ${FIRSTTRACKNUMBER} -ne 1 ]; then

	DISCID=`sh ${SCRIPT_PARENT}/gendiscid.sh -f ${FIRSTTRACKNUMBER} -d ${DEVICE_FILE}`
else

	DISCID=`sh ${SCRIPT_PARENT}/gendiscid.sh -d ${DEVICE_FILE}`
fi

#
#DISCID="XtGRGo2.lfgx3ik_4Hcw6jiCLsE-"
#TOC="1+8+186574+150+30624+51193+74815+100962+121553+139527+166943"
#

#
#DISCID="9WK5TEsoQiKcT1iTkhgiTyp2fKs-"
#TOC="1+8+172688+150+19618+27537+55184+76519+96628+116805+143552"
#

DUMPFILENAME=`basename ${DEVICE_FILE}``cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1`
MUSICBRAINZXMLNAME=${DUMPFILENAME}.xml

curl -X GET https://musicbrainz.org/ws/2/discid/${DISCID}?inc=artists+recordings | xmllint --format - > ${MUSICBRAINZXMLNAME}

#MUSICBRAINZXMLNAME="aabCMzEgXUcL5AMgW0.xml"
#MUSICBRAINZXMLNAME="test.xml"

RELEASEIDS=()

get_element_with_xpath ${MUSICBRAINZXMLNAME} "//defaultns:disc[@id=\"${DISCID}\"]/ancestor::defaultns:release/@id" "^\s*id=\"" "\"" RELEASEIDS

ALBUMTITLES=()

get_element_with_xpath ${MUSICBRAINZXMLNAME} "//defaultns:disc[@id=\"${DISCID}\"]/ancestor::defaultns:medium-list/preceding-sibling::defaultns:title" "^\s*<title>" "<\/title>" ALBUMTITLES

ARTISTS=()

get_element_with_xpath ${MUSICBRAINZXMLNAME} "//defaultns:disc[@id=\"${DISCID}\"]/ancestor::defaultns:medium-list/preceding-sibling::defaultns:artist-credit/descendant::defaultns:name" "<name>" "<\/name>" ARTISTS

DISCNUMBERS=()

get_element_with_xpath ${MUSICBRAINZXMLNAME} "//defaultns:disc[@id=\"${DISCID}\"]/ancestor::defaultns:medium/defaultns:position" "^\s*<position>" "<\/position>" DISCNUMBERS

TOTALDISCS=()

get_element_with_xpath ${MUSICBRAINZXMLNAME} "//defaultns:disc[@id=\"${DISCID}\"]/ancestor::defaultns:medium-list/@count" "^\s*count=\"" "\"" TOTALDISCS

RELEASEDATES=()

get_element_with_xpath ${MUSICBRAINZXMLNAME} "//defaultns:disc[@id=\"${DISCID}\"]/ancestor::defaultns:release/defaultns:date" "^\s*<date>" "<\/date>" RELEASEDATES

COUNTRIES=()

get_element_with_xpath ${MUSICBRAINZXMLNAME} "//defaultns:disc[@id=\"${DISCID}\"]/ancestor::defaultns:release/defaultns:country" "^\s*<country>" "<\/country>" COUNTRIES


CATALOGS=()

get_element_with_xpath ${MUSICBRAINZXMLNAME} "//defaultns:disc[@id=\"${DISCID}\"]/ancestor::defaultns:release/defaultns:barcode" "^\s*<barcode>" "<\/barcode>" CATALOGS


UPPERBOUNDINDEX=$((${#ALBUMTITLES[@]}-1))

if [ ${UPPERBOUNDINDEX} -lt 1 ]; then

	echo "There is no artist and album title. ${UPPERBOUNDINDEX}" >&2
	exit 1
fi

for INDEX in `seq 0 ${UPPERBOUNDINDEX}`; do

	TOTALDISCNUMBER=$((${TOTALDISCS[${INDEX}]}))

	if [ -z "${DISCNUMBERS[${INDEX}]}" ] || [ -z ${TOTALDISCNUMBER} ] || [ ${TOTALDISCNUMBER} -lt 2 ]; then

		echo "[${INDEX}]: ${ARTISTS[${INDEX}]} - ${ALBUMTITLES[${INDEX}]} (Release: ${RELEASEDATES[${INDEX}]} Country: ${COUNTRIES[${INDEX}]} ID: ${RELEASEIDS[${INDEX}]})"
	else
		echo "[${INDEX}]: ${ARTISTS[${INDEX}]} - ${ALBUMTITLES[${INDEX}]} Disc ${DISCNUMBERS[${INDEX}]}  (Release: ${RELEASEDATES[${INDEX}]} Country: ${COUNTRIES[${INDEX}]} ID: ${RELEASEIDS[${INDEX}]})"
	fi
done

echo -n "please select the number of album title: "
read SELECTEDNUMBER

SELECTEDNUMBER=$((${SELECTEDNUMBER}))

if ! [[ "${SELECTEDNUMBER}" =~ ^[0-9]+$ ]] ; then

	echo "Not number. Force to select 0." >&2
	SELECTEDNUMBER=0

elif [ "${SELECTEDNUMBER}" -gt "${UPPERBOUNDINDEX}" ]; then

	echo "Larger than bounds. Force to select ${UPPERBOUNDINDEX}." >&2
	SELECTEDNUMBER=${UPPERBOUNDINDEX}

elif [ "${SELECTEDNUMBER}" -lt 0 ]; then
	
	echo "Less than bounds. Force to select 0." >&2
	SELECTEDNUMBER=0
fi

if [ -z "${ARTISTS[${SELECTEDNUMBER}]}" ] || [ -z "${ALBUMTITLES[${SELECTEDNUMBER}]}" ]; then

	echo "There is no artist and album title." >&2
	exit 1
fi

TITLES=()

get_element_with_xpath ${MUSICBRAINZXMLNAME} "//defaultns:release[@id=\"${RELEASEIDS[${SELECTEDNUMBER}]}\"]/descendant::defaultns:medium/defaultns:position[text()=\"${DISCNUMBERS[${SELECTEDNUMBER}]}\"]/following-sibling::defaultns:track-list/defaultns:track/defaultns:recording/defaultns:title" "^\s*<title>" "<\/title>" TITLES


TRACKNUMBERS=()

get_element_with_xpath ${MUSICBRAINZXMLNAME} "//defaultns:release[@id=\"${RELEASEIDS[${SELECTEDNUMBER}]}\"]/descendant::defaultns:medium/defaultns:position[text()=\"${DISCNUMBERS[${SELECTEDNUMBER}]}\"]/following-sibling::defaultns:track-list/defaultns:track/defaultns:number" "^\s*<number>" "<\/number>" TRACKNUMBERS

for INDEX in `seq 0 $((${#TRACKNUMBERS[@]}-1))`; do

	echo -e "\tTrack${TRACKNUMBERS[${INDEX}]}: \t${TITLES[${INDEX}]}"
done

DUMPCUEFILENAME=${DUMPFILENAME}.cue

FILECNT=0
TRACKCNT=0
INDEXCNT=0
TITLECNT=0
PERFORMERCNT=0

while read LINE; do

	CUECOMMAND=`echo ${LINE} | cut -d" " -f1`
	if [[ ${CUECOMMAND} == "FILE" ]]; then

		FILECNT=$((FILECNT+1))

	elif [[ ${CUECOMMAND} == "TRACK" ]]; then
		
		TRACKCNT=$((TRACKCNT+1))

	elif [[ ${CUECOMMAND} == "INDEX" ]]; then

		INDEXCNT=$((INDEXCNT+1))

	elif [[ ${CUECOMMAND} == "TITLE" ]]; then

		TITLECNT=$((TITLECNT+1))

	elif [[ ${CUECOMMAND} == "PERFORMER" ]]; then

		PERFORMERCNT=$((PERFORMERCNT+1))
	fi

done < ${TARGET_CUE_PATH}

if [ ${FILECNT} -ne 1 ] || [ ${TRACKCNT} -ne ${INDEXCNT} ] || [ ${TRACKCNT} -ne ${#TRACKNUMBERS[@]} ] || [ ${TITLECNT} -gt 0 ] || [ ${PERFORMERCNT} -gt 0 ]; then

	echo "Fail to verify cue sheet: not match MusicBrainz data. (FILECNT: ${FILECNT}, TRACKCNT: ${TRACKCNT}, INDEXCNT: ${INDEXCNT}, TITLECNT:${TITLECNT}, PERFORMERCNT: ${PERFORMERCNT})" >&2
	exit 1
fi

mv ${TARGET_CUE_PATH} ${DUMPCUEFILENAME}

if [ -z "${CATALOGS[${SELECTEDNUMBER}]}" ]; then

	echo -n "" > ${TARGET_CUE_PATH}
else
	MODCATALOGS=`printf "%013d" ${CATALOGS[${SELECTEDNUMBER}]}`
	echo "CATALOG ${MODCATALOGS}" > ${TARGET_CUE_PATH}
fi

if ! [[ -z "${ALBUMTITLES[${SELECTEDNUMBER}]}" ]] ; then

	echo "TITLE \"${ALBUMTITLES[${SELECTEDNUMBER}]}\"" >> ${TARGET_CUE_PATH}
fi

if ! [[ -z "${ARTISTS[${SELECTEDNUMBER}]}" ]] ; then

	echo "PERFORMER \"${ARTISTS[${SELECTEDNUMBER}]}\"" >> ${TARGET_CUE_PATH}
fi

SELECTEDDATE=`echo ${RELEASEDATES[${SELECTEDNUMBER}]} | sed -E "s/^.*([0-9][0-9][0-9][0-9])-.*$/\1/"`
#CDDBENTITY=`cd-discid ${DEVICE_FILE} | cut -d" " -f1`

if ! [[ -z "${SELECTEDDATE}" ]] ; then

	echo "REM DATE ${SELECTEDDATE}" >> ${TARGET_CUE_PATH}
fi
#echo "CDDB \"${CDDBENTITY}\"" >> ${TARGET_CUE_PATH}

SELECTEDTOTALDISCNUMBER=$((${TOTALDISCS[${SELECTEDNUMBER}]}))
SELECTEDDISCNUMBER=${DISCNUMBERS[${SELECTEDNUMBER}]}

if ! [[ -z ${SELECTEDTOTALDISCNUMBER} ]] || [ ${SELECTEDTOTALDISCNUMBER} -gt 1 ] ; then

	echo "REM DISCNUMBER ${SELECTEDDISCNUMBER}" >> ${TARGET_CUE_PATH}
	echo "REM TOTALDISCS ${SELECTEDTOTALDISCNUMBER}" >> ${TARGET_CUE_PATH}
fi

echo "" >> ${TARGET_CUE_PATH}


LOADING_ON=0
INSERT_ON=0

cat ${DUMPCUEFILENAME} | while read LINE; do

	CUECOMMAND=`echo ${LINE} | cut -d" " -f1`

	if [[ ${CUECOMMAND} == "FILE"  ]]; then
		LOADING_ON=1
	fi

	if [[ ${LOADING_ON} -eq 1 ]]; then

		if [[ ${CUECOMMAND} == "FILE" ]]; then

			echo "${LINE}" >> ${TARGET_CUE_PATH}

		elif [[ ${CUECOMMAND} == "TRACK" ]]; then
			
			CUETRACKNUMBER=`echo ${LINE} | cut -d" " -f2`

			CUETRACKNUMBER=$((10#${CUETRACKNUMBER}-1))

			echo "${LINE}" >> ${TARGET_CUE_PATH}
			INSERT_ON=1

		elif [[ ${CUECOMMAND} == "INDEX" ]]; then

			echo "${LINE}" >> ${TARGET_CUE_PATH}
			echo "" >> ${TARGET_CUE_PATH}
			INSERT_ON=0
		fi

		if [[ ${INSERT_ON} -eq 1 ]]; then

			echo "TITLE \"${TITLES[${CUETRACKNUMBER}]}\"" >> ${TARGET_CUE_PATH}
			echo "PERFORMER \"${ARTISTS[${SELECTEDNUMBER}]}\"" >> ${TARGET_CUE_PATH}
		fi
	fi
done

rm ${DUMPCUEFILENAME}

if [ -z "${SELECTEDDISCNUMBER}" ] || [ -z ${SELECTEDTOTALDISCNUMBER} ] || [ ${SELECTEDTOTALDISCNUMBER} -lt 2 ]; then

	SAVEDXMLFILENAME=`echo "${ARTISTS[${SELECTEDNUMBER}]} - ${ALBUMTITLES[${SELECTEDNUMBER}]}" | sed 's/\//#/g'`
else
	SAVEDXMLFILENAME=`echo "${ARTISTS[${SELECTEDNUMBER}]} - ${ALBUMTITLES[${SELECTEDNUMBER}]} Disc ${SELECTEDDISCNUMBER}" | sed 's/\//#/g'`
fi

mv ${MUSICBRAINZXMLNAME} "${SAVEDXMLFILENAME}.xml"

exit 0
