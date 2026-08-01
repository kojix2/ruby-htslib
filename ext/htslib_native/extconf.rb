# frozen_string_literal: true

require "mkmf"

unless pkg_config("htslib")
  vendored_include = File.expand_path("../../htslib", __dir__)
  $INCFLAGS << " -I#{vendored_include}" if File.exist?(File.join(vendored_include, "htslib", "sam.h"))
end

have_header("htslib/sam.h")
create_makefile("htslib_native_ext")
