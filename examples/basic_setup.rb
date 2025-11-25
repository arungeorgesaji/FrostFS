$:.unshift(File.expand_path(File.dirname(__FILE__) + '/../lib'))

require 'frostfs'

puts "=== FrostFS Basic Setup Test ==="

test_dir = "./test_storage_#{Time.now.to_i}"

begin
  fs = FrostFS::Filesystem.new(test_dir, {
    chill_time: 60,  
    freeze_time: 120 
  })

  puts "FrostFS initialized successfully!"
  puts "  Root path: #{fs.root_path}"
  puts "  Metadata path: #{fs.metadata_path}"
  puts "  Config:"
  fs.config.to_h.each do |key, value|
    puts "    #{key}: #{value}"
  end
  
  if File.directory?(fs.metadata_path)
    puts "Metadata directory created successfully"
  else
    puts "Metadata directory creation failed"
  end

rescue => e
  puts "Error: #{e.message}"
  puts e.backtrace
end
