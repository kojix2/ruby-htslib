#include "htslib_native.h"
#include <ruby/thread.h>

#include <htslib/bgzf.h>
#include <htslib/cram.h>
#include <htslib/hfile.h>
#include <htslib/hts.h>
#include <htslib/kstring.h>
#include <htslib/sam.h>
#include <errno.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

typedef struct { sam_hdr_t *pointer; } ruby_sam_header_t;
typedef struct { bam1_t *pointer; } ruby_bam_record_t;
typedef struct {
    htsFile *file;
    hts_idx_t *index;
    VALUE path;
    int active_io;
} ruby_bam_file_t;
typedef struct {
    hts_itr_t *iterator;
    VALUE file;
} ruby_bam_iterator_t;
typedef struct {
    hts_base_mod_state *state;
    VALUE record;
} ruby_base_mod_t;
typedef struct {
    bam_plp_t pileup;
    hts_itr_t *iterator;
    VALUE file;
    VALUE header;
} ruby_pileup_t;
typedef struct {
    ruby_bam_file_t *file;
    sam_hdr_t *header;
    hts_itr_t *iterator;
} ruby_mplp_input_t;
typedef struct {
    bam_mplp_t pileup;
    int count;
    ruby_mplp_input_t *inputs;
    void **input_data;
    int *depths;
    const bam_pileup1_t **entries;
    VALUE files;
    VALUE headers;
} ruby_mpileup_t;

static VALUE cNativeSamHeader, cNativeBamRecord, cNativeBamFile, cNativeBamIterator, cNativeBaseMod, cNativePileup, cNativeMpileup;

static void sam_header_free(void *data) {
    ruby_sam_header_t *value = data;
    if (value->pointer) sam_hdr_destroy(value->pointer);
    xfree(value);
}
static size_t sam_header_size(const void *data) { return data ? sizeof(ruby_sam_header_t) : 0; }
static const rb_data_type_t sam_header_type = {
    .wrap_struct_name = "HTS::Native::SamHeaderHandle",
    .function = { .dfree = sam_header_free, .dsize = sam_header_size },
    .flags = RUBY_TYPED_FREE_IMMEDIATELY,
};
static ruby_sam_header_t *get_header(VALUE self) {
    ruby_sam_header_t *value;
    TypedData_Get_Struct(self, ruby_sam_header_t, &sam_header_type, value);
    if (!value->pointer) rb_raise(rb_eIOError, "closed BAM header");
    return value;
}
static VALUE wrap_header(sam_hdr_t *header) {
    ruby_sam_header_t *value;
    VALUE object;
    if (!header) rb_raise(rb_eRuntimeError, "failed to create BAM header");
    object = TypedData_Make_Struct(cNativeSamHeader, ruby_sam_header_t, &sam_header_type, value);
    value->pointer = header;
    return object;
}

static void bam_record_free(void *data) {
    ruby_bam_record_t *value = data;
    if (value->pointer) bam_destroy1(value->pointer);
    xfree(value);
}
static size_t bam_record_size(const void *data) { return data ? sizeof(ruby_bam_record_t) : 0; }
static const rb_data_type_t bam_record_type = {
    .wrap_struct_name = "HTS::Native::BamRecordHandle",
    .function = { .dfree = bam_record_free, .dsize = bam_record_size },
    .flags = RUBY_TYPED_FREE_IMMEDIATELY,
};
static ruby_bam_record_t *get_record(VALUE self) {
    ruby_bam_record_t *value;
    TypedData_Get_Struct(self, ruby_bam_record_t, &bam_record_type, value);
    if (!value->pointer) rb_raise(rb_eIOError, "closed BAM record");
    return value;
}
static VALUE wrap_record(bam1_t *record) {
    ruby_bam_record_t *value;
    VALUE object;
    if (!record) rb_raise(rb_eNoMemError, "bam_init1 failed");
    object = TypedData_Make_Struct(cNativeBamRecord, ruby_bam_record_t, &bam_record_type, value);
    value->pointer = record;
    return object;
}

static void bam_file_mark(void *data) { rb_gc_mark_movable(((ruby_bam_file_t *)data)->path); }
static void bam_file_compact(void *data) {
    ruby_bam_file_t *value = data;
    value->path = rb_gc_location(value->path);
}
static void bam_file_free(void *data) {
    ruby_bam_file_t *value = data;
    if (value->index) hts_idx_destroy(value->index);
    if (value->file) hts_close(value->file);
    xfree(value);
}
static size_t bam_file_size(const void *data) { return data ? sizeof(ruby_bam_file_t) : 0; }
static const rb_data_type_t bam_file_type = {
    .wrap_struct_name = "HTS::Native::BamFileHandle",
    .function = { .dmark = bam_file_mark, .dfree = bam_file_free, .dsize = bam_file_size, .dcompact = bam_file_compact },
    .flags = RUBY_TYPED_FREE_IMMEDIATELY | RUBY_TYPED_WB_PROTECTED,
};
static ruby_bam_file_t *get_file(VALUE self, int allow_closed) {
    ruby_bam_file_t *value;
    TypedData_Get_Struct(self, ruby_bam_file_t, &bam_file_type, value);
    if (!allow_closed && !value->file) rb_raise(rb_eIOError, "closed stream");
    return value;
}

static void bam_iterator_mark(void *data) { rb_gc_mark_movable(((ruby_bam_iterator_t *)data)->file); }
static void bam_iterator_compact(void *data) {
    ruby_bam_iterator_t *value = data;
    value->file = rb_gc_location(value->file);
}
static void bam_iterator_free(void *data) {
    ruby_bam_iterator_t *value = data;
    if (value->iterator) hts_itr_destroy(value->iterator);
    xfree(value);
}
static size_t bam_iterator_size(const void *data) { return data ? sizeof(ruby_bam_iterator_t) : 0; }
static const rb_data_type_t bam_iterator_type = {
    .wrap_struct_name = "HTS::Native::BamIteratorHandle",
    .function = { .dmark = bam_iterator_mark, .dfree = bam_iterator_free, .dsize = bam_iterator_size, .dcompact = bam_iterator_compact },
    .flags = RUBY_TYPED_FREE_IMMEDIATELY | RUBY_TYPED_WB_PROTECTED,
};
static ruby_bam_iterator_t *get_iterator(VALUE self) {
    ruby_bam_iterator_t *value;
    TypedData_Get_Struct(self, ruby_bam_iterator_t, &bam_iterator_type, value);
    if (!value->iterator) rb_raise(rb_eIOError, "closed BAM iterator");
    return value;
}
static VALUE wrap_iterator(VALUE file_object, hts_itr_t *iterator) {
    ruby_bam_iterator_t *value;
    VALUE object;
    if (!iterator) return Qnil;
    object = TypedData_Make_Struct(cNativeBamIterator, ruby_bam_iterator_t, &bam_iterator_type, value);
    value->iterator = iterator;
    value->file = file_object;
    RB_OBJ_WRITE(object, &value->file, file_object);
    return object;
}

