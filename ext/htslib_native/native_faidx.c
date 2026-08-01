#include "htslib_native.h"

#include <htslib/faidx.h>
#include <stdlib.h>

typedef struct {
    faidx_t *fai;
} ruby_faidx_t;

static VALUE cNativeFaidx;

static void ruby_faidx_free(void *pointer)
{
    ruby_faidx_t *handle = pointer;
    if (handle->fai != NULL) fai_destroy(handle->fai);
    xfree(handle);
}

static size_t ruby_faidx_size(const void *pointer)
{
    return pointer == NULL ? 0 : sizeof(ruby_faidx_t);
}

static const rb_data_type_t ruby_faidx_type = {
    .wrap_struct_name = "HTS::Native::FaidxHandle",
    .function = {
        .dmark = NULL,
        .dfree = ruby_faidx_free,
        .dsize = ruby_faidx_size,
    },
    .flags = RUBY_TYPED_FREE_IMMEDIATELY,
};

static ruby_faidx_t *get_faidx(VALUE self, int allow_closed)
{
    ruby_faidx_t *handle;
    TypedData_Get_Struct(self, ruby_faidx_t, &ruby_faidx_type, handle);
    if (!allow_closed && handle->fai == NULL) rb_raise(rb_eIOError, "closed Faidx");
    return handle;
}

static VALUE native_faidx_open(VALUE klass, VALUE path_value, VALUE format_value, VALUE auto_build_value)
{
    ruby_faidx_t *handle;
    VALUE object;
    const char *path = StringValueCStr(path_value);
    enum fai_format_options format = NUM2INT(format_value) == 1 ? FAI_FASTQ : FAI_FASTA;

    object = TypedData_Make_Struct(klass, ruby_faidx_t, &ruby_faidx_type, handle);
    handle->fai = RTEST(auto_build_value)
        ? fai_load_format(path, format)
        : fai_load3_format(path, NULL, NULL, 0, format);
    if (handle->fai == NULL) rb_syserr_fail_str(ENOENT, path_value);
    return object;
}

static VALUE native_faidx_build(VALUE klass, VALUE path_value, VALUE fai_value, VALUE gzi_value)
{
    const char *path = StringValueCStr(path_value);
    const char *fai_path = NIL_P(fai_value) ? NULL : StringValueCStr(fai_value);
    const char *gzi_path = NIL_P(gzi_value) ? NULL : StringValueCStr(gzi_value);
    return INT2NUM(fai_build3(path, fai_path, gzi_path));
}

static VALUE native_faidx_close(VALUE self)
{
    ruby_faidx_t *handle = get_faidx(self, 1);
    if (handle->fai != NULL) {
        fai_destroy(handle->fai);
        handle->fai = NULL;
    }
    return Qnil;
}

static VALUE native_faidx_closed(VALUE self)
{
    return get_faidx(self, 1)->fai == NULL ? Qtrue : Qfalse;
}

static VALUE native_faidx_size_method(VALUE self)
{
    return INT2NUM(faidx_nseq(get_faidx(self, 0)->fai));
}

static VALUE native_faidx_names(VALUE self)
{
    faidx_t *fai = get_faidx(self, 0)->fai;
    int count = faidx_nseq(fai), index;
    VALUE result = rb_ary_new_capa(count);
    for (index = 0; index < count; index++) {
        const char *name = faidx_iseq(fai, index);
        rb_ary_push(result, name == NULL ? Qnil : rb_str_new_cstr(name));
    }
    return result;
}

static VALUE native_faidx_has_seq(VALUE self, VALUE name_value)
{
    faidx_t *fai = get_faidx(self, 0)->fai;
    int result = faidx_has_seq(fai, StringValueCStr(name_value));
    if (result == 1) return Qtrue;
    if (result == 0) return Qfalse;
    rb_raise(rb_eRuntimeError, "unexpected return value from faidx_has_seq");
}

static VALUE native_faidx_seq_len(VALUE self, VALUE name_value)
{
    faidx_t *fai = get_faidx(self, 0)->fai;
    return LL2NUM(faidx_seq_len64(fai, StringValueCStr(name_value)));
}

static VALUE faidx_fetch_result(char *result, hts_pos_t length)
{
    VALUE string = Qnil, pair;
    if (result != NULL && length >= 0) string = rb_str_new(result, length);
    free(result);
    pair = rb_ary_new_capa(2);
    rb_ary_push(pair, LL2NUM(length));
    rb_ary_push(pair, string);
    return pair;
}

static VALUE native_faidx_fetch_seq(VALUE self, VALUE name_value, VALUE start_value, VALUE stop_value)
{
    faidx_t *fai = get_faidx(self, 0)->fai;
    hts_pos_t length = 0;
    char *result = faidx_fetch_seq64(fai, StringValueCStr(name_value),
                                     NUM2LL(start_value), NUM2LL(stop_value), &length);
    return faidx_fetch_result(result, length);
}

static VALUE native_faidx_fetch_qual(VALUE self, VALUE name_value, VALUE start_value, VALUE stop_value)
{
    faidx_t *fai = get_faidx(self, 0)->fai;
    hts_pos_t length = 0;
    char *result = faidx_fetch_qual64(fai, StringValueCStr(name_value),
                                      NUM2LL(start_value), NUM2LL(stop_value), &length);
    return faidx_fetch_result(result, length);
}

void Init_htslib_native_faidx(VALUE native)
{
    cNativeFaidx = rb_define_class_under(native, "FaidxHandle", rb_cObject);
    rb_undef_alloc_func(cNativeFaidx);
    rb_define_singleton_method(cNativeFaidx, "open", native_faidx_open, 3);
    rb_define_singleton_method(cNativeFaidx, "build", native_faidx_build, 3);
    rb_define_method(cNativeFaidx, "close", native_faidx_close, 0);
    rb_define_method(cNativeFaidx, "closed?", native_faidx_closed, 0);
    rb_define_method(cNativeFaidx, "size", native_faidx_size_method, 0);
    rb_define_method(cNativeFaidx, "names", native_faidx_names, 0);
    rb_define_method(cNativeFaidx, "has_seq?", native_faidx_has_seq, 1);
    rb_define_method(cNativeFaidx, "seq_len", native_faidx_seq_len, 1);
    rb_define_method(cNativeFaidx, "fetch_seq", native_faidx_fetch_seq, 3);
    rb_define_method(cNativeFaidx, "fetch_qual", native_faidx_fetch_qual, 3);
}
