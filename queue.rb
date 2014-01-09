$stdout.sync = true

require_relative 'lib/config'
require_relative 'lib/models'

puts "Watching queues: #{Task.queues}"

Task.process_queues
