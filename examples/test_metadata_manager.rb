$:.unshift(File.expand_path(File.dirname(__FILE__) + '/../lib'))

require 'frostfs'

puts "=== Testing Metadata Manager ==="

test_dir = "./test_metadata_#{Time.now.to_i}"

begin
  fs = FrostFS::Filesystem.new(test_dir)
  metadata_manager = fs.metadata_manager

  metadata1 = metadata_manager.get("test_file.txt")
  puts "Created metadata for test_file.txt"
  puts "  State: #{metadata1.current_state}"
  puts "  Access count: #{metadata1.access_count}"

  metadata1.record_access
  metadata_manager.update("test_file.txt", metadata1)
  puts "Recorded access - count: #{metadata1.access_count}"

  metadata_manager.save
  puts "Metadata saved to disk"

  fs2 = FrostFS::Filesystem.new(test_dir)
  loaded_metadata = fs2.metadata_manager.get("test_file.txt")
  puts "Metadata loaded from disk"
  puts "  Access count: #{loaded_metadata.access_count}"

  FileUtils.rm_rf(test_dir) if File.directory?(test_dir)
  puts "Test directory cleaned up"

rescue => e
  puts "Error: #{e.message}"
  puts e.backtrace
  FileUtils.rm_rf(test_dir) if File.directory?(test_dir)
end
