#include "htslib_native.h"
#include <htslib/hts.h>

static VALUE native_htslib_version(VALUE self)
{
    return rb_str_new_cstr(hts_version());
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

void Init_htslib_native_ext(void)
{
    VALUE hts = rb_define_module("HTS");
    VALUE native = rb_define_module_under(hts, "Native");
    rb_define_module_function(native, "htslib_version", native_htslib_version, 0);
    rb_define_module_function(native, "selected_fields", selected_fields, 2);
    Init_htslib_native_faidx(native);
    Init_htslib_native_tabix(native);
    Init_htslib_native_bam(native);
    Init_htslib_native_bcf(native);
}
