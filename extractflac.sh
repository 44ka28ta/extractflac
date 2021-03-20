#/bin/bash

show_help() {
	echo "Create FLAC audio with CUESheet from CD" >&2
	echo "$0 [-h] [-p] [-s SAVE_PATH] -d DEVICE_FILE" >&2
	echo "" >&2
	echo "-h: show this." >&2
	echo "-p: option of making artist / album directory." >&2
	echo "-s: save directory path" >&2
	echo "-d: device file" >&2
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
	cueconvert $1.toc $1.cue
}

get_artist_and_album_from_cue() {

	ARTIST=`head -n 5 \1 | grep "PERFORMER" | sed -E 's/PERFORMER\ |"//g'`
	ALBUM=`head -n 5 \1 | grep "TITLE" | sed -E 's/TITLE\ |"//g'`
	DATE=`head -n 5 \1 | grep "REM DATE" | sed -E 's/REM\ DATE\ |"//g'`
}


OPTINT=1

SAVE_PATH=`pwd`
DEVICE_FILE=""
ARTIST_ALBUM_DIR_OPTION=0

SCRIPT_PARENT=`dirname ${0}`

while getopts "h?ps:d:" opt; do
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
	esac
done

if [ -z ${DEVICE_FILE} ]; then
	show_help
	exit 0
fi

shift $((OPTINT-1))

DUMPFILENAME=`basename ${DEVICE_FILE}``cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1`

echo "[INFO] 1/6: Extract CD to ${SAVE_PATH}/${DUMPFILENAME}"

cdrdao read-cd --device ${DEVICE_FILE} --datafile ${SAVE_PATH}/${DUMPFILENAME}.{bin,toc}

fix_toc_and_convert_cue ${SAVE_PATH}/${DUMPFILENAME}

echo "[INFO] 2/6: Convert TOC to CUESheet (by MusicBrainz)"

sh ${SCRIPT_PARENT}/getmusicbrainz.sh -d ${DEVICE_FILE} -c ${SAVE_PATH}/${DUMPFILENAME}.cue

if [ $? -ne 0 ]; then

	cdrdao read-cddb --cddb-servers "freedbtest.dyndns.org:/~cddb/cddbutf8.cgi" ${SAVE_PATH}/${DUMPFILENAME}.toc

	printf "$(cat ${SAVE_PATH}/${DUMPFILENAME}.toc)\n" > ${SAVE_PATH}/${DUMPFILENAME}.toc # Fix octal code point of unicode in CUE Sheet

	echo "[INFO] 2/6: Convert TOC to CUESheet"

	fix_toc_and_convert_cue ${SAVE_PATH}/${DUMPFILENAME}

	get_artist_and_album_from_cue ${SAVE_PATH}/${DUMPFILENAME}.cue

	if [ -z "${ARTIST}" ]; then

		echo "[INFO] 2/6: Convert TOC to CUESheet: Does not hit, 1st Reloading ..."

		cdrdao read-cddb --cddb-servers "gnudb.gnudb.org:/~cddb/cddb.cgi" ${SAVE_PATH}/${DUMPFILENAME}.toc

		fix_toc_and_convert_cue ${SAVE_PATH}/${DUMPFILENAME}

		get_artist_and_album_from_cue ${SAVE_PATH}/${DUMPFILENAME}.cue

		if [ -z "${ARTIST}" ]; then

			echo "[INFO] 2/6: Convert TOC to CUESheet: Does not hit, 2nd Reloading ..."

			cdrdao read-cddb --cddb-servers "freedb.dbpoweramp.com:/~cddb/cddb.cgi" ${SAVE_PATH}/${DUMPFILENAME}.toc

			fix_toc_and_convert_cue ${SAVE_PATH}/${DUMPFILENAME}

			get_artist_and_album_from_cue ${SAVE_PATH}/${DUMPFILENAME}.cue

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
	get_artist_and_album_from_cue ${SAVE_PATH}/${DUMPFILENAME}.cue
fi

FLACFILENAME="${ARTIST} - ${ALBUM}"

sed -i -E -e "s/FILE\ \".*${DUMPFILENAME}\.bin/FILE\ \"${FLACFILENAME}\.wav/" "${SAVE_PATH}/${DUMPFILENAME}.cue"
mv "${SAVE_PATH}/${DUMPFILENAME}.cue" "${SAVE_PATH}/${FLACFILENAME}.cue"

echo "[INFO] 3/6: Convert Bin to WAV"

sox -t cdda "${SAVE_PATH}/${DUMPFILENAME}.bin" "${SAVE_PATH}/${FLACFILENAME}.wav"

echo "[INFO] 4/6: Compress WAV with FLAC"

flac --best --cuesheet="${SAVE_PATH}/${FLACFILENAME}.cue" "${SAVE_PATH}/${FLACFILENAME}.wav"

#
# put Vorbis comment
#
metaflac --set-tag-from-file="CUESHEET=${SAVE_PATH}/${FLACFILENAME}.cue" "${SAVE_PATH}/${FLACFILENAME}.flac"
metaflac --set-tag="ARTIST=${ARTIST}" "${SAVE_PATH}/${FLACFILENAME}.flac"
metaflac --set-tag="ALBUM=${ALBUM}" "${SAVE_PATH}/${FLACFILENAME}.flac"
metaflac --set-tag="DATE=${DATE}" "${SAVE_PATH}/${FLACFILENAME}.flac"

echo "[INFO] 5/6: Finalize temporarl data"

rm "${SAVE_PATH}/${FLACFILENAME}.wav"
rm "${SAVE_PATH}/${DUMPFILENAME}.toc"
rm "${SAVE_PATH}/${DUMPFILENAME}.bin"

if [ ${ARTIST_ALBUM_DIR_OPTION} -eq 1 ]; then

	SAVEFULLPATH="${SAVE_PATH}/${ARTIST}/${ALBUM}"
	mkdir -p "${SAVEFULLPATH}"

	mv "${SAVE_PATH}/${FLACFILENAME}.flac" "${SAVEFULLPATH}"
	mv "${SAVE_PATH}/${FLACFILENAME}.cue" "${SAVEFULLPATH}"
fi

echo "[INFO] 6/6: Finish"
