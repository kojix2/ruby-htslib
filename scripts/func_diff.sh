#!/usr/bin/env bash

cd "$(dirname "$0")"

delta <(./func_h.sh $1) <(./func_ffi.sh $1)
