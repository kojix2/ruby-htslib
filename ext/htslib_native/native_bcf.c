#include "htslib_native.h"
#include <ruby/thread.h>

#include <htslib/bgzf.h>
#include <htslib/hfile.h>
#include <htslib/hts.h>
#include <htslib/kstring.h>
#include <htslib/tbx.h>
#include <htslib/vcf.h>
#include <errno.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>

typedef struct { bcf_hdr_t *pointer; } ruby_bcf_header_t;
typedef struct { bcf1_t *pointer; } ruby_bcf_record_t;
typedef struct { bcf_hrec_t *pointer; } ruby_bcf_hrec_t;
typedef struct {
    htsFile *file;
    hts_idx_t *index;
    tbx_t *tabix;
    VALUE path;
    int active_io;
} ruby_bcf_file_t;
typedef struct {
    hts_itr_t *iterator;
    VALUE file;
    VALUE header;
    int tabix;
    kstring_t line;
} ruby_bcf_iterator_t;

static VALUE cBcfHeader, cBcfRecord, cBcfHrec, cBcfFile, cBcfIterator;

static void bcf_header_free(void *data) { ruby_bcf_header_t *v=data; if(v->pointer) bcf_hdr_destroy(v->pointer); xfree(v); }
static size_t bcf_header_size(const void *data) { return data ? sizeof(ruby_bcf_header_t) : 0; }
static const rb_data_type_t bcf_header_type = {
    .wrap_struct_name="HTS::Native::BcfHeaderHandle",
    .function={.dfree=bcf_header_free,.dsize=bcf_header_size}, .flags=RUBY_TYPED_FREE_IMMEDIATELY
};
static ruby_bcf_header_t *get_bcf_header(VALUE self) {
    ruby_bcf_header_t *v; TypedData_Get_Struct(self,ruby_bcf_header_t,&bcf_header_type,v);
    if(!v->pointer) rb_raise(rb_eIOError,"closed BCF header");
    return v;
}
static VALUE wrap_bcf_header(bcf_hdr_t *pointer) {
    ruby_bcf_header_t *v; VALUE object;
    if(!pointer) rb_raise(rb_eRuntimeError,"failed to create BCF header");
    object=TypedData_Make_Struct(cBcfHeader,ruby_bcf_header_t,&bcf_header_type,v); v->pointer=pointer; return object;
}

static void bcf_record_free(void *data) { ruby_bcf_record_t *v=data; if(v->pointer) bcf_destroy(v->pointer); xfree(v); }
static size_t bcf_record_size(const void *data) { return data ? sizeof(ruby_bcf_record_t) : 0; }
static const rb_data_type_t bcf_record_type = {
    .wrap_struct_name="HTS::Native::BcfRecordHandle",
    .function={.dfree=bcf_record_free,.dsize=bcf_record_size}, .flags=RUBY_TYPED_FREE_IMMEDIATELY
};
static ruby_bcf_record_t *get_bcf_record(VALUE self) {
    ruby_bcf_record_t *v; TypedData_Get_Struct(self,ruby_bcf_record_t,&bcf_record_type,v);
    if(!v->pointer) rb_raise(rb_eIOError,"closed BCF record");
    return v;
}
static VALUE wrap_bcf_record(bcf1_t *pointer) {
    ruby_bcf_record_t *v; VALUE object;
    if(!pointer) rb_raise(rb_eNoMemError,"bcf_init failed");
    object=TypedData_Make_Struct(cBcfRecord,ruby_bcf_record_t,&bcf_record_type,v); v->pointer=pointer; return object;
}

static void bcf_hrec_free(void *data) { ruby_bcf_hrec_t *v=data; if(v->pointer) bcf_hrec_destroy(v->pointer); xfree(v); }
static size_t bcf_hrec_size(const void *data) { return data ? sizeof(ruby_bcf_hrec_t) : 0; }
static const rb_data_type_t bcf_hrec_type = {
    .wrap_struct_name="HTS::Native::BcfHeaderRecordHandle",
    .function={.dfree=bcf_hrec_free,.dsize=bcf_hrec_size}, .flags=RUBY_TYPED_FREE_IMMEDIATELY
};
static ruby_bcf_hrec_t *get_bcf_hrec(VALUE self) {
    ruby_bcf_hrec_t *v; TypedData_Get_Struct(self,ruby_bcf_hrec_t,&bcf_hrec_type,v);
    if(!v->pointer) rb_raise(rb_eIOError,"closed BCF header record");
    return v;
}
static VALUE wrap_bcf_hrec(bcf_hrec_t *pointer) {
    ruby_bcf_hrec_t *v; VALUE object;
    if(!pointer) return Qnil;
    object=TypedData_Make_Struct(cBcfHrec,ruby_bcf_hrec_t,&bcf_hrec_type,v); v->pointer=pointer; return object;
}

static void bcf_file_mark(void *data) { rb_gc_mark_movable(((ruby_bcf_file_t*)data)->path); }
static void bcf_file_compact(void *data) { ruby_bcf_file_t *v=data; v->path=rb_gc_location(v->path); }
static void bcf_file_free(void *data) {
    ruby_bcf_file_t *v=data; if(v->index) hts_idx_destroy(v->index); if(v->tabix) tbx_destroy(v->tabix);
    if(v->file) hts_close(v->file);
    xfree(v);
}
static size_t bcf_file_size(const void *data) { return data ? sizeof(ruby_bcf_file_t) : 0; }
static const rb_data_type_t bcf_file_type = {
    .wrap_struct_name="HTS::Native::BcfFileHandle",
    .function={.dmark=bcf_file_mark,.dfree=bcf_file_free,.dsize=bcf_file_size,.dcompact=bcf_file_compact},
    .flags=RUBY_TYPED_FREE_IMMEDIATELY|RUBY_TYPED_WB_PROTECTED
};
static ruby_bcf_file_t *get_bcf_file(VALUE self,int allow_closed) {
    ruby_bcf_file_t *v; TypedData_Get_Struct(self,ruby_bcf_file_t,&bcf_file_type,v);
    if(!allow_closed && !v->file) rb_raise(rb_eIOError,"closed stream");
    return v;
}

