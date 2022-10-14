# frozen_string_literal: true

require_relative "flag"
require_relative "cigar"
require_relative "auxi"

module HTS
  class Bam < Hts
    # A class for working with alignment records.
    class Record
      SEQ_NT16_STR = "=ACMGRSVTWYHKDBN"

      attr_reader :header

      def initialize(bam1_t, header)
        @bam1 = bam1_t
        @header = header
      end

      # Return the FFI::Struct object.
      def struct
        @bam1
      end

      def to_ptr
        @bam1.to_ptr
      end

      # Get the read name. (a.k.a QNAME)
      # @return [String] query template name
      def qname
        LibHTS.bam_get_qname(@bam1).read_string
      end

      # Get the chromosome ID of the alignment. -1 if not mapped.
      # @return [Integer] chromosome ID
      def tid
        @bam1[:core][:tid]
      end

      def tid=(tid)
        @bam1[:core][:tid] = tid
      end

      # Get the chromosome ID of the mate. -1 if not mapped.
      # @return [Integer] chromosome ID
      def mtid
        @bam1[:core][:mtid]
      end

      def mtid=(mtid)
        @bam1[:core][:mtid] = mtid
      end

      # Get the 0-based leftmost coordinate of the alignment.
      # @return [Integer] 0-based leftmost coordinate
      def pos
        @bam1[:core][:pos]
      end

      def pos=(pos)
        @bam1[:core][:pos] = pos
      end

      # Get the 0-based leftmost coordinate of the mate.
      # @return [Integer] 0-based leftmost coordinate
      def mate_pos
        @bam1[:core][:mpos]
      end

      def mate_pos=(mpos)
        @bam1[:core][:mpos] = mpos
      end

      alias mpos mate_pos
      alias mpos= mate_pos=

      # Get the bin calculated by bam_reg2bin().
      # @return [Integer] bin
      def bin
        @bam1[:core][:bin]
      end

      def bin=(bin)
        @bam1[:core][:bin] = bin
      end

      # Get the rightmost base position of the alignment on the reference genome.
      # @return [Integer] 0-based rightmost coordinate
      def endpos
        LibHTS.bam_endpos @bam1
      end

      # Get the reference sequence name of the alignment. (a.k.a RNAME)
      # '' if not mapped.
      # @return [String] reference sequence name
      def chrom
        return "" if tid == -1

        LibHTS.sam_hdr_tid2name(@header, tid)
      end

      alias contig chrom

      # Get the reference sequence name of the mate.
      # '' if not mapped.
      # @return [String] reference sequence name
      def mate_chrom
        return "" if mtid == -1

        LibHTS.sam_hdr_tid2name(@header, mtid)
      end

      alias mate_contig mate_chrom

      # Get whether the query is on the reverse strand.
      # @return [String] strand "+" or "-"
      def strand
        LibHTS.bam_is_rev(@bam1) ? "-" : "+"
      end

      # Get whether the query's mate is on the reverse strand.
      # @return [String] strand "+" or "-"
      def mate_strand
        LibHTS.bam_is_mrev(@bam1) ? "-" : "+"
      end

      # Get the observed template length. (a.k.a TLEN)
      # @return [Integer] isize
      def insert_size
        @bam1[:core][:isize]
      end

      def insert_size=(isize)
        @bam1[:core][:isize] = isize
      end

      alias isize insert_size
      alias isize= insert_size=

      # Get the mapping quality of the alignment. (a.k.a MAPQ)
      # @return [Integer] mapping quality
      def mapq
        @bam1[:core][:qual]
      end

      def mapq=(mapq)
        @bam1[:core][:qual] = mapq
      end

      # Get the Bam::Cigar object.
      # @return [Bam::Cigar] cigar
      def cigar
        Cigar.new(LibHTS.bam_get_cigar(@bam1), @bam1[:core][:n_cigar])
      end

      # Calculate query length from CIGAR.
      # @return [Integer] query length
      def qlen
        LibHTS.bam_cigar2qlen(
          @bam1[:core][:n_cigar],
          LibHTS.bam_get_cigar(@bam1)
        )
      end

      # Calculate reference length from CIGAR.
      # @return [Integer] reference length
      def rlen
        LibHTS.bam_cigar2rlen(
          @bam1[:core][:n_cigar],
          LibHTS.bam_get_cigar(@bam1)
        )
      end

      # Get the sequence. (a.k.a SEQ)
      # @return [String] sequence
      def seq
        r = LibHTS.bam_get_seq(@bam1)
        seq = String.new
        (@bam1[:core][:l_qseq]).times do |i|
          seq << SEQ_NT16_STR[LibHTS.bam_seqi(r, i)]
        end
        seq
      end
      alias sequence seq

      # Get the length of the query sequence.
      # @return [Integer] query length
      def len
        @bam1[:core][:l_qseq]
      end

      # Get the base of the requested index "i" of the query sequence.
      # @param [Integer] i index
      # @return [String] base
      def base(n)
        n += @bam1[:core][:l_qseq] if n < 0
        return "." if (n >= @bam1[:core][:l_qseq]) || (n < 0) # eg. base(-1000)

        r = LibHTS.bam_get_seq(@bam1)
        SEQ_NT16_STR[LibHTS.bam_seqi(r, n)]
      end

      # Get the base qualities.
      # @return [Array] base qualities
      def qual
        q_ptr = LibHTS.bam_get_qual(@bam1)
        q_ptr.read_array_of_uint8(@bam1[:core][:l_qseq])
      end

      # Get the base qualities as a string. (a.k.a QUAL)
      # ASCII of base quality + 33.
      # @return [String] base qualities
      def qual_string
        qual.map { |q| (q + 33).chr }.join
      end

      # Get the base quality of the requested index "i" of the query sequence.
      # @param [Integer] i index
      # @return [Integer] base quality
      def base_qual(n)
        n += @bam1[:core][:l_qseq] if n < 0
        return 0 if (n >= @bam1[:core][:l_qseq]) || (n < 0) # eg. base_qual(-1000)

        q_ptr = LibHTS.bam_get_qual(@bam1)
        q_ptr.get_uint8(n)
      end

      # Get Bam::Flag object of the alignment.
      # @return [Bam::Flag] flag
      def flag
        Flag.new(@bam1[:core][:flag])
      end

      def flag=(flag)
        case flag
        when Integer
          @bam1[:core][:flag] = flag
        when Flag
          @bam1[:core][:flag] = flag.value
        else
          raise "Invalid flag type: #{flag.class}"
        end
      end

      # Get the auxiliary data.
      # @param [String] key tag name
      # @return [String] value
      def aux(key = nil)
        aux = Aux.new(self)
        if key
          aux.get(key)
        else
          aux
        end
      end

      # TODO: add a method to get the auxillary fields as a hash.

      # TODO: add a method to set the auxillary fields.

      # TODO: add a method to remove the auxillary fields.

      # TODO: add a method to set variable length data (qname, cigar, seq, qual).

      # Calling flag is delegated to the Flag object.
      Flag::TABLE.each_key do |m|
        define_method(m) do
          flag.send(m)
        end
      end

      # @return [String] a string representation of the alignment.
      def to_s
        kstr = LibHTS::KString.new
        raise "Failed to format bam record" if LibHTS.sam_format1(@header.struct, @bam1, kstr) == -1

        kstr[:s]
      end

      private

      def initialize_copy(orig)
        @header = orig.header
        @bam = LibHTS.bam_dup1(orig.struct)
      end
    end
  end
end
