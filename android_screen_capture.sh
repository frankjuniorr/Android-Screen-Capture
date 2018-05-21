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
#  screen_capture_gif -- records video from an Android device to a GIF file.
#
################################################################################
# Synopsis:
#   screen_capture_gif [output]
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
#   screen_capture_gif [filename]
#   <do stuff on device>
#   <ctrl+c> to stop recording
#
################################################################################
# Author this fork: Frank Junior <frankcbjunior@gmail.com>
# Forked by Outlook: https://github.com/outlook/gifcap
# Since: 16-05-2018
################################################################################

set -e

################################################################################
# Variables - Variables stay here

file_output=$1

################################################################################
# Utils - Utils functions

# return codes
readonly SUCCESS=0
readonly ERROR=1

# ============================================
# Function to print information (yellow)
# ============================================
_print_info(){
  local amarelo="\033[33m"
  local reset="\033[m"

  printf "${amarelo}$1${reset}\n"
}

# ============================================
# Function to print error and exit
# ============================================
die() {
  local msg="$1"

  echo >&2 "$msg"
  exit "$ERROR"
}

################################################################################
# Validations

# ============================================
# Function to install dependencies
# ============================================
require() {
  local dependency=$1
  if ! type "$dependency" > /dev/null 2>&1; then
    echo "installing dependencies..."
    echo "---- [$dependency] ----"
    sudo apt-get install -y "$dependency"
  fi
}

# ============================================
# Check dependency. If is null abort script
# ============================================
require_block() {
  local dependency=$1
  if ! type "$dependency" > /dev/null 2>&1; then
    die "is necessary $dependency to run this script. Aborting..."
  fi
}

# ============================================
# Function to check if device is attached in computer
# ============================================
isDeviceAttached(){
  local isDevice=$(adb devices | grep --after-context=2 "List of devices attached" | tail -n1)
  if [ -z "$isDevice" ];then
    die "Device is not attached"
    exit "$ERROR"
  fi
}

# ============================================
# Validations handle
# ============================================
validations() {
  require_block adb
  require ffmpeg
  require ffprobe

  isDeviceAttached
}


################################################################################
# Script functions - Specific functions of script

# ============================================
# Function to print help
# ============================================
print_help() {
  cat <<- "EOF"
usage: screen_capture_gif [options...] [output]

Record video from an Android device and make a gif out of it

options:
  -s <specific device> - directs command to the device with the given serial
                         number or qualifier. Override ANDROID_SERIAL env
                         variable.
  -h, --help           - show this help message
positional arguments:
  output - the output filename; defaults to output.gif

EOF
}

# ============================================
# Given foo.bar, creates a tempfile named foo.XXXXX.bar,
# where Xs are random.
# The file will be created inside of TMPDIR.
# ============================================
better_mktemp() {
  local arg="$1"

  local filename=${arg%.*}.XXX
  local extesion=${arg##*.}

  local file=$(mktemp -t ${filename}) || die "Failed to create temp file: $arg"

  local destiny="${file}.${extesion}"

  mv ${file} "$destiny" || die "Failed to rename temp file $arg to $destiny"

  echo "$destiny"
}

# ============================================
# Main function
# ============================================
main(){
  # if $file_output is not defined, set as 'output.gif'
  local output=${file_output:=output.gif}

  # Do all work in a temp directory that is deleted on script exit.
  local my_temp_dir=$(mktemp -d gifcap.XXXXX) || die "Failed to create a temporary working directory, aborting"
  trap "rm -rf ${my_temp_dir}" EXIT

  local screen_capture=$(TMPDIR=${my_temp_dir} better_mktemp screencap.mp4)
  local palette=$(TMPDIR=${my_temp_dir} better_mktemp palette.png)

  local adb_screen_capture_path="/sdcard/$(basename ${screen_capture})"

  echo "Recording, end with CTRL+C"
  trap "echo 'Recording stopped.'" INT

  # adb shell screenrecord returns non-zero on success
  set +e
  $ADB -d shell screenrecord ${adb_screen_capture_path}
  set -e

  trap - INT

  # It takes non-zero time for the device to finish writing the video file.
  # Wait, then pull.

  sleep 5 # determined by science

  _print_info "creating file..."
  $ADB -d pull ${adb_screen_capture_path} ${screen_capture}
  $ADB -d shell rm -f ${adb_screen_capture_path}

  # Grab the length of the video in seconds
  local duration=$(ffprobe ${screen_capture} -show_format 2>/dev/null | awk -F '=' '/^duration/ { print $2}')
  # Determine an appropriate color palette for the video
  local input_flags="-y -ss 0 -t ${duration} -i ${screen_capture}"
  local vf_flags="fps=30,scale=320:-1:flags=lanczos,palettegen"

  _print_info "building file..."
  ffmpeg ${input_flags} -vf ${vf_flags} ${palette} &>/dev/null

  # Using the palette, convert the video to a gif.
  local filter="fps=30,scale=320:-1:flags=lanczos[x];[x][1:v]"
  local paletteuse="paletteuse=dither=bayer:bayer_scale=4"
  local filter_complex="${filter}${paletteuse}"

  _print_info "Converting..."
  ffmpeg ${input_flags} -i ${palette} -filter_complex "$filter_complex" "$output" &>/dev/null
  _print_info "Done."
}

################################################################################
# Main - Script execution

  # Default adb command, which may get extra adb args
  ADB="adb"

  # Parse optional arguments
  opt_index=1
  while getopts "s:h-:" opt; do
    case "$opt" in
      s) # -s: pass thru device serial to adb command
          ADB="adb -s $opt_arg"
          ;;
      h) # -h: short opt for help
          print_help
          exit $SUCCESS
          ;;
      -) # long opts e.g. --help
          case "$opt_arg" in
            help) # --help: long opt for help
              print_help
              ;;
          esac
          ;;
    esac
  done
  shift "$((opt_index-1))"

validations
main

################################################################################
# End of Script =D
