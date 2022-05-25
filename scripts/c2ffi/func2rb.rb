require "json"

d = JSON[ARGF.read]

d.each do |h|
  next if h["tag"] != "function"
  args = h.dig('parameters').map{|pm| pm.dig('type', 'tag')}
  rt = h.dig('return-type', 'tag')
  puts <<~EOS
    attach_function \\
      :#{h['name']},
      [#{args.join(', ')}],
      #{rt}

  EOS
end