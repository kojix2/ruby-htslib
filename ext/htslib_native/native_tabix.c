#include "htslib_native.h"

#include <htslib/hts.h>
#include <htslib/kstring.h>
#include <htslib/tbx.h>
#include <stdlib.h>

typedef struct {
    htsFile *file;
    tbx_t *index;
    VALUE path;
    int active_queries;
} ruby_tabix_t;

typedef struct {
    ruby_tabix_t *handle;
    hts_itr_t *iterator;
    kstring_t line;
} tabix_query_t;

static VALUE cNativeTabix;

static void ruby_tabix_mark(void *pointer)
{
    ruby_tabix_t *handle = pointer;
    rb_gc_mark_movable(handle->path);
}

static void ruby_tabix_compact(void *pointer)
{
    ruby_tabix_t *handle = pointer;
    handle->path = rb_gc_location(handle->path);
}

static void ruby_tabix_free(void *pointer)
{
    ruby_tabix_t *handle = pointer;
    if (handle->index != NULL) tbx_destroy(handle->index);
    if (handle->file != NULL) hts_close(handle->file);
    xfree(handle);
}

static size_t ruby_tabix_size(const void *pointer)
{
    return pointer == NULL ? 0 : sizeof(ruby_tabix_t);
}

static const rb_data_type_t ruby_tabix_type = {
    .wrap_struct_name = "HTS::Native::TabixHandle",
    .function = {
        .dmark = ruby_tabix_mark,
        .dfree = ruby_tabix_free,
        .dsize = ruby_tabix_size,
        .dcompact = ruby_tabix_compact,
    },
    .flags = RUBY_TYPED_FREE_IMMEDIATELY | RUBY_TYPED_WB_PROTECTED,
};

static ruby_tabix_t *get_tabix(VALUE self, int allow_closed)
{
    ruby_tabix_t *handle;
    TypedData_Get_Struct(self, ruby_tabix_t, &ruby_tabix_type, handle);
    if (!allow_closed && handle->file == NULL) rb_raise(rb_eIOError, "closed Tabix");
    return handle;
}

static VALUE native_tabix_open(VALUE klass, VALUE path_value)
{
    ruby_tabix_t *handle;
    VALUE object = TypedData_Make_Struct(klass, ruby_tabix_t, &ruby_tabix_type, handle);
    handle->index = NULL;
    handle->active_queries = 0;
    handle->path = rb_str_dup(StringValue(path_value));
    RB_OBJ_WRITE(object, &handle->path, handle->path);
    handle->file = hts_open(StringValueCStr(handle->path), "r");
    if (handle->file == NULL) rb_syserr_fail_str(ENOENT, path_value);
    return object;
}

static VALUE native_tabix_close(VALUE self)
{
    ruby_tabix_t *handle = get_tabix(self, 1);
    if (handle->active_queries > 0) rb_raise(rb_eIOError, "cannot close Tabix during an active query");
    if (handle->index != NULL) {
        tbx_destroy(handle->index);
        handle->index = NULL;
    }
    if (handle->file != NULL) {
        hts_close(handle->file);
        handle->file = NULL;
    }
    return Qnil;
}

static VALUE native_tabix_closed(VALUE self)
{
    return get_tabix(self, 1)->file == NULL ? Qtrue : Qfalse;
}

static VALUE native_tabix_set_threads(VALUE self, VALUE count_value)
{
    ruby_tabix_t *handle = get_tabix(self, 0);
    return INT2NUM(hts_set_threads(handle->file, NUM2INT(count_value)));
}

static VALUE native_tabix_format(VALUE self)
{
    ruby_tabix_t *handle = get_tabix(self, 0);
    const htsFormat *format = hts_get_format(handle->file);
    if (format == NULL) return Qnil;
    switch (format->format) {
    case vcf: return rb_str_new_cstr("vcf");
    case bcf: return rb_str_new_cstr("bcf");
    case sam: return rb_str_new_cstr("sam");
    case bam: return rb_str_new_cstr("bam");
    case cram: return rb_str_new_cstr("cram");
    case bed: return rb_str_new_cstr("bed");
    default: return rb_str_new_cstr("unknown_format");
    }
}

static VALUE native_tabix_format_version(VALUE self)
{
    ruby_tabix_t *handle = get_tabix(self, 0);
    const htsFormat *format = hts_get_format(handle->file);
    if (format == NULL) return Qnil;
    if (format->version.minor == -1) return rb_sprintf("%d", format->version.major);
    return rb_sprintf("%d.%d", format->version.major, format->version.minor);
}

static VALUE native_tabix_build(VALUE klass, VALUE path_value, VALUE index_value, VALUE shift_value)
{
    const char *path = StringValueCStr(path_value);
    int shift = NUM2INT(shift_value), result;
    if (NIL_P(index_value)) {
        result = tbx_index_build(path, shift, &tbx_conf_vcf);
    } else {
        result = tbx_index_build2(path, StringValueCStr(index_value), shift, &tbx_conf_vcf);
    }
    return INT2NUM(result);
}

