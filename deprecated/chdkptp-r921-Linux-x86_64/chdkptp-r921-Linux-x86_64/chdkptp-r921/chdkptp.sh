#!/bin/sh
# shell script wrapper for self contained CLI install
CHDKPTP_EXE=chdkptp
# path where chdkptp is installed
CHDKPTP_DIR="$/home/user_name/folder_name/chdkptp-r921"
# set lua paths, double ; appends default
export LUA_PATH="$CHDKPTP_DIR/lua/?.lua;;"
export LUA_CPATH="$CHDKPTP_DIR/?.so;;"
"$CHDKPTP_DIR/$CHDKPTP_EXE" "$@"
