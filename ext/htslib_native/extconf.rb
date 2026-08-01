# frozen_string_literal: true

require "mkmf"

htslib_dir = with_config("htslib-dir", ENV["HTSLIBDIR"])
if htslib_dir
  include_dir = File.directory?(File.join(htslib_dir, "include")) ? File.join(htslib_dir, "include") : htslib_dir
  library_dir = if File.directory?(File.join(htslib_dir, "lib"))
                  File.join(htslib_dir, "lib")
                else
                  htslib_dir
                end
  dir_config("htslib", include_dir, library_dir)
end

pkg_config("htslib") unless htslib_dir

abort "HTSlib headers were not found. Install the HTSlib development package or set --with-htslib-dir." unless \
  have_header("htslib/hts.h") && have_header("htslib/sam.h") &&
  have_header("htslib/vcf.h") && have_header("htslib/faidx.h") && have_header("htslib/tbx.h")

abort "HTSlib library was not found. Install HTSlib or set --with-htslib-dir." unless \
  have_library("hts", "hts_version")

required_functions = {
  "sam_read1" => "htslib/sam.h",
  "bam_plp_init" => "htslib/sam.h",
  "bam_mplp64_auto" => "htslib/sam.h",
  "bam_mplp_init_overlaps" => "htslib/sam.h",
  "hts_base_mod_state_alloc" => "htslib/sam.h",
  "bcf_read" => "htslib/vcf.h",
  "bcf_hdr_set" => "htslib/vcf.h",
  "fai_load3_format" => "htslib/faidx.h",
  "tbx_index_load3" => "htslib/tbx.h"
}
missing_functions = required_functions.reject { |function, header| have_func(function, header) }.keys
unless missing_functions.empty?
  abort "HTSlib is missing required functions: #{missing_functions.join(', ')}. Install a supported HTSlib development package."
end

create_makefile("htslib_native_ext")
