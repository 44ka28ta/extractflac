Extract FLAC Audio with CUE sheet from CD
-----

Create FLAC audio with CUE sheet resolved CDDB from CD.

This script resolve CD Infomation by using following CDDB servers:

* MusicBrainz (https://musicbrainz.org/ws/2/)
* freedbtest.dyndns.org
* gnudb.gnudb.org
* freedb.dbpoweramp.com

Further, this project has following helper scripts:

* `renameflac.sh`
* `getcoverart.sh`
* `updateartistgenre.sh`
* `addcoverart.sh`

Dependencies
=====

* curl
* cdrdao
* SoX
* flac
* metaflac
* cueconvert (cuetools)
* cd-discid
* openssl
* base64
* xmllint
* iconv
* mid3v2 (python3-mutagen)

Usage
=====

<pre><code>Create FLAC audio with CUE sheet from CD
extractflac.sh [-h] [-p] [-u] [-x] [-y] [-z] [-0] [-s SAVE_PATH] [-r RESUME_FILE] -d DEVICE_FILE

-h: show this.
-p: option of making artist / album directory.
-s: save directory path
-d: device file
-r: resume extraction
-u: UTF-8 encoding of CUE sheet from CDDB, MusicBrainz for the resume and default CD-TEXT (the default encoding is Latin1 (ISO-8859-1))
-x: enable --driver generic-mmc:0x1 option for cdrdao
-y: enable --driver generic-mmc:0x80000 option for cdrdao
-z: enable --driver generic-mmc:0x3 option for cdrdao
-0: enable --driver generic-mmc:0x100000 option for cdrdao</code></pre>
