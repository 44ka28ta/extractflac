#!/bin/bash

show_help() {
	echo "Create FLAC audio with CUE sheet from CD" >&2
	echo "$0 [-h] [-p] [-u] [-x] [-y] [-z] [-0] [-s SAVE_PATH] [-r RESUME_FILE] -d DEVICE_FILE" >&2
	echo "" >&2
	echo "-h: show this." >&2
	echo "-p: option of making artist / album directory." >&2
	echo "-s: save directory path" >&2
	echo "-d: device file" >&2
	echo "-r: resume extraction" >&2
	echo "-u: UTF-8 encoding of CUE sheet from CDDB, MusicBrainz for the resume and default CD-TEXT (the default encoding is Latin1 (ISO-8859-1))" >&2
	echo "-x: enable --driver generic-mmc:0x1 option for cdrdao" >&2
	echo "-y: enable --driver generic-mmc:0x80000 option for cdrdao" >&2
	echo "-z: enable --driver generic-mmc:0x3 option for cdrdao" >&2
	echo "-0: enable --driver generic-mmc:0x100000 option for cdrdao" >&2
}

ARTIST=''
ALBUM=''
DEFAULT_ENCODING="iso-8859-1"

clean_cue() {

	sed -i '/CATALOG/d' "$1"
	sed -i '/TITLE/d' "$1"
	sed -i '/PERFORMER/d' "$1"
}

fix_toc_and_convert_cue() {

	sed -i '/TOC_INFO1/d' "$1.toc" # Remove except syntax
	sed -i '/UPC_EAN/d' "$1.toc" # Remove except syntax
	sed -i '/RESERVED4/d' "$1.toc" # Remove except syntax: RESERVED4 "Mastered using SADiE v5.6.2"
	#    SIZE_INFO { 0,  1,  9,  0, 12, 14,  0,  0,  0, 32,  0,  0,
	#                1,  0,  0,  0,  0,  0, 10,  3, 71,  0,  0,  0,
	#                0,  0,  0,  0,  9,  0,  0,  0,  0,  0,  0,  0}
	sed -E -i '/SIZE_INFO \{/{:a;N;/\}/!ba};/SIZE_INFO \{.*\}/d' "$1.toc"
	sed -E -i '/LANGUAGE [0-9]+ \{/{:a;N;/\}/!ba};s/\s+ISRC "[^"]*"//' "$1.toc" # Remove duplicated ISRC in LANGUAGE block
	#    GENRE { 0,  0, 79, 116, 104, 101, 114,  0}
	sed -E -i '/GENRE \{.*\}/d' "$1.toc"
	sed -E -i '/GENRE \{/{:a;N;/\}/!ba};/GENRE \{.*\}/d' "$1.toc"
	sed -i 's/　/ /g' "$1.toc" # Replace two-byte space with one-byte space
	sed -i 's/／/\//g' "$1.toc" # Replace two-byte slash with one-byte slash
	sed -i 's/\\"/\\\\"/g' "$1.toc" # For escaping convertion of double quote
	_DEBUG_CONVERT=`printf "$(cat "$1.toc")\n" > "$1.toc"` # Convert escaped characters to UTF-8
	cueconvert "$1.toc" "$1.cue"
}

get_artist_and_album_info_from_cue() {

	FILELINE=1

	DATE=""

	while read LINE; do

		CUECOMMAND=`echo ${LINE} | cut -d" " -f1`
		if [[ ${CUECOMMAND} == "FILE" ]]; then

			break

		elif [[ ${CUECOMMAND} == "MESSAGE" ]]; then
	
			DATESTR="`echo ${LINE} | sed -e 's/^MESSAGE \"\s*YEAR: \([0-9][0-9][0-9][0-9]\)\s*\"$/\1/'`"

			if [[ "${DATESTR}" =~ ^[0-9][0-9][0-9][0-9]$ ]] ; then

				DATE=${DATESTR}
			fi

		else
			FILELINE=$((FILELINE+1))
		fi

	done < "$1"

	# First, fix octal code point of unicode or other encodings in CUE Sheet
	# Finally, convert character encoding (because PERFORMER and TITLE entries in CUE Sheet are encoded latin1 (iso-8859-1))
	ARTIST=`printf "$(cat "$1")\n" | head -n ${FILELINE} | grep -a "PERFORMER" | sed -E 's/PERFORMER\ |"//g' | iconv -f $2 -t utf-8`
	ALBUM=`printf "$(cat "$1")\n" | head -n ${FILELINE} | grep -a "TITLE" | sed -E 's/TITLE\ |"//g' | iconv -f $2 -t utf-8`
	DISCNUMBER=`head -n ${FILELINE} "$1" | grep "REM DISCNUMBER" | sed -E 's/REM\ DISCNUMBER\ |"//g'`
	TOTALDISCS=`head -n ${FILELINE} "$1" | grep "REM TOTALDISCS" | sed -E 's/REM\ TOTALDISCS\ |"//g'`
	CATALOG=`head -n ${FILELINE} "$1" | grep "CATALOG" | sed -E 's/CATALOG\ |"//g'`

	if [ -z "${DATE}" ]; then

		DATE=`head -n ${FILELINE} "$1" | grep "REM DATE" | sed -E 's/REM\ DATE\ |"//g'`
	fi
}


OPTINT=1

SAVE_PATH=`pwd`
DEVICE_FILE=""
RESUME_FILE=""
ARTIST_ALBUM_DIR_OPTION=0

SCRIPT_PARENT=`dirname ${0}`

CDRDAO_DRIVER=""