/* Header */
static VALUE native_header_create(VALUE klass) { return wrap_header(sam_hdr_init()); }
static VALUE native_header_parse(VALUE klass, VALUE text) {
    StringValue(text);
    return wrap_header(sam_hdr_parse(RSTRING_LEN(text), RSTRING_PTR(text)));
}
static VALUE native_header_duplicate(VALUE self) { return wrap_header(sam_hdr_dup(get_header(self)->pointer)); }
static VALUE native_header_target_count(VALUE self) { return INT2NUM(sam_hdr_nref(get_header(self)->pointer)); }
static VALUE native_header_target_name(VALUE self, VALUE tid) {
    const char *name = sam_hdr_tid2name(get_header(self)->pointer, NUM2INT(tid));
    return name ? rb_str_new_cstr(name) : Qnil;
}
static VALUE native_header_target_length(VALUE self, VALUE tid) {
    return LL2NUM(sam_hdr_tid2len(get_header(self)->pointer, NUM2INT(tid)));
}
static VALUE native_header_name2tid(VALUE self, VALUE name) {
    return INT2NUM(sam_hdr_name2tid(get_header(self)->pointer, StringValueCStr(name)));
}
static VALUE native_header_to_s(VALUE self) {
    const char *text = sam_hdr_str(get_header(self)->pointer);
    return text ? rb_str_new_cstr(text) : rb_str_new("", 0);
}
static VALUE native_header_add_lines(VALUE self, VALUE text) {
    StringValue(text);
    return INT2NUM(sam_hdr_add_lines(get_header(self)->pointer, RSTRING_PTR(text), RSTRING_LEN(text)));
}
static VALUE header_kstring_result(int code, kstring_t *string) {
    VALUE result = code == 0 ? rb_str_new(string->s, string->l) : Qnil;
    free(string->s);
    return result;
}
static VALUE native_header_find_line(VALUE self, VALUE type, VALUE key, VALUE value) {
    kstring_t str = KS_INITIALIZE;
    int code = sam_hdr_find_line_id(get_header(self)->pointer, StringValueCStr(type),
                                    NIL_P(key) ? NULL : StringValueCStr(key),
                                    NIL_P(value) ? NULL : StringValueCStr(value), &str);
    return header_kstring_result(code, &str);
}
static VALUE native_header_find_tag(VALUE self, VALUE type, VALUE id_key, VALUE id_value, VALUE key) {
    kstring_t str = KS_INITIALIZE;
    int code = sam_hdr_find_tag_id(get_header(self)->pointer, StringValueCStr(type), StringValueCStr(id_key),
                                   StringValueCStr(id_value), StringValueCStr(key), &str);
    return header_kstring_result(code, &str);
}
static VALUE native_header_find_line_at(VALUE self, VALUE type, VALUE position) {
    kstring_t str = KS_INITIALIZE;
    int code = sam_hdr_find_line_pos(get_header(self)->pointer, StringValueCStr(type), NUM2INT(position), &str);
    return header_kstring_result(code, &str);
}
static VALUE native_header_remove_line(VALUE self, VALUE type, VALUE key, VALUE value) {
    return INT2NUM(sam_hdr_remove_line_id(get_header(self)->pointer, StringValueCStr(type),
                                         NIL_P(key) ? NULL : StringValueCStr(key),
                                         NIL_P(value) ? NULL : StringValueCStr(value)));
}
static VALUE native_header_remove_line_at(VALUE self, VALUE type, VALUE position) {
    return INT2NUM(sam_hdr_remove_line_pos(get_header(self)->pointer, StringValueCStr(type), NUM2INT(position)));
}
static VALUE native_header_remove_tag(VALUE self, VALUE type, VALUE id_key, VALUE id_value, VALUE key) {
    return INT2NUM(sam_hdr_remove_tag_id(get_header(self)->pointer, StringValueCStr(type), StringValueCStr(id_key),
                                        StringValueCStr(id_value), StringValueCStr(key)));
}
static VALUE native_header_count_lines(VALUE self, VALUE type) {
    return INT2NUM(sam_hdr_count_lines(get_header(self)->pointer, StringValueCStr(type)));
}
static VALUE native_header_line_index(VALUE self, VALUE type, VALUE key) {
    return INT2NUM(sam_hdr_line_index(get_header(self)->pointer, StringValueCStr(type), StringValueCStr(key)));
}
static VALUE native_header_line_name(VALUE self, VALUE type, VALUE pos) {
    const char *name = sam_hdr_line_name(get_header(self)->pointer, StringValueCStr(type), NUM2INT(pos));
    return name ? rb_str_new_cstr(name) : Qnil;
}