static void bcf_iterator_mark(void *data) { ruby_bcf_iterator_t *v=data; rb_gc_mark_movable(v->file); rb_gc_mark_movable(v->header); }
static void bcf_iterator_compact(void *data) { ruby_bcf_iterator_t *v=data; v->file=rb_gc_location(v->file); v->header=rb_gc_location(v->header); }
static void bcf_iterator_free(void *data) { ruby_bcf_iterator_t *v=data; if(v->iterator) hts_itr_destroy(v->iterator); free(v->line.s); xfree(v); }
static size_t bcf_iterator_size(const void *data) { return data ? sizeof(ruby_bcf_iterator_t) : 0; }
static const rb_data_type_t bcf_iterator_type = {
    .wrap_struct_name="HTS::Native::BcfIteratorHandle",
    .function={.dmark=bcf_iterator_mark,.dfree=bcf_iterator_free,.dsize=bcf_iterator_size,.dcompact=bcf_iterator_compact},
    .flags=RUBY_TYPED_FREE_IMMEDIATELY|RUBY_TYPED_WB_PROTECTED
};
static ruby_bcf_iterator_t *get_bcf_iterator(VALUE self) {
    ruby_bcf_iterator_t *v; TypedData_Get_Struct(self,ruby_bcf_iterator_t,&bcf_iterator_type,v);
    if(!v->iterator) rb_raise(rb_eIOError,"closed BCF iterator");
    return v;
}
static VALUE wrap_bcf_iterator(VALUE file,VALUE header,hts_itr_t *iterator,int tabix) {
    ruby_bcf_iterator_t *v; VALUE object; if(!iterator) return Qnil;
    object=TypedData_Make_Struct(cBcfIterator,ruby_bcf_iterator_t,&bcf_iterator_type,v);
    v->iterator=iterator; v->file=file; v->header=header; v->tabix=tabix; v->line=(kstring_t)KS_INITIALIZE;
    RB_OBJ_WRITE(object,&v->file,file); RB_OBJ_WRITE(object,&v->header,header); return object;
}

/* Header */
static VALUE native_bcf_header_create(VALUE klass) { return wrap_bcf_header(bcf_hdr_init("w")); }
static VALUE native_bcf_header_duplicate(VALUE self) { return wrap_bcf_header(bcf_hdr_dup(get_bcf_header(self)->pointer)); }
static VALUE native_bcf_header_version(VALUE self) { const char *v=bcf_hdr_get_version(get_bcf_header(self)->pointer); return v?rb_str_new_cstr(v):Qnil; }
static VALUE native_bcf_header_set_version(VALUE self,VALUE value) { return INT2NUM(bcf_hdr_set_version(get_bcf_header(self)->pointer,StringValueCStr(value))); }
static VALUE native_bcf_header_read_file(VALUE self,VALUE path) { return INT2NUM(bcf_hdr_set(get_bcf_header(self)->pointer,StringValueCStr(path))); }
static VALUE native_bcf_header_nsamples(VALUE self) { return INT2NUM(bcf_hdr_nsamples(get_bcf_header(self)->pointer)); }
static VALUE native_bcf_header_samples(VALUE self) {
    bcf_hdr_t *h=get_bcf_header(self)->pointer; int count=bcf_hdr_nsamples(h),i; VALUE a=rb_ary_new_capa(count);
    for(i=0;i<count;i++) rb_ary_push(a,rb_str_new_cstr(h->samples[i]));
    return a;
}
static VALUE native_bcf_header_seqnames(VALUE self) {
    int count=0,i; const char **names=bcf_hdr_seqnames(get_bcf_header(self)->pointer,&count); VALUE a=rb_ary_new_capa(count);
    for(i=0;i<count;i++) rb_ary_push(a,rb_str_new_cstr(names[i]));
    free(names);
    return a;
}
static VALUE native_bcf_header_name2id(VALUE self,VALUE name) { return INT2NUM(bcf_hdr_name2id(get_bcf_header(self)->pointer,StringValueCStr(name))); }
static VALUE native_bcf_header_id2name(VALUE self,VALUE id) { const char *v=bcf_hdr_id2name(get_bcf_header(self)->pointer,NUM2INT(id)); return v?rb_str_new_cstr(v):Qnil; }
static VALUE native_bcf_header_add_sample(VALUE self,VALUE sample) { return INT2NUM(bcf_hdr_add_sample(get_bcf_header(self)->pointer,StringValueCStr(sample))); }
static VALUE native_bcf_header_sync(VALUE self) { return INT2NUM(bcf_hdr_sync(get_bcf_header(self)->pointer)); }
static VALUE native_bcf_header_append(VALUE self,VALUE line) { return INT2NUM(bcf_hdr_append(get_bcf_header(self)->pointer,StringValueCStr(line))); }
static VALUE native_bcf_header_merge(VALUE self,VALUE other) {
    bcf_hdr_t *result=bcf_hdr_merge(get_bcf_header(self)->pointer,get_bcf_header(other)->pointer);
    if(!result) rb_raise(rb_eRuntimeError,"failed to merge BCF headers");
    return self;
}
static VALUE native_bcf_header_to_s(VALUE self) {
    kstring_t str=KS_INITIALIZE; VALUE result;
    if(bcf_hdr_format(get_bcf_header(self)->pointer,0,&str)<0) { free(str.s); rb_raise(rb_eRuntimeError,"failed to format BCF header"); }
    result=rb_str_new(str.s,str.l); free(str.s); return result;
}
static int header_kind(VALUE kind) {
    const char *s=StringValueCStr(kind);
    if(!strcasecmp(s,"FILTER")||!strcasecmp(s,"FIL")) return BCF_HL_FLT;
    if(!strcasecmp(s,"INFO")) return BCF_HL_INFO;
    if(!strcasecmp(s,"FORMAT")||!strcasecmp(s,"FMT")) return BCF_HL_FMT;
    if(!strcasecmp(s,"CONTIG")||!strcasecmp(s,"CTG")) return BCF_HL_CTG;
    if(!strcasecmp(s,"STRUCTURED")||!strcasecmp(s,"STR")) return BCF_HL_STR;
    if(!strcasecmp(s,"GENOTYPE")||!strcasecmp(s,"GEN")) return BCF_HL_GEN;
    rb_raise(rb_eTypeError,"invalid BCF header kind");
}
static VALUE native_bcf_header_remove(VALUE self,VALUE kind,VALUE key) {
    bcf_hdr_remove(get_bcf_header(self)->pointer,header_kind(kind),NIL_P(key)?NULL:StringValueCStr(key)); return Qnil;
}
static VALUE native_bcf_header_get_hrec(VALUE self,VALUE kind,VALUE key,VALUE value,VALUE str_class) {
    bcf_hrec_t *record=bcf_hdr_get_hrec(get_bcf_header(self)->pointer,header_kind(kind),
        NIL_P(key)?NULL:StringValueCStr(key),NIL_P(value)?NULL:StringValueCStr(value),
        NIL_P(str_class)?NULL:StringValueCStr(str_class));
    return record?wrap_bcf_hrec(bcf_hrec_dup(record)):Qnil;
}
static VALUE type_symbol(int type) {
    switch(type) { case BCF_HT_FLAG:return ID2SYM(rb_intern("flag")); case BCF_HT_INT:return ID2SYM(rb_intern("int"));
    case BCF_HT_REAL:return ID2SYM(rb_intern("float")); case BCF_HT_STR:return ID2SYM(rb_intern("string"));
    case BCF_HT_LONG:return ID2SYM(rb_intern("int64")); default:return Qnil; }
}
static VALUE native_bcf_header_schema(VALUE self,VALUE kind_value,VALUE key_value) {
    bcf_hdr_t *h=get_bcf_header(self)->pointer; int kind=header_kind(kind_value), id=bcf_hdr_id2int(h,BCF_DT_ID,StringValueCStr(key_value));
    VALUE result;
    if(id<0 || !bcf_hdr_idinfo_exists(h,kind,id)) return Qnil;
    result=rb_ary_new_capa(3); rb_ary_push(result,type_symbol(bcf_hdr_id2type(h,kind,id)));
    rb_ary_push(result,INT2NUM(bcf_hdr_id2number(h,kind,id))); rb_ary_push(result,INT2NUM(id)); return result;
}
static VALUE native_bcf_header_subset(VALUE self,VALUE samples) {
    bcf_hdr_t *h=get_bcf_header(self)->pointer,*subset; int count=RARRAY_LEN(samples),i; char **names=NULL; int *imap=NULL; VALUE map,names_storage=0,imap_storage=0;
    if(count>0) { names=ALLOCV_N(char*,names_storage,count); imap=ALLOCV_N(int,imap_storage,count); for(i=0;i<count;i++) { VALUE sample=rb_ary_entry(samples,i); names[i]=StringValueCStr(sample); } }
    subset=bcf_hdr_subset(h,count,names,imap); ALLOCV_END(names_storage); if(!subset){ALLOCV_END(imap_storage);return Qnil;}
    VALUE subset_value=wrap_bcf_header(subset);
    map=rb_ary_new_capa(count); for(i=0;i<count;i++)rb_ary_push(map,INT2NUM(imap[i])); ALLOCV_END(imap_storage);
    return rb_ary_new_from_args(2,subset_value,map);
}

