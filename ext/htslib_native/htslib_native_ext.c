#include "ruby.h"
#include <stdint.h>
#include <string.h>

#ifdef HAVE_HTSLIB_SAM_H
#include <htslib/sam.h>
#endif
#ifdef HAVE_HTSLIB_VCF_H
#include <htslib/vcf.h>
#endif

static ID id_to_ptr;
static ID id_address;

static void *ruby_record_pointer(VALUE record)
{
    VALUE pointer = rb_funcall(record, id_to_ptr, 0);
    VALUE address = rb_funcall(pointer, id_address, 0);
    return (void *)(uintptr_t)NUM2ULL(address);
}

static VALUE native_available(VALUE self)
{
#if defined(HAVE_HTSLIB_SAM_H) || defined(HAVE_HTSLIB_VCF_H)
    return Qtrue;
#else
    return Qfalse;
#endif
}

static VALUE selected_fields(VALUE self, VALUE line, VALUE columns)
{
    const char *bytes;
    long length, column_count, field_start = 0, column = 0, offset, i;
    VALUE result;

    StringValue(line);
    Check_Type(columns, T_ARRAY);
    bytes = RSTRING_PTR(line);
    length = RSTRING_LEN(line);
    column_count = RARRAY_LEN(columns);
    result = rb_ary_new_capa(column_count);
    for (i = 0; i < column_count; i++) rb_ary_push(result, Qnil);

    for (offset = 0; offset <= length; offset++) {
        if (offset == length || bytes[offset] == '\t') {
            for (i = 0; i < column_count; i++) {
                long requested = NUM2LONG(rb_ary_entry(columns, i));
                if (requested == column) {
                    rb_ary_store(result, i, rb_str_new(bytes + field_start, offset - field_start));
                }
            }
            column++;
            field_start = offset + 1;
        }
    }
    return result;
}

static VALUE aux_b_array(VALUE self, VALUE address_value)
{
    const uint8_t *aux = (const uint8_t *)(uintptr_t)NUM2ULL(address_value);
    const uint8_t *payload;
    uint32_t length, i;
    char subtype;
    VALUE result;

    if (aux[0] != 'B') rb_raise(rb_eTypeError, "AUX value is not a B array");
    subtype = (char)aux[1];
    memcpy(&length, aux + 2, sizeof(length));
    payload = aux + 6;
    result = rb_ary_new_capa(length);

    for (i = 0; i < length; i++) {
        VALUE value;
        switch (subtype) {
        case 'c': { int8_t v; memcpy(&v, payload + i, 1); value = INT2NUM(v); break; }
        case 'C': { uint8_t v; memcpy(&v, payload + i, 1); value = UINT2NUM(v); break; }
        case 's': { int16_t v; memcpy(&v, payload + i * 2, 2); value = INT2NUM(v); break; }
        case 'S': { uint16_t v; memcpy(&v, payload + i * 2, 2); value = UINT2NUM(v); break; }
        case 'i': { int32_t v; memcpy(&v, payload + i * 4, 4); value = INT2NUM(v); break; }
        case 'I': { uint32_t v; memcpy(&v, payload + i * 4, 4); value = UINT2NUM(v); break; }
        case 'f': { float v; memcpy(&v, payload + i * 4, 4); value = DBL2NUM(v); break; }
        default: rb_raise(rb_eNotImpError, "unsupported AUX B-array subtype: %c", subtype);
        }
        rb_ary_push(result, value);
    }
    return result;
}

#ifdef HAVE_HTSLIB_SAM_H
static VALUE bam_sequence(VALUE self, VALUE address_value)
{
    static const char nt16[] = "=ACMGRSVTWYHKDBN";
    const bam1_t *bam = (const bam1_t *)(uintptr_t)NUM2ULL(address_value);
    const uint8_t *packed = bam_get_seq(bam);
    long length = bam->core.l_qseq, i;
    VALUE result = rb_str_new(NULL, length);
    char *output = RSTRING_PTR(result);
    for (i = 0; i < length; i++) output[i] = nt16[bam_seqi(packed, i)];
    return result;
}

static VALUE bam_quality_string(VALUE self, VALUE address_value)
{
    const bam1_t *bam = (const bam1_t *)(uintptr_t)NUM2ULL(address_value);
    const uint8_t *quality = bam_get_qual(bam);
    long length = bam->core.l_qseq, i;
    VALUE result;
    char *output;

    if (length == 0) return rb_str_new("", 0);
    if (quality[0] == 255) return rb_str_new("*", 1);
    result = rb_str_new(NULL, length);
    output = RSTRING_PTR(result);
    for (i = 0; i < length; i++) output[i] = (char)(quality[i] + 33);
    return result;
}

static int base_count_index(uint8_t base)
{
    switch (base) {
    case 1: return 1;
    case 2: return 2;
    case 4: return 3;
    case 8: return 4;
    default: return 5;
    }
}

static VALUE pileup_base_counts(VALUE self, VALUE address_value, VALUE depth_value,
                                VALUE min_baseq_value, VALUE min_mapq_value,
                                VALUE result)
{
    bam_pileup1_t *entries = (bam_pileup1_t *)(uintptr_t)NUM2ULL(address_value);
    long depth = NUM2LONG(depth_value), counts[10] = {0}, i;
    int min_baseq = NUM2INT(min_baseq_value), min_mapq = NUM2INT(min_mapq_value);

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
            if (quality < min_baseq) continue;
            counts[base_count_index(bam_seqi(bam_get_seq(bam), qpos))]++;
        }
        counts[0]++;
        counts[bam_is_rev(bam) ? 7 : 6]++;
        if (entry->indel > 0) counts[9]++;
    }
    rb_ary_resize(result, 10);
    for (i = 0; i < 10; i++) rb_ary_store(result, i, LONG2NUM(counts[i]));
    return result;
}

