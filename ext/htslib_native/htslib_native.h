#ifndef RUBY_HTSLIB_NATIVE_H
#define RUBY_HTSLIB_NATIVE_H

#include "ruby.h"

void Init_htslib_native_faidx(VALUE native);
void Init_htslib_native_tabix(VALUE native);
void Init_htslib_native_bam(VALUE native);
void Init_htslib_native_bcf(VALUE native);

#endif