/* Header record */
static VALUE native_bcf_hrec_duplicate(VALUE self) { return wrap_bcf_hrec(bcf_hrec_dup(get_bcf_hrec(self)->pointer)); }
static VALUE native_bcf_hrec_add_key(VALUE self,VALUE key) { return INT2NUM(bcf_hrec_add_key(get_bcf_hrec(self)->pointer,StringValueCStr(key),RSTRING_LEN(key))); }
static VALUE native_bcf_hrec_set_value(VALUE self,VALUE index,VALUE value,VALUE quote) { StringValue(value); return INT2NUM(bcf_hrec_set_val(get_bcf_hrec(self)->pointer,NUM2INT(index),RSTRING_PTR(value),RSTRING_LEN(value),RTEST(quote))); }
static VALUE native_bcf_hrec_find_key(VALUE self,VALUE key) { return INT2NUM(bcf_hrec_find_key(get_bcf_hrec(self)->pointer,StringValueCStr(key))); }
static VALUE native_bcf_hrec_to_s(VALUE self) { kstring_t s=KS_INITIALIZE; VALUE r; bcf_hrec_format(get_bcf_hrec(self)->pointer,&s); r=rb_str_new(s.s,s.l); free(s.s); return r; }

/* Record core */
static void raise_bcf_record_error(const char *message) {
    VALUE hts=rb_const_get(rb_cObject,rb_intern("HTS"));
    VALUE bcf=rb_const_get(hts,rb_intern("Bcf"));
    VALUE error=rb_const_get(bcf,rb_intern("RecordError"));
    rb_raise(error,"%s",message);
}
static void check_bcf_unpack(bcf1_t *record,int fields) {
    if(bcf_unpack(record,fields)<0)raise_bcf_record_error("Failed to unpack BCF record");
}
static const char *checked_bcf_id(bcf_hdr_t *header,int id) {
    const char *name=(id>=0 && id<header->n[BCF_DT_ID] && header->id[BCF_DT_ID])?bcf_hdr_int2id(header,BCF_DT_ID,id):NULL;
    if(!name)raise_bcf_record_error("BCF record contains an ID that is absent from the supplied header");
    return name;
}
static VALUE native_bcf_record_create(VALUE klass) { return wrap_bcf_record(bcf_init()); }
static VALUE native_bcf_record_duplicate(VALUE self) { return wrap_bcf_record(bcf_dup(get_bcf_record(self)->pointer)); }
static VALUE native_bcf_record_core_get(VALUE self,VALUE field) {
    bcf1_t *r=get_bcf_record(self)->pointer; ID id=SYM2ID(field);
    if(id==rb_intern("rid"))return INT2NUM(r->rid);
    if(id==rb_intern("pos"))return LL2NUM(r->pos);
    if(id==rb_intern("rlen"))return LL2NUM(r->rlen);
    if(id==rb_intern("qual"))return DBL2NUM(r->qual);
    rb_raise(rb_eArgError,"unknown BCF field");
}
static VALUE native_bcf_record_core_set(VALUE self,VALUE field,VALUE value) {
    bcf1_t *r=get_bcf_record(self)->pointer; ID id=SYM2ID(field);
    if(id==rb_intern("rid"))r->rid=NUM2INT(value); else if(id==rb_intern("pos"))r->pos=NUM2LL(value);
    else if(id==rb_intern("qual"))r->qual=(float)NUM2DBL(value);
    else rb_raise(rb_eArgError,"unknown BCF field");
    return value;
}
static VALUE native_bcf_record_id(VALUE self) { bcf1_t *r=get_bcf_record(self)->pointer; check_bcf_unpack(r,BCF_UN_STR); if(!r->d.id)raise_bcf_record_error("BCF record ID is missing after unpack"); return rb_str_new_cstr(r->d.id); }
static VALUE native_bcf_record_set_id(VALUE self,VALUE header,VALUE id) { return INT2NUM(bcf_update_id(get_bcf_header(header)->pointer,get_bcf_record(self)->pointer,StringValueCStr(id))); }
static VALUE native_bcf_record_alleles(VALUE self) { bcf1_t *r=get_bcf_record(self)->pointer; int i; VALUE a; check_bcf_unpack(r,BCF_UN_STR); a=rb_ary_new_capa(r->n_allele); for(i=0;i<r->n_allele;i++){if(!r->d.allele[i])raise_bcf_record_error("BCF allele is missing after unpack");rb_ary_push(a,rb_str_new_cstr(r->d.allele[i]));} return a; }
static VALUE native_bcf_record_set_alleles(VALUE self,VALUE header,VALUE value) { return INT2NUM(bcf_update_alleles_str(get_bcf_header(header)->pointer,get_bcf_record(self)->pointer,StringValueCStr(value))); }
static VALUE native_bcf_record_filter_ids(VALUE self) { bcf1_t *r=get_bcf_record(self)->pointer; int i; VALUE a; check_bcf_unpack(r,BCF_UN_FLT); a=rb_ary_new_capa(r->d.n_flt); for(i=0;i<r->d.n_flt;i++)rb_ary_push(a,INT2NUM(r->d.flt[i])); return a; }
static VALUE native_bcf_record_filter_names(VALUE self,VALUE header) { bcf1_t *r=get_bcf_record(self)->pointer; bcf_hdr_t *h=get_bcf_header(header)->pointer; int i; VALUE a; check_bcf_unpack(r,BCF_UN_FLT); a=rb_ary_new_capa(r->d.n_flt); for(i=0;i<r->d.n_flt;i++)rb_ary_push(a,rb_str_new_cstr(checked_bcf_id(h,r->d.flt[i]))); return a; }
static VALUE native_bcf_record_to_s(VALUE self,VALUE header) { kstring_t s=KS_INITIALIZE; VALUE v; if(vcf_format(get_bcf_header(header)->pointer,get_bcf_record(self)->pointer,&s)<0){free(s.s);rb_raise(rb_eRuntimeError,"failed to format BCF record");}v=rb_str_new(s.s,s.l);free(s.s);return v; }
static VALUE native_bcf_record_set_unpack(VALUE self,VALUE level){get_bcf_record(self)->pointer->max_unpack=NUM2INT(level);return level;}
static VALUE native_bcf_record_subset(VALUE self,VALUE header,VALUE map){VALUE storage=0;int count=RARRAY_LEN(map),i,*imap=ALLOCV_N(int,storage,count?count:1);for(i=0;i<count;i++)imap[i]=NUM2INT(rb_ary_entry(map,i));int result=bcf_subset(get_bcf_header(header)->pointer,get_bcf_record(self)->pointer,count,imap);ALLOCV_END(storage);return INT2NUM(result);}

