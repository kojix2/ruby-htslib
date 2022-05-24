#!/usr/bin/env bash

cd "$(dirname "$0")"

if [ "$1" == "" ]; then
  echo "Usage: $0 <basename>"
  ls ../htslib/htslib  
  exit 1
fi

delta <(./func_h.sh $1) <(./func_ffi.sh $1)
