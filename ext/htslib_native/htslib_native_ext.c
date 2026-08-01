#include "ruby.h"

#ifdef HAVE_HTSLIB_SAM_H
#include <htslib/sam.h>
#endif

static VALUE native_available(VALUE self)
{
#ifdef HAVE_HTSLIB_SAM_H
    return Qtrue;
#else
    return Qfalse;
#endif
}

#ifdef HAVE_HTSLIB_SAM_H
static int base_count_index(uint8_t base)
{
    switch (base) {
    case 1: return 1; /* A */
    case 2: return 2; /* C */
    case 4: return 3; /* G */
    case 8: return 4; /* T */
    default: return 5; /* N and ambiguous codes */
    }
}

/*
 * Result layout:
 *   depth, A, C, G, T, N, forward, reverse, deletion, insertion
 */
static VALUE pileup_base_counts(VALUE self, VALUE address_value, VALUE depth_value,
                                VALUE min_baseq_value, VALUE min_mapq_value,
                                VALUE result)
{
    bam_pileup1_t *entries = (bam_pileup1_t *)(uintptr_t)NUM2ULL(address_value);
    long depth = NUM2LONG(depth_value);
    int min_baseq = NUM2INT(min_baseq_value);
    int min_mapq = NUM2INT(min_mapq_value);
    long counts[10] = {0};
    long i;

    Check_Type(result, T_ARRAY);
    for (i = 0; i < depth; i++) {
        const bam_pileup1_t *entry = &entries[i];
        const bam1_t *bam = entry->b;
        int qpos = entry->qpos;

        if (entry->is_refskip || bam->core.qual < min_mapq) continue;

        if (entry->is_del || qpos < 0) {
            counts[8]++;
        } else {
            uint8_t quality = bam_get_qual(bam)[qpos];
            uint8_t base;
            if (quality < min_baseq) continue;
            base = bam_seqi(bam_get_seq(bam), qpos);
            counts[base_count_index(base)]++;
        }

        counts[0]++;
        counts[bam_is_rev(bam) ? 7 : 6]++;
        if (entry->indel > 0) counts[9]++;
    }

    rb_ary_resize(result, 10);
    for (i = 0; i < 10; i++) rb_ary_store(result, i, LONG2NUM(counts[i]));
    return result;
}
#endif

void Init_htslib_native_ext(void)
{
    VALUE hts = rb_define_module("HTS");
    VALUE native = rb_define_module_under(hts, "Native");

    rb_define_const(native, "AVAILABLE", native_available(native));
#ifdef HAVE_HTSLIB_SAM_H
    rb_define_module_function(native, "pileup_base_counts", pileup_base_counts, 5);
#endif
}