static VALUE field_rows(bcf_hdr_t *h,bcf1_t *r,int format) {
    int i,count; VALUE rows; if(format){check_bcf_unpack(r,BCF_UN_FMT);count=r->n_fmt;}else{check_bcf_unpack(r,BCF_UN_INFO);count=r->n_info;}
    rows=rb_ary_new_capa(count);
    for(i=0;i<count;i++) { int id=format?r->d.fmt[i].id:r->d.info[i].key, kind=format?BCF_HL_FMT:BCF_HL_INFO; VALUE row=rb_hash_new();
        rb_hash_aset(row,ID2SYM(rb_intern("name")),rb_str_new_cstr(checked_bcf_id(h,id)));
        rb_hash_aset(row,ID2SYM(rb_intern("n")),INT2NUM(bcf_hdr_id2number(h,kind,id)));
        rb_hash_aset(row,ID2SYM(rb_intern("type")),type_symbol(bcf_hdr_id2type(h,kind,id)));
        rb_hash_aset(row,ID2SYM(rb_intern(format?"id":"key")),INT2NUM(id)); rb_ary_push(rows,row); }
    return rows;
}
static VALUE native_bcf_record_info_fields(VALUE self,VALUE header) { return field_rows(get_bcf_header(header)->pointer,get_bcf_record(self)->pointer,0); }
static VALUE native_bcf_record_format_fields(VALUE self,VALUE header) { return field_rows(get_bcf_header(header)->pointer,get_bcf_record(self)->pointer,1); }

