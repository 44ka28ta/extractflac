#!/bin/bash

get_src_from_img_element_with_xpath() {
	local ELEMENTSTR=$(xmllint --html --shell $1 2> /dev/null <<EOF
cat //img[@id="$2"]/@src
bye
EOF
)

	local ELEMENTSTR="`echo ${ELEMENTSTR} | grep -a -E 'src' | sed -E 's/^.*src="(.*)".*$/\1/'`"

	# Fifth argument is defined return value.
	local -n ELEMENTS=$3

	while IFS= read -r LINE; do

		ELEMENTS+=("`echo "${LINE}" | sed 's/\&amp\;/\&/g; s/\&lt\;/\</g; s/\&gt\;/\>/g; s/\&quot\;/\"/g; s/\&apos\;/'\''/g'`")


	done <<< "${ELEMENTSTR}"
}

modify_amazon_image_url() {

	echo "$1" | sed -E 's/^.*(https:\/\/.*)\.[^\.]+\.jpg/\1\.jpg/'
}

show_help() {
        echo "Get the cover art image file from Amazon.co.jp" >&2
        echo "$0 [-h] [-f FILENAME] -c AMAZON_CODE" >&2
        echo "" >&2
	echo "-c: specify the commodity code. AMAZON_CODE is in https://www.amazon.co.jp/dp/AMAZON_CODE ." >&2
	echo "-f: specify the name of downloaded cover art file." >&2
        echo "-h: show this." >&2
}

FILE_NAME='folder.jpg'
AMAZON_CODE=''

while getopts "h?f:c:" opt; do
	case "${opt}" in
		h|\?)
			show_help
			exit 0
			;;
		f)
			FILE_NAME=${OPTARG}
			;;
		c)
			AMAZON_CODE=${OPTARG}
			;;
	esac
done

if [ -z "${AMAZON_CODE}" ]; then
        show_help
        exit 0
fi


COMMODITYXMLNAME=${AMAZON_CODE}.xml
USER_AGENT="Mozilla/5.0 (X11; Linux i586; rv:31.0) Gecko/20100101 Firefox/31.0"
ACCEPT_ENCODING="gzip,deflate"

curl -L -X GET https://www.amazon.co.jp/dp/${AMAZON_CODE} -H "User-Agent: ${USER_AGENT}, Accept-Encoding:${ACCEPT_ENCODING}" | xmllint --html --format - 2> /dev/null > ${COMMODITYXMLNAME}

IMAGE_URL=()

get_src_from_img_element_with_xpath ${COMMODITYXMLNAME} "landingImage" IMAGE_URL

curl -o ${FILE_NAME} $(modify_amazon_image_url ${IMAGE_URL[0]})


