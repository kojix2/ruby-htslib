#!/usr/bin/env bash

cd "$(dirname "$0")"

echo "count try_extern"
cat ../htslib/htslib/$1.h \
  | grep -o "HTSLIB_EXPORT" \
  | wc -l

cat ../htslib/htslib/$1.h \
  | sed -e "s/#.*$//" \
  | sed -e "s/\/\/.*$//" \
  | sed -ze "s/\n//g" \
  | sed -ze "s/;/;\n/g" \
  | grep -oP "(?<=HTSLIB_EXPORT).*(?=;)" \
  | sed -e "s/^[ \t]*//" -e "s/[ \t]*$//" \
  | sed -r "s/\s+/ /g" \
  | cut -f2 -d " "