/* Record */
static VALUE native_record_create(VALUE klass) { return wrap_record(bam_init1()); }
static VALUE native_record_duplicate(VALUE self) { return wrap_record(bam_dup1(get_record(self)->pointer)); }
static VALUE native_record_replace(VALUE self, VALUE qname, VALUE flag, VALUE tid, VALUE pos,
                                   VALUE mapq, VALUE cigar_value, VALUE mtid, VALUE mpos,
                                   VALUE isize, VALUE sequence, VALUE qualities) {
    bam1_t *record = get_record(self)->pointer;
    long cigar_count, i;
    uint32_t *cigar = NULL;
    VALUE cigar_storage = 0;
    const char *quality_data = NULL;
    int result;

    StringValue(qname);
    StringValue(sequence);
    if (memchr(RSTRING_PTR(qname), '\0', RSTRING_LEN(qname))) {
        rb_raise(rb_eArgError, "qname must not contain NUL bytes");
    }
    Check_Type(cigar_value, T_ARRAY);
    cigar_count = RARRAY_LEN(cigar_value);
    if (cigar_count > 0) {
        cigar = ALLOCV_N(uint32_t, cigar_storage, cigar_count);
        for (i = 0; i < cigar_count; i++) cigar[i] = NUM2UINT(rb_ary_entry(cigar_value, i));
    }
    if (!NIL_P(qualities)) {
        StringValue(qualities);
        if (RSTRING_LEN(qualities) != RSTRING_LEN(sequence)) {
            ALLOCV_END(cigar_storage);
            rb_raise(rb_eArgError, "qualities length must match sequence length");
        }
        quality_data = RSTRING_PTR(qualities);
    }

    errno = 0;
    result = bam_set1(record,
                      (size_t)RSTRING_LEN(qname), RSTRING_PTR(qname),
                      NUM2UINT(flag), NUM2INT(tid), NUM2LL(pos), NUM2UINT(mapq),
                      (size_t)cigar_count, cigar,
                      NUM2INT(mtid), NUM2LL(mpos), NUM2LL(isize),
                      (size_t)RSTRING_LEN(sequence), RSTRING_PTR(sequence), quality_data, 0);
    ALLOCV_END(cigar_storage);
    if (result < 0) {
        if (errno) rb_sys_fail("bam_set1");
        rb_raise(rb_eRuntimeError, "bam_set1 failed: %d", result);
    }
    return self;
}
static VALUE native_record_qname(VALUE self) { return rb_str_new_cstr(bam_get_qname(get_record(self)->pointer)); }
static VALUE native_record_set_qname(VALUE self, VALUE name) {
    int result = bam_set_qname(get_record(self)->pointer, StringValueCStr(name));
    if (result < 0) rb_raise(rb_eRuntimeError, "bam_set_qname failed: %d", result);
    return name;
}
static void native_record_update_bin(bam1_t *record) {
    record->core.bin = hts_reg2bin(record->core.pos, bam_endpos(record), 14, 5);
}
static VALUE native_record_core_get(VALUE self, VALUE field) {
    bam1_core_t *core = &get_record(self)->pointer->core;
    ID id = SYM2ID(field);
    if (id == rb_intern("tid")) return INT2NUM(core->tid);
    if (id == rb_intern("mtid")) return INT2NUM(core->mtid);
    if (id == rb_intern("pos")) return LL2NUM(core->pos);
    if (id == rb_intern("mpos")) return LL2NUM(core->mpos);
    if (id == rb_intern("bin")) return UINT2NUM(core->bin);
    if (id == rb_intern("isize")) return LL2NUM(core->isize);
    if (id == rb_intern("mapq")) return UINT2NUM(core->qual);
    if (id == rb_intern("flag")) return UINT2NUM(core->flag);
    if (id == rb_intern("length")) return LL2NUM(core->l_qseq);
    rb_raise(rb_eArgError, "unknown BAM core field");
}
static VALUE native_record_core_set(VALUE self, VALUE field, VALUE new_value) {
    bam1_t *record = get_record(self)->pointer;
    bam1_core_t *core = &record->core;
    ID id = SYM2ID(field);
    if (id == rb_intern("tid")) core->tid = NUM2INT(new_value);
    else if (id == rb_intern("mtid")) core->mtid = NUM2INT(new_value);
    else if (id == rb_intern("pos")) core->pos = NUM2LL(new_value);
    else if (id == rb_intern("mpos")) core->mpos = NUM2LL(new_value);
    else if (id == rb_intern("bin")) core->bin = NUM2UINT(new_value);
    else if (id == rb_intern("isize")) core->isize = NUM2LL(new_value);
    else if (id == rb_intern("mapq")) core->qual = NUM2UINT(new_value);
    else if (id == rb_intern("flag")) core->flag = NUM2UINT(new_value);
    else rb_raise(rb_eArgError, "unknown or read-only BAM core field");
    if (id == rb_intern("pos") || id == rb_intern("flag")) native_record_update_bin(record);
    return new_value;
}
static VALUE native_record_endpos(VALUE self) { return LL2NUM(bam_endpos(get_record(self)->pointer)); }
static VALUE native_record_cigar_values(VALUE self) {
    bam1_t *record = get_record(self)->pointer;
    uint32_t *cigar = bam_get_cigar(record);
    VALUE result = rb_ary_new_capa(record->core.n_cigar);
    uint32_t i;
    for (i = 0; i < record->core.n_cigar; i++) rb_ary_push(result, UINT2NUM(cigar[i]));
    return result;
}
static VALUE native_record_set_cigar(VALUE self, VALUE text) {
    bam1_t *record = get_record(self)->pointer;
    int result = bam_parse_cigar(StringValueCStr(text), NULL, record);
    if (result < 0) rb_raise(rb_eRuntimeError, "bam_parse_cigar failed: %d", result);
    native_record_update_bin(record);
    return text;
}
static VALUE native_record_qlen(VALUE self) {
    bam1_t *record = get_record(self)->pointer;
    return LL2NUM(bam_cigar2qlen(record->core.n_cigar, bam_get_cigar(record)));
}
static VALUE native_record_rlen(VALUE self) {
    bam1_t *record = get_record(self)->pointer;
    return LL2NUM(bam_cigar2rlen(record->core.n_cigar, bam_get_cigar(record)));
}
static VALUE native_record_sequence(VALUE self) {
    static const char table[] = "=ACMGRSVTWYHKDBN";
    bam1_t *record = get_record(self)->pointer;
    uint8_t *packed = bam_get_seq(record);
    hts_pos_t i, length = record->core.l_qseq;
    VALUE result = rb_str_new(NULL, length);
    char *out = RSTRING_PTR(result);
    for (i = 0; i < length; i++) out[i] = table[bam_seqi(packed, i)];
    return result;
}
static VALUE native_record_sequence_codes(VALUE self) {
    bam1_t *record = get_record(self)->pointer;
    uint8_t *packed = bam_get_seq(record);
    hts_pos_t i, length = record->core.l_qseq;
    VALUE result = rb_ary_new_capa(length);
    for (i = 0; i < length; i++) rb_ary_push(result, INT2NUM(bam_seqi(packed, i)));
    return result;
}
static VALUE native_record_qualities(VALUE self) {
    bam1_t *record = get_record(self)->pointer;
    uint8_t *qualities = bam_get_qual(record);
    hts_pos_t i, length = record->core.l_qseq;
    VALUE result = rb_ary_new_capa(length);
    for (i = 0; i < length; i++) rb_ary_push(result, UINT2NUM(qualities[i]));
    return result;
}
static VALUE native_record_quality_string(VALUE self) {
    bam1_t *record = get_record(self)->pointer;
    uint8_t *qualities = bam_get_qual(record);
    hts_pos_t i, length = record->core.l_qseq;
    VALUE result;
    if (length == 0) return rb_str_new("", 0);
    if (qualities[0] == 255) return rb_str_new("*", 1);
    result = rb_str_new(NULL, length);
    for (i = 0; i < length; i++) RSTRING_PTR(result)[i] = (char)(qualities[i] + 33);
    return result;
}
static VALUE native_record_base_code(VALUE self, VALUE index) {
    bam1_t *record = get_record(self)->pointer;
    long i = NUM2LONG(index);
    if (i < 0 || i >= record->core.l_qseq) return Qnil;
    return INT2NUM(bam_seqi(bam_get_seq(record), i));
}
static VALUE native_record_quality_at(VALUE self, VALUE index) {
    bam1_t *record = get_record(self)->pointer;
    long i = NUM2LONG(index);
    if (i < 0 || i >= record->core.l_qseq) return Qnil;
    return UINT2NUM(bam_get_qual(record)[i]);
}
static VALUE native_record_to_s(VALUE self, VALUE header_value) {
    kstring_t string = KS_INITIALIZE;
    int result = sam_format1(get_header(header_value)->pointer, get_record(self)->pointer, &string);
    VALUE value;
    if (result < 0) { free(string.s); rb_raise(rb_eRuntimeError, "failed to format BAM record"); }
    value = rb_str_new(string.s, string.l);
    free(string.s);
    return value;
}
typedef struct { uint32_t *cigar; long count; } cigar_result_t;
static VALUE native_cigar_result_to_array(VALUE data) {
    cigar_result_t *result = (cigar_result_t *)(uintptr_t)data;
    VALUE array = rb_ary_new_capa(result->count);
    long i;
    for (i = 0; i < result->count; i++) rb_ary_push(array, UINT2NUM(result->cigar[i]));
    return array;
}
static VALUE native_cigar_result_free(VALUE data) {
    cigar_result_t *result = (cigar_result_t *)(uintptr_t)data;
    free(result->cigar);
    result->cigar = NULL;
    return Qnil;
}
static VALUE native_cigar_parse(VALUE klass, VALUE text) {
    uint32_t *cigar = NULL;
    size_t capacity = 0;
    long result = sam_parse_cigar(StringValueCStr(text), NULL, &cigar, &capacity);
    cigar_result_t parsed;
    if (result < 0) { free(cigar); rb_raise(rb_eRuntimeError, "sam_parse_cigar failed: %ld", result); }
    parsed.cigar = cigar;
    parsed.count = result;
    return rb_ensure(native_cigar_result_to_array, (VALUE)(uintptr_t)&parsed,
                     native_cigar_result_free, (VALUE)(uintptr_t)&parsed);
}
static VALUE native_cigar_qlen(VALUE klass, VALUE array) {
    long count = RARRAY_LEN(array), i;
    VALUE storage = 0;
    uint32_t *values = ALLOCV_N(uint32_t, storage, count ? count : 1);
    for (i = 0; i < count; i++) values[i] = NUM2UINT(rb_ary_entry(array, i));
    hts_pos_t result = bam_cigar2qlen(count, values);
    ALLOCV_END(storage);
    return LL2NUM(result);
}
static VALUE native_cigar_rlen(VALUE klass, VALUE array) {
    long count = RARRAY_LEN(array), i;
    VALUE storage = 0;
    uint32_t *values = ALLOCV_N(uint32_t, storage, count ? count : 1);
    for (i = 0; i < count; i++) values[i] = NUM2UINT(rb_ary_entry(array, i));
    hts_pos_t result = bam_cigar2rlen(count, values);
    ALLOCV_END(storage);
    return LL2NUM(result);
}

