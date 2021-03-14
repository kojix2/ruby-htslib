# frozen_string_literal: true

module HTS
  module FFI
    # constants
    BAM_CMATCH     = 0
    BAM_CINS       = 1
    BAM_CDEL       = 2
    BAM_CREF_SKIP  = 3
    BAM_CSOFT_CLIP = 4
    BAM_CHARD_CLIP = 5
    BAM_CPAD       = 6
    BAM_CEQUAL     = 7
    BAM_CDIFF      = 8
    BAM_CBACK      = 9

    BAM_CIGAR_STR = 'MIDNSHP=XB'
    BAM_CIGAR_STR_PADDED = 'MIDNSHP=XB??????'
    BAM_CIGAR_SHIFT = 4
    BAM_CIGAR_MASK  = 0xf
    BAM_CIGAR_TYPE  = 0x3C1A7

    # macros
    class << self
      def bam_cigar_op(c)
        c & BAM_CIGAR_MASK
      end

      def bam_cigar_oplen(c)
        c >> BAM_CIGAR_SHIFT
      end

      def bam_cigar_opchr(c)
        ("#{BAM_CIGAR_STR}??????")[bam_cigar_op(c)]
      end

      def bam_cigar_gen(l, o)
        l << BAM_CIGAR_SHIFT | o
      end

      def bam_cigar_type(o)
        BAM_CIGAR_TYPE >> (o << 1) & 3
      end
    end

    BAM_FPAIRED        =    1
    BAM_FPROPER_PAIR   =    2
    BAM_FUNMAP         =    4
    BAM_FMUNMAP        =    8
    BAM_FREVERSE       =   16
    BAM_FMREVERSE      =   32
    BAM_FREAD1         =   64
    BAM_FREAD2         =  128
    BAM_FSECONDARY     =  256
    BAM_FQCFAIL        =  512
    BAM_FDUP           = 1024
    BAM_FSUPPLEMENTARY = 2048

    # macros
    # function-like macros
    class << self
      def bam_is_rev(b)
        b[:core][:flag] & BAM_FREVERSE != 0
      end

      def bam_is_mrev(b)
        b[:core][:flag] & BAM_FMREVERSE != 0
      end

      def bam_get_qname(b)
        b[:data]
      end

      def bam_get_cigar(b)
        b[:data] + b[:core][:l_qname]
      end

      def bam_get_seq(b)
        b[:data] + (b[:core][:n_cigar] << 2) + b[:core][:l_qname]
      end

      def bam_get_qual(b)
        b[:data] + (b[:core][:n_cigar] << 2) + b[:core][:l_qname] + ((b[:core][:l_qseq] + 1) >> 1)
      end

      def bam_get_aux(b)
        b[:data] + (b[:core][:n_cigar] << 2) + b[:core][:l_qname] + ((b[:core][:l_qseq] + 1) >> 1) + b[:core][:l_qseq]
      end

      def bam_get_l_aux(b)
        b[:l_data] - (b[:core][:n_cigar] << 2) - b[:core][:l_qname] - b[:core][:l_qseq] - ((b[:core][:l_qseq] + 1) >> 1)
      end

      def bam_seqi(s, i)
        s[(i) >> 1].read_uint8 >> ((~i & 1) << 2) & 0xf
      end

      # def bam_set_seqi(s, i, b)
    end

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
      hts_log_error('Null iterator') if itr.null?
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
      :string

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
      BamPlp

    attach_function \
      :bam_plp_destroy,
      [BamPlp],
      :void

    attach_function \
      :bam_plp_push,
      [BamPlp, Bam1],
      :int

    attach_function \
      :bam_plp_next,
      [BamPlp, :pointer, :pointer, :pointer],
      :pointer

    attach_function \
      :bam_plp_auto,
      [BamPlp, :pointer, :pointer, :pointer],
      :pointer

    attach_function \
      :bam_plp64_next,
      [BamPlp, :pointer, :pointer, :pointer],
      :pointer

    attach_function \
      :bam_plp64_auto,
      [BamPlp, :pointer, :pointer, :pointer],
      :pointer

    attach_function \
      :bam_plp_set_maxcnt,
      [BamPlp, :int],
      :void

    attach_function \
      :bam_plp_reset,
      [BamPlp],
      :void

    # sets a callback to initialise any per-pileup1_t fields.
    attach_function \
      :bam_plp_insertion,
      [:pointer, KString, :pointer],
      :int

    # sets a callback to initialise any per-pileup1_t fields.
    # bam_plp_constructor

    # bam_plp_destructor

    # Get pileup padded insertion sequence
    # bam_plp_insertion

    attach_function \
      :bam_mplp_init,
      %i[int bam_plp_auto_f pointer],
      BamMplp.by_ref

    attach_function \
      :bam_mplp_init_overlaps,
      [BamMplp],
      :int

    attach_function \
      :bam_mplp_destroy,
      [BamMplp],
      :void

    attach_function \
      :bam_mplp_set_maxcnt,
      [BamMplp, :int],
      :void

    attach_function \
      :bam_mplp_auto,
      [BamMplp, :pointer, :pointer, :pointer, :pointer],
      :int

    attach_function \
      :bam_mplp64_auto,
      [BamMplp, :pointer, :pointer, :pointer, :pointer],
      :int

    attach_function \
      :bam_mplp_reset,
      [BamMplp],
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
