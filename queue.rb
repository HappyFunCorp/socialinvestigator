$stdout.sync = true

require_relative 'lib/config'
require_relative 'lib/models'

puts "Loading stop words"
File.open( "english.stop.txt" ).each_line do |word|
  REDIS.sadd "stopwords", word.gsub( /\s*/, "" )
  # puts word
end
puts "Done"

puts "Watching queues: #{Task.queues}"

Task.process_queues
