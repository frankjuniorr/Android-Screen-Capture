#!/bin/bash

# LICENSE
################################################################################
#  The MIT License (MIT)
#  Copyright (c) Microsoft Corporation
#
#  Permission is hereby granted, free of charge, to any person obtaining a copy of this software
#  and associated documentation files (the "Software"), to deal in the Software without restriction,
#  including without limitation the rights to use, copy, modify, merge, publish, distribute,
#  sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
#  furnished to do so, subject to the following conditions:
#
#  The above copyright notice and this permission notice shall be included in all copies or
#  substantial portions of the Software.
#
#  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
#  BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
#  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
#  DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
################################################################################

################################################################################
# Name:
#  gifcap -- records video from an Android device to a GIF file.
#
################################################################################
# Synopsis:
#   gifcap [output]
#
################################################################################
# Description:
#   Records video from an Android device to a gif file.  If no output filename
#   is given, 'output.gif' is used.
#
#   On invocation, screen capture will begin.  Script execution will block until
#   SIGINT is received (i.e., CTRL+C), which ends video recording.
#
#   Note that this script only works on physical devices - emulators typically don't
#   have the requisite screenrecord binary.
#
################################################################################
# Requirements:
#   adb - Android Debug Bridge, needed for communication
#   ffmpeg - Needed for converting between video and gif
#   ffprobe - Used to glean info about video. Usually bundled with ffmpeg.
#
################################################################################
# Usage:
#   <plug in device>
#   gifcap [filename]
#   <do stuff on device>
#   <ctrl+c> to stop recording
#
################################################################################
# Author this fork: Frank Junior <frankcbjunior@gmail.com>
# Forked by Outlook: https://github.com/outlook/gifcap
# Since: 16-05-2018
################################################################################

set -eu

function die() {
  echo >&2 "$1"
  exit 1
}

function require() {
  type $1 &>/dev/null || die "I require $1 to be installed and in your PATH.  Aborting."
}

# Given foo.bar, creates a tempfile named foo.XXXXX.bar, where Xs are random.
# The file will be created inside of TMPDIR.
function better_mktemp() {
  ARG="$1"
  FILENAME=${ARG%.*}.XXX
  EXT=${ARG##*.}

  FILE=`mktemp -t ${FILENAME}` || die "Failed to create temp file: $ARG"

  DEST="$FILE.$EXT"
  mv ${FILE} "$DEST" || die "Failed to rename temp file '$ARG' to '$DEST'"

  echo "$DEST"
}

function print_help() {
  cat <<- "EOF"
usage: gifcap [options...] [output]

Record video from an Android device and make a gif out of it

options:
  -s <specific device> - directs command to the device with the given serial
                         number or qualifier. Override ANDROID_SERIAL env
                         variable.
  -h, --help           - show this help message
positional arguments:
  output - the output filename; defaults to output.gif

EOF
  exit 0
}

# Default adb command, which may get extra adb args
ADB="adb"

# Parse optional arguments
OPTIND=1
while getopts "s:h-:" opt; do
  case "$opt" in
    s) # -s: pass thru device serial to adb command
        ADB="adb -s $OPTARG"
        ;;
    h) # -h: short opt for help
        print_help
        ;;
    -) # long opts e.g. --help
        case "$OPTARG" in
          help) # --help: long opt for help
            print_help
            ;;
        esac
        ;;
  esac
done
shift "$((OPTIND-1))"

require adb
require ffmpeg
require ffprobe

OUTPUT="output.gif"
if [ ! -z "${1-}" ]; then
  OUTPUT="$1"
fi

# Do all work in a temp directory that is deleted on script exit.
MY_TMPDIR=`mktemp -d gifcap.XXXXX` || die "Failed to create a temporary working directory, aborting"
trap "rm -rf ${MY_TMPDIR}" EXIT

SCREENCAP=`TMPDIR=${MY_TMPDIR} better_mktemp screencap.mp4`
PALETTE=`TMPDIR=${MY_TMPDIR} better_mktemp palette.png`

ADB_SCREENCAP_PATH="/sdcard/$(basename ${SCREENCAP})"

echo "Recording, end with CTRL+C"
trap "echo 'Recording stopped.  Converting...'" INT

# adb shell screenrecord returns non-zero on success
set +e
$ADB -d shell screenrecord ${ADB_SCREENCAP_PATH}
set -e

trap - INT

# It takes non-zero time for the device to finish writing the video file.
# Wait, then pull.

sleep 5 # determined by science

$ADB -d pull ${ADB_SCREENCAP_PATH} ${SCREENCAP}
$ADB -d shell rm -f ${ADB_SCREENCAP_PATH}

# Grab the length of the video in seconds
DURATION=$( ffprobe ${SCREENCAP} -show_format 2>/dev/null | awk -F '=' '/^duration/ { print $2}' )

# Determine an appropriate color palette for the video
INPUT_FLAGS="-y -ss 0 -t ${DURATION} -i ${SCREENCAP}"
VF_FLAGS="fps=30,scale=320:-1:flags=lanczos,palettegen"
ffmpeg ${INPUT_FLAGS} -vf ${VF_FLAGS} ${PALETTE} &>/dev/null

# Using the palette, convert the video to a gif.
FILTER="fps=30,scale=320:-1:flags=lanczos[x];[x][1:v]"
PALETTEUSE="paletteuse=dither=bayer:bayer_scale=4"
FILTER_COMPLEX="$FILTER$PALETTEUSE"
ffmpeg ${INPUT_FLAGS} -i ${PALETTE} -filter_complex "$FILTER_COMPLEX" "$OUTPUT" &>/dev/null