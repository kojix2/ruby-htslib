# frozen_string_literal: true

begin
  require "htslib_native_ext"
rescue LoadError => e
  raise LoadError, <<~MESSAGE
    #{e.message}
    ruby-htslib requires its native extension linked against HTSlib.
    Install the HTSlib development package and reinstall the gem. If HTSlib is
    in a non-standard prefix, use --with-htslib-dir or set HTSLIBDIR while
    building the gem.
  MESSAGE
end
