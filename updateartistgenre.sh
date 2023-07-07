#!/bin/bash

show_help() {
	echo "Update GENRE tag of Vorbis comments and CUE sheet" >&2
	echo "$0 [-h] [-g GENRE_NAME] -f FOLDER_PATH" >&2
	echo "" >&2
	echo "-h: show this." >&2
	echo "-f: artist directory path" >&2
	echo "-g: add or update a genre entry"
}


DIR_PATH=""
SCRIPT_DIR=`dirname $0`
WORKING_DIR=`pwd`

while getopts "h?f:g:" opt; do
	case "${opt}" in
		h|\?)
			show_help
			exit 0
			;;
		f)
			DIR_PATH=${OPTARG}
			;;
		g)
			UPDATE_GENRE=${OPTARG}
			;;
	esac
done

if [ ! -e "${DIR_PATH}" ]; then

	echo "There is no valid directory path of artist." >&2

	show_help
	exit 0
fi

if [ -n "${UPDATE_GENRE}" ]; then

	# For FLAC audio.
	find "${DIR_PATH}" -type f -regex ".*\.flac$" -print0 | xargs -0 -I {} sh ${SCRIPT_DIR}/renameflac.sh -g "${UPDATE_GENRE}" -f "${WORKING_DIR}/{}"
	# For MP3 audio.
	find "${DIR_PATH}" -type f -regex ".*\.mp3$" -print0 | xargs -0 -I {} sh -c 'mid3v2 -g "'${UPDATE_GENRE}'" "{}" && echo "{}: tag update succeeds." || echo "{}: tag update fails."'
else
	echo "No GENRE keyword."
fi