typedef struct { void *dst; int count; int type; } bcf_value_result_t;
static void raise_bcf_field_read_error(const char *kind,const char *key,int code) {
    VALUE hts=rb_const_get(rb_cObject,rb_intern("HTS"));
    VALUE bcf=rb_const_get(hts,rb_intern("Bcf"));
    VALUE error=rb_const_get(bcf,rb_intern(kind));
    const char *reason;
    switch(code){case -1:reason="tag is not defined in the header";break;case -2:reason="stored type does not match the requested type";break;case -4:reason="native allocation failed";break;default:reason="native read failed";break;}
    rb_raise(error,"Failed to read %s (HTSlib error %d: %s)",key,code,reason);
}
static VALUE bcf_value_result_free(VALUE data) {
    bcf_value_result_t *result=(bcf_value_result_t *)(uintptr_t)data;
    free(result->dst); result->dst=NULL; return Qnil;
}
static VALUE bcf_info_result_to_ruby(VALUE data) {
    bcf_value_result_t *result=(bcf_value_result_t *)(uintptr_t)data; int i; VALUE value;
    if(result->type==BCF_HT_STR)return rb_str_new_cstr((char*)result->dst);
    value=rb_ary_new_capa(result->count); for(i=0;i<result->count;i++) {
        if(result->type==BCF_HT_INT){
            int32_t item=((int32_t*)result->dst)[i];
            if(item==bcf_int32_vector_end)break;
            rb_ary_push(value,item==bcf_int32_missing?Qnil:INT2NUM(item));
        }
        else if(result->type==BCF_HT_LONG){
            int64_t item=((int64_t*)result->dst)[i];
            if(item==bcf_int64_vector_end)break;
            rb_ary_push(value,item==bcf_int64_missing?Qnil:LL2NUM(item));
        }
        else {
            float item=((float*)result->dst)[i];
            if(bcf_float_is_vector_end(item))break;
            rb_ary_push(value,bcf_float_is_missing(item)?Qnil:DBL2NUM(item));
        }
    }
    return value;
}
static VALUE info_get(VALUE self,VALUE header_value,VALUE key_value,VALUE type_value) {
    bcf_hdr_t *h=get_bcf_header(header_value)->pointer; bcf1_t *r=get_bcf_record(self)->pointer; int type=NUM2INT(type_value),cap=0,count; void *dst=NULL; bcf_value_result_t result;
    count=bcf_get_info_values(h,r,StringValueCStr(key_value),&dst,&cap,type);
    if(count<0){const char *key=StringValueCStr(key_value);free(dst);if(count==-3)return Qnil;raise_bcf_field_read_error("InfoReadError",key,count);}
    if(type==BCF_HT_FLAG){free(dst);return count==1?Qtrue:Qnil;}
    result.dst=dst;result.count=count;result.type=type;
    return rb_ensure(bcf_info_result_to_ruby,(VALUE)(uintptr_t)&result,
                     bcf_value_result_free,(VALUE)(uintptr_t)&result);
}
static VALUE native_bcf_info_get(VALUE self,VALUE header,VALUE key,VALUE type) { return info_get(self,header,key,type); }
static VALUE native_bcf_info_present(VALUE self,VALUE header,VALUE key,VALUE type) { return NIL_P(info_get(self,header,key,type))?Qfalse:Qtrue; }
static VALUE native_bcf_info_update(VALUE self,VALUE header,VALUE key,VALUE type_value,VALUE values) {
    bcf_hdr_t*h=get_bcf_header(header)->pointer;bcf1_t*r=get_bcf_record(self)->pointer;int type=NUM2INT(type_value),n,i,result;void*data=NULL;VALUE storage=0;
    if(type!=BCF_HT_FLAG && (NIL_P(values) || values==Qfalse)){
        return INT2NUM(bcf_update_info(h,r,StringValueCStr(key),NULL,0,type));
    }
    if(type==BCF_HT_INT){int32_t*p;n=RARRAY_LEN(values);p=ALLOCV_N(int32_t,storage,n?n:1);for(i=0;i<n;i++)p[i]=NUM2INT(rb_ary_entry(values,i));data=p;result=bcf_update_info(h,r,StringValueCStr(key),data,n,type);ALLOCV_END(storage);}
    else if(type==BCF_HT_REAL){float*p;n=RARRAY_LEN(values);p=ALLOCV_N(float,storage,n?n:1);for(i=0;i<n;i++)p[i]=(float)NUM2DBL(rb_ary_entry(values,i));data=p;result=bcf_update_info(h,r,StringValueCStr(key),data,n,type);ALLOCV_END(storage);}
    else if(type==BCF_HT_STR){result=bcf_update_info(h,r,StringValueCStr(key),StringValueCStr(values),1,type);}
    else { n=RTEST(values)?1:0; result=bcf_update_info(h,r,StringValueCStr(key),NULL,n,type); }
    return INT2NUM(result);
}

typedef struct { char **strings; int sample_count; } bcf_string_result_t;
static VALUE bcf_string_result_free(VALUE data) {
    bcf_string_result_t *result=(bcf_string_result_t *)(uintptr_t)data;
    if(result->strings){if(result->sample_count>0)free(result->strings[0]);free(result->strings);result->strings=NULL;}
    return Qnil;
}
static VALUE bcf_string_result_to_ruby(VALUE data) {
    bcf_string_result_t *result=(bcf_string_result_t *)(uintptr_t)data; int i;
    VALUE value=rb_ary_new_capa(result->sample_count);
    for(i=0;i<result->sample_count;i++)rb_ary_push(value,rb_str_new_cstr(result->strings[i]));
    return value;
}
typedef struct { void *dst; int count; int type; VALUE raw; } bcf_format_result_t;
static VALUE bcf_format_result_to_ruby(VALUE data) {
    bcf_format_result_t *result=(bcf_format_result_t *)(uintptr_t)data; int i; VALUE value=rb_ary_new_capa(result->count);
    for(i=0;i<result->count;i++){if(result->type==BCF_HT_INT)rb_ary_push(value,INT2NUM(((int32_t*)result->dst)[i]));else {float f=((float*)result->dst)[i];uint32_t word;memcpy(&word,&f,4);if(RTEST(result->raw))rb_ary_push(value,UINT2NUM(word));else if(bcf_float_is_missing(f)||bcf_float_is_vector_end(f))rb_ary_push(value,Qnil);else rb_ary_push(value,DBL2NUM(f));}}
    return value;
}
static VALUE native_bcf_format_get(VALUE self,VALUE header_value,VALUE key_value,VALUE type_value,VALUE raw_value) {
    bcf_hdr_t*h=get_bcf_header(header_value)->pointer;bcf1_t*r=get_bcf_record(self)->pointer;int type=NUM2INT(type_value),cap=0,count;void*dst=NULL;
    if(type==BCF_HT_STR){
        char **strings=NULL;
        int sample_count=bcf_hdr_nsamples(h);
        bcf_string_result_t result;
        count=bcf_get_format_string(h,r,StringValueCStr(key_value),&strings,&cap);
        if(count<0){const char *key=StringValueCStr(key_value);free(strings);if(count==-3)return Qnil;raise_bcf_field_read_error("FormatReadError",key,count);}
        result.strings=strings;result.sample_count=sample_count;
        return rb_ensure(bcf_string_result_to_ruby,(VALUE)(uintptr_t)&result,
                         bcf_string_result_free,(VALUE)(uintptr_t)&result);
    }
    count=bcf_get_format_values(h,r,StringValueCStr(key_value),&dst,&cap,type);if(count<0){const char *key=StringValueCStr(key_value);free(dst);if(count==-3)return Qnil;raise_bcf_field_read_error("FormatReadError",key,count);}
    bcf_format_result_t result={dst,count,type,raw_value};
    return rb_ensure(bcf_format_result_to_ruby,(VALUE)(uintptr_t)&result,
                     bcf_value_result_free,(VALUE)(uintptr_t)&result);
}
static VALUE native_bcf_format_update(VALUE self,VALUE header,VALUE key,VALUE type_value,VALUE values) {
    bcf_hdr_t*h=get_bcf_header(header)->pointer;bcf1_t*r=get_bcf_record(self)->pointer;int type=NUM2INT(type_value),n,i,result;VALUE storage=0;
    if(type==BCF_HT_INT){int32_t*p;n=RARRAY_LEN(values);p=ALLOCV_N(int32_t,storage,n?n:1);for(i=0;i<n;i++)p[i]=NUM2INT(rb_ary_entry(values,i));result=bcf_update_format_int32(h,r,StringValueCStr(key),p,n);ALLOCV_END(storage);}
    else if(type==BCF_HT_REAL){float*p;n=RARRAY_LEN(values);p=ALLOCV_N(float,storage,n?n:1);for(i=0;i<n;i++)p[i]=(float)NUM2DBL(rb_ary_entry(values,i));result=bcf_update_format_float(h,r,StringValueCStr(key),p,n);ALLOCV_END(storage);}
    else {int i;char**strings;n=RARRAY_LEN(values);strings=ALLOCV_N(char*,storage,n?n:1);for(i=0;i<n;i++){VALUE string=rb_ary_entry(values,i);strings[i]=StringValueCStr(string);}result=bcf_update_format_string(h,r,StringValueCStr(key),(const char**)strings,n);ALLOCV_END(storage);}return INT2NUM(result);
}
static VALUE native_bcf_format_update_float_words(VALUE self,VALUE header,VALUE key,VALUE values) {
    bcf_hdr_t *h=get_bcf_header(header)->pointer;
    bcf1_t *r=get_bcf_record(self)->pointer;
    int n=RARRAY_LEN(values),i,result;
    VALUE storage=0;
    float *floats=ALLOCV_N(float,storage,n?n:1);
    for(i=0;i<n;i++){
        uint32_t word=NUM2UINT(rb_ary_entry(values,i));
        memcpy(&floats[i],&word,sizeof(word));
    }
    result=bcf_update_format_float(h,r,StringValueCStr(key),floats,n);
    ALLOCV_END(storage);
    return INT2NUM(result);
}
static VALUE native_bcf_genotype_update(VALUE self,VALUE header,VALUE values) {VALUE storage=0;int32_t*p;int n=RARRAY_LEN(values),i;p=ALLOCV_N(int32_t,storage,n?n:1);for(i=0;i<n;i++)p[i]=NUM2INT(rb_ary_entry(values,i));int result=bcf_update_genotypes(get_bcf_header(header)->pointer,get_bcf_record(self)->pointer,p,n);ALLOCV_END(storage);return INT2NUM(result);}
static VALUE native_bcf_format_delete(VALUE self,VALUE header,VALUE key,VALUE type) {return INT2NUM(bcf_update_format(get_bcf_header(header)->pointer,get_bcf_record(self)->pointer,StringValueCStr(key),NULL,0,NUM2INT(type)));}

