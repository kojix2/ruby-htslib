# frozen_string_literal: true

module HTS
  module FFI
    extend ::FFI::Library

    begin
      ffi_lib HTS.ffi_lib
    rescue LoadError => e
      raise LoadError, "Could not find HTSlib.#{FFI::Platform::LIBSUFFIX}"
    end

    def self.attach_function(*)
      super
    rescue ::FFI::NotFoundError => e
      warn e.message
    end
  end
end

require_relative 'ffi/struct'
require_relative 'ffi/constants'

module HTS
  module FFI
    # hfile

    # Open the named file or URL as a stream
    attach_function \
      :hopen,
      %i[string string varargs],
      :HFILE

    # Associate a stream with an existing open file descriptor
    attach_function \
      :hdopen,
      %i[int string],
      :HFILE

    # Report whether the file name or URL denotes remote storage
    attach_function \
      :hisremote,
      [:string],
      :int

    # Append an extension or replace an existing extension
    attach_function \
      :haddextension,
      [Kstring, :string, :int, :string],
      :string

    # Flush (for output streams) and close the stream
    attach_function \
      :hclose,
      [:HFILE],
      :int

    # Close the stream, without flushing or propagating errors
    attach_function \
      :hclose_abruptly,
      [:HFILE],
      :void

    # Reposition the read/write stream offset
    attach_function \
      :hseek,
      %i[HFILE off_t int],
      :off_t

    # Read from the stream until the delimiter, up to a maximum length
    attach_function \
      :hgetdelim,
      %i[string size_t int HFILE],
      :ssize_t

    # Read a line from the stream, up to a maximum length
    attach_function \
      :hgets,
      %i[string int HFILE],
      :string

    # Peek at characters to be read without removing them from buffers
    attach_function \
      :hpeek,
      %i[HFILE pointer size_t],
      :ssize_t

    # For writing streams, flush buffered output to the underlying stream
    attach_function \
      :hflush,
      [:HFILE],
      :int

    # For hfile_mem: get the internal buffer and it's size from a hfile
    attach_function \
      :hfile_mem_get_buffer,
      %i[HFILE pointer],
      :string

    # For hfile_mem: get the internal buffer and it's size from a hfile.
    attach_function \
      :hfile_mem_steal_buffer,
      %i[HFILE pointer],
      :string

    # BGZF

    # Open an existing file descriptor for reading or writing.
    attach_function \
      :bgzf_dopen,
      %i[int string],
      BGZF.by_ref

    # Open the specified file for reading or writing.
    attach_function \
      :bgzf_open,
      %i[string string],
      BGZF.by_ref

    # Open an existing hFILE stream for reading or writing.
    attach_function \
      :bgzf_hopen,
      %i[HFILE string],
      BGZF.by_ref

    # Close the BGZF and free all associated resources.
    attach_function \
      :bgzf_close,
      [:HFILE],
      :int

    # Read up to _length_ bytes from the file storing into _data_.
    attach_function \
      :bgzf_read,
      %i[HFILE pointer size_t],
      :ssize_t

    # Write _length_ bytes from _data_ to the file. If no I/O errors occur,
    # the complete _length_ bytes will be written (or queued for writing).
    attach_function \
      :bgzf_write,
      [BGZF, :pointer, :size_t],
      :ssize_t

    # Write _length_ bytes from _data_ to the file, the index will be used to
    # decide the amount of uncompressed data to be writen to each bgzip block.
    attach_function \
      :bgzf_block_write,
      [BGZF, :pointer, :size_t],
      :ssize_t

    # Returns the next byte in the file without consuming it.
    attach_function \
      :bgzf_peek,
      [BGZF],
      :int

    # Read up to _length_ bytes directly from the underlying stream without
    # decompressing.  Bypasses BGZF blocking, so must be used with care in
    # specialised circumstances only.
    attach_function \
      :bgzf_raw_read,
      [BGZF, :pointer, :size_t],
      :ssize_t

    # Write _length_ bytes directly to the underlying stream without
    # compressing.  Bypasses BGZF blocking, so must be used with care
    # in specialised circumstances only.
    attach_function \
      :bgzf_raw_write,
      [BGZF, :pointer, :size_t],
      :ssize_t

    # Write the data in the buffer to the file.
    attach_function \
      :bgzf_flush,
      [BGZF],
      :int

    # Set the file to read from the location specified by _pos_.
    attach_function \
      :bgzf_seek,
      [BGZF, :int64, :int],
      :int64

    # Check if the BGZF end-of-file (EOF) marker is present
    attach_function \
      :bgzf_check_EOF,
      [BGZF],
      :int

    # Return the file's compression format
    attach_function \
      :bgzf_compression,
      [BGZF],
      :int

    # Check if a file is in the BGZF format
    attach_function \
      :bgzf_is_bgzf,
      [:string],
      :int

    # Set the cache size. Only effective when compiled with -DBGZF_CACHE.
    attach_function \
      :bgzf_set_cache_size,
      [BGZF, :int],
      :void

    # Flush the file if the remaining buffer size is smaller than _size_
    attach_function \
      :bgzf_flush_try,
      [BGZF, :ssize_t],
      :int

    # Read one byte from a BGZF file. It is faster than bgzf_read()
    attach_function \
      :bgzf_getc,
      [BGZF],
      :int

    # Read one line from a BGZF file. It is faster than bgzf_getc()
    attach_function \
      :bgzf_getline,
      [BGZF, :int, Kstring],
      :int

    # Read the next BGZF block.
    attach_function \
      :bgzf_read_block,
      [BGZF],
      :int

    # Enable multi-threading (when compiled with -DBGZF_MT) via a shared
    # thread pool.
    attach_function \
      :bgzf_thread_pool,
      [BGZF, :pointer, :int],
      :int

    # Enable multi-threading (only effective when the library was compiled
    # with -DBGZF_MT)
    attach_function \
      :bgzf_mt,
      [BGZF, :int, :int],
      :int

    # Compress a single BGZF block.
    attach_function \
      :bgzf_compress,
      %i[pointer pointer pointer size_t int],
      :int

    # Position BGZF at the uncompressed offset
    attach_function \
      :bgzf_useek,
      [BGZF, :off_t, :int],
      :int

    # Position in uncompressed BGZF
    attach_function \
      :bgzf_utell,
      [BGZF],
      :off_t

    # Tell BGZF to build index while compressing.
    attach_function \
      :bgzf_index_build_init,
      [BGZF],
      :int

    # Load BGZF index
    attach_function \
      :bgzf_index_load,
      [BGZF, :string, :string],
      :int

    # Load BGZF index from an hFILE
    attach_function \
      :bgzf_index_load_hfile,
      [BGZF, :HFILE, :string],
      :int

    # Save BGZF index
    attach_function \
      :bgzf_index_dump,
      [BGZF, :string, :string],
      :int

    # Write a BGZF index to an hFILE
    attach_function \
      :bgzf_index_dump_hfile,
      [BGZF, :HFILE, :string],
      :int

    # hts

    # sam

    class << self
      def bam_cigar_op(c)
        c & BAM_CIGAR_MASK
      end

      def bam_cigar_oplen(c)
        c >> BAM_CIGAR_SHIFT
      end

      def bam_cigar_opchar(c)
        _BAM_CIGAR_STR_PADDED[bam_cigar_op(c)]
      end

      def bam_cigar_gen(l, o)
        l << BAM_CIGAR_SHIFT | o
      end

      def bam_cigar_type(o)
        BAM_CIGAR_TYPE >> (o << 1) & 3
      end
    end

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

      # def bam_seqi(s, i)

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
      [SamHdr, :string, :string, :string, Kstring],
      :int

    # Returns a complete line of formatted text for a given type and index.
    attach_function \
      :sam_hdr_find_line_pos,
      [SamHdr, :string, :int, Kstring],
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
      [SamHdr, :string, :string, :string, :string, Kstring],
      :int

    # Return the value associated with a key for a header line identified by position
    attach_function \
      :sam_hdr_find_tag_pos,
      [SamHdr, :string, :int, :string, Kstring],
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
      [Kstring, SamHdr, Bam1],
      :int

    attach_function \
      :sam_format1,
      [SamHdr, Bam1, Kstring],
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
      [:pointer, Kstring, :pointer],
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

    # kfunc

    # Log gamma function
    attach_function \
      :kf_lgamma,
      [:double],
      :double

    # complementary error function
    attach_function \
      :kf_erfc,
      [:double],
      :double

    # The following computes regularized incomplete gamma functions.
    attach_function \
      :kf_gammap,
      %i[double double],
      :double

    attach_function \
      :kf_gammaq,
      %i[double double],
      :double

    attach_function \
      :kf_betai,
      %i[double double double],
      :double

    attach_function \
      :kt_fisher_exact,
      %i[int int int int pointer pointer pointer],
      :double

    # hts

    # hts_expand
    # hts_expand3
    # hts_resize

    attach_function \
      :hts_lib_shutdown,
      [:void],
      :void

    attach_function \
      :hts_free,
      [:pointer],
      :void

    # Parses arg and appends it to the option list.
    attach_function \
      :hts_opt_add,
      %i[pointer string],
      :int

    # Applies an hts_opt option list to a given htsFile.
    attach_function \
      :hts_opt_apply,
      [HtsFile, HtsOpt],
      :int

    # Frees an hts_opt list.
    attach_function \
      :hts_opt_free,
      [HtsOpt],
      :void

    # Accepts a string file format (sam, bam, cram, vcf, bam)
    attach_function \
      :hts_parse_format,
      [HtsFormat, :string],
      :int

    # Tokenise options as (key(=value)?,)*(key(=value)?)?
    attach_function \
      :hts_parse_opt_list,
      [HtsFormat, :string],
      :int

    # Get the htslib version number
    attach_function \
      :hts_version,
      [],
      :string

    # Determine format by peeking at the start of a file
    attach_function \
      :hts_detect_format,
      [:HFILE, HtsFormat],
      :int

    # Get a human-readable description of the file format
    attach_function \
      :hts_format_description,
      [HtsFormat],
      :string

    # Open a sequence data (SAM/BAM/CRAM) or variant data (VCF/BCF)
    # or possibly-compressed textual line-orientated file
    attach_function \
      :hts_open,
      %i[string string],
      HtsFile.by_ref

    # Open a SAM/BAM/CRAM/VCF/BCF/etc file
    attach_function \
      :hts_open_format,
      [:string, :string, HtsFormat],
      HtsFile.by_ref

    # Open an existing stream as a SAM/BAM/CRAM/VCF/BCF/etc file
    attach_function \
      :hts_hopen,
      %i[HFILE string string],
      HtsFile.by_ref

    # Close a file handle, flushing buffered data for output streams
    attach_function \
      :hts_close,
      [HtsFile],
      :int

    # Returns the file's format information
    attach_function \
      :hts_get_format,
      [HtsFile],
      HtsFormat.by_ref

    # Returns a string containing the file format extension.
    attach_function \
      :hts_format_file_extension,
      [HtsFormat],
      :string

    # Sets a specified CRAM option on the open file handle.
    attach_function \
      :hts_set_opt,
      [HtsFile, HtsFmtOption, :varargs],
      :int

    # Read a line (and its \n or \r\n terminator) from a file
    attach_function \
      :hts_getline,
      [HtsFile, :int, Kstring],
      :int

    attach_function \
      :hts_readlines,
      %i[string pointer],
      :pointer

    # Parse comma-separated list or read list from a file
    attach_function \
      :hts_readlist,
      %i[string int pointer],
      :pointer

    # Create extra threads to aid compress/decompression for this file
    attach_function \
      :hts_set_threads,
      [HtsFile, :int],
      :int

    # Create extra threads to aid compress/decompression for this file
    attach_function \
      :hts_set_thread_pool,
      [HtsFile, HtsThreadPool],
      :int

    # Adds a cache of decompressed blocks, potentially speeding up seeks.
    attach_function \
      :hts_set_cache_size,
      [HtsFile, :int],
      :void

    # Set .fai filename for a file opened for reading
    attach_function \
      :hts_set_fai_filename,
      [HtsFile, :string],
      :int

    # Determine whether a given htsFile contains a valid EOF block
    attach_function \
      :hts_check_EOF,
      [HtsFile],
      :int

    # hts_pair_pos_t
    # hts_pair64_t
    # hts_pair4_max_t
    # hts_reglist_t
    # hts_readrec_func
    # hts_seek_func
    # hts_tell_func

    # Create a BAI/CSI/TBI type index structure
    attach_function \
      :hts_idx_init,
      %i[int int uint64 int int],
      :pointer

    # Free a BAI/CSI/TBI type index
    attach_function \
      :hts_idx_destroy,
      [HtsIdx],
      :void

    # Push an index entry
    attach_function \
      :hts_idx_push,
      [HtsIdx, :int, :int64, :int64, :uint64, :int],
      :int

    # Finish building an index
    attach_function \
      :hts_idx_finish,
      [HtsIdx, :uint64],
      :int

    # Returns index format
    attach_function \
      :hts_idx_fmt,
      [HtsIdx],
      :int

    # Add name to TBI index meta-data
    attach_function \
      :hts_idx_tbi_name,
      [HtsIdx, :int, :string],
      :int

    # Save an index to a file
    attach_function \
      :hts_idx_save,
      [HtsIdx, :string, :int],
      :int

    # Save an index to a specific file
    attach_function \
      :hts_idx_save_as,
      [HtsIdx, :string, :string, :int],
      :int

    # Load an index file
    attach_function \
      :hts_idx_load,
      %i[string int],
      HtsIdx.by_ref

    # Load a specific index file
    attach_function \
      :hts_idx_load2,
      %i[string string],
      HtsIdx.by_ref

    # Load a specific index file
    attach_function \
      :hts_idx_load3,
      %i[string string int int],
      HtsIdx.by_ref

    # Get extra index meta-data
    attach_function \
      :hts_idx_get_meta,
      [HtsIdx, :pointer],
      :uint8

    # Set extra index meta-data
    attach_function \
      :hts_idx_set_meta,
      [HtsIdx, :uint32, :pointer, :int],
      :int

    # Get number of mapped and unmapped reads from an index
    attach_function \
      :hts_idx_get_stat,
      [HtsIdx, :int, :pointer, :pointer],
      :int

    # Return the number of unplaced reads from an index
    attach_function \
      :hts_idx_get_n_no_coor,
      [HtsIdx],
      :uint64

    attach_function \
      :hts_parse_decimal,
      %i[string pointer int],
      :long_long

    # Parse a "CHR:START-END"-style region string
    attach_function \
      :hts_parse_reg64,
      %i[string pointer pointer],
      :string

    # Parse a "CHR:START-END"-style region string
    attach_function \
      :hts_parse_reg,
      %i[string pointer pointer],
      :string

    # Parse a "CHR:START-END"-style region string
    attach_function \
      :hts_parse_region,
      %i[string pointer pointer pointer pointer pointer int],
      :string

    # Create a single-region iterator
    attach_function \
      :hts_itr_query,
      [HtsIdx, :int, :hts_pos_t, :hts_pos_t, :pointer],
      HtsItr.by_ref

    # Free an iterator
    attach_function \
      :hts_itr_destroy,
      [HtsItr],
      :void

    # Create a single-region iterator from a text region specification
    attach_function \
      :hts_itr_querys,
      [HtsIdx, :string, :pointer, :pointer, :pointer, :pointer],
      HtsItr.by_ref

    # Return the next record from an iterator
    attach_function \
      :hts_itr_next,
      [BGZF, HtsItr, :pointer, :pointer],
      :int

    attach_function \
      :hts_idx_seqnames,
      [HtsIdx, :pointer, :pointer, :pointer],
      :pointer

    # hts_itr_multi_bam
    # hts_itr_multi_cram
    # hts_itr_regions
    # hts_itr_multi_next
    # hts_reglist_create
    # hts_reglist_free
    # errmod_init
    # errmod_destroy
    # errmod_call
    # proabln_glocal
    # hts_md5_context
    # hts_md5_update
    # hts_md5_final
    # hts_md5_reset
    # hts_md5_hex
    # hts_md5_destroy

    # attach_function :sam_hdr_tid2name,          [:pointer, :int],                             :string

    # tbx

    attach_function \
      :tbx_name2id,
      [Tbx, :string],
      :int

    # Internal helper function used by tbx_itr_next()
    attach_function \
      :hts_get_bgzfp,
      [HtsFile],
      BGZF.by_ref

    attach_function \
      :tbx_readrec,
      [BGZF, :pointer, :pointer, :pointer, :pointer, :pointer],
      :int

    # Build an index of the lines in a BGZF-compressed file
    attach_function \
      :tbx_index,
      [BGZF, :int, TbxConf],
      Tbx.by_ref

    attach_function \
      :tbx_index_build,
      [:string, :int, TbxConf],
      :int

    attach_function \
      :tbx_index_build2,
      [:string, :string, :int, TbxConf],
      :int

    attach_function \
      :tbx_index_build3,
      [:string, :string, :int, :int, TbxConf],
      :int

    # Load or stream a .tbi or .csi index
    attach_function \
      :tbx_index_load,
      [:string],
      Tbx.by_ref

    # Load or stream a .tbi or .csi index
    attach_function \
      :tbx_index_load2,
      %i[string string],
      Tbx.by_ref

    # Load or stream a .tbi or .csi index
    attach_function \
      :tbx_index_load3,
      %i[string string int],
      Tbx.by_ref

    attach_function \
      :tbx_seqnames,
      [Tbx, :int],
      :pointer

    attach_function \
      :tbx_destroy,
      [Tbx],
      :void

    # faidx

    # Build index for a FASTA or FASTQ or bgzip-compressed FASTA or FASTQ file.
    attach_function \
      :fai_build3,
      %i[string string string],
      :int

    # Build index for a FASTA or FASTQ or bgzip-compressed FASTA or FASTQ file.
    attach_function \
      :fai_build,
      [:string],
      :int

    # Destroy a faidx_t struct
    attach_function \
      :fai_destroy,
      [Faidx],
      :void

    # Load FASTA indexes.
    attach_function \
      :fai_load3,
      %i[string string string int],
      Faidx.by_ref

    # Load index from "fn.fai".
    attach_function \
      :fai_load,
      [:string],
      Faidx.by_ref

    #  Load FASTA or FASTQ indexes.
    attach_function \
      :fai_load3_format,
      [:string, :string, :string, :int, FaiFormatOptions],
      Faidx.by_ref

    # Load index from "fn.fai".
    attach_function \
      :fai_load_format,
      [:string, FaiFormatOptions],
      Faidx.by_ref

    # Fetch the sequence in a region
    attach_function \
      :fai_fetch,
      [Faidx, :string, :pointer],
      :string

    # Fetch the sequence in a region
    attach_function \
      :fai_fetch64,
      [Faidx, :string, :pointer],
      :string

    # Fetch the quality string for a region for FASTQ files
    attach_function \
      :fai_fetchqual,
      [Faidx, :string, :pointer],
      :string

    attach_function \
      :fai_fetchqual64,
      [Faidx, :string, :pointer],
      :string

    # Fetch the number of sequences
    attach_function \
      :faidx_fetch_nseq,
      [Faidx],
      :int

    # Fetch the sequence in a region
    attach_function \
      :faidx_fetch_seq,
      [Faidx, :string, :int, :int, :pointer],
      :string

    # Fetch the sequence in a region
    attach_function \
      :faidx_fetch_seq64,
      [Faidx, :string, :int64, :int64, :pointer],
      :string

    # Fetch the quality string in a region for FASTQ files
    attach_function \
      :faidx_fetch_qual,
      [Faidx, :string, :int, :int, :pointer],
      :string

    # Fetch the quality string in a region for FASTQ files
    attach_function \
      :faidx_fetch_qual64,
      [Faidx, :string, :int64, :int64, :pointer],
      :string

    # Query if sequence is present
    attach_function \
      :faidx_has_seq,
      [Faidx, :string],
      :int

    # Return number of sequences in fai index
    attach_function \
      :faidx_nseq,
      [Faidx],
      :int

    # Return name of i-th sequence
    attach_function \
      :faidx_iseq,
      [Faidx, :int],
      :string

    # Return sequence length, -1 if not present
    attach_function \
      :faidx_seq_len,
      [Faidx, :string],
      :int

    # Parses a region string.
    attach_function \
      :fai_parse_region,
      [Faidx, :string, :pointer, :pointer, :pointer, :int], :string

    # Sets the cache size of the underlying BGZF compressed file
    attach_function \
      :fai_set_cache_size,
      [Faidx, :int],
      :void

    # Determines the path to the reference index file
    attach_function \
      :fai_path,
      [:string],
      :string

    # vcf
  end
end
