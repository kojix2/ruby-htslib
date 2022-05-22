#!/usr/bin/env bash

cd "$(dirname "$0")"

echo "count try_extern"
cat ../lib/hts/libhts/$1.rb \
  | grep -o "attach_function" \
  | wc -l

cat ../lib/hts/libhts/$1.rb \
  | sed -ze "s/ *\\\\ *\n *//g" \
  | grep -oP "(?<=attach_function:).*(?=,)" \
  | sed -e "s/^[ \t]*//" -e "s/[ \t]*$//" \
  | sed -e "s/try_extern '//" -e "s/'$//"