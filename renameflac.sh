#/bin/bash

show_help() {
	echo "Rename FLAC audio with Vorbis comments and CUE sheet" >&2
	echo "$0 [-h] [-d] [-l] [-a ARTIST_NAME] [-t ALBUM_TITLE] [-n DISC_NUMBER] [-u TOTAL_DISC_NUMBER] -f FILE_PATH" >&2
	echo "" >&2
	echo "-h: show this." >&2
	echo "-a: renaming artist name" >&2
	echo "-t: renaming album title" >&2
	echo "-f: file path" >&2
	echo "-n: disc number" >&2
	echo "-u: total disc number" >&2
	echo "-d: renaming with the directory structure"
	echo "-l: TITLE entries from captal to lower case"
}

FILE_PATH=""
RENAMING_ARTIST=""
RENAMING_ALBUM=""
WITH_DIR_STRUCTURE=0
TITLE_TO_CAMEL_CASE=0

WORKING_DIR="`pwd`"

while getopts "h?a:t:f:n:u:dl" opt; do
	case "${opt}" in
		h|\?)
			show_help
			exit 0
			;;
		a)
			RENAMING_ARTIST=${OPTARG}
			;;
		t)
			RENAMING_ALBUM=${OPTARG}
			;;
		f)
			FILE_PATH=${OPTARG}
			;;
		n)
			UPDATE_DISC_NUMBER=${OPTARG}
			;;
		u)
			UPDATE_TOTAL_DISC_NUMBER=${OPTARG}
			;;
		d)
			WITH_DIR_STRUCTURE=1
			;;
		l)
			TITLE_TO_CAMEL_CASE=1
			;;
	esac
done

if [ ! -e "${FILE_PATH}" ]; then

	echo "There is no valid file path of FLAC audio." >&2

	show_help
	exit 0
fi

FILE_PATH=`realpath --relative-to="${WORKING_DIR}" "${FILE_PATH}"`

metaflac --list "${FILE_PATH}" &> /dev/null

if [ $? -eq 1 ]; then

	echo "FILE_PATH is not valid file path of FLAC audio." >&2
	exit 1
fi

DIRECTORY_PATH=$(dirname "${FILE_PATH}")
FILE_NAME_WITHOUT_EXT=$(basename "${FILE_PATH}" .flac)

CUE_FILE_NAME="${FILE_NAME_WITHOUT_EXT}.cue"
CUE_FILE_PATH="${DIRECTORY_PATH}/${CUE_FILE_NAME}"

XML_FILE_NAME="${FILE_NAME_WITHOUT_EXT}.xml"
XML_FILE_PATH="${DIRECTORY_PATH}/${XML_FILE_NAME}"

if [ ! -e "${CUE_FILE_PATH}" ]; then

	echo "There is no valid file path of CUE sheet of FLAC audio." >&2
	exit 1
fi

PRE_ARTIST=$(metaflac "${FILE_PATH}" --show-tag="ARTIST" | sed "s/^ARTIST=//")

if [ -n "${RENAMING_ARTIST}" ]; then

	echo "[INFO] Rename artist information."
	metaflac "${FILE_PATH}" --remove-tag="ARTIST"
	metaflac "${FILE_PATH}" --set-tag="ARTIST=${RENAMING_ARTIST}"
else
	RENAMING_ARTIST=$(metaflac "${FILE_PATH}" --show-tag="ARTIST" | sed "s/^ARTIST=//")
fi

PRE_ALBUM=$(metaflac "${FILE_PATH}" --show-tag="ALBUM" | sed "s/^ALBUM=//")
PRE_DISCNUMBER=$(metaflac "${FILE_PATH}" --show-tag="DISCNUMBER" | sed "s/^DISCNUMBER=//")

if [ -n "${RENAMING_ALBUM}" ]; then

	echo "[INFO] Rename album information."
	metaflac "${FILE_PATH}" --remove-tag="ALBUM"
	metaflac "${FILE_PATH}" --set-tag="ALBUM=${RENAMING_ALBUM}"
else
	RENAMING_ALBUM=$(metaflac "${FILE_PATH}" --show-tag="ALBUM" | sed "s/^ALBUM=//")
fi

RENEW_FILE_NAME_WITHOUT_EXT="${RENAMING_ARTIST} - ${RENAMING_ALBUM}"

if [ -n "${UPDATE_DISC_NUMBER}" ]; then

	echo "[INFO] Update disk nubmer information."
	
	metaflac "${FILE_PATH}" --remove-tag="DISCNUMBER"
	metaflac "${FILE_PATH}" --set-tag="DISCNUMBER=${UPDATE_DISC_NUMBER}"

	if [ $? -eq 0 ]; then

		PRE_DISCNUMBER=${UPDATE_DISC_NUMBER}
	else
		echo "Invalid specified disk number." >&2
		exit 1
	fi
fi

if [ -n "${UPDATE_TOTAL_DISC_NUMBER}" ]; then

	echo "[INFO] Update total disk nubmer information."
	
	metaflac "${FILE_PATH}" --remove-tag="TOTALDISCS"
	metaflac "${FILE_PATH}" --set-tag="TOTALDISCS=${UPDATE_TOTAL_DISC_NUMBER}"

	if [ $? -ne 0 ]; then

		echo "Invalid specified total disk number." >&2
		exit 1
	fi
fi

if [ -n "${PRE_DISCNUMBER}" ]; then

	RENEW_FILE_NAME_WITHOUT_EXT="${RENEW_FILE_NAME_WITHOUT_EXT} Disc ${PRE_DISCNUMBER}"
fi

