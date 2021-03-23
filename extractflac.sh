#/bin/bash

show_help() {
	echo "Create FLAC audio with CUESheet from CD" >&2
	echo "$0 [-h] [-p] [-s SAVE_PATH] [-r RESUME_FILE] -d DEVICE_FILE" >&2
	echo "" >&2
	echo "-h: show this." >&2
	echo "-p: option of making artist / album directory." >&2
	echo "-s: save directory path" >&2
	echo "-d: device file" >&2
	echo "-r: resume extraction" >&2
}

ARTIST=''
ALBUM=''

fix_toc_and_convert_cue() {

	sed -i '/TOC_INFO1/d' $1.toc # Remove except syntax
	sed -i '/UPC_EAN/d' $1.toc # Remove except syntax
	#    SIZE_INFO { 0,  1,  9,  0, 12, 14,  0,  0,  0, 32,  0,  0,
	#                1,  0,  0,  0,  0,  0, 10,  3, 71,  0,  0,  0,
	#                0,  0,  0,  0,  9,  0,  0,  0,  0,  0,  0,  0}
	sed -E -i '/SIZE_INFO \{/{:a;N;/\}/!ba};/SIZE_INFO \{.*\}/d' $1.toc
	sed -E -i '/LANGUAGE [0-9]+ \{/{:a;N;/\}/!ba};s/\s+ISRC "[^"]+"//' $1.toc # Remove duplicated ISRC in LANGUAGE block
	sed -i 's/　/ /g' $1.toc # Replace two-byte space with one-byte space
	sed -i 's/／/\//g' $1.toc # Replace two-byte slash with one-byte slash
	cueconvert $1.toc $1.cue
}

get_artist_and_album_info_from_cue() {

	FILELINE=1

	DATE=""

	while read LINE; do

		CUECOMMAND=`echo ${LINE} | cut -d" " -f1`
		if [[ ${CUECOMMAND} == "FILE" ]]; then

			break

		elif [[ ${CUECOMMAND} == "MESSAGE" ]]; then
	
			DATESTR="`echo ${LINE} | sed -e 's/^MESSAGE \"\s*YEAR: \([0-9][0-9][0-9][0-9]\)\s*\"/\1/'`"

			if ! [[ -z "${DATESTR}" ]]; then

				DATE=${DATESTR}
			fi

		else
			FILELINE=$((FILELINE+1))
		fi

	done < $1

	ARTIST=`head -n ${FILELINE} $1 | grep "PERFORMER" | sed -E 's/PERFORMER\ |"//g'`
	ALBUM=`head -n ${FILELINE} $1 | grep "TITLE" | sed -E 's/TITLE\ |"//g'`
	DISCNUMBER=`head -n ${FILELINE} $1 | grep "REM DISCNUMBER" | sed -E 's/REM\ DISCNUMBER\ |"//g'`
	TOTALDISCS=`head -n ${FILELINE} $1 | grep "REM TOTALDISCS" | sed -E 's/REM\ TOTALDISCS\ |"//g'`
	CATALOG=`head -n ${FILELINE} $1 | grep "CATALOG" | sed -E 's/CATALOG\ |"//g'`

	if [ -z "${DATE}" ]; then

		DATE=`head -n ${FILELINE} $1 | grep "REM DATE" | sed -E 's/REM\ DATE\ |"//g'`
	fi
}


OPTINT=1

SAVE_PATH=`pwd`
DEVICE_FILE=""
RESUME_FILE=""
ARTIST_ALBUM_DIR_OPTION=0

SCRIPT_PARENT=`dirname ${0}`

while getopts "h?ps:d:r:" opt; do
	case "${opt}" in
		h|\?)
			show_help
			exit 0
			;;
		p)
			ARTIST_ALBUM_DIR_OPTION=1
			;;
		s)
			SAVE_PATH=${OPTARG}
			;;
		d)
			DEVICE_FILE=${OPTARG}
			;;
		r)
			RESUME_FILE=${OPTARG}
			;;
	esac
done

if [ -z ${DEVICE_FILE} ]; then

	show_help
	exit 0
fi

shift $((OPTINT-1))

if [ -z "${RESUME_FILE}" ]; then

	DUMPFILENAME=`basename ${DEVICE_FILE}``cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1`
else
	DUMPFILENAME="${RESUME_FILE%.*}"
	SAVE_PATH=`dirname ${RESUME_FILE}`
fi

echo "[INFO] 1/6: Extract CD to ${SAVE_PATH}/${DUMPFILENAME}"

if [ -z "${RESUME_FILE}" ]; then

	cdrdao read-cd --device ${DEVICE_FILE} --datafile ${SAVE_PATH}/${DUMPFILENAME}.{bin,toc}

	fix_toc_and_convert_cue ${SAVE_PATH}/${DUMPFILENAME}
fi

echo "[INFO] 2/6: Convert TOC to CUESheet (by MusicBrainz)"

sh ${SCRIPT_PARENT}/getmusicbrainz.sh -d ${DEVICE_FILE} -c ${SAVE_PATH}/${DUMPFILENAME}.cue