static VALUE aux_decode(uint8_t *aux, VALUE requested) {
    char actual = (char)aux[0], wanted = NIL_P(requested) ? actual : StringValueCStr(requested)[0];
    VALUE value, pair;
    int compatible = (wanted == actual) ||
        (strchr("iIcCsS", wanted) && strchr("iIcCsS", actual)) ||
        (strchr("fd", wanted) && strchr("fd", actual)) ||
        (strchr("ZH", wanted) && strchr("ZH", actual));
    if (!compatible) rb_raise(rb_eTypeError, "AUX type mismatch: requested %c, actual %c", wanted, actual);
    switch (wanted) {
    case 'i': case 'I': case 'c': case 'C': case 's': case 'S': value = LL2NUM(bam_aux2i(aux)); break;
    case 'f': case 'd': value = DBL2NUM(bam_aux2f(aux)); break;
    case 'Z': case 'H': { char *str = bam_aux2Z(aux); value = str ? rb_str_new_cstr(str) : Qnil; break; }
    case 'A': value = rb_str_new((char[]){bam_aux2A(aux)}, 1); break;
    case 'B': {
        uint32_t count = bam_auxB_len(aux), i;
        char subtype = (char)aux[1];
        value = rb_ary_new_capa(count);
        for (i = 0; i < count; i++) {
            if (subtype == 'f') rb_ary_push(value, DBL2NUM(bam_auxB2f(aux, i)));
            else rb_ary_push(value, LL2NUM(bam_auxB2i(aux, i)));
        }
        break;
    }
    default: rb_raise(rb_eNotImpError, "unsupported AUX type: %c", wanted);
    }
    pair = rb_ary_new_capa(2);
    if (actual == 'B') rb_ary_push(pair, rb_sprintf("B:%c", aux[1]));
    else rb_ary_push(pair, rb_str_new(&actual, 1));
    rb_ary_push(pair, value);
    return pair;
}
static VALUE native_record_aux_get(VALUE self, VALUE key, VALUE requested) {
    uint8_t *aux = bam_aux_get(get_record(self)->pointer, StringValueCStr(key));
    return aux ? aux_decode(aux, requested) : Qnil;
}
static VALUE native_record_aux_entries(VALUE self) {
    bam1_t *record = get_record(self)->pointer;
    uint8_t *aux = bam_aux_first(record);
    VALUE result = rb_ary_new();
    while (aux) {
        VALUE entry = aux_decode(aux, Qnil);
        rb_ary_unshift(entry, rb_str_new((char *)aux - 2, 2));
        rb_ary_push(result, entry);
        aux = bam_aux_next(record, aux);
    }
    return result;
}
static VALUE native_record_aux_update_int(VALUE self, VALUE key, VALUE value) {
    return INT2NUM(bam_aux_update_int(get_record(self)->pointer, StringValueCStr(key), NUM2LL(value)));
}
static VALUE native_record_aux_update_float(VALUE self, VALUE key, VALUE value) {
    return INT2NUM(bam_aux_update_float(get_record(self)->pointer, StringValueCStr(key), NUM2DBL(value)));
}
static VALUE native_record_aux_update_string(VALUE self, VALUE key, VALUE value) {
    return INT2NUM(bam_aux_update_str(get_record(self)->pointer, StringValueCStr(key), -1, StringValueCStr(value)));
}
static VALUE native_record_aux_append(VALUE self, VALUE key, VALUE type, VALUE payload) {
    StringValue(payload);
    return INT2NUM(bam_aux_append(get_record(self)->pointer, StringValueCStr(key), StringValueCStr(type)[0],
                                  RSTRING_LEN(payload), (uint8_t *)RSTRING_PTR(payload)));
}
static VALUE native_record_aux_update_array(VALUE self, VALUE key, VALUE type_value, VALUE array) {
    char type = StringValueCStr(type_value)[0];
    long count = RARRAY_LEN(array), i;
    size_t width;
    uint8_t *buffer;
    VALUE buffer_storage = 0;
    int result;
    switch (type) { case 'c': case 'C': width = 1; break; case 's': case 'S': width = 2; break; default: width = 4; }
    buffer = ALLOCV_N(uint8_t, buffer_storage, count * width + 1);
    for (i = 0; i < count; i++) {
        VALUE item = rb_ary_entry(array, i);
        if (type == 'c') { int8_t v = NUM2INT(item); memcpy(buffer + i, &v, 1); }
        else if (type == 'C') { uint8_t v = NUM2UINT(item); memcpy(buffer + i, &v, 1); }
        else if (type == 's') { int16_t v = NUM2INT(item); memcpy(buffer + i * 2, &v, 2); }
        else if (type == 'S') { uint16_t v = NUM2UINT(item); memcpy(buffer + i * 2, &v, 2); }
        else if (type == 'i') { int32_t v = NUM2INT(item); memcpy(buffer + i * 4, &v, 4); }
        else if (type == 'I') { uint32_t v = NUM2UINT(item); memcpy(buffer + i * 4, &v, 4); }
        else if (type == 'f') { float v = (float)NUM2DBL(item); memcpy(buffer + i * 4, &v, 4); }
        else { ALLOCV_END(buffer_storage); rb_raise(rb_eArgError, "invalid AUX array type"); }
    }
    result = bam_aux_update_array(get_record(self)->pointer, StringValueCStr(key), type, count, buffer);
    ALLOCV_END(buffer_storage);
    return INT2NUM(result);
}
static VALUE native_record_aux_delete(VALUE self, VALUE key) {
    bam1_t *record = get_record(self)->pointer;
    uint8_t *aux = bam_aux_get(record, StringValueCStr(key));
    if (!aux) return Qfalse;
    if (bam_aux_del(record, aux) < 0) rb_raise(rb_eRuntimeError, "failed to delete AUX tag");
    return Qtrue;
}
static VALUE native_record_aux_key(VALUE self, VALUE key) {
    return bam_aux_get(get_record(self)->pointer, StringValueCStr(key)) ? Qtrue : Qfalse;
}

