# frozen_string_literal: true

module HTS
  module LibHTS
    # Generates a new unpopulated header structure.
    attach_function \
      :sam_hdr_init,
      [],
      SamHdr.by_ref

    # Read the header from a BAM compressed file.
    attach_function \
      :bam_hdr_read,
      [BGZF],
      SamHdr.by_ref

    # Writes the header to a BAM file.
    attach_function \
      :bam_hdr_write,
      [BGZF, SamHdr],
      :int

    # Frees the resources associated with a header.
    attach_function \
      :sam_hdr_destroy,
      [SamHdr],
      :void

    # Duplicate a header structure.
    attach_function \
      :sam_hdr_dup,
      [SamHdr],
      SamHdr.by_ref

    # Create a header from existing text.
    attach_function \
      :sam_hdr_parse,
      %i[size_t string],
      SamHdr.by_ref

    # Read a header from a SAM, BAM or CRAM file.
    attach_function \
      :sam_hdr_read,
      [SamFile],
      SamHdr.by_ref

    # Write a header to a SAM, BAM or CRAM file.
    attach_function \
      :sam_hdr_write,
      [SamFile, SamHdr],
      :int

    # Returns the current length of the header text.
    attach_function \
      :sam_hdr_length,
      [SamHdr],
      :size_t

    # Returns the text representation of the header.
    attach_function \
      :sam_hdr_str,
      [SamHdr],
      :string

    # Returns the number of references in the header.
    attach_function \
      :sam_hdr_nref,
      [SamHdr],
      :int

    # Add formatted lines to an existing header.
    attach_function \
      :sam_hdr_add_lines,
      [SamHdr, :string, :size_t],
      :int

    # Adds a single line to an existing header.
    attach_function \
      :sam_hdr_add_line,
      [SamHdr, :string, :varargs],
      :int

    # Returns a complete line of formatted text for a given type and ID.
    attach_function \
      :sam_hdr_find_line_id,
      [SamHdr, :string, :string, :string, KString],
      :int

    # Returns a complete line of formatted text for a given type and index.
    attach_function \
      :sam_hdr_find_line_pos,
      [SamHdr, :string, :int, KString],
      :int

    # Remove a line with given type / id from a header
    attach_function \
      :sam_hdr_remove_line_id,
      [SamHdr, :string, :string, :string],
      :int

    # Remove nth line of a given type from a header
    attach_function \
      :sam_hdr_remove_line_pos,
      [SamHdr, :string, :int],
      :int

    # Add or update tag key,value pairs in a header line.
    attach_function \
      :sam_hdr_update_line,
      [SamHdr, :string, :string, :string, :varargs],
      :int

    # Remove all lines of a given type from a header, except the one matching an ID
    attach_function \
      :sam_hdr_remove_except,
      [SamHdr, :string, :string, :string],
      :int

    # Remove header lines of a given type, except those in a given ID set
    attach_function \
      :sam_hdr_remove_lines,
      [SamHdr, :string, :string, :pointer],
      :int

    # Count the number of lines for a given header type
    attach_function \
      :sam_hdr_count_lines,
      [SamHdr, :string],
      :int

    # Index of the line for the types that have dedicated look-up tables (SQ, RG, PG)
    attach_function \
      :sam_hdr_line_index,
      [SamHdr, :string, :string],
      :int

    # Id key of the line for the types that have dedicated look-up tables (SQ, RG, PG)
    attach_function \
      :sam_hdr_line_name,
      [SamHdr, :string, :int],
      :string

    # Return the value associated with a key for a header line identified by ID_key:ID_val
    attach_function \
      :sam_hdr_find_tag_id,
      [SamHdr, :string, :string, :string, :string, KString],
      :int

    # Return the value associated with a key for a header line identified by position
    attach_function \
      :sam_hdr_find_tag_pos,
      [SamHdr, :string, :int, :string, KString],
      :int

    # Remove the key from the line identified by type, ID_key and ID_value.
    attach_function \
      :sam_hdr_remove_tag_id,
      [SamHdr, :string, :string, :string, :string],
      :int

    # Get the target id for a given reference sequence name
    attach_function \
      :sam_hdr_name2tid,
      [SamHdr, :string],
      :int

    # Get the reference sequence name from a target index
    attach_function \
      :sam_hdr_tid2name,
      [SamHdr, :int],
      :string

    # Get the reference sequence length from a target index
    attach_function \
      :sam_hdr_tid2len,
      [SamHdr, :int],
      :hts_pos_t

    # Generate a unique \@PG ID: value
    attach_function \
      :sam_hdr_pg_id,
      [SamHdr, :string],
      :string

    # Add an \@PG line.
    attach_function \
      :sam_hdr_add_pg,
      [SamHdr, :string, :varargs],
      :int

    # A function to help with construction of CL tags in @PG records.
    attach_function \
      :stringify_argv,
      %i[int pointer],
      :string

    # Increments the reference count on a header
    attach_function \
      :sam_hdr_incr_ref,
      [SamHdr],
      :void

    # Create a new bam1_t alignment structure
    attach_function \
      :bam_init1,
      [],
      Bam1.by_ref

    # Destroy a bam1_t structure
    attach_function \
      :bam_destroy1,
      [Bam1],
      :void

    # Read a BAM format alignment record
    attach_function \
      :bam_read1,
      [BGZF, Bam1],
      :int

    # Write a BAM format alignment record
    attach_function \
      :bam_write1,
      [BGZF, Bam1],
      :int

    # Copy alignment record data
    attach_function \
      :bam_copy1,
      [Bam1, Bam1],
      Bam1.by_ref

    # Create a duplicate alignment record
    attach_function \
      :bam_dup1,
      [Bam1],
      Bam1.by_ref

    # Set all components of an alignment structure
    attach_function \
      :bam_set1,
      [Bam1,
       :size_t,
       :string,
       :uint16_t,
       :int32_t,
       :hts_pos_t,
       :uint8_t,
       :size_t,
       :string,
       :int32_t,
       :hts_pos_t,
       :hts_pos_t,
       :size_t,
       :string,
       :string,
       :size_t],
      :int

    # Calculate query length from CIGAR data
    attach_function \
      :bam_cigar2qlen,
      %i[int pointer],
      :int64

    # Calculate reference length from CIGAR data
    attach_function \
      :bam_cigar2rlen,
      %i[int pointer],
      :hts_pos_t

    # Calculate the rightmost base position of an alignment on the reference genome.
    attach_function \
      :bam_endpos,
      [Bam1],
      :hts_pos_t

    attach_function \
      :bam_str2flag,
      [:string],
      :int

    attach_function \
      :bam_flag2str,
      [:int],
      :string

    # Set the name of the query
    attach_function \
      :bam_set_qname,
      [Bam1, :string],
      :int

    # Parse a CIGAR string into a uint32_t array
    attach_function \
      :sam_parse_cigar,
      %i[string pointer pointer pointer],
      :ssize_t

    # Parse a CIGAR string into a bam1_t struct
    attach_function \
      :bam_parse_cigar,
      [:string, :pointer, Bam1],
      :ssize_t

    # Initialise fp->idx for the current format type for SAM, BAM and CRAM types .
    attach_function \
      :sam_idx_init,
      [HtsFile, SamHdr, :int, :string],
      :int

    # Writes the index initialised with sam_idx_init to disk.
    attach_function \
      :sam_idx_save,
      [HtsFile],
      :int

    # Load a BAM (.csi or .bai) or CRAM (.crai) index file
    attach_function \
      :sam_index_load,
      [HtsFile, :string],
      HtsIdx.by_ref

    # Load a specific BAM (.csi or .bai) or CRAM (.crai) index file
    attach_function \
      :sam_index_load2,
      [HtsFile, :string, :string],
      HtsIdx.by_ref

    # Load or stream a BAM (.csi or .bai) or CRAM (.crai) index file
    attach_function \
      :sam_index_load3,
      [HtsFile, :string, :string, :int],
      HtsIdx.by_ref

    # Generate and save an index file
    attach_function \
      :sam_index_build,
      %i[string int],
      :int

    # Generate and save an index to a specific file
    attach_function \
      :sam_index_build2,
      %i[string string int],
      :int

    # Generate and save an index to a specific file
    attach_function \
      :sam_index_build3,
      %i[string string int int],
      :int

    # Create a BAM/CRAM iterator
    attach_function \
      :sam_itr_queryi,
      [HtsIdx, :int, :hts_pos_t, :hts_pos_t],
      HtsItr.by_ref

    # Create a SAM/BAM/CRAM iterator
    attach_function \
      :sam_itr_querys,
      [HtsIdx, SamHdr, :string],
      HtsItr.by_ref

    # Create a multi-region iterator
    attach_function \
      :sam_itr_regions,
      [HtsIdx, SamHdr, :pointer, :uint],
      HtsItr.by_ref

    # Create a multi-region iterator
    attach_function \
      :sam_itr_regarray,
      [HtsIdx, SamHdr, :pointer, :uint],
      HtsItr.by_ref

    # Get the next read from a SAM/BAM/CRAM iterator
    def self.sam_itr_next(htsfp, itr, r)
      # FIXME: check if htsfp is compressed BGZF
      raise("Null iterator") if itr.null?

      # FIXME: check multi
      hts_itr_next(htsfp[:fp][:bgzf], itr, r, htsfp)
    end

    attach_function \
      :sam_parse_region,
      [SamHdr, :string, :pointer, :pointer, :pointer, :int],
      :string

    # SAM I/O

    # macros (or alias)
    # sam_open
    # sam_open_format
    # sam_close

    attach_function \
      :sam_open_mode,
      %i[string string string],
      :int

    # A version of sam_open_mode that can handle ,key=value options.
    attach_function \
      :sam_open_mode_opts,
      %i[string string string],
      :string

    attach_function \
      :sam_hdr_change_HD,
      [SamHdr, :string, :string],
      :int

    attach_function \
      :sam_parse1,
      [KString, SamHdr, Bam1],
      :int

    attach_function \
      :sam_format1,
      [SamHdr, Bam1, KString],
      :int

    # Read a record from a file
    attach_function \
      :sam_read1,
      [HtsFile, SamHdr, Bam1],
      :int

    # Write a record to a file
    attach_function \
      :sam_write1,
      [HtsFile, SamHdr, Bam1],
      :int

    # Checks whether a record passes an hts_filter.
    attach_function \
      :sam_passes_filter,
      [SamHdr, Bam1, :pointer], # hts_filter_t
      :int

    # Return a pointer to an aux record
    attach_function \
      :bam_aux_get,
      [Bam1, :string], # FIXME
      :pointer

    # Get an integer aux value
    attach_function \
      :bam_aux2i,
      [:pointer],
      :int64

    # Get an integer aux value
    attach_function \
      :bam_aux2f,
      [:pointer],
      :double

    # Get a character aux value
    attach_function \
      :bam_aux2A,
      [:pointer],
      :char

    # Get a string aux value
    attach_function \
      :bam_aux2Z,
      [:pointer],
      :string

    # Get the length of an array-type ('B') tag
    attach_function \
      :bam_auxB_len,
      [:pointer],
      :uint

    # Get an integer value from an array-type tag
    attach_function \
      :bam_auxB2i,
      %i[pointer uint],
      :int64

    # Get a floating-point value from an array-type tag
    attach_function \
      :bam_auxB2f,
      %i[pointer uint],
      :double

    # Append tag data to a bam record
    attach_function \
      :bam_aux_append,
      [Bam1, :string, :string, :int, :pointer],
      :int

    # Delete tag data from a bam record
    attach_function \
      :bam_aux_del,
      [Bam1, :pointer],
      :int

    # Update or add a string-type tag
    attach_function \
      :bam_aux_update_str,
      [Bam1, :string, :int, :string],
      :int

    # Update or add an integer tag
    attach_function \
      :bam_aux_update_int,
      [Bam1, :string, :int64],
      :int

    # Update or add a floating-point tag
    attach_function \
      :bam_aux_update_float,
      [Bam1, :string, :float],
      :int

    # Update or add an array tag
    attach_function \
      :bam_aux_update_array,
      [Bam1, :string, :uint8, :uint32, :pointer],
      :int

    # sets an iterator over multiple
    attach_function \
      :bam_plp_init,
      %i[bam_plp_auto_f pointer],
      :bam_plp

    attach_function \
      :bam_plp_destroy,
      [:bam_plp],
      :void

    attach_function \
      :bam_plp_push,
      [:bam_plp, Bam1],
      :int

    attach_function \
      :bam_plp_next,
      %i[bam_plp pointer pointer pointer],
      BamPileup1.by_ref

    attach_function \
      :bam_plp_auto,
      %i[bam_plp pointer pointer pointer],
      BamPileup1.by_ref

    attach_function \
      :bam_plp64_next,
      %i[bam_plp pointer pointer pointer],
      BamPileup1.by_ref

    attach_function \
      :bam_plp64_auto,
      %i[bam_plp pointer pointer pointer],
      BamPileup1.by_ref

    attach_function \
      :bam_plp_set_maxcnt,
      %i[bam_plp int],
      :void

    attach_function \
      :bam_plp_reset,
      [:bam_plp],
      :void

    # sets a callback to initialise any per-pileup1_t fields.
    attach_function \
      :bam_plp_insertion,
      [BamPileup1, KString, :pointer],
      :int

    # sets a callback to initialise any per-pileup1_t fields.
    # bam_plp_constructor

    # bam_plp_destructor

    # Get pileup padded insertion sequence
    # bam_plp_insertion

    attach_function \
      :bam_mplp_init,
      %i[int bam_plp_auto_f pointer],
      :bam_mplp

    attach_function \
      :bam_mplp_init_overlaps,
      [:bam_mplp],
      :int

    attach_function \
      :bam_mplp_destroy,
      [:bam_mplp],
      :void

    attach_function \
      :bam_mplp_set_maxcnt,
      %i[bam_mplp int],
      :void

    attach_function \
      :bam_mplp_auto,
      %i[bam_mplp pointer pointer pointer pointer], # BamPileup1T
      :int

    attach_function \
      :bam_mplp64_auto,
      %i[bam_mplp pointer pointer pointer pointer], # BamPileup1T
      :int

    attach_function \
      :bam_mplp_reset,
      [:bam_mplp],
      :void

    # bam_mplp_constructor
    # bam_mplp_destructor

    attach_function \
      :sam_cap_mapq,
      [Bam1, :string, :hts_pos_t, :int],
      :int

    attach_function \
      :sam_prob_realn,
      [Bam1, :string, :hts_pos_t, :int],
      :int
  end
end

require_relative "sam_funcs"
