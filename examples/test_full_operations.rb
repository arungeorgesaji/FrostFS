$:.unshift(File.expand_path(File.dirname(__FILE__) + '/../lib'))

require 'frostfs'

puts "=== Testing Full FrostFS Operations ==="

test_dir = "./test_full_#{Time.now.to_i}"

begin
  fs = FrostFS::Filesystem.new(test_dir, {
    chill_time: 2,      
    freeze_time: 5,       
    deep_freeze_time: 10, 
    access_delay: {
      active: 0.0,
      chilled: 0.1,
      frozen: 0.2,
      deep_frozen: 0.3
    }
  })

  puts "FrostFS initialized"

  result = fs.write_file("test.txt", "Hello FrostFS!")
  puts "File written: #{result[:path]} (state: #{result[:state]})"

  result = fs.read_file("test.txt")
  puts "File read: '#{result[:content]}' (state: #{result[:state]}, delay: #{result[:access_delay]}s)"

  info = fs.file_info("test.txt")
  puts "File info: state=#{info[:state]}, accesses=#{info[:access_count]}"

  puts "Waiting for file to chill..."
  sleep(3)
  
  fs.update_all_states
  state = fs.file_state("test.txt")
  puts "File state after 3s: #{state}"

  result = fs.read_file("test.txt")
  puts "Read chilled file (delay: #{result[:access_delay]}s)"

  fs.state_manager.force_state("test.txt", :frozen, 'testing')
  puts "Forced file to frozen state"

  result = fs.read_file("test.txt")
  puts "Read frozen file (delay: #{result[:access_delay]}s)"

  fs.state_manager.force_state("test.txt", :deep_frozen, 'testing')
  puts " Forced file to deep frozen"

  result = fs.read_file("test.txt")
  if result[:error] == :requires_thaw
    puts "Deep frozen file requires thaw (as expected)"
  end

  fs.thaw_file("test.txt")
  result = fs.read_file_with_thaw("test.txt")
  puts "Thawed and read file: '#{result[:content]}'"

  stats = fs.state_stats
  puts "State statistics: #{stats}"

  fs.delete_file("test.txt")
  FileUtils.rm_rf(test_dir)
  puts "Cleanup completed"

rescue => e
  puts "Error: #{e.message}"
  puts e.backtrace
  FileUtils.rm_rf(test_dir) if File.directory?(test_dir)
end