/* File and iterator */
static void raise_bam_open_error(VALUE path_value, int error) {
    if (error) rb_syserr_fail_str(error, path_value);
    VALUE hts=rb_const_get(rb_cObject,rb_intern("HTS"));
    VALUE bam=rb_const_get(hts,rb_intern("Bam"));
    VALUE klass=rb_const_get(bam,rb_intern("OpenError"));
    rb_raise(klass,"Failed to open %"PRIsVALUE": HTSlib could not recognize or open the input",path_value);
}
static VALUE native_bam_open(VALUE klass, VALUE path_value, VALUE mode_value) {
    ruby_bam_file_t *value;
    VALUE object = TypedData_Make_Struct(klass, ruby_bam_file_t, &bam_file_type, value);
    value->index = NULL;
    value->active_io = 0;
    value->path = rb_str_dup(StringValue(path_value));
    RB_OBJ_WRITE(object, &value->path, value->path);
    errno = 0;
    value->file = hts_open(StringValueCStr(value->path), StringValueCStr(mode_value));
    if (!value->file) raise_bam_open_error(path_value, errno);
    return object;
}
static VALUE native_bam_close(VALUE self) {
    ruby_bam_file_t *value = get_file(self, 1);
    int result = 0;
    if (value->active_io) rb_raise(rb_eIOError, "cannot close BAM during active I/O");
    if (value->index) { hts_idx_destroy(value->index); value->index = NULL; }
    if (value->file) { result = hts_close(value->file); value->file = NULL; }
    return INT2NUM(result);
}
static VALUE native_bam_closed(VALUE self) { return get_file(self, 1)->file ? Qfalse : Qtrue; }
typedef struct { htsFile *file; sam_hdr_t *header; bam1_t *record; hts_itr_t *iterator; int result; } bam_io_args_t;
typedef struct { htsFile *file; sam_hdr_t *result; } bam_header_read_args_t;
static void *bam_read_header_without_gvl(void *data) { bam_header_read_args_t *args=data; args->result=sam_hdr_read(args->file); return NULL; }
static void *bam_write_header_without_gvl(void *data) { bam_io_args_t *args=data; args->result=sam_hdr_write(args->file,args->header); return NULL; }
static void *bam_read_without_gvl(void *data) { bam_io_args_t *args=data; args->result=sam_read1(args->file,args->header,args->record); return NULL; }
static void *bam_write_without_gvl(void *data) { bam_io_args_t *args=data; args->result=sam_write1(args->file,args->header,args->record); return NULL; }
static void *bam_iterator_without_gvl(void *data) { bam_io_args_t *args=data; args->result=sam_itr_next(args->file,args->iterator,args->record); return NULL; }
static void bam_io_begin(ruby_bam_file_t *file) { if(file->active_io)rb_raise(rb_eIOError,"concurrent BAM I/O is not supported"); file->active_io=1; }
static VALUE native_bam_read_header(VALUE self) {
    ruby_bam_file_t *file=get_file(self,0); bam_header_read_args_t args={file->file,NULL};
    bam_io_begin(file); rb_thread_call_without_gvl(bam_read_header_without_gvl,&args,RUBY_UBF_IO,NULL); file->active_io=0;
    return wrap_header(args.result);
}
static VALUE native_bam_write_header(VALUE self, VALUE header) {
    ruby_bam_file_t *file=get_file(self,0); bam_io_args_t args={file->file,get_header(header)->pointer,NULL,NULL,0};
    bam_io_begin(file); rb_thread_call_without_gvl(bam_write_header_without_gvl,&args,RUBY_UBF_IO,NULL); file->active_io=0; return INT2NUM(args.result);
}
static VALUE native_bam_read(VALUE self, VALUE header, VALUE record) {
    ruby_bam_file_t *file=get_file(self,0); bam_io_args_t args={file->file,get_header(header)->pointer,get_record(record)->pointer,NULL,0};
    bam_io_begin(file); rb_thread_call_without_gvl(bam_read_without_gvl,&args,RUBY_UBF_IO,NULL); file->active_io=0; return INT2NUM(args.result);
}
static VALUE native_bam_write(VALUE self, VALUE header, VALUE record) {
    ruby_bam_file_t *file=get_file(self,0); bam_io_args_t args={file->file,get_header(header)->pointer,get_record(record)->pointer,NULL,0};
    bam_io_begin(file); rb_thread_call_without_gvl(bam_write_without_gvl,&args,RUBY_UBF_IO,NULL); file->active_io=0; return INT2NUM(args.result);
}
static VALUE native_bam_set_fai(VALUE self, VALUE path) {
    return INT2NUM(hts_set_fai_filename(get_file(self, 0)->file, StringValueCStr(path)));
}
static VALUE native_bam_set_threads(VALUE self, VALUE count) {
    return INT2NUM(hts_set_threads(get_file(self, 0)->file, NUM2INT(count)));
}
static VALUE native_bam_format(VALUE self) {
    const htsFormat *format = hts_get_format(get_file(self, 0)->file);
    if (!format) return Qnil;
    switch (format->format) {
    case sam: return rb_str_new_cstr("sam");
    case bam: return rb_str_new_cstr("bam");
    case cram: return rb_str_new_cstr("cram");
    case vcf: return rb_str_new_cstr("vcf");
    case bcf: return rb_str_new_cstr("bcf");
    default: return rb_str_new_cstr("unknown_format");
    }
}
static VALUE native_bam_format_version(VALUE self) {
    const htsFormat *format = hts_get_format(get_file(self, 0)->file);
    if (!format) return Qnil;
    if (format->version.minor == -1) return rb_sprintf("%d", format->version.major);
    return rb_sprintf("%d.%d", format->version.major, format->version.minor);
}
static VALUE native_bam_seek(VALUE self, VALUE offset) {
    htsFile *file = get_file(self, 0)->file;
    int64_t position = NUM2LL(offset);
    if (file->is_cram) return LL2NUM(cram_seek(file->fp.cram, position, SEEK_SET));
    if (file->is_bgzf) return LL2NUM(bgzf_seek(file->fp.bgzf, position, SEEK_SET));
    return LL2NUM(hseek(file->fp.hfile, position, SEEK_SET));
}
static VALUE native_bam_tell(VALUE self) {
    htsFile *file = get_file(self, 0)->file;
    if (file->is_cram) return Qnil;
    if (file->is_bgzf) return LL2NUM(bgzf_tell(file->fp.bgzf));
    return LL2NUM(htell(file->fp.hfile));
}
static VALUE native_bam_load_index(VALUE self, VALUE index_value) {
    ruby_bam_file_t *value = get_file(self, 0);
    if (value->index) { hts_idx_destroy(value->index); value->index = NULL; }
    value->index = NIL_P(index_value)
        ? sam_index_load3(value->file, StringValueCStr(value->path), NULL, HTS_IDX_SAVE_REMOTE)
        : sam_index_load2(value->file, StringValueCStr(value->path), StringValueCStr(index_value));
    return value->index ? Qtrue : Qfalse;
}
static VALUE native_bam_index_loaded(VALUE self) { return get_file(self, 0)->index ? Qtrue : Qfalse; }
static VALUE native_bam_build_index(VALUE klass, VALUE path, VALUE index, VALUE shift, VALUE threads) {
    return INT2NUM(sam_index_build3(StringValueCStr(path), NIL_P(index) ? NULL : StringValueCStr(index),
                                    NUM2INT(shift), NUM2INT(threads)));
}
static VALUE native_bam_query_interval(VALUE self, VALUE tid, VALUE beg, VALUE end) {
    ruby_bam_file_t *file = get_file(self, 0);
    if (!file->index) rb_raise(rb_eRuntimeError, "index file is required");
    return wrap_iterator(self, sam_itr_queryi(file->index, NUM2INT(tid), NUM2LL(beg), NUM2LL(end)));
}
static VALUE native_bam_query_region(VALUE self, VALUE header, VALUE region) {
    ruby_bam_file_t *file = get_file(self, 0);
    if (!file->index) rb_raise(rb_eRuntimeError, "index file is required");
    return wrap_iterator(self, sam_itr_querys(file->index, get_header(header)->pointer, StringValueCStr(region)));
}
static VALUE native_bam_iterator_next(VALUE self, VALUE record) {
    ruby_bam_iterator_t *iterator = get_iterator(self);
    ruby_bam_file_t *file = get_file(iterator->file, 0);
    bam_io_args_t args={file->file,NULL,get_record(record)->pointer,iterator->iterator,0};
    bam_io_begin(file);
    rb_thread_call_without_gvl(bam_iterator_without_gvl,&args,RUBY_UBF_IO,NULL);
    file->active_io=0;
    return INT2NUM(args.result);
}
static VALUE native_bam_iterator_close(VALUE self) {
    ruby_bam_iterator_t *value;
    TypedData_Get_Struct(self, ruby_bam_iterator_t, &bam_iterator_type, value);
    if (value->iterator) { hts_itr_destroy(value->iterator); value->iterator = NULL; }
    return Qnil;
}

static VALUE native_bam_flag_string(VALUE native, VALUE flag) {
    char *value = bam_flag2str(NUM2INT(flag));
    VALUE result = value ? rb_str_new_cstr(value) : Qnil;
    free(value);
    return result;
}

