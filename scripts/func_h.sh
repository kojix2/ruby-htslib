#!/usr/bin/env bash

cd "$(dirname "$0")"

echo "count HTSLIB_EXPORT"
cat ../htslib/htslib/$1.h \
  | grep -o "HTSLIB_EXPORT" \
  | wc -l

cat ../htslib/htslib/$1.h \
  | gcc -fpreprocessed -dD -E - \
  | sed -ze "s/\n//g" \
  | sed -ze "s/;/;\n/g" \
  | grep -oP "(?<=HTSLIB_EXPORT).*(?=;)" \
  | sed -e "s/^[ \t]*//" -e "s/[ \t]*$//" \
  | sed -r "s/\s+/ /g" \
  | ruby -nle 'print $_.split("(")[0].split(" ")[-1]' \
  | sed -e "s/^\**//"

