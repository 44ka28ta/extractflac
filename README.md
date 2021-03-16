Extract FLAC Audio with CUE sheet from CD
-----

Create FLAC audio with CUE sheet resolved CDDB from CD.

This script resolve CD Infomation by using following CDDB servers:

* freedbtest.dyndns.org
* gnudb.gnudb.org
* freedb.dbpoweramp.com

Dependency
=====

* cdrdao
* SoX
* flac
* metaflac
* cueconvert (cuetools)

Usage
=====

<pre><code>
Create FLAC audio with CUESheet from CD
extractflac.sh [-h] [-p] [-s SAVE_PATH] -d DEVICE_FILE

-h: show this.
-p: option of making artist / album directory.
-s: save directory path
-d: device file</code></pre>
