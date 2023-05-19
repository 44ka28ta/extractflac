#!/bin/bash

get_src_from_specific_element_with_xpath() {
	local ELEMENTSTR=$(xmllint --html --shell $1 2> /dev/null <<EOF
cat //$2/@$3
bye
EOF
)

	local ELEMENTSTR="`echo ${ELEMENTSTR} | grep -a -E $3 | sed -E 's/^.*'$3'="(.*)".*$/\1/'`"

	# Third argument is defined return value.
	local -n ELEMENTS=$4

	while IFS= read -r LINE; do

		ELEMENTS+=("`echo "${LINE}" | sed 's/\&amp\;/\&/g; s/\&lt\;/\</g; s/\&gt\;/\>/g; s/\&quot\;/\"/g; s/\&apos\;/'\''/g'`")


	done <<< "${ELEMENTSTR}"
}

modify_amazon_image_url() {

	echo "$1" | sed -E 's/^.*(https:\/\/.*)\.[^\.]+\.jpg/\1\.jpg/'
}

show_help() {
        echo "Get the cover art image file from Amazon.co.jp or Discorgs" >&2
        echo "$0 [-h] [-d] [-f FILENAME] -c CODE" >&2
        echo "" >&2
	echo "-c: specify the commodity code. CODE is in the case of https://www.amazon.co.jp/dp/CODE or https://www.discogs.com/ja/release/CODE-XXX." >&2
	echo "-f: specify the name of downloaded cover art file." >&2
	echo "-d: specify Discogs as the image source." >&2
        echo "-h: show this." >&2
}

FILE_NAME='folder.jpg'
CODE=''
ALTIMAGESRC=''

while getopts "h?f:c:d" opt; do
	case "${opt}" in
		h|\?)
			show_help
			exit 0
			;;
		f)
			FILE_NAME=${OPTARG}
			;;
		c)
			CODE=${OPTARG}
			;;
		d)
			ALTIMAGESRC='https://www.discogs.com/ja/release/'
			;;
	esac
done

if [ -z "${CODE}" ]; then
        show_help
        exit 0
fi


COMMODITYXMLNAME=${CODE}.xml
USER_AGENT="Mozilla/5.0 (X11; Linux i586; rv:31.0) Gecko/20100101 Firefox/31.0"
ACCEPT_ENCODING="gzip,deflate"

if [ -z "${ALTIMAGESRC}" ]; then
	AMAZON_SOURCE='https://www.amazon.co.jp/dp/'

	curl -L -X GET ${AMAZON_SOURCE}${CODE} -H "User-Agent: ${USER_AGENT}, Accept-Encoding:${ACCEPT_ENCODING}" | xmllint --html --format - 2> /dev/null > ${COMMODITYXMLNAME}

	IMAGE_URL=()

	get_src_from_specific_element_with_xpath ${COMMODITYXMLNAME} 'img[@id="landingImage"]' 'src' IMAGE_URL

	curl -o ${FILE_NAME} $(modify_amazon_image_url ${IMAGE_URL[0]})
else
	curl -L -X GET ${ALTIMAGESRC}${CODE} -H "User-Agent: ${USER_AGENT}, Accept-Encoding:${ACCEPT_ENCODING}" | xmllint --html --format - 2> /dev/null > ${COMMODITYXMLNAME}

	IMAGE_URL=()

	get_src_from_specific_element_with_xpath ${COMMODITYXMLNAME} 'meta[@property="og:image"]' 'content' IMAGE_URL

	curl -o ${FILE_NAME} ${IMAGE_URL[0]}
fi

rm ${COMMODITYXMLNAME}