/* File */
typedef struct {htsFile*file;bcf_hdr_t*header;bcf1_t*record;hts_itr_t*iterator;tbx_t*tabix;kstring_t*line;int result;} bcf_io_args_t;
typedef struct {htsFile*file;bcf_hdr_t*result;} bcf_header_read_args_t;
static void *bcf_read_header_without_gvl(void*data){bcf_header_read_args_t*a=data;a->result=bcf_hdr_read(a->file);return NULL;}
static void *bcf_read_without_gvl(void*data){bcf_io_args_t*a=data;a->result=bcf_read(a->file,a->header,a->record);return NULL;}
static void *bcf_write_header_without_gvl(void*data){bcf_io_args_t*a=data;a->result=bcf_hdr_write(a->file,a->header);return NULL;}
static void *bcf_write_without_gvl(void*data){bcf_io_args_t*a=data;a->result=bcf_write(a->file,a->header,a->record);return NULL;}
static void *bcf_iterator_without_gvl(void*data){bcf_io_args_t*a=data;if(a->tabix){int n=tbx_itr_next(a->file,a->tabix,a->iterator,a->line);a->result=n<0?n:vcf_parse(a->line,a->header,a->record);}else a->result=bcf_itr_next(a->file,a->iterator,a->record);return NULL;}
static void bcf_io_begin(ruby_bcf_file_t*v){if(v->active_io)rb_raise(rb_eIOError,"concurrent BCF I/O is not supported");v->active_io=1;}
static VALUE native_bcf_file_open(VALUE klass,VALUE path,VALUE mode) {ruby_bcf_file_t*v;VALUE o=TypedData_Make_Struct(klass,ruby_bcf_file_t,&bcf_file_type,v);v->index=NULL;v->tabix=NULL;v->active_io=0;v->path=rb_str_dup(StringValue(path));RB_OBJ_WRITE(o,&v->path,v->path);v->file=hts_open(StringValueCStr(v->path),StringValueCStr(mode));if(!v->file)rb_syserr_fail_str(ENOENT,path);return o;}
static VALUE native_bcf_file_close(VALUE self){ruby_bcf_file_t*v=get_bcf_file(self,1);int result=0;if(v->active_io)rb_raise(rb_eIOError,"cannot close BCF during active I/O");if(v->index){hts_idx_destroy(v->index);v->index=NULL;}if(v->tabix){tbx_destroy(v->tabix);v->tabix=NULL;}if(v->file){result=hts_close(v->file);v->file=NULL;}return INT2NUM(result);}
static VALUE native_bcf_file_closed(VALUE self){return get_bcf_file(self,1)->file?Qfalse:Qtrue;}
static VALUE native_bcf_file_read_header(VALUE self){ruby_bcf_file_t*v=get_bcf_file(self,0);bcf_header_read_args_t a={v->file,NULL};bcf_io_begin(v);rb_thread_call_without_gvl(bcf_read_header_without_gvl,&a,RUBY_UBF_IO,NULL);v->active_io=0;return wrap_bcf_header(a.result);}
static VALUE native_bcf_file_read(VALUE self,VALUE header,VALUE record){ruby_bcf_file_t*v=get_bcf_file(self,0);bcf_io_args_t a={v->file,get_bcf_header(header)->pointer,get_bcf_record(record)->pointer,NULL,NULL,NULL,0};bcf_io_begin(v);rb_thread_call_without_gvl(bcf_read_without_gvl,&a,RUBY_UBF_IO,NULL);v->active_io=0;return INT2NUM(a.result);}
static VALUE native_bcf_file_write_header(VALUE self,VALUE header){ruby_bcf_file_t*v=get_bcf_file(self,0);bcf_io_args_t a={v->file,get_bcf_header(header)->pointer,NULL,NULL,NULL,NULL,0};bcf_io_begin(v);rb_thread_call_without_gvl(bcf_write_header_without_gvl,&a,RUBY_UBF_IO,NULL);v->active_io=0;return INT2NUM(a.result);}
static VALUE native_bcf_file_write(VALUE self,VALUE header,VALUE record){ruby_bcf_file_t*v=get_bcf_file(self,0);bcf_io_args_t a={v->file,get_bcf_header(header)->pointer,get_bcf_record(record)->pointer,NULL,NULL,NULL,0};bcf_io_begin(v);rb_thread_call_without_gvl(bcf_write_without_gvl,&a,RUBY_UBF_IO,NULL);v->active_io=0;return INT2NUM(a.result);}
static VALUE native_bcf_file_set_threads(VALUE self,VALUE n){return INT2NUM(hts_set_threads(get_bcf_file(self,0)->file,NUM2INT(n)));}
static VALUE native_bcf_file_format(VALUE self){const htsFormat*f=hts_get_format(get_bcf_file(self,0)->file);if(!f)return Qnil;switch(f->format){case vcf:return rb_str_new_cstr("vcf");case bcf:return rb_str_new_cstr("bcf");default:return rb_str_new_cstr("unknown_format");}}
static VALUE native_bcf_file_version(VALUE self){const htsFormat*f=hts_get_format(get_bcf_file(self,0)->file);if(!f)return Qnil;if(f->version.minor==-1)return rb_sprintf("%d",f->version.major);return rb_sprintf("%d.%d",f->version.major,f->version.minor);}
static VALUE native_bcf_file_seek(VALUE self,VALUE offset){htsFile*f=get_bcf_file(self,0)->file;return LL2NUM(f->is_bgzf?bgzf_seek(f->fp.bgzf,NUM2LL(offset),SEEK_SET):hseek(f->fp.hfile,NUM2LL(offset),SEEK_SET));}
static VALUE native_bcf_file_tell(VALUE self){htsFile*f=get_bcf_file(self,0)->file;return LL2NUM(f->is_bgzf?bgzf_tell(f->fp.bgzf):htell(f->fp.hfile));}
static VALUE native_bcf_file_load_index(VALUE self,VALUE index){ruby_bcf_file_t*v=get_bcf_file(self,0);const htsFormat*f=hts_get_format(v->file);if(v->index){hts_idx_destroy(v->index);v->index=NULL;}if(v->tabix){tbx_destroy(v->tabix);v->tabix=NULL;}if(f&&f->format==vcf)v->tabix=NIL_P(index)?tbx_index_load3(StringValueCStr(v->path),NULL,HTS_IDX_SAVE_REMOTE):tbx_index_load2(StringValueCStr(v->path),StringValueCStr(index));else v->index=NIL_P(index)?bcf_index_load3(StringValueCStr(v->path),NULL,HTS_IDX_SAVE_REMOTE):bcf_index_load2(StringValueCStr(v->path),StringValueCStr(index));return(v->index||v->tabix)?Qtrue:Qfalse;}
static VALUE native_bcf_file_index_loaded(VALUE self){ruby_bcf_file_t*v=get_bcf_file(self,0);return(v->index||v->tabix)?Qtrue:Qfalse;}
static VALUE native_bcf_file_build_index(VALUE klass,VALUE path,VALUE index,VALUE shift,VALUE threads){return INT2NUM(bcf_index_build3(StringValueCStr(path),NIL_P(index)?NULL:StringValueCStr(index),NUM2INT(shift),NUM2INT(threads)));}
static VALUE native_bcf_file_query_region(VALUE self,VALUE header,VALUE region){ruby_bcf_file_t*v=get_bcf_file(self,0);hts_itr_t*i;if(v->tabix)i=tbx_itr_querys(v->tabix,StringValueCStr(region));else i=bcf_itr_querys(v->index,get_bcf_header(header)->pointer,StringValueCStr(region));return wrap_bcf_iterator(self,header,i,v->tabix!=NULL);}
static VALUE native_bcf_file_query_interval(VALUE self,VALUE header,VALUE rid,VALUE beg,VALUE end){ruby_bcf_file_t*v=get_bcf_file(self,0);hts_itr_t*i=v->tabix?tbx_itr_queryi(v->tabix,NUM2INT(rid),NUM2LL(beg),NUM2LL(end)):bcf_itr_queryi(v->index,NUM2INT(rid),NUM2LL(beg),NUM2LL(end));return wrap_bcf_iterator(self,header,i,v->tabix!=NULL);}
static VALUE native_bcf_iterator_next(VALUE self,VALUE record){ruby_bcf_iterator_t*i=get_bcf_iterator(self);ruby_bcf_file_t*f=get_bcf_file(i->file,0);bcf_io_args_t a={f->file,get_bcf_header(i->header)->pointer,get_bcf_record(record)->pointer,i->iterator,i->tabix?f->tabix:NULL,&i->line,0};bcf_io_begin(f);rb_thread_call_without_gvl(bcf_iterator_without_gvl,&a,RUBY_UBF_IO,NULL);f->active_io=0;return INT2NUM(a.result);}
static VALUE native_bcf_iterator_close(VALUE self){ruby_bcf_iterator_t*v;TypedData_Get_Struct(self,ruby_bcf_iterator_t,&bcf_iterator_type,v);if(v->iterator){hts_itr_destroy(v->iterator);v->iterator=NULL;}return Qnil;}