static void base_mod_mark(void *data) { rb_gc_mark_movable(((ruby_base_mod_t *)data)->record); }
static void base_mod_compact(void *data) {
    ruby_base_mod_t *value = data;
    value->record = rb_gc_location(value->record);
}
static void base_mod_free(void *data) {
    ruby_base_mod_t *value = data;
    if (value->state) hts_base_mod_state_free(value->state);
    xfree(value);
}
static size_t base_mod_size(const void *data) { return data ? sizeof(ruby_base_mod_t) : 0; }
static const rb_data_type_t base_mod_type = {
    .wrap_struct_name = "HTS::Native::BaseModHandle",
    .function = { .dmark = base_mod_mark, .dfree = base_mod_free, .dsize = base_mod_size, .dcompact = base_mod_compact },
    .flags = RUBY_TYPED_FREE_IMMEDIATELY | RUBY_TYPED_WB_PROTECTED,
};
static ruby_base_mod_t *get_base_mod(VALUE self) {
    ruby_base_mod_t *value;
    TypedData_Get_Struct(self, ruby_base_mod_t, &base_mod_type, value);
    if (!value->state) rb_raise(rb_eIOError, "closed base modification state");
    return value;
}
static VALUE native_base_mod_open(VALUE klass, VALUE record) {
    ruby_base_mod_t *value;
    VALUE object;
    get_record(record);
    object = TypedData_Make_Struct(klass, ruby_base_mod_t, &base_mod_type, value);
    value->state = hts_base_mod_state_alloc();
    if (!value->state) rb_raise(rb_eNoMemError, "failed to allocate base modification state");
    value->record = record;
    RB_OBJ_WRITE(object, &value->record, record);
    return object;
}
static VALUE native_base_mod_close(VALUE self) {
    ruby_base_mod_t *value;
    TypedData_Get_Struct(self, ruby_base_mod_t, &base_mod_type, value);
    if (value->state) { hts_base_mod_state_free(value->state); value->state = NULL; }
    return Qnil;
}
static VALUE native_base_mod_parse(VALUE self, VALUE flags) {
    ruby_base_mod_t *value = get_base_mod(self);
    return INT2NUM(bam_parse_basemod2(get_record(value->record)->pointer, value->state, NUM2INT(flags)));
}
static VALUE base_mod_array(const hts_base_mod *mods, int count) {
    int index;
    VALUE result = rb_ary_new_capa(count);
    for (index = 0; index < count; index++) {
        VALUE item = rb_ary_new_capa(4);
        rb_ary_push(item, INT2NUM(mods[index].canonical_base));
        rb_ary_push(item, INT2NUM(mods[index].modified_base));
        rb_ary_push(item, INT2NUM(mods[index].strand));
        rb_ary_push(item, INT2NUM(mods[index].qual));
        rb_ary_push(result, item);
    }
    return result;
}
static void raise_base_mod_error(const char *operation) {
    VALUE hts = rb_const_get(rb_cObject, rb_intern("HTS"));
    VALUE bam = rb_const_get(hts, rb_intern("Bam"));
    VALUE base_mod = rb_const_get(bam, rb_intern("BaseMod"));
    VALUE error = rb_const_get(base_mod, rb_intern("Error"));
    rb_raise(error, "%s failed", operation);
}
static VALUE native_base_mod_at(VALUE self, VALUE position, VALUE max_value) {
    ruby_base_mod_t *value = get_base_mod(self);
    int max = NUM2INT(max_value), count;
    hts_base_mod *mods;
    VALUE mods_storage = 0;
    if (max <= 0) rb_raise(rb_eArgError, "max_mods must be positive");
    mods = ALLOCV_N(hts_base_mod, mods_storage, max);
    count = bam_mods_at_qpos(get_record(value->record)->pointer, NUM2INT(position), value->state, mods, max);
    if (count < 0) {
        ALLOCV_END(mods_storage);
        raise_base_mod_error("bam_mods_at_qpos");
    }
    VALUE result = count > 0 ? base_mod_array(mods, count < max ? count : max) : Qnil;
    ALLOCV_END(mods_storage);
    return result;
}
static VALUE native_base_mod_each_raw(VALUE self, VALUE max_value) {
    ruby_base_mod_t *value = get_base_mod(self);
    int max = NUM2INT(max_value), count, position, index;
    hts_base_mod *mods;
    VALUE mods_storage = 0;
    if (!rb_block_given_p()) rb_raise(rb_eArgError, "block is required");
    if (max <= 0) rb_raise(rb_eArgError, "max_mods must be positive");
    mods = ALLOCV_N(hts_base_mod, mods_storage, max);
    while ((count = bam_next_basemod(get_record(value->record)->pointer, value->state, mods, max, &position)) > 0) {
        if (count > max) count = max;
        for (index = 0; index < count; index++) {
            rb_yield_values(5, INT2NUM(position), INT2NUM(mods[index].canonical_base),
                            INT2NUM(mods[index].modified_base), INT2NUM(mods[index].strand),
                            INT2NUM(mods[index].qual));
        }
    }
    if (count < 0) {
        ALLOCV_END(mods_storage);
        raise_base_mod_error("bam_next_basemod");
    }
    ALLOCV_END(mods_storage);
    return self;
}
static VALUE native_base_mod_types(VALUE self) {
    ruby_base_mod_t *value = get_base_mod(self);
    int count = 0, index, *codes = bam_mods_recorded(value->state, &count);
    VALUE result = rb_ary_new_capa(count);
    for (index = 0; index < count; index++) rb_ary_push(result, INT2NUM(codes[index]));
    return result;
}
static VALUE base_mod_info(int code, int result, int strand, int implicit, char canonical, int include_code) {
    VALUE hash;
    if (result < 0) return Qnil;
    hash = rb_hash_new();
    if (include_code) rb_hash_aset(hash, ID2SYM(rb_intern("code")), INT2NUM(code));
    rb_hash_aset(hash, ID2SYM(rb_intern("canonical")), rb_str_new(&canonical, 1));
    rb_hash_aset(hash, ID2SYM(rb_intern("strand")), INT2NUM(strand));
    rb_hash_aset(hash, ID2SYM(rb_intern("implicit")), implicit ? Qtrue : Qfalse);
    return hash;
}
static VALUE native_base_mod_query(VALUE self, VALUE code_value) {
    ruby_base_mod_t *value = get_base_mod(self);
    int code = NUM2INT(code_value), strand, implicit;
    char canonical;
    int result = bam_mods_query_type(value->state, code, &strand, &implicit, &canonical);
    return base_mod_info(code, result, strand, implicit, canonical, 0);
}
static VALUE native_base_mod_query_at(VALUE self, VALUE index_value) {
    ruby_base_mod_t *value = get_base_mod(self);
    int index = NUM2INT(index_value), strand, implicit, count = 0;
    char canonical;
    int result = bam_mods_queryi(value->state, index, &strand, &implicit, &canonical);
    int *codes = bam_mods_recorded(value->state, &count);
    int code = index >= 0 && index < count ? codes[index] : 0;
    return base_mod_info(code, result, strand, implicit, canonical, 1);
}

static void pileup_mark(void *data) {
    ruby_pileup_t *value = data;
    rb_gc_mark_movable(value->file);
    rb_gc_mark_movable(value->header);
}
static void pileup_compact(void *data) {
    ruby_pileup_t *value = data;
    value->file = rb_gc_location(value->file);
    value->header = rb_gc_location(value->header);
}
static void pileup_free(void *data) {
    ruby_pileup_t *value = data;
    if (value->pileup) bam_plp_destroy(value->pileup);
    if (value->iterator) hts_itr_destroy(value->iterator);
    xfree(value);
}
static size_t pileup_size(const void *data) { return data ? sizeof(ruby_pileup_t) : 0; }
static const rb_data_type_t pileup_type = {
    .wrap_struct_name = "HTS::Native::PileupHandle",
    .function = { .dmark = pileup_mark, .dfree = pileup_free, .dsize = pileup_size, .dcompact = pileup_compact },
    .flags = RUBY_TYPED_FREE_IMMEDIATELY | RUBY_TYPED_WB_PROTECTED,
};
static ruby_pileup_t *get_pileup(VALUE self, int allow_closed) {
    ruby_pileup_t *value;
    TypedData_Get_Struct(self, ruby_pileup_t, &pileup_type, value);
    if (!allow_closed && !value->pileup) rb_raise(rb_eIOError, "closed pileup");
    return value;
}
static int native_pileup_read(void *data, bam1_t *record) {
    ruby_pileup_t *value = data;
    ruby_bam_file_t *file = get_file(value->file, 0);
    if (value->iterator) return sam_itr_next(file->file, value->iterator, record);
    return sam_read1(file->file, get_header(value->header)->pointer, record);
}
static VALUE native_pileup_open(VALUE klass, VALUE file_value, VALUE header_value,
                                VALUE region_value, VALUE beg_value, VALUE end_value, VALUE max_value) {
    ruby_pileup_t *value;
    ruby_bam_file_t *file = get_file(file_value, 0);
    VALUE object;
    get_header(header_value);
    object = TypedData_Make_Struct(klass, ruby_pileup_t, &pileup_type, value);
    value->pileup = NULL;
    value->iterator = NULL;
    value->file = file_value;
    value->header = header_value;
    RB_OBJ_WRITE(object, &value->file, file_value);
    RB_OBJ_WRITE(object, &value->header, header_value);
    if (!NIL_P(region_value)) {
        if (!file->index) rb_raise(rb_eRuntimeError, "index file is required to use region pileup");
        if (NIL_P(beg_value) && NIL_P(end_value))
            value->iterator = sam_itr_querys(file->index, get_header(header_value)->pointer, StringValueCStr(region_value));
        else
            value->iterator = sam_itr_queryi(file->index,
                sam_hdr_name2tid(get_header(header_value)->pointer, StringValueCStr(region_value)),
                NUM2LL(beg_value), NUM2LL(end_value));
        if (!value->iterator) rb_raise(rb_eRuntimeError, "failed to query pileup region");
    }
    value->pileup = bam_plp_init(native_pileup_read, value);
    if (!value->pileup) rb_raise(rb_eNoMemError, "bam_plp_init failed");
    if (!NIL_P(max_value)) bam_plp_set_maxcnt(value->pileup, NUM2INT(max_value));
    return object;
}
static VALUE pileup_rows(const bam_pileup1_t *entries, int count) {
    int index;
    VALUE rows;
    rows = rb_ary_new_capa(count);
    for (index = 0; index < count; index++) {
        const bam_pileup1_t *entry = &entries[index];
        const bam1_t *record = entry->b;
        int qpos = entry->qpos;
        VALUE row = rb_ary_new_capa(11);
        VALUE base = Qnil, quality = Qnil;
        if (!entry->is_del && !entry->is_refskip && qpos >= 0) {
            base = INT2NUM(bam_seqi(bam_get_seq(record), qpos));
            quality = UINT2NUM(bam_get_qual(record)[qpos]);
        }
        rb_ary_push(row, wrap_record(bam_dup1(record)));
        rb_ary_push(row, INT2NUM(qpos));
        rb_ary_push(row, INT2NUM(entry->indel));
        rb_ary_push(row, entry->is_del ? Qtrue : Qfalse);
        rb_ary_push(row, entry->is_head ? Qtrue : Qfalse);
        rb_ary_push(row, entry->is_tail ? Qtrue : Qfalse);
        rb_ary_push(row, entry->is_refskip ? Qtrue : Qfalse);
        rb_ary_push(row, UINT2NUM(record->core.flag));
        rb_ary_push(row, base);
        rb_ary_push(row, quality);
        rb_ary_push(row, UINT2NUM(record->core.qual));
        rb_ary_push(rows, row);
    }
    return rows;
}
static VALUE native_pileup_next(VALUE self) {
    ruby_pileup_t *value = get_pileup(self, 0);
    int tid = -1, count = 0;
    hts_pos_t position = -1;
    const bam_pileup1_t *entries = bam_plp64_auto(value->pileup, &tid, &position, &count);
    VALUE result;
    if (!entries) {
        if (count < 0) rb_raise(rb_eRuntimeError, "HTSlib pileup error");
        return Qnil;
    }
    result = rb_ary_new_capa(3);
    rb_ary_push(result, INT2NUM(tid));
    rb_ary_push(result, LL2NUM(position));
    rb_ary_push(result, pileup_rows(entries, count));
    return result;
}
static VALUE native_pileup_reset(VALUE self) {
    bam_plp_reset(get_pileup(self, 0)->pileup);
    return Qnil;
}
static VALUE native_pileup_close(VALUE self) {
    ruby_pileup_t *value = get_pileup(self, 1);
    if (value->pileup) { bam_plp_destroy(value->pileup); value->pileup = NULL; }
    if (value->iterator) { hts_itr_destroy(value->iterator); value->iterator = NULL; }
    return Qnil;
}

