#!/usr/bin/env bash

cd "$(dirname "$0")"

files=("bgzf" "cram" "faidx" "hfile" "hts" "kfunc" "sam" "tbx" "vcf")

echo -e "# FUNC_REPORT\n" > FUNC_REPORT.md

for file in ${files[@]}; do
  echo -e "## $file\n"                             >> FUNC_REPORT.md
  echo "\`\`\`diff"                                >> FUNC_REPORT.md
  diff <(./func_ffi.sh $file) <(./func_h.sh $file) >> FUNC_REPORT.md
  echo -e "\`\`\`\n"                               >> FUNC_REPORT.md
done