static VALUE bam_filter_records(VALUE self, VALUE records, VALUE required_value,
                                VALUE excluded_value, VALUE min_mapq_value,
                                VALUE tid_value, VALUE beg_value, VALUE end_value)
{
    long i, length;
    uint32_t required = NUM2UINT(required_value), excluded = NUM2UINT(excluded_value);
    int min_mapq = NUM2INT(min_mapq_value);
    VALUE result;
    Check_Type(records, T_ARRAY);
    length = RARRAY_LEN(records);
    result = rb_ary_new_capa(length);
    for (i = 0; i < length; i++) {
        VALUE record = rb_ary_entry(records, i);
        const bam1_t *bam = (const bam1_t *)ruby_record_pointer(record);
        if ((bam->core.flag & required) != required || (bam->core.flag & excluded) != 0) continue;
        if (bam->core.qual < min_mapq) continue;
        if (!NIL_P(tid_value) && bam->core.tid != NUM2INT(tid_value)) continue;
        if (!NIL_P(beg_value) && bam_endpos(bam) <= NUM2LL(beg_value)) continue;
        if (!NIL_P(end_value) && bam->core.pos >= NUM2LL(end_value)) continue;
        rb_ary_push(result, record);
    }
    return result;
}
#endif

#ifdef HAVE_HTSLIB_VCF_H
static VALUE format_float_values(VALUE self, VALUE address_value, VALUE count_value,
                                 VALUE sample_count_value, VALUE scalar_value)
{
    const float *values = (const float *)(uintptr_t)NUM2ULL(address_value);
    long count = NUM2LONG(count_value), samples = NUM2LONG(sample_count_value);
    long width, sample, index;
    VALUE result;
    if (samples <= 0 || count % samples != 0) rb_raise(rb_eArgError, "invalid FORMAT sample layout");
    width = count / samples;
    result = rb_ary_new_capa(samples);
    for (sample = 0; sample < samples; sample++) {
        if (RTEST(scalar_value)) {
            float value = values[sample * width];
            rb_ary_push(result, (bcf_float_is_missing(value) || bcf_float_is_vector_end(value)) ? Qnil : DBL2NUM(value));
        } else {
            VALUE row = rb_ary_new_capa(width);
            for (index = 0; index < width; index++) {
                float value = values[sample * width + index];
                if (bcf_float_is_vector_end(value)) break;
                rb_ary_push(row, bcf_float_is_missing(value) ? Qnil : DBL2NUM(value));
            }
            rb_ary_push(result, row);
        }
    }
    return result;
}

static VALUE bcf_filter_records(VALUE self, VALUE records, VALUE rid_value,
                                VALUE beg_value, VALUE end_value,
                                VALUE min_qual_value, VALUE filter_id_value)
{
    long i, length;
    VALUE result;
    Check_Type(records, T_ARRAY);
    length = RARRAY_LEN(records);
    result = rb_ary_new_capa(length);
    for (i = 0; i < length; i++) {
        VALUE record = rb_ary_entry(records, i);
        bcf1_t *bcf = (bcf1_t *)ruby_record_pointer(record);
        int matched = 1;
        if (!NIL_P(rid_value) && bcf->rid != NUM2INT(rid_value)) continue;
        if (!NIL_P(beg_value) && bcf->pos + bcf->rlen <= NUM2LL(beg_value)) continue;
        if (!NIL_P(end_value) && bcf->pos >= NUM2LL(end_value)) continue;
        if (!NIL_P(min_qual_value) && (bcf_float_is_missing(bcf->qual) || bcf->qual < NUM2DBL(min_qual_value))) continue;
        if (!NIL_P(filter_id_value)) {
            int j, target = NUM2INT(filter_id_value);
            if (bcf_unpack(bcf, BCF_UN_FLT) < 0) rb_raise(rb_eRuntimeError, "failed to unpack BCF filters");
            matched = 0;
            for (j = 0; j < bcf->d.n_flt; j++) if (bcf->d.flt[j] == target) { matched = 1; break; }
        }
        if (matched) rb_ary_push(result, record);
    }
    return result;
}
#endif

void Init_htslib_native_ext(void)
{
    VALUE hts = rb_define_module("HTS");
    VALUE native = rb_define_module_under(hts, "Native");
    id_to_ptr = rb_intern("to_ptr");
    id_address = rb_intern("address");
    rb_define_const(native, "AVAILABLE", native_available(native));
    rb_define_module_function(native, "selected_fields", selected_fields, 2);
    rb_define_module_function(native, "aux_b_array", aux_b_array, 1);
#ifdef HAVE_HTSLIB_SAM_H
    rb_define_module_function(native, "bam_sequence", bam_sequence, 1);
    rb_define_module_function(native, "bam_quality_string", bam_quality_string, 1);
    rb_define_module_function(native, "pileup_base_counts", pileup_base_counts, 5);
    rb_define_module_function(native, "bam_filter_records", bam_filter_records, 7);
#endif
#ifdef HAVE_HTSLIB_VCF_H
    rb_define_module_function(native, "format_float_values", format_float_values, 4);
    rb_define_module_function(native, "bcf_filter_records", bcf_filter_records, 6);
#endif
}