while getopts "h?upzx0ys:d:r:" opt; do
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
		u)
			DEFAULT_ENCODING="utf-8"
			;;
		x)
			CDRDAO_DRIVER="--driver generic-mmc:0x1"
			;;
		y)
			CDRDAO_DRIVER="--driver generic-mmc:0x80000"
			;;
		z)
			CDRDAO_DRIVER="--driver generic-mmc:0x3"
			;;
		0)
			CDRDAO_DRIVER="--driver generic-mmc:0x100000"
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
	SAVE_PATH=`dirname "${RESUME_FILE}"`
fi

echo "[INFO] 1/6: Extract CD to ${SAVE_PATH}/${DUMPFILENAME}"

if [ -z "${RESUME_FILE}" ]; then

	cdrdao read-cd --device ${DEVICE_FILE} ${CDRDAO_DRIVER} --datafile "${SAVE_PATH}/${DUMPFILENAME}".{bin,toc}

fi

if [ $? -ne 0 ]; then

	echo "CD Read Error." 
	exit -1
fi

if ! [[ -e "${SAVE_PATH}/${DUMPFILENAME}.toc" ]]; then

	echo "[INFO] 1/6: Extract TOC from ${SAVE_PATH}/${DUMPFILENAME}"

	cdrdao read-toc --device ${DEVICE_FILE} ${CDRDAO_DRIVER} "${SAVE_PATH}/${DUMPFILENAME}.toc"

	sed -i -E -e "s/FILE\ \"data\.wav\"/FILE\ \"${DUMPFILENAME}\.bin\"/g" "${SAVE_PATH}/${DUMPFILENAME}.toc"
fi

if ! [[ -e "${SAVE_PATH}/${DUMPFILENAME}.cue" ]]; then

	echo "[INFO] 2/6: Convert TOC to CUE sheet (from CD)"

	fix_toc_and_convert_cue "${SAVE_PATH}/${DUMPFILENAME}"
fi

echo "[INFO] 2/6: Check CUE sheet"

get_artist_and_album_info_from_cue "${SAVE_PATH}/${DUMPFILENAME}.cue" ${DEFAULT_ENCODING}

if [[ -z "$(echo ${ARTIST} | tr -d '[:space:]')" ]] || [[ -z "$(echo ${ALBUM} | tr -d '[:space:]')" ]]; then

	echo "[INFO] 2/6: Proceed to clean CUE sheet"

	clean_cue "${SAVE_PATH}/${DUMPFILENAME}.cue"

	echo "[INFO] 2/6: Convert TOC to CUE Sheet (by MusicBrainz)"

	sh ${SCRIPT_PARENT}/getmusicbrainz.sh -d ${DEVICE_FILE} -c "${SAVE_PATH}/${DUMPFILENAME}.cue"

	if [ $? -ne 0 ]; then

		cdrdao read-cddb --cddb-servers "freedbtest.dyndns.org:/~cddb/cddbutf8.cgi" "${SAVE_PATH}/${DUMPFILENAME}.toc"

		if [ $? -ne 0 ]; then
			## For CDDB READ failed: 401 data No such CD entry in database.
			yes 1 | cdrdao read-cddb --cddb-servers "freedbtest.dyndns.org:/~cddb/cddbutf8.cgi" "${SAVE_PATH}/${DUMPFILENAME}.toc"
		fi

		echo "[INFO] 2/6: Convert TOC to CUE sheet"

		fix_toc_and_convert_cue "${SAVE_PATH}/${DUMPFILENAME}"

		get_artist_and_album_info_from_cue "${SAVE_PATH}/${DUMPFILENAME}.cue" "utf-8"

		if [ -z "${ARTIST}" ]; then

			echo "[INFO] 2/6: Convert TOC to CUE sheet: Does not hit, 1st Reloading ..."

			cdrdao read-cddb --cddb-servers "gnudb.gnudb.org:/~cddb/cddb.cgi" "${SAVE_PATH}/${DUMPFILENAME}.toc"

			fix_toc_and_convert_cue "${SAVE_PATH}/${DUMPFILENAME}"

			get_artist_and_album_info_from_cue "${SAVE_PATH}/${DUMPFILENAME}.cue" "utf-8"

			if [ -z "${ARTIST}" ]; then

				echo "[INFO] 2/6: Convert TOC to CUE sheet: Does not hit, 2nd Reloading ..."

				cdrdao read-cddb --cddb-servers "freedb.dbpoweramp.com:/~cddb/cddb.cgi" "${SAVE_PATH}/${DUMPFILENAME}.toc"

				fix_toc_and_convert_cue "${SAVE_PATH}/${DUMPFILENAME}"

				get_artist_and_album_info_from_cue "${SAVE_PATH}/${DUMPFILENAME}.cue" "utf-8"

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
		get_artist_and_album_info_from_cue "${SAVE_PATH}/${DUMPFILENAME}.cue" "utf-8"
	fi
fi

if [ -z "${DISCNUMBER}" ] || [ -z ${TOTALDISCS} ] || [ ${TOTALDISCS} -lt 2 ]; then

	FLACFILENAME=`echo "${ARTIST} - ${ALBUM}" | sed 's/\//#/g'`
else
	FLACFILENAME=`echo "${ARTIST} - ${ALBUM} Disc ${DISCNUMBER}" | sed 's/\//#/g'`
fi

sed -i -E -e "s/FILE\ \".*${DUMPFILENAME}\.bin\"/FILE\ \"${FLACFILENAME}\.flac\"/" "${SAVE_PATH}/${DUMPFILENAME}.cue"
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

	if [ "${#CATALOG}" -lt 13 ]; then

		CATALOG=`printf "%013d" ${CATALOG}`
	fi
	metaflac --set-tag="CATALOGNUMBER=${CATALOG}" "${SAVE_PATH}/${FLACFILENAME}.flac"
fi

echo "[INFO] 5/6: Finalize temporal data"

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
