# frozen_string_literal: true

# Based on hts-python
# https://github.com/quinlan-lab/hts-python

module HTS
  class Bam < Hts
    class Record
      SEQ_NT16_STR = "=ACMGRSVTWYHKDBN"

      attr_reader :header

      def initialize(bam1_t, header)
        @bam1 = bam1_t
        @header = header
      end

      def struct
        @bam1
      end

      def to_ptr
        @bam1.to_ptr
      end

      # returns the query name.
      def qname
        LibHTS.bam_get_qname(@bam1).read_string
      end

      # Set (query) name.
      # def qname=(name)
      #   raise 'Not Implemented'
      # end

      # returns the tid of the record or -1 if not mapped.
      def tid
        @bam1[:core][:tid]
      end

      def tid=(tid)
        @bam1[:core][:tid] = tid
      end

      # returns the tid of the mate or -1 if not mapped.
      def mtid
        @bam1[:core][:mtid]
      end

      def mtid=(mtid)
        @bam1[:core][:mtid] = mtid
      end

      # returns 0-based start position.
      def pos
        @bam1[:core][:pos]
      end

      def pos=(pos)
        @bam1[:core][:pos] = pos
      end

      # returns 0-based mate position
      def mpos
        @bam1[:core][:mpos]
      end

      def mpos=(mpos)
        @bam1[:core][:mpos] = mpos
      end

      def bin
        @bam1[:core][:bin]
      end

      def bin=(bin)
        @bam1[:core][:bin] = bin
      end

      # returns end position of the read.
      def stop
        LibHTS.bam_endpos @bam1
      end

      # returns the chromosome or '' if not mapped.
      def chrom
        return "" if tid == -1

        LibHTS.sam_hdr_tid2name(@header, tid)
      end

      # returns the chromosome or '' if not mapped.
      def contig
        chrom
      end

      # returns the chromosome of the mate or '' if not mapped.
      def mate_chrom
        return "" if mtid == -1

        LibHTS.sam_hdr_tid2name(@header, mtid)
      end

      # Get strand information.
      def strand
        LibHTS.bam_is_rev(@bam1) ? "-" : "+"
      end

      # insert size
      def insert_size
        @bam1[:core][:isize]
      end
      alias isize insert_size

      # mapping quality
      def mapq
        @bam1[:core][:qual]
      end

      def mapq=(mapq)
        @bam1[:core][:qual] = mapq
      end

      # returns a `Cigar` object.
      def cigar
        Cigar.new(LibHTS.bam_get_cigar(@bam1), @bam1[:core][:n_cigar])
      end

      def qlen
        LibHTS.bam_cigar2qlen(
          @bam1[:core][:n_cigar],
          LibHTS.bam_get_cigar(@bam1)
        )
      end

      def rlen
        LibHTS.bam_cigar2rlen(
          @bam1[:core][:n_cigar],
          LibHTS.bam_get_cigar(@bam1)
        )
      end

      # return the read sequence
      def sequence
        r = LibHTS.bam_get_seq(@bam1)
        seq = String.new
        (@bam1[:core][:l_qseq]).times do |i|
          seq << SEQ_NT16_STR[LibHTS.bam_seqi(r, i)]
        end
        seq
      end

      # return only the base of the requested index "i" of the query sequence.
      def base_at(n)
        n += @bam1[:core][:l_qseq] if n < 0
        return "." if (n >= @bam1[:core][:l_qseq]) || (n < 0) # eg. base_at(-1000)

        r = LibHTS.bam_get_seq(@bam1)
        SEQ_NT16_STR[LibHTS.bam_seqi(r, n)]
      end

      # return the base qualities
      def base_qualities
        q_ptr = LibHTS.bam_get_qual(@bam1)
        q_ptr.read_array_of_uint8(@bam1[:core][:l_qseq])
      end

      # return only the base quality of the requested index "i" of the query sequence.
      def base_quality_at(n)
        n += @bam1[:core][:l_qseq] if n < 0
        return 0 if (n >= @bam1[:core][:l_qseq]) || (n < 0) # eg. base_quality_at(-1000)

        q_ptr = LibHTS.bam_get_qual(@bam1)
        q_ptr.get_uint8(n)
      end

      # returns a `Flag` object.
      def flag
        Flag.new(@bam1[:core][:flag])
      end

      def flag=(flag)
        case flag
        when Fixnum
          @bam1[:core][:flag] = flag
        when Flag
          @bam1[:core][:flag] = flag.value
        else
          raise "Invalid flag type: #{flag.class}"
        end
      end

      def tag(str)
        aux = LibHTS.bam_aux_get(@bam1, str)
        return nil if aux.null?

        t = aux.read_string(1)

        # A (character), B (general array),
        # f (real number), H (hexadecimal array),
        # i (integer), or Z (string).

        case t
        when "i", "I", "c", "C", "s", "S"
          LibHTS.bam_aux2i(aux)
        when "f", "d"
          LibHTS.bam_aux2f(aux)
        when "Z", "H"
          LibHTS.bam_aux2Z(aux)
        when "A" # char
          LibHTS.bam_aux2A(aux).chr
        end
      end

      # def tags; end

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
