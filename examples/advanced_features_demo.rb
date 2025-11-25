#!/usr/bin/env ruby

$:.unshift(File.expand_path(File.dirname(__FILE__) + '/../lib'))

require 'frostfs'

puts "=== FROSTFS ADVANCED FEATURES DEMO ==="
puts

test_dir = "./frostfs_demo_#{Time.now.to_i}"
fs = FrostFS::Filesystem.new(test_dir, {
  chill_time: 3,        
  freeze_time: 6,       
  deep_freeze_time: 10, 
  algorithm: 'intelligent'
})

puts "1. ICE CRYSTALS - File Fragmentation Over Time"
puts "=" * 50

fs.write_file("fragment_me.txt", "This file will get fragmented over time")
fs.write_file("stable_file.txt", "This file stays active")

fs.state_manager.force_state("fragment_me.txt", :frozen, 'demo')

frag1 = fs.ice_crystals.calculate_fragmentation("fragment_me.txt")
frag2 = fs.ice_crystals.calculate_fragmentation("stable_file.txt")

puts "Fragmentation Levels:"
puts "   fragment_me.txt: #{frag1}% (frozen → high fragmentation)"
puts "   stable_file.txt: #{frag2}% (active → low fragmentation)"
puts "   Fragmentation penalty: #{fs.ice_crystals.fragmentation_penalty("fragment_me.txt").round(3)}s"

if fs.ice_crystals.should_defragment?("fragment_me.txt")
  result = fs.ice_crystals.defragment_file("fragment_me.txt")
  puts "Defragmented: #{result[:before]}% → #{result[:after]}%"
end

puts
puts "2. FROST PATTERNS - Visual File States"
puts "=" * 50

fs.write_file("active_file.txt", "I'm active!")
fs.state_manager.force_state("active_file.txt", :active, 'demo')

fs.write_file("chilled_file.log", "I'm chilled")
fs.state_manager.force_state("chilled_file.log", :chilled, 'demo')

fs.write_file("frozen_data.dat", "I'm frozen")
fs.state_manager.force_state("frozen_data.dat", :frozen, 'demo')

fs.write_file("deep_frozen.archive", "I'm deep frozen")
fs.state_manager.force_state("deep_frozen.archive", :deep_frozen, 'demo')

puts "File Tree with Frost Patterns:"
FrostFS::FrostPatterns.visualize_file_tree(fs)

puts
puts "Thermal Imaging - Heat Map:"
heat_map = fs.thermal_imaging
heat_map.each do |file, data|
  puts "   #{file}: #{data[:score]}/100 heat (#{data[:state]}, #{data[:accesses]} accesses)"
end

puts
puts "3. SEASONAL THAWING - Automatic Cycles"
puts "=" * 50

5.times do |i|
  fs.write_file("frozen_#{i}.txt", "Frozen file #{i}")
  fs.state_manager.force_state("frozen_#{i}.txt", :deep_frozen, 'demo')
end

puts "Current season: #{fs.seasonal_thawing.current_season}"
puts "Deep frozen files before: #{fs.metadata_manager.files_by_state(:deep_frozen).size}"

thaw_result = fs.seasonal_thawing.seasonal_thaw
puts "Seasonal thaw result:"
puts "   Attempted: #{thaw_result[:attempted]}"
puts "   Thawed: #{thaw_result[:thawed]}"
puts "   Files: #{thaw_result[:files].join(', ')}" if thaw_result[:files].any?

puts "Deep frozen files after: #{fs.metadata_manager.files_by_state(:deep_frozen).size}"

puts
puts "4. FREEZING ALGORITHMS - Intelligent Freezing"
puts "=" * 50

filesystems = {
  'Standard' => FrostFS::Filesystem.new("./test_standard", algorithm: 'standard'),
  'Intelligent' => FrostFS::Filesystem.new("./test_intelligent", algorithm: 'intelligent'),
  'Predictive' => FrostFS::Filesystem.new("./test_predictive", algorithm: 'predictive')
}