static VALUE native_tabix_load_index(VALUE self, VALUE index_value)
{
    ruby_tabix_t *handle = get_tabix(self, 0);
    if (handle->index != NULL) {
        tbx_destroy(handle->index);
        handle->index = NULL;
    }
    handle->index = NIL_P(index_value)
        ? tbx_index_load3(StringValueCStr(handle->path), NULL, HTS_IDX_SAVE_REMOTE)
        : tbx_index_load2(StringValueCStr(handle->path), StringValueCStr(index_value));
    return handle->index == NULL ? Qfalse : Qtrue;
}

static VALUE native_tabix_index_loaded(VALUE self)
{
    return get_tabix(self, 0)->index == NULL ? Qfalse : Qtrue;
}

static VALUE native_tabix_name2id(VALUE self, VALUE name_value)
{
    ruby_tabix_t *handle = get_tabix(self, 0);
    if (handle->index == NULL) rb_raise(rb_eRuntimeError, "index file is required");
    return INT2NUM(tbx_name2id(handle->index, StringValueCStr(name_value)));
}

static VALUE native_tabix_seqnames(VALUE self)
{
    ruby_tabix_t *handle = get_tabix(self, 0);
    const char **names;
    int count = 0, index;
    VALUE result;
    if (handle->index == NULL) rb_raise(rb_eRuntimeError, "index file is required");
    names = tbx_seqnames(handle->index, &count);
    result = rb_ary_new_capa(count);
    for (index = 0; index < count; index++) rb_ary_push(result, rb_str_new_cstr(names[index]));
    free(names);
    return result;
}

static VALUE tabix_query_body(VALUE data_value)
{
    tabix_query_t *query = (tabix_query_t *)data_value;
    int result;
    while ((result = tbx_itr_next(query->handle->file, query->handle->index,
                                  query->iterator, &query->line)) >= 0) {
        rb_yield(rb_str_new(query->line.s, query->line.l));
    }
    if (result < -1) rb_raise(rb_eRuntimeError, "failed while reading Tabix query");
    return Qnil;
}

static VALUE tabix_query_cleanup(VALUE data_value)
{
    tabix_query_t *query = (tabix_query_t *)data_value;
    if (query->iterator != NULL) hts_itr_destroy(query->iterator);
    free(query->line.s);
    query->handle->active_queries--;
    return Qnil;
}

static VALUE native_tabix_query_region(VALUE self, VALUE region_value)
{
    ruby_tabix_t *handle = get_tabix(self, 0);
    tabix_query_t query = { .handle = handle, .iterator = NULL, .line = KS_INITIALIZE };
    if (!rb_block_given_p()) rb_raise(rb_eArgError, "block is required");
    if (handle->index == NULL) rb_raise(rb_eRuntimeError, "index file is required");
    query.iterator = tbx_itr_querys(handle->index, StringValueCStr(region_value));
    if (query.iterator == NULL) rb_raise(rb_eRuntimeError, "failed to query region");
    handle->active_queries++;
    rb_ensure(tabix_query_body, (VALUE)&query, tabix_query_cleanup, (VALUE)&query);
    return self;
}

static VALUE native_tabix_query_interval(VALUE self, VALUE id_value, VALUE start_value, VALUE end_value)
{
    ruby_tabix_t *handle = get_tabix(self, 0);
    tabix_query_t query = { .handle = handle, .iterator = NULL, .line = KS_INITIALIZE };
    if (!rb_block_given_p()) rb_raise(rb_eArgError, "block is required");
    if (handle->index == NULL) rb_raise(rb_eRuntimeError, "index file is required");
    query.iterator = tbx_itr_queryi(handle->index, NUM2INT(id_value), NUM2LL(start_value), NUM2LL(end_value));
    if (query.iterator == NULL) rb_raise(rb_eRuntimeError, "failed to query region");
    handle->active_queries++;
    rb_ensure(tabix_query_body, (VALUE)&query, tabix_query_cleanup, (VALUE)&query);
    return self;
}

void Init_htslib_native_tabix(VALUE native)
{
    cNativeTabix = rb_define_class_under(native, "TabixHandle", rb_cObject);
    rb_undef_alloc_func(cNativeTabix);
    rb_define_singleton_method(cNativeTabix, "open", native_tabix_open, 1);
    rb_define_singleton_method(cNativeTabix, "build", native_tabix_build, 3);
    rb_define_method(cNativeTabix, "close", native_tabix_close, 0);
    rb_define_method(cNativeTabix, "closed?", native_tabix_closed, 0);
    rb_define_method(cNativeTabix, "set_threads", native_tabix_set_threads, 1);
    rb_define_method(cNativeTabix, "file_format", native_tabix_format, 0);
    rb_define_method(cNativeTabix, "file_format_version", native_tabix_format_version, 0);
    rb_define_method(cNativeTabix, "load_index", native_tabix_load_index, 1);
    rb_define_method(cNativeTabix, "index_loaded?", native_tabix_index_loaded, 0);
    rb_define_method(cNativeTabix, "name2id", native_tabix_name2id, 1);
    rb_define_method(cNativeTabix, "seqnames", native_tabix_seqnames, 0);
    rb_define_method(cNativeTabix, "query_region", native_tabix_query_region, 1);
    rb_define_method(cNativeTabix, "query_interval", native_tabix_query_interval, 3);
}