RENEW_CUE_FILE_NAME=`echo "${RENEW_FILE_NAME_WITHOUT_EXT}.cue" | sed 's/\//#/g'`
RENEW_FILE_NAME=`echo "${RENEW_FILE_NAME_WITHOUT_EXT}.flac" | sed 's/\//#/g'`
RENEW_XML_FILE_NAME=`echo "${RENEW_FILE_NAME_WITHOUT_EXT}.xml" | sed 's/\//#/g'`

RENEW_FILE_PATH="${DIRECTORY_PATH}/${RENEW_FILE_NAME}"
RENEW_CUE_PATH="${DIRECTORY_PATH}/${RENEW_CUE_FILE_NAME}"
RENEW_XML_PATH="${DIRECTORY_PATH}/${RENEW_XML_FILE_NAME}"

if [ ! "${FILE_PATH}" = "${RENEW_FILE_PATH}" ]; then

	mv "${FILE_PATH}" "${RENEW_FILE_PATH}"
else
	echo "[INFO] Skip FLAC file renaming."
fi

if [ -n "${CUE_FILE_PATH}" ]; then

	echo "[INFO] Modify CUE sheet."

	if [ ${TITLE_TO_CAMEL_CASE} -eq 1 ]; then

		echo "[INFO] TITLE entries to Camel case."

		CUE_LINE_CNT=0
		ENTRY_REGEX='^TITLE "(.+)"$'

		cat "${CUE_FILE_PATH}" | awk 1 | while read LINE; do

			if [[ ${LINE} =~ ${ENTRY_REGEX} ]]; then

				if [ ${CUE_LINE_CNT} -ne 0 ]; then

					CAMEL_CASE_TITLE=`echo "${BASH_REMATCH[1]}" | sed -E 's/.+/\L&/g; s/\w+/\u&/g'`

					echo "TITLE \"${CAMEL_CASE_TITLE}\"" >> "${CUE_FILE_PATH}.new"
				else

					echo "${LINE}" >> "${CUE_FILE_PATH}.new"
				fi

				((CUE_LINE_CNT++))
			else
				echo "${LINE}" >> "${CUE_FILE_PATH}.new"
			fi
		done

		mv "${CUE_FILE_PATH}.new" "${CUE_FILE_PATH}"
	fi

	SED_RENAMING_ALBUM=`echo ${RENAMING_ALBUM} | sed 's/\//\\\\\//g'`

	sed -i -E -e "s/FILE\ \".*\"/FILE\ \"${RENEW_FILE_NAME}\"/" "${CUE_FILE_PATH}"

	sed -i -E -e "s/PERFORMER \"${PRE_ARTIST}\"/PERFORMER \"${RENAMING_ARTIST}\"/g" "${CUE_FILE_PATH}"
	sed -i -E -e "0,/TITLE \".*\"/{s/TITLE \".*\"/TITLE \"${SED_RENAMING_ALBUM}\"/}" "${CUE_FILE_PATH}"


	if [ ! "${CUE_FILE_PATH}" = "${RENEW_CUE_PATH}" ]; then

		mv "${CUE_FILE_PATH}" "${RENEW_CUE_PATH}"
	else
		echo "[INFO] Skip CUE sheet renaming."
	fi

	metaflac "${RENEW_FILE_PATH}" --remove-tag="CUESHEET"
	metaflac "${RENEW_FILE_PATH}" --set-tag-from-file="CUESHEET=${RENEW_CUE_PATH}"
fi

if [ -e "${XML_FILE_PATH}" ]; then

	echo "[INFO] Rename XML file."

	mv "${XML_FILE_PATH}" "${RENEW_XML_PATH}"
fi

if [ ${WITH_DIR_STRUCTURE} -eq 1 ]; then

	echo "[INFO] Modify the directory structure."
	cd ${BASE_DIR_PATH}

	ALBUM_DIR_PATH=`dirname "${WORKING_DIR}/${RENEW_FILE_PATH}"`
	ARTIST_DIR_PATH=$(dirname "${ALBUM_DIR_PATH}")
	BASE_DIR_PATH=$(dirname "${ARTIST_DIR_PATH}")

	RENAMING_ARTIST_DIR=`echo "${RENAMING_ARTIST}"| sed 's/\//#/g'`
	RENAMING_ALBUM_DIR=`echo "${RENAMING_ALBUM}"| sed 's/\//#/g'`

	#echo "${BASE_DIR_PATH}"
	#echo "${ALBUM_DIR_PATH} > ${ARTIST_DIR_PATH}/${RENAMING_ALBUM}"
	#echo "${ARTIST_DIR_PATH} > ${BASE_DIR_PATH}/${RENAMING_ARTIST}"

	if [ ! "${ALBUM_DIR_PATH}" = "${ARTIST_DIR_PATH}/${RENAMING_ALBUM_DIR}" ]; then

		mv "${ALBUM_DIR_PATH}" "${ARTIST_DIR_PATH}/${RENAMING_ALBUM_DIR}"
	else
		echo "[INFO] Skip album renaming."
	fi

	if [ ! "${ARTIST_DIR_PATH}" = "${BASE_DIR_PATH}/${RENAMING_ARTIST_DIR}" ]; then

		if [ -d "${BASE_DIR_PATH}/${RENAMING_ARTIST_DIR}" ]; then

			mv "${ARTIST_DIR_PATH}/${RENAMING_ALBUM_DIR}" "${BASE_DIR_PATH}/${RENAMING_ARTIST_DIR}"
			#rm -r "${ARTIST_DIR_PATH}"
		else
			mv "${ARTIST_DIR_PATH}" "${BASE_DIR_PATH}/${RENAMING_ARTIST_DIR}"
		fi
	else
		echo "[INFO] Skip artist renaming."
	fi
fi