static void mpileup_mark(void *data) {
    ruby_mpileup_t *value = data;
    rb_gc_mark_movable(value->files);
    rb_gc_mark_movable(value->headers);
}
static void mpileup_compact(void *data) {
    ruby_mpileup_t *value = data;
    value->files = rb_gc_location(value->files);
    value->headers = rb_gc_location(value->headers);
}
static void mpileup_release(ruby_mpileup_t *value) {
    int index;
    if (value->pileup) { bam_mplp_destroy(value->pileup); value->pileup = NULL; }
    if (value->inputs) {
        for (index = 0; index < value->count; index++) {
            if (value->inputs[index].iterator) hts_itr_destroy(value->inputs[index].iterator);
        }
        xfree(value->inputs);
        value->inputs = NULL;
    }
    xfree(value->input_data); value->input_data = NULL;
    xfree(value->depths); value->depths = NULL;
    xfree(value->entries); value->entries = NULL;
}
static void mpileup_free(void *data) {
    ruby_mpileup_t *value = data;
    mpileup_release(value);
    xfree(value);
}
static size_t mpileup_size(const void *data) {
    const ruby_mpileup_t *value = data;
    return value ? sizeof(*value) + value->count * (sizeof(ruby_mplp_input_t) + sizeof(void *) + sizeof(int) + sizeof(bam_pileup1_t *)) : 0;
}
static const rb_data_type_t mpileup_type = {
    .wrap_struct_name = "HTS::Native::MpileupHandle",
    .function = { .dmark = mpileup_mark, .dfree = mpileup_free, .dsize = mpileup_size, .dcompact = mpileup_compact },
    .flags = RUBY_TYPED_FREE_IMMEDIATELY | RUBY_TYPED_WB_PROTECTED,
};
static ruby_mpileup_t *get_mpileup(VALUE self, int allow_closed) {
    ruby_mpileup_t *value;
    TypedData_Get_Struct(self, ruby_mpileup_t, &mpileup_type, value);
    if (!allow_closed && !value->pileup) rb_raise(rb_eIOError, "closed mpileup");
    return value;
}
static int native_mpileup_read(void *data, bam1_t *record) {
    ruby_mplp_input_t *input = data;
    if (!input->file->file) return -2;
    if (input->iterator) return sam_itr_next(input->file->file, input->iterator, record);
    return sam_read1(input->file->file, input->header, record);
}
static VALUE native_mpileup_open(VALUE klass, VALUE files, VALUE headers, VALUE region,
                                 VALUE beg, VALUE end, VALUE maxcnt, VALUE overlaps) {
    ruby_mpileup_t *value;
    VALUE object;
    int index, count;
    Check_Type(files, T_ARRAY);
    Check_Type(headers, T_ARRAY);
    count = RARRAY_LEN(files);
    if (count <= 0 || RARRAY_LEN(headers) != count) rb_raise(rb_eArgError, "invalid mpileup inputs");
    object = TypedData_Make_Struct(klass, ruby_mpileup_t, &mpileup_type, value);
    memset(value, 0, sizeof(*value));
    value->count = count;
    value->files = files;
    value->headers = headers;
    RB_OBJ_WRITE(object, &value->files, files);
    RB_OBJ_WRITE(object, &value->headers, headers);
    value->inputs = ALLOC_N(ruby_mplp_input_t, count);
    value->input_data = ALLOC_N(void *, count);
    value->depths = ALLOC_N(int, count);
    value->entries = ALLOC_N(const bam_pileup1_t *, count);
    memset(value->inputs, 0, sizeof(ruby_mplp_input_t) * count);
    for (index = 0; index < count; index++) {
        ruby_bam_file_t *file = get_file(rb_ary_entry(files, index), 0);
        sam_hdr_t *header = get_header(rb_ary_entry(headers, index))->pointer;
        value->inputs[index].file = file;
        value->inputs[index].header = header;
        if (!NIL_P(region)) {
            if (!file->index) { mpileup_release(value); rb_raise(rb_eRuntimeError, "index file is required to use region mpileup"); }
            if (NIL_P(beg) && NIL_P(end))
                value->inputs[index].iterator = sam_itr_querys(file->index, header, StringValueCStr(region));
            else
                value->inputs[index].iterator = sam_itr_queryi(file->index, sam_hdr_name2tid(header, StringValueCStr(region)), NUM2LL(beg), NUM2LL(end));
            if (!value->inputs[index].iterator) { mpileup_release(value); rb_raise(rb_eRuntimeError, "failed to query mpileup region"); }
        }
        value->input_data[index] = &value->inputs[index];
    }
    value->pileup = bam_mplp_init(count, native_mpileup_read, value->input_data);
    if (!value->pileup) { mpileup_release(value); rb_raise(rb_eNoMemError, "bam_mplp_init failed"); }
    if (!NIL_P(maxcnt)) bam_mplp_set_maxcnt(value->pileup, NUM2INT(maxcnt));
    if (RTEST(overlaps) && bam_mplp_init_overlaps(value->pileup) < 0) {
        mpileup_release(value);
        rb_raise(rb_eRuntimeError, "bam_mplp_init_overlaps failed");
    }
    return object;
}
static VALUE native_mpileup_next(VALUE self) {
    ruby_mpileup_t *value = get_mpileup(self, 0);
    int tid = -1, result, index;
    hts_pos_t position = -1;
    VALUE rows, depths, output;
    result = bam_mplp64_auto(value->pileup, &tid, &position, value->depths, value->entries);
    if (result == 0) return Qnil;
    if (result < 0) rb_raise(rb_eRuntimeError, "HTSlib mpileup error");
    rows = rb_ary_new_capa(value->count);
    depths = rb_ary_new_capa(value->count);
    for (index = 0; index < value->count; index++) {
        rb_ary_push(depths, INT2NUM(value->depths[index]));
        rb_ary_push(rows, pileup_rows(value->entries[index], value->depths[index]));
    }
    output = rb_ary_new_capa(4);
    rb_ary_push(output, INT2NUM(tid));
    rb_ary_push(output, LL2NUM(position));
    rb_ary_push(output, depths);
    rb_ary_push(output, rows);
    return output;
}
static VALUE native_mpileup_reset(VALUE self) { bam_mplp_reset(get_mpileup(self, 0)->pileup); return Qnil; }
static VALUE native_mpileup_close(VALUE self) { mpileup_release(get_mpileup(self, 1)); return Qnil; }

