#!/bin/bash

# Copyright (c) 2019 Josh Bassett
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

set -e

SRC_ROM=${1:-rygar.zip}
TARGET_ROM=a.rygar.rom
TARGET_MD5=e0355e7803fdab0a8d8b5bda284ef2a5
WORK_DIR=$(mktemp -d)

function unzip_rom () {
  echo "Unzipping $SRC_ROM"
  unzip -q "$SRC_ROM" -d "$WORK_DIR"
}

function build_rom () {
  echo "Building $TARGET_ROM"

  cat "$WORK_DIR/5.5p" \
      "$WORK_DIR/cpu_5m.bin" \
      "$WORK_DIR/cpu_5j.bin" \
      "$WORK_DIR/cpu_8k.bin" \
      "$WORK_DIR/vid_6p.bin" \
      "$WORK_DIR/vid_6o.bin" \
      "$WORK_DIR/vid_6n.bin" \
      "$WORK_DIR/vid_6l.bin" \
      "$WORK_DIR/vid_6f.bin" \
      "$WORK_DIR/vid_6e.bin" \
      "$WORK_DIR/vid_6c.bin" \
      "$WORK_DIR/vid_6b.bin" \
      "$WORK_DIR/vid_6k.bin" \
      "$WORK_DIR/vid_6j.bin" \
      "$WORK_DIR/vid_6h.bin" \
      "$WORK_DIR/vid_6g.bin" \
      "$WORK_DIR/cpu_4h.bin" \
      "$WORK_DIR/cpu_1f.bin" \
      > $TARGET_ROM
}

function check_md5 () {
  echo "Checking MD5"

  if [[ -x "$(command -v md5sum)" ]]; then
    MD5=$(md5sum $TARGET_ROM | cut -d " " -f 1)
  elif [[ -x "$(command -v md5)" ]]; then
    MD5=$(md5 -q $TARGET_ROM)
  else
    echo "ERROR: No MD5 command is available."
    exit 1
  fi

  if [[ "$MD5" != "$TARGET_MD5" ]]; then
    echo "WARNING: The MD5 for the target ROM is invalid. Please check your source ROM files."
  fi
}

function cleanup () {
  echo "Cleaning up $WORK_DIR"
  rm -rf "$WORK_DIR"
}

trap cleanup EXIT

echo "'########::'##:::'##::'######::::::'###::::'########::"
echo " ##.... ##:. ##:'##::'##... ##::::'## ##::: ##.... ##:"
echo " ##:::: ##::. ####::: ##:::..::::'##:. ##:: ##:::: ##:"
echo " ########::::. ##:::: ##::'####:'##:::. ##: ########::"
echo " ##.. ##:::::: ##:::: ##::: ##:: #########: ##.. ##:::"
echo " ##::. ##::::: ##:::: ##::: ##:: ##.... ##: ##::. ##::"
echo " ##:::. ##:::: ##::::. ######::: ##:::: ##: ##:::. ##:"
echo "..:::::..:::::..::::::......::::..:::::..::..:::::..::"
echo

unzip_rom
build_rom
check_md5