if [ $? -ne 0 ]; then

	cdrdao read-cddb --cddb-servers "freedbtest.dyndns.org:/~cddb/cddbutf8.cgi" ${SAVE_PATH}/${DUMPFILENAME}.toc

	printf "$(cat ${SAVE_PATH}/${DUMPFILENAME}.toc)\n" > ${SAVE_PATH}/${DUMPFILENAME}.toc # Fix octal code point of unicode in CUE Sheet

	echo "[INFO] 2/6: Convert TOC to CUESheet"

	fix_toc_and_convert_cue ${SAVE_PATH}/${DUMPFILENAME}

	get_artist_and_album_info_from_cue ${SAVE_PATH}/${DUMPFILENAME}.cue

	if [ -z "${ARTIST}" ]; then

		echo "[INFO] 2/6: Convert TOC to CUESheet: Does not hit, 1st Reloading ..."

		cdrdao read-cddb --cddb-servers "gnudb.gnudb.org:/~cddb/cddb.cgi" ${SAVE_PATH}/${DUMPFILENAME}.toc

		fix_toc_and_convert_cue ${SAVE_PATH}/${DUMPFILENAME}

		get_artist_and_album_info_from_cue ${SAVE_PATH}/${DUMPFILENAME}.cue

		if [ -z "${ARTIST}" ]; then

			echo "[INFO] 2/6: Convert TOC to CUESheet: Does not hit, 2nd Reloading ..."

			cdrdao read-cddb --cddb-servers "freedb.dbpoweramp.com:/~cddb/cddb.cgi" ${SAVE_PATH}/${DUMPFILENAME}.toc

			fix_toc_and_convert_cue ${SAVE_PATH}/${DUMPFILENAME}

			get_artist_and_album_info_from_cue ${SAVE_PATH}/${DUMPFILENAME}.cue

			if [ -z "${ARTIST}" ]; then

				ARTIST='NoName'
				ALBUM='NoTitle'
			else
				echo "[INFO] 2/6: Fetched Data; Artist: ${ARTIST}, Album: ${ALBUM}"
			fi
		else
			echo "[INFO] 2/6: Fetched Data; Artist: ${ARTIST}, Album: ${ALBUM}"
		fi
	else
		echo "[INFO] 2/6: Fetched Data; Artist: ${ARTIST}, Album: ${ALBUM}"
	fi
else
	get_artist_and_album_info_from_cue ${SAVE_PATH}/${DUMPFILENAME}.cue
fi

if [ -z "${DISCNUMBER}" ] || [ -z ${TOTALDISCS} ] || [ ${TOTALDISCS} -lt 2 ]; then

	FLACFILENAME=`echo "${ARTIST} - ${ALBUM}" | sed 's/\//#/g'`
else
	FLACFILENAME=`echo "${ARTIST} - ${ALBUM} Disc ${DISCNUMBER}" | sed 's/\//#/g'`
fi

sed -i -E -e "s/FILE\ \".*${DUMPFILENAME}\.bin/FILE\ \"${FLACFILENAME}\.flac/" "${SAVE_PATH}/${DUMPFILENAME}.cue"
mv "${SAVE_PATH}/${DUMPFILENAME}.cue" "${SAVE_PATH}/${FLACFILENAME}.cue"

echo "[INFO] 3/6: Convert Bin to WAV"

sox -t cdda "${SAVE_PATH}/${DUMPFILENAME}.bin" "${SAVE_PATH}/${FLACFILENAME}.wav"

echo "[INFO] 4/6: Compress WAV with FLAC"

flac --best --cuesheet="${SAVE_PATH}/${FLACFILENAME}.cue" "${SAVE_PATH}/${FLACFILENAME}.wav"

#
# put Vorbis comment
#
metaflac --set-tag-from-file="CUESHEET=${SAVE_PATH}/${FLACFILENAME}.cue" "${SAVE_PATH}/${FLACFILENAME}.flac"

if ! [[ -z "${ARTIST}" ]] ; then

	metaflac --set-tag="ARTIST=${ARTIST}" "${SAVE_PATH}/${FLACFILENAME}.flac"
fi

if ! [[ -z "${ALBUM}" ]] ; then

	metaflac --set-tag="ALBUM=${ALBUM}" "${SAVE_PATH}/${FLACFILENAME}.flac"
fi

if ! [[ -z "${DATE}" ]] ; then

	metaflac --set-tag="DATE=${DATE}" "${SAVE_PATH}/${FLACFILENAME}.flac"
fi

if ! [[ -z "${DISCNUMBER}" ]] ; then

	metaflac --set-tag="DISCNUMBER=${DISCNUMBER}" "${SAVE_PATH}/${FLACFILENAME}.flac"
fi

if ! [[ -z "${TOTALDISCS}" ]] ; then

	metaflac --set-tag="TOTALDISCS=${TOTALDISCS}" "${SAVE_PATH}/${FLACFILENAME}.flac"
fi

if ! [[ -z "${CATALOG}" ]] ; then

	CATALOG=`printf "%013d" ${CATALOG}`
	metaflac --set-tag="CATALOGNUMBER=${CATALOG}" "${SAVE_PATH}/${FLACFILENAME}.flac"
fi

echo "[INFO] 5/6: Finalize temporarl data"

rm "${SAVE_PATH}/${FLACFILENAME}.wav"
rm "${SAVE_PATH}/${DUMPFILENAME}.toc"
rm "${SAVE_PATH}/${DUMPFILENAME}.bin"

if [ ${ARTIST_ALBUM_DIR_OPTION} -eq 1 ]; then

	FOLDER_ARTIST=`echo ${ARTIST} | sed 's/\//#/g'`
	FOLDER_ALBUM=`echo ${ALBUM} | sed 's/\//#/g'`
	SAVEFULLPATH="${SAVE_PATH}/${FOLDER_ARTIST}/${FOLDER_ALBUM}"
	mkdir -p "${SAVEFULLPATH}"

	mv "${SAVE_PATH}/${FLACFILENAME}.flac" "${SAVEFULLPATH}"
	mv "${SAVE_PATH}/${FLACFILENAME}.cue" "${SAVEFULLPATH}"

	if [ -e "${SAVE_PATH}/${FLACFILENAME}.xml" ]; then

		mv "${SAVE_PATH}/${FLACFILENAME}.xml" "${SAVEFULLPATH}"
	fi
fi

echo "[INFO] 6/6: Finish"
