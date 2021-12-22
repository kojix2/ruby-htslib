# frozen_string_literal: true

# Based on hts-python
# https://github.com/quinlan-lab/hts-python

module HTS
  class Bam
    class Record
      SEQ_NT16_STR = "=ACMGRSVTWYHKDBN"

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

      # def initialize_copy
      #   super
      # end

      def self.rom_sam_str; end

      def tags; end

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

      # returns the tid of the mate or -1 if not mapped.
      def mate_tid
        @bam1[:core][:mtid]
      end

      # returns 0-based start position.
      def start
        @bam1[:core][:pos]
      end

      # returns end position of the read.
      def stop
        LibHTS.bam_endpos @bam1
      end

      # returns 0-based mate position
      def mate_start
        @bam1[:core][:mpos]
      end
      alias mate_pos mate_start

      # returns the chromosome or '' if not mapped.
      def chrom
        tid = @bam1[:core][:tid]
        return "" if tid == -1

        LibHTS.sam_hdr_tid2name(@header, tid)
      end

      # returns the chromosome of the mate or '' if not mapped.
      def mate_chrom
        tid = @bam1[:core][:mtid]
        return "" if tid == -1

        LibHTS.sam_hdr_tid2name(@header, tid)
      end

      def strand
        LibHTS.bam_is_rev(@bam1) ? "-" : "+"
      end

      # def start=(v)
      #   raise 'Not Implemented'
      # end

      # insert size
      def isize
        @bam1[:core][:isize]
      end

      # mapping quality
      def mapping_quality
        @bam1[:core][:qual]
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

      def flag_str
        LibHTS.bam_flag2str(@bam1[:core][:flag])
      end

      # returns a `Flag` object.
      def flag
        Flag.new(@bam1[:core][:flag])
      end

      def tag(str)
        aux = LibHTS.bam_aux_get(@bam1, str)
        return nil if aux.null?

        t = aux.read_string(1)
        case t
        when 'i', 'I', 'c', 'C', 's', 'S'
          LibHTS.bam_aux2i(aux)
        when 'f', 'd'
          LibHTS.bam_aux2f(aux)
        when 'Z', 'H'
          LibHTS.bam_aux2Z(aux)
        when 'A'
          LibHTS.bam_aux2A(aux)
        end
      end 

      def to_s
        kstr = LibHTS::KString.new
        raise "Failed to format bam record" if LibHTS.sam_format1(@header.struct, @bam1, kstr) == -1

        kstr[:s]
      end

      # TODO:
      # def eql?
      # def hash
    end
  end
end
