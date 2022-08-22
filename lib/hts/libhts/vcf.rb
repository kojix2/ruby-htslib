# frozen_string_literal: true

module HTS
  module LibHTS
    # Create an empty BCF header.
    attach_function \
      :bcf_hdr_init,
      [:string],
      BcfHdr.by_ref

    # Destroy a BCF header struct
    attach_function \
      :bcf_hdr_destroy,
      [BcfHdr],
      :void

    # Allocate and initialize a bcf1_t object.
    attach_function \
      :bcf_init,
      [],
      Bcf1.by_ref

    # Deallocate a bcf1_t object
    attach_function \
      :bcf_destroy,
      [Bcf1],
      :void

    # Same as bcf_destroy() but frees only the memory allocated by bcf1_t,
    # not the bcf1_t object itself.
    attach_function \
      :bcf_empty,
      [Bcf1],
      :void

    # Make the bcf1_t object ready for next read.
    attach_function \
      :bcf_clear,
      [Bcf1],
      :void

    # Read a VCF or BCF header
    attach_function \
      :bcf_hdr_read,
      [HtsFile],
      BcfHdr.by_ref

    # for more efficient VCF parsing when only one/few samples are needed
    attach_function \
      :bcf_hdr_set_samples,
      [BcfHdr, :string, :int],
      :int

    attach_function \
      :bcf_subset_format,
      [BcfHdr, Bcf1],
      :int

    # Write a VCF or BCF header
    attach_function \
      :bcf_hdr_write,
      [HtsFile, BcfHdr],
      :int

    # Parse VCF line contained in kstring and populate the bcf1_t struct
    attach_function \
      :vcf_parse,
      [KString, BcfHdr, Bcf1],
      :int

    # Complete the file opening mode, according to its extension.
    attach_function \
      :vcf_open_mode,
      %i[string string string],
      :int

    # The opposite of vcf_parse.
    attach_function \
      :vcf_format,
      [BcfHdr, Bcf1, KString],
      :int

    # Read next VCF or BCF record
    attach_function \
      :bcf_read,
      [HtsFile, BcfHdr, Bcf1],
      :int

    # unpack/decode a BCF record (fills the bcf1_t::d field)
    attach_function \
      :bcf_unpack,
      [Bcf1, :int],
      :int

    # Create a copy of BCF record.
    attach_function \
      :bcf_dup,
      [Bcf1],
      Bcf1.by_ref

    attach_function \
      :bcf_copy,
      [Bcf1, Bcf1],
      Bcf1.by_ref

    # Write one VCF or BCF record.
    attach_function \
      :bcf_write,
      [HtsFile, BcfHdr, Bcf1],
      :int

    # Read a VCF format header
    attach_function \
      :vcf_hdr_read,
      [HtsFile],
      BcfHdr.by_ref

    # Write a VCF format header
    attach_function \
      :vcf_hdr_write,
      [HtsFile, BcfHdr],
      :int

    # Read a record from a VCF file
    attach_function \
      :vcf_read,
      [HtsFile, BcfHdr, Bcf1],
      :int

    # Write a record to a VCF file
    attach_function \
      :vcf_write,
      [HtsFile, BcfHdr, Bcf1],
      :int

    # Helper function for the bcf_itr_next() macro
    attach_function \
      :bcf_readrec,
      [BGZF, :pointer, :pointer, :pointer, :hts_pos_t, :hts_pos_t],
      :int

    # Write a line to a VCF file
    attach_function \
      :vcf_write_line,
      [HtsFile, KString],
      :int

    # Header querying and manipulation routines

    # Create a new header using the supplied template
    attach_function \
      :bcf_hdr_dup,
      [BcfHdr],
      BcfHdr.by_ref

    # DEPRECATED please use bcf_hdr_merge instead
    #
    # attach_function \
    #   :bcf_hdr_combine,
    #   [BcfHdr, BcfHdr],
    #   :int

    # Copy header lines from src to dst, see also bcf_translate()
    attach_function \
      :bcf_hdr_merge,
      [BcfHdr, BcfHdr],
      BcfHdr.by_ref

    # Add a new sample.
    attach_function \
      :bcf_hdr_add_sample,
      [BcfHdr, :string],
      :int

    # Read VCF header from a file and update the header
    attach_function \
      :bcf_hdr_set,
      [BcfHdr, :string],
      :int

    # Appends formatted header text to _str_.
    attach_function \
      :bcf_hdr_format,
      [BcfHdr, :int, KString],
      :int

    # DEPRECATED use bcf_hdr_format() instead
    #
    # attach_function \
    #   :bcf_hdr_fmt_text,
    #   [BcfHdr, :int, :pointer],
    #   :string

    # Append new VCF header line
    attach_function \
      :bcf_hdr_append,
      [BcfHdr, :string],
      :int

    attach_function \
      :bcf_hdr_printf,
      [BcfHdr, :string, :varargs],
      :int

    # VCF version, e.g. VCFv4.2
    attach_function \
      :bcf_hdr_get_version,
      [BcfHdr],
      :string

    # Set version in bcf header
    attach_function \
      :bcf_hdr_set_version,
      [BcfHdr, :string],
      :int

    # Remove VCF header tag
    attach_function \
      :bcf_hdr_remove,
      [BcfHdr, :int, :string],
      :void

    # Creates a new copy of the header removing unwanted samples
    attach_function \
      :bcf_hdr_subset,
      [BcfHdr, :int, :pointer, :pointer],
      BcfHdr.by_ref

    # Creates a list of sequence names.
    attach_function \
      :bcf_hdr_seqnames,
      [BcfHdr, :pointer],
      :pointer

    attach_function \
      :bcf_hdr_parse,
      [BcfHdr, :string],
      :int

    # Synchronize internal header structures
    attach_function \
      :bcf_hdr_sync,
      [BcfHdr],
      :int

    # parse a single line of VCF textual header
    attach_function \
      :bcf_hdr_parse_line,
      [BcfHdr, :string, :pointer],
      BcfHrec.by_ref

    # Convert a bcf header record to string form
    attach_function \
      :bcf_hrec_format,
      [BcfHrec, KString],
      :int

    attach_function \
      :bcf_hdr_add_hrec,
      [BcfHdr, BcfHrec],
      :int

    # Get header line info
    attach_function \
      :bcf_hdr_get_hrec,
      [BcfHdr, :int, :string, :string, :string],
      BcfHrec.by_ref

    # Duplicate a header record
    attach_function \
      :bcf_hrec_dup,
      [BcfHrec],
      BcfHrec.by_ref

    # Add a new header record key
    attach_function \
      :bcf_hrec_add_key,
      [BcfHrec, :string, :size_t],
      :int

    # Set a header record value
    attach_function \
      :bcf_hrec_set_val,
      [BcfHrec, :int, :string, :size_t, :int],
      :int

    attach_function \
      :bcf_hrec_find_key,
      [BcfHrec, :string],
      :int

    # Add an IDX header record
    attach_function \
      :hrec_add_idx,
      [BcfHrec, :int],
      :int

    # Free up a header record and associated structures
    attach_function \
      :bcf_hrec_destroy,
      [BcfHrec],
      :void

    # Individual record querying and manipulation routines

    # See the description of bcf_hdr_subset()
    attach_function \
      :bcf_subset,
      [BcfHdr, Bcf1, :int, :pointer],
      :int

    # Translate tags ids to be consistent with different header.
    attach_function \
      :bcf_translate,
      [BcfHdr, BcfHdr, Bcf1],
      :int

    # Get variant types in a BCF record
    attach_function \
      :bcf_get_variant_types,
      [Bcf1],
      :int

    # Get variant type in a BCF record, for a given allele
    attach_function \
      :bcf_get_variant_type,
      [Bcf1, :int],
      :int

    # Check for presence of variant types in a BCF record
    attach_function \
      :bcf_has_variant_types,
      [Bcf1, :uint32, :int],
      :int

    # Check for presence of variant types in a BCF record, for a given allele
    attach_function \
      :bcf_has_variant_type,
      [Bcf1, :int, :uint32],
      :int

    # Return the number of bases affected by a variant, for a given allele
    attach_function \
      :bcf_variant_length,
      [Bcf1, :int],
      :int

    attach_function \
      :bcf_is_snp,
      [Bcf1],
      :int

    # Sets the FILTER column
    attach_function \
      :bcf_update_filter,
      [BcfHdr, Bcf1, :pointer, :int],
      :int

    # Adds to the FILTER column
    attach_function \
      :bcf_add_filter,
      [BcfHdr, Bcf1, :int],
      :int

    # Removes from the FILTER column
    attach_function \
      :bcf_remove_filter,
      [BcfHdr, Bcf1, :int, :int],
      :int

    # Returns 1 if present, 0 if absent, or -1 if filter does not exist.
    # "PASS" and "." can be used interchangeably.
    attach_function \
      :bcf_has_filter,
      [BcfHdr, Bcf1, :string],
      :int

    # Update REF and ALT column
    attach_function \
      :bcf_update_alleles,
      [BcfHdr, Bcf1, :pointer, :int],
      :int

    attach_function \
      :bcf_update_alleles_str,
      [BcfHdr, Bcf1, :string],
      :int

    # Sets new ID string
    attach_function \
      :bcf_update_id,
      [BcfHdr, Bcf1, :string],
      :int

    attach_function \
      :bcf_add_id,
      [BcfHdr, Bcf1, :string],
      :int

    # Functions for updating INFO fields
    attach_function \
      :bcf_update_info,
      [BcfHdr, Bcf1, :string, :pointer, :int, :int],
      :int

    attach_function \
      :bcf_update_format_string,
      [BcfHdr, Bcf1, :string, :pointer, :int],
      :int

    # Functions for updating FORMAT fields
    attach_function \
      :bcf_update_format,
      [BcfHdr, Bcf1, :string, :pointer, :int, :int],
      :int

    # Returns pointer to FORMAT's field data
    attach_function \
      :bcf_get_fmt,
      [BcfHdr, Bcf1, :string],
      BcfFmt.by_ref

    attach_function \
      :bcf_get_info,
      [BcfHdr, Bcf1, :string],
      BcfInfo.by_ref

    # Returns pointer to FORMAT/INFO field data given the header index instead of the string ID
    attach_function \
      :bcf_get_fmt_id,
      [Bcf1, :int],
      BcfFmt.by_ref

    attach_function \
      :bcf_get_info_id,
      [Bcf1, :int],
      BcfInfo.by_ref

    # get INFO values
    attach_function \
      :bcf_get_info_values,
      [BcfHdr, Bcf1, :string, :pointer, :pointer, :int],
      :int

    attach_function \
      :bcf_get_format_string,
      [BcfHdr, Bcf1, :string, :pointer, :pointer],
      :int

    attach_function \
      :bcf_get_format_values,
      [BcfHdr, Bcf1, :string, :pointer, :pointer, :int],
      :int

    # Helper functions

    # Translates string into numeric ID
    attach_function \
      :bcf_hdr_id2int,
      [BcfHdr, :int, :string],
      :int

    # Convert BCF FORMAT data to string form
    attach_function \
      :bcf_fmt_array,
      [KString, :int, :int, :pointer],
      :int

    attach_function \
      :bcf_fmt_sized_array,
      [KString, :pointer],
      :uint8_t

    # Encode a variable-length char array in BCF format
    attach_function \
      :bcf_enc_vchar,
      [KString, :int, :string],
      :int

    # Encode a variable-length integer array in BCF format
    attach_function \
      :bcf_enc_vint,
      [KString, :int, :pointer, :int],
      :int

    # Encode a variable-length float array in BCF format
    attach_function \
      :bcf_enc_vfloat,
      [KString, :int, :pointer],
      :int

    # BCF index

    # Load a BCF index from a given index file name
    attach_function \
      :bcf_index_load2,
      %i[string string],
      HtsIdx.by_ref

    # Load a BCF index from a given index file name
    attach_function \
      :bcf_index_load3,
      %i[string string int],
      HtsIdx.by_ref

    # Generate and save an index file
    attach_function \
      :bcf_index_build,
      %i[string int],
      :int

    # Generate and save an index to a specific file
    attach_function \
      :bcf_index_build2,
      %i[string string int],
      :int

    # Generate and save an index to a specific file
    attach_function \
      :bcf_index_build3,
      %i[string string int int],
      :int

    # Initialise fp->idx for the current format type, for VCF and BCF files.
    attach_function \
      :bcf_idx_init,
      [HtsFile, BcfHdr, :int, :string],
      :int

    # Writes the index initialised with bcf_idx_init to disk.
    attach_function \
      :bcf_idx_save,
      [HtsFile],
      :int

    attach_function \
      :bcf_float_vector_end,
      [],
      :uint32

    attach_function \
      :bcf_float_missing,
      [],
      :uint32
  end
end

require_relative "vcf_funcs"