void Init_htslib_native_bam(VALUE native) {
    cNativeSamHeader = rb_define_class_under(native, "SamHeaderHandle", rb_cObject);
    rb_undef_alloc_func(cNativeSamHeader);
    rb_define_singleton_method(cNativeSamHeader, "create", native_header_create, 0);
    rb_define_singleton_method(cNativeSamHeader, "parse", native_header_parse, 1);
    rb_define_method(cNativeSamHeader, "duplicate", native_header_duplicate, 0);
    rb_define_method(cNativeSamHeader, "target_count", native_header_target_count, 0);
    rb_define_method(cNativeSamHeader, "target_name", native_header_target_name, 1);
    rb_define_method(cNativeSamHeader, "target_length", native_header_target_length, 1);
    rb_define_method(cNativeSamHeader, "name2tid", native_header_name2tid, 1);
    rb_define_method(cNativeSamHeader, "to_s", native_header_to_s, 0);
    rb_define_method(cNativeSamHeader, "add_lines", native_header_add_lines, 1);
    rb_define_method(cNativeSamHeader, "find_line", native_header_find_line, 3);
    rb_define_method(cNativeSamHeader, "find_tag", native_header_find_tag, 4);
    rb_define_method(cNativeSamHeader, "find_line_at", native_header_find_line_at, 2);
    rb_define_method(cNativeSamHeader, "remove_line", native_header_remove_line, 3);
    rb_define_method(cNativeSamHeader, "remove_line_at", native_header_remove_line_at, 2);
    rb_define_method(cNativeSamHeader, "remove_tag", native_header_remove_tag, 4);
    rb_define_method(cNativeSamHeader, "count_lines", native_header_count_lines, 1);
    rb_define_method(cNativeSamHeader, "line_index", native_header_line_index, 2);
    rb_define_method(cNativeSamHeader, "line_name", native_header_line_name, 2);

    cNativeBamRecord = rb_define_class_under(native, "BamRecordHandle", rb_cObject);
    rb_undef_alloc_func(cNativeBamRecord);
    rb_define_singleton_method(cNativeBamRecord, "create", native_record_create, 0);
    rb_define_method(cNativeBamRecord, "duplicate", native_record_duplicate, 0);
    rb_define_method(cNativeBamRecord, "replace", native_record_replace, 11);
    rb_define_method(cNativeBamRecord, "qname", native_record_qname, 0);
    rb_define_method(cNativeBamRecord, "qname=", native_record_set_qname, 1);
    rb_define_method(cNativeBamRecord, "core_get", native_record_core_get, 1);
    rb_define_method(cNativeBamRecord, "core_set", native_record_core_set, 2);
    rb_define_method(cNativeBamRecord, "endpos", native_record_endpos, 0);
    rb_define_method(cNativeBamRecord, "cigar_values", native_record_cigar_values, 0);
    rb_define_method(cNativeBamRecord, "cigar=", native_record_set_cigar, 1);
    rb_define_method(cNativeBamRecord, "qlen", native_record_qlen, 0);
    rb_define_method(cNativeBamRecord, "rlen", native_record_rlen, 0);
    rb_define_method(cNativeBamRecord, "sequence", native_record_sequence, 0);
    rb_define_method(cNativeBamRecord, "sequence_codes", native_record_sequence_codes, 0);
    rb_define_method(cNativeBamRecord, "qualities", native_record_qualities, 0);
    rb_define_method(cNativeBamRecord, "quality_string", native_record_quality_string, 0);
    rb_define_method(cNativeBamRecord, "base_code", native_record_base_code, 1);
    rb_define_method(cNativeBamRecord, "quality_at", native_record_quality_at, 1);
    rb_define_method(cNativeBamRecord, "format", native_record_to_s, 1);
    rb_define_method(cNativeBamRecord, "aux_get", native_record_aux_get, 2);
    rb_define_method(cNativeBamRecord, "aux_entries", native_record_aux_entries, 0);
    rb_define_method(cNativeBamRecord, "aux_update_int", native_record_aux_update_int, 2);
    rb_define_method(cNativeBamRecord, "aux_update_float", native_record_aux_update_float, 2);
    rb_define_method(cNativeBamRecord, "aux_update_string", native_record_aux_update_string, 2);
    rb_define_method(cNativeBamRecord, "aux_append", native_record_aux_append, 3);
    rb_define_method(cNativeBamRecord, "aux_update_array", native_record_aux_update_array, 3);
    rb_define_method(cNativeBamRecord, "aux_delete", native_record_aux_delete, 1);
    rb_define_method(cNativeBamRecord, "aux_key?", native_record_aux_key, 1);

    cNativeBamFile = rb_define_class_under(native, "BamFileHandle", rb_cObject);
    rb_undef_alloc_func(cNativeBamFile);
    rb_define_singleton_method(cNativeBamFile, "open", native_bam_open, 2);
    rb_define_singleton_method(cNativeBamFile, "build_index", native_bam_build_index, 4);
    rb_define_method(cNativeBamFile, "close", native_bam_close, 0);
    rb_define_method(cNativeBamFile, "closed?", native_bam_closed, 0);
    rb_define_method(cNativeBamFile, "read_header", native_bam_read_header, 0);
    rb_define_method(cNativeBamFile, "write_header", native_bam_write_header, 1);
    rb_define_method(cNativeBamFile, "read", native_bam_read, 2);
    rb_define_method(cNativeBamFile, "write", native_bam_write, 2);
    rb_define_method(cNativeBamFile, "set_fai", native_bam_set_fai, 1);
    rb_define_method(cNativeBamFile, "set_threads", native_bam_set_threads, 1);
    rb_define_method(cNativeBamFile, "file_format", native_bam_format, 0);
    rb_define_method(cNativeBamFile, "file_format_version", native_bam_format_version, 0);
    rb_define_method(cNativeBamFile, "seek", native_bam_seek, 1);
    rb_define_method(cNativeBamFile, "tell", native_bam_tell, 0);
    rb_define_method(cNativeBamFile, "load_index", native_bam_load_index, 1);
    rb_define_method(cNativeBamFile, "index_loaded?", native_bam_index_loaded, 0);
    rb_define_method(cNativeBamFile, "query_interval", native_bam_query_interval, 3);
    rb_define_method(cNativeBamFile, "query_region", native_bam_query_region, 2);

    cNativeBamIterator = rb_define_class_under(native, "BamIteratorHandle", rb_cObject);
    rb_undef_alloc_func(cNativeBamIterator);
    rb_define_method(cNativeBamIterator, "next", native_bam_iterator_next, 1);
    rb_define_method(cNativeBamIterator, "close", native_bam_iterator_close, 0);

    rb_define_singleton_method(native, "cigar_parse", native_cigar_parse, 1);
    rb_define_singleton_method(native, "cigar_qlen", native_cigar_qlen, 1);
    rb_define_singleton_method(native, "cigar_rlen", native_cigar_rlen, 1);
    rb_define_singleton_method(native, "bam_flag_string", native_bam_flag_string, 1);

    cNativeBaseMod = rb_define_class_under(native, "BaseModHandle", rb_cObject);
    rb_undef_alloc_func(cNativeBaseMod);
    rb_define_singleton_method(cNativeBaseMod, "open", native_base_mod_open, 1);
    rb_define_method(cNativeBaseMod, "close", native_base_mod_close, 0);
    rb_define_method(cNativeBaseMod, "parse", native_base_mod_parse, 1);
    rb_define_method(cNativeBaseMod, "at", native_base_mod_at, 2);
    rb_define_method(cNativeBaseMod, "each_raw", native_base_mod_each_raw, 1);
    rb_define_method(cNativeBaseMod, "types", native_base_mod_types, 0);
    rb_define_method(cNativeBaseMod, "query", native_base_mod_query, 1);
    rb_define_method(cNativeBaseMod, "query_at", native_base_mod_query_at, 1);

    cNativePileup = rb_define_class_under(native, "PileupHandle", rb_cObject);
    rb_undef_alloc_func(cNativePileup);
    rb_define_singleton_method(cNativePileup, "open", native_pileup_open, 6);
    rb_define_method(cNativePileup, "next", native_pileup_next, 0);
    rb_define_method(cNativePileup, "reset", native_pileup_reset, 0);
    rb_define_method(cNativePileup, "close", native_pileup_close, 0);

    cNativeMpileup = rb_define_class_under(native, "MpileupHandle", rb_cObject);
    rb_undef_alloc_func(cNativeMpileup);
    rb_define_singleton_method(cNativeMpileup, "open", native_mpileup_open, 7);
    rb_define_method(cNativeMpileup, "next", native_mpileup_next, 0);
    rb_define_method(cNativeMpileup, "reset", native_mpileup_reset, 0);
    rb_define_method(cNativeMpileup, "close", native_mpileup_close, 0);
}