void Init_htslib_native_bcf(VALUE native) {
    cBcfHeader=rb_define_class_under(native,"BcfHeaderHandle",rb_cObject);rb_undef_alloc_func(cBcfHeader);
    rb_define_singleton_method(cBcfHeader,"create",native_bcf_header_create,0);rb_define_method(cBcfHeader,"duplicate",native_bcf_header_duplicate,0);
    rb_define_method(cBcfHeader,"version",native_bcf_header_version,0);rb_define_method(cBcfHeader,"set_version",native_bcf_header_set_version,1);rb_define_method(cBcfHeader,"read_file",native_bcf_header_read_file,1);
    rb_define_method(cBcfHeader,"nsamples",native_bcf_header_nsamples,0);rb_define_method(cBcfHeader,"samples",native_bcf_header_samples,0);
    rb_define_method(cBcfHeader,"seqnames",native_bcf_header_seqnames,0);rb_define_method(cBcfHeader,"name2id",native_bcf_header_name2id,1);rb_define_method(cBcfHeader,"id2name",native_bcf_header_id2name,1);
    rb_define_method(cBcfHeader,"add_sample",native_bcf_header_add_sample,1);rb_define_method(cBcfHeader,"sync",native_bcf_header_sync,0);rb_define_method(cBcfHeader,"append",native_bcf_header_append,1);
    rb_define_method(cBcfHeader,"merge",native_bcf_header_merge,1);rb_define_method(cBcfHeader,"to_s",native_bcf_header_to_s,0);rb_define_method(cBcfHeader,"remove",native_bcf_header_remove,2);
    rb_define_method(cBcfHeader,"get_hrec",native_bcf_header_get_hrec,4);rb_define_method(cBcfHeader,"schema",native_bcf_header_schema,2);rb_define_method(cBcfHeader,"subset",native_bcf_header_subset,1);
    cBcfHrec=rb_define_class_under(native,"BcfHeaderRecordHandle",rb_cObject);rb_undef_alloc_func(cBcfHrec);rb_define_method(cBcfHrec,"duplicate",native_bcf_hrec_duplicate,0);rb_define_method(cBcfHrec,"add_key",native_bcf_hrec_add_key,1);rb_define_method(cBcfHrec,"set_value",native_bcf_hrec_set_value,3);rb_define_method(cBcfHrec,"find_key",native_bcf_hrec_find_key,1);rb_define_method(cBcfHrec,"to_s",native_bcf_hrec_to_s,0);
    cBcfRecord=rb_define_class_under(native,"BcfRecordHandle",rb_cObject);rb_undef_alloc_func(cBcfRecord);rb_define_singleton_method(cBcfRecord,"create",native_bcf_record_create,0);rb_define_method(cBcfRecord,"duplicate",native_bcf_record_duplicate,0);rb_define_method(cBcfRecord,"core_get",native_bcf_record_core_get,1);rb_define_method(cBcfRecord,"core_set",native_bcf_record_core_set,2);rb_define_method(cBcfRecord,"id",native_bcf_record_id,0);rb_define_method(cBcfRecord,"set_id",native_bcf_record_set_id,2);rb_define_method(cBcfRecord,"alleles",native_bcf_record_alleles,0);rb_define_method(cBcfRecord,"set_alleles",native_bcf_record_set_alleles,2);rb_define_method(cBcfRecord,"filter_ids",native_bcf_record_filter_ids,0);rb_define_method(cBcfRecord,"filter_names",native_bcf_record_filter_names,1);rb_define_method(cBcfRecord,"format_record",native_bcf_record_to_s,1);rb_define_method(cBcfRecord,"info_fields",native_bcf_record_info_fields,1);rb_define_method(cBcfRecord,"format_fields",native_bcf_record_format_fields,1);rb_define_method(cBcfRecord,"info_get",native_bcf_info_get,3);rb_define_method(cBcfRecord,"info_present?",native_bcf_info_present,3);rb_define_method(cBcfRecord,"info_update",native_bcf_info_update,4);rb_define_method(cBcfRecord,"format_get",native_bcf_format_get,4);rb_define_method(cBcfRecord,"format_update",native_bcf_format_update,4);rb_define_method(cBcfRecord,"format_update_float_words",native_bcf_format_update_float_words,3);rb_define_method(cBcfRecord,"genotype_update",native_bcf_genotype_update,2);rb_define_method(cBcfRecord,"format_delete",native_bcf_format_delete,3);
    rb_define_method(cBcfRecord,"max_unpack=",native_bcf_record_set_unpack,1);rb_define_method(cBcfRecord,"subset",native_bcf_record_subset,2);
    cBcfFile=rb_define_class_under(native,"BcfFileHandle",rb_cObject);rb_undef_alloc_func(cBcfFile);rb_define_singleton_method(cBcfFile,"open",native_bcf_file_open,2);rb_define_singleton_method(cBcfFile,"build_index",native_bcf_file_build_index,4);rb_define_method(cBcfFile,"close",native_bcf_file_close,0);rb_define_method(cBcfFile,"closed?",native_bcf_file_closed,0);rb_define_method(cBcfFile,"read_header",native_bcf_file_read_header,0);rb_define_method(cBcfFile,"read",native_bcf_file_read,2);rb_define_method(cBcfFile,"write_header",native_bcf_file_write_header,1);rb_define_method(cBcfFile,"write",native_bcf_file_write,2);rb_define_method(cBcfFile,"set_threads",native_bcf_file_set_threads,1);rb_define_method(cBcfFile,"file_format",native_bcf_file_format,0);rb_define_method(cBcfFile,"file_format_version",native_bcf_file_version,0);rb_define_method(cBcfFile,"seek",native_bcf_file_seek,1);rb_define_method(cBcfFile,"tell",native_bcf_file_tell,0);rb_define_method(cBcfFile,"load_index",native_bcf_file_load_index,1);rb_define_method(cBcfFile,"index_loaded?",native_bcf_file_index_loaded,0);rb_define_method(cBcfFile,"query_region",native_bcf_file_query_region,2);rb_define_method(cBcfFile,"query_interval",native_bcf_file_query_interval,4);
    cBcfIterator=rb_define_class_under(native,"BcfIteratorHandle",rb_cObject);rb_undef_alloc_func(cBcfIterator);rb_define_method(cBcfIterator,"next",native_bcf_iterator_next,1);rb_define_method(cBcfIterator,"close",native_bcf_iterator_close,0);
    rb_define_const(native,"BCF_HT_FLAG",INT2NUM(BCF_HT_FLAG));rb_define_const(native,"BCF_HT_INT",INT2NUM(BCF_HT_INT));rb_define_const(native,"BCF_HT_REAL",INT2NUM(BCF_HT_REAL));rb_define_const(native,"BCF_HT_STR",INT2NUM(BCF_HT_STR));rb_define_const(native,"BCF_HT_LONG",INT2NUM(BCF_HT_LONG));rb_define_const(native,"BCF_INT32_MISSING",INT2NUM(bcf_int32_missing));rb_define_const(native,"BCF_INT32_VECTOR_END",INT2NUM(bcf_int32_vector_end));rb_define_const(native,"BCF_FLOAT_MISSING",UINT2NUM(bcf_float_missing));rb_define_const(native,"BCF_FLOAT_VECTOR_END",UINT2NUM(bcf_float_vector_end));
}