filesystems.each do |name, alg_fs|
  alg_fs.write_file("frequent.txt", "Frequently accessed")
  alg_fs.write_file("rare.txt", "Rarely accessed")
  
  5.times { alg_fs.read_file("frequent.txt") }
  
  alg_fs.state_manager.force_state("frequent.txt", :chilled, 'test')
  alg_fs.state_manager.force_state("rare.txt", :chilled, 'test')
  
  freq_state = alg_fs.file_state("frequent.txt")
  rare_state = alg_fs.file_state("rare.txt")
  
  puts "#{name} Algorithm:"
  puts "   frequent.txt: #{freq_state} (resists freezing)"
  puts "   rare.txt: #{rare_state} (freezes normally)"
  
  FileUtils.rm_rf(alg_fs.root_path)
end

puts
puts "5. ANTIFREEZE - Files That Resist Freezing"
puts "=" * 50

antifreeze_files = {
  'temp_log.log' => "Temporary log data",
  'cache_file.cache' => "Cache data",
  'session_data.tmp' => "Session information",
  'normal_file.txt' => "Regular file"
}

antifreeze_files.each do |filename, content|
  fs.write_file(filename, content)
  fs.state_manager.force_state(filename, :chilled, 'demo')
  
  strength = fs.antifreeze.antifreeze_strength(filename)
  has_antifreeze = fs.antifreeze.has_antifreeze_properties?(filename)
  
  puts "#{filename}:"
  puts "   Antifreeze: #{has_antifreeze ? 'YES' : 'NO'}"
  puts "   Strength: #{strength}%"
  puts "   Effective age reduction: #{(strength / 2.0).round(1)}%"
end

puts
puts "6. GLACIER STORAGE - Deep Archival"
puts "=" * 50

large_content = "X" * 1024  
fs.write_file("large_data.dat", large_content)
fs.state_manager.force_state("large_data.dat", :deep_frozen, 'demo')

puts "Before glacier storage:"
puts "   File exists: #{fs.file_exists?('large_data.dat')}"
puts "   File state: #{fs.file_state('large_data.dat')}"

glacier_result = fs.glacier_storage.send_to_glacier("large_data.dat")
if glacier_result[:success]
  puts "Sent to glacier storage:"
  puts "   Compression: #{(glacier_result[:compression_ratio] * 100).round(1)}%"
  puts "   Original: #{glacier_result[:original_size]} bytes"
  puts "   Archived: #{glacier_result[:archived_size]} bytes"
  puts "   Recovery cost: $#{fs.glacier_storage.glacier_recovery_cost('large_data.dat').round(4)}"
end

puts "After glacier storage:"
puts "   File exists: #{fs.file_exists?('large_data.dat')}"
puts "   File state: #{fs.file_info('large_data.dat')[:state] rescue 'missing'}"

restore_result = fs.glacier_storage.restore_from_glacier("large_data.dat")
if restore_result[:success]
  puts "Restored from glacier:"
  puts "   Restoration time: #{restore_result[:restoration_time]}"
  puts "   File state now: #{fs.file_state('large_data.dat')}"
end

puts
puts "7. COMPREHENSIVE MAINTENANCE DEMO"
puts "=" * 50

puts "Performing full seasonal maintenance..."
maintenance_result = fs.seasonal_maintenance

puts "Maintenance Results:"
puts "   Season: #{maintenance_result[:season]}"
puts "   Files thawed: #{maintenance_result[:thawed]}"
puts "   Files defragmented: #{maintenance_result[:defragmented]}"
puts "   Files archived to glacier: #{maintenance_result[:archived]}"

puts
puts "Final Statistics:"
stats = fs.state_stats
total_files = stats.values.sum
puts "Total files: #{total_files}"
stats.each do |state, count|
  percentage = (count.to_f / total_files * 100).round(1)
  pattern = FrostFS::FrostPatterns.pattern_for_state(state)
  puts "   #{pattern} #{state}: #{count} files (#{percentage}%)"
end

puts
puts "DEMO COMPLETE!"
puts "Cleanup..."
FileUtils.rm_rf(test_dir)

puts
puts "FROSTFS FEATURES SUMMARY:"
puts "Ice Crystals - Files fragment when frozen, affecting performance"
puts "Frost Patterns - Visual indicators of file states"
puts "Seasonal Thawing - Automatic thawing based on seasons"
puts "Freezing Algorithms - Smart freezing based on usage patterns"
puts "Antifreeze - Certain files resist freezing naturally"
puts "Glacier Storage - Deep archival with cost-based recovery"
puts "Thermal Imaging - Heat maps showing file activity"
puts "Enhanced CLI - Full command-line interface"
