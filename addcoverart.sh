#!/bin/bash

show_help() {
	echo "Add a cover art to FLAC audio" >&2
	echo "$0 [-h] [-u] -a COVER_ART_PATH -f FILE_PATH" >&2
	echo "" >&w2
	echo "-h: show this." >&2
	echo "-a: cover art picture path" >&2
	echo "-f: file path" >&2
	echo "-u: forcibly update option (default is not update coverart if FLAC audio already has include cover art)" >&2
}

FILE_PATH=""
PICTURE_PATH=""
FORCIBLY_UPDATE=0

WORKING_DIR="`pwd`"

while getopts "h?a:f:u" opt; do
	case "${opt}" in
		h|\?)
			show_help
			exit 0
			;;
		a)
			PICTURE_PATH=${OPTARG}
			;;
		f)
			FILE_PATH=${OPTARG}
			;;
		u)
			FORCIBLY_UPDATE=1
			;;
	esac
done

if [ ! -e "${FILE_PATH}" ]; then

	echo "${FILE_PATH}: There is no valid file path of FLAC audio." >&2

	show_help
	exit 0
fi

FILE_PATH=`realpath --relative-to="${WORKING_DIR}" "${FILE_PATH}"`

if [ ! -e "${PICTURE_PATH}" ]; then

	echo "${PICTURE_PATH}: There is no valid cover art picture file path." >&2

	show_help
	exit 0
fi


_METADATA_PICTURE_BLOCK=`metaflac --list --block-type=PICTURE "${FILE_PATH}"`

if [ -n "${_METADATA_PICTURE_BLOCK}" ]; then

	if [ ${FORCIBLY_UPDATE} -eq 1 ]; then

		metaflac --remove --block-type=PICTURE "${FILE_PATH}"
		metaflac --import-picture-from="${PICTURE_PATH}" "${FILE_PATH}"
	fi
else

	metaflac --import-picture-from="${PICTURE_PATH}" "${FILE_PATH}"
fi
