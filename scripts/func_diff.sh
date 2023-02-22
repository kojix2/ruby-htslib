#!/usr/bin/env bash

cd "$(dirname "$0")"

if [ "$1" == "" ]; then
  echo "Usage: $0 <basename>"
  ls ../htslib/htslib  
  exit 1
fi

delta <(./func_ffi.rb $1) <(./func_h.rb $1)
