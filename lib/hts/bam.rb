# frozen_string_literal: true

# Create a skeleton using hts-python as a reference.
# https://github.com/quinlan-lab/hts-python

module HTS
  class BamHeader
    attr_reader :h

    def initialize(h)
      @h = h
    end

    def seqs
      Array.new(@h[:n_targets]) do |i|
        @h[:target_name][i].read_string # FIXME
      end
    end

    def text
      @h[:text]
    end
  end

  # A cigar object usually created from `Alignment`.
  class Cigar
    OPS = 'MIDNSHP=XB'

    def initialize(cigar, n_cigar)
      @c = cigar
      @n_cigar = n_cigar
    end

    def to_s
      warn 'WIP'
      Array.new(@_cigar) do |i|
        c = @c[i]
        [HTS::FFI.bam_cigar_oplen(c),
         HTS::FFI.bam_cigar_opchar(c)]
      end
    end

    def each
    end
    # def inspect; end
  end

  class Alignment
    def initialize(bam1_t, bam_hdr_t)
      @b = bam1_t
      @h = bam_hdr_t
    end

    def initialize_copy
      super
    end

    def self.rom_sam_str; end

    def tags; end

    # Read (query) name.
    def qname
      HTS::FFI.bam_get_qname(@b).read_string
    end

    # Set (query) name.
    def qname=(name); end

    def rnext
      @b[:core][:mpos]
    end

    def pnext; end

    def rname; end

    def strand; end

    def base_qualities; end

    def pos; end

    def pos=; end

    def isize; end

    def mapping_quality; end

    def cigar; end

    def qlen; end

    def rlen; end

    def seqs; end

    def flag_str; end

    def flag; end

    # def eql?
    # def hash

    def to_s; end
  end

  class Bam
    include Enumerable
    attr_reader :fname, :mode, :header, :htf

    def initialize(fname, mode = 'r', create_index: nil, header: nil, fasta: nil)
      @fname = File.expand_path(fname)
      @mode = mode
      @htf = HTS::FFI.hts_open(@fname, mode)

      if mode[0] == 'r'
        @idx = HTS::FFI.sam_index_load(@htf, @fname)
        if (@idx.nil? && create_index.nil?) || create_index
          HTS::FFI.bam_index_build(fname, -1)
          @idx = HTS::FFI.sam_index_load(@htf, @fname)
          warn 'NO querying'
        end
        @header = BamHeader.new(HTS::FFI.sam_hdr_read(@htf))
        @b = HTS::FFI.bam_init1

      else
        # FIXME
        raise 'not implemented yet.'

      end
    end

    def self.header_from_fasta; end

    def write(alns)
      alns.each do
        HTS::FFI.sam_write1(@htf, @header, alns.b) > 0 || raise
      end
    end

    # Close the current file.
    def close
      HTS::FFI.hts_close(@htf)
    end

    # Flush the current file.
    def flush
      raise
      # HTS::FFI.bgzf_flush(@htf.fp.bgzf)
    end

    def each(&block)
      block.call(Alignment.new(@b, @header.h)) while HTS::FFI.sam_read1(@htf, @header.h, @b) > 0
    end

    # def call
  end
end
