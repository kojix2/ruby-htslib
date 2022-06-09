# frozen_string_literal: true

require "json"
require "awesome_print"
require "active_support/core_ext/string/inflections"

str = ARGF.read
json = JSON.parse(str)

json.each do |item|
  name = item["name"]
  next if item["fields"].nil?

  next if item["tag"] != "struct"
  next if item["bit-size"] == 0

  str = item["fields"].map do |f|
    n = f["name"]
    "    :#{n}, " + " " * (20 - n.size) + (f["type"]["tag"]).to_s
  end.join("\n")

  puts <<~EOS
    class #{name.camelize} < FFI::Struct
      layout \\
    #{str}
    end

  EOS
end
