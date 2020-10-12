# frozen_string_literal: true

module HTS
  module FFI
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
  end
end
