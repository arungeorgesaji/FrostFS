$:.unshift(File.expand_path(File.dirname(__FILE__) + '/../lib'))

require 'frostfs'

puts "=== Testing CLI Commands ==="

test_dir = "./test_cli_#{Time.now.to_i}"

begin
  fs = FrostFS::Filesystem.new(test_dir, {
    chill_time: 2,
    freeze_time: 4,
    deep_freeze_time: 6
  })

  fs.write_file("active.txt", "I'm active!")
  fs.write_file("chill_me.txt", "I want to be chilled")
  
  fs.state_manager.force_state("chill_me.txt", :chilled, 'test')
  
  puts "Test files created"

  batch = FrostFS::BatchOperations.new(fs)
  
  old_files = batch.find_old_files(1) 
  puts "Old files: #{old_files.size}"
  
  logger = FrostFS::FrostLogger.new
  logger.log_operation("TEST", "test.txt", state: :active)
  
  puts "All CLI components working"

  FileUtils.rm_rf(test_dir)

rescue => e
  puts "Error: #{e.message}"
  puts e.backtrace
  FileUtils.rm_rf(test_dir) if File.directory?(test_dir)
end
