require 'fileutils'
require_relative 'metadata_manager'
require_relative 'state_manager'
require_relative '../operations/file_operations'
require_relative '../features/ice_crystals'
require_relative '../features/frost_patterns'
require_relative '../features/seasonal_thawing'
require_relative '../features/freezing_algorithms'
require_relative '../features/antifreeze'
require_relative '../features/glacier_storage'

module FrostFS
  class Filesystem
    attr_reader :root_path, :metadata_path, :config, :metadata_manager, :state_manager, :file_ops, :ice_crystals, :frost_patterns, :seasonal_thawing, :antifreeze, :glacier_storage, :freezing_algorithm

    def initialize(root_path, config = {})
      @root_path = File.expand_path(root_path)
      @metadata_path = File.join(@root_path, '.frostfs')
      @config = config.is_a?(FrostConfig) ? config : FrostConfig.new(config)
      
      setup_filesystem
      initialize_core_components
      initialize_advanced_features
    end

    def write_file(path, content)
      @file_ops.write(path, content)
    end

    def read_file(path)
      @file_ops.read(path)
    end

    def read_file_with_thaw(path)
      @file_ops.read_with_thaw(path)
    end

    def delete_file(path)
      @file_ops.delete(path)
    end

    def file_info(path)
      @file_ops.info(path)
    end

    def thaw_file(path)
      @file_ops.thaw(path)
    end

    def file_exists?(path)
      @file_ops.exists?(path)
    end

    def file_state(path)
      @state_manager.current_state(path)
    end

    def state_stats
      @state_manager.state_statistics
    end

    def update_all_states
      @state_manager.update_all_states
    end

    def fragmentation_level(file_path)
      @ice_crystals.calculate_fragmentation(file_path)
    end

    def fragmentation_penalty(file_path)
      @ice_crystals.fragmentation_penalty(file_path)
    end

    def should_defragment?(file_path)
      @ice_crystals.should_defragment?(file_path)
    end

    def defragment_file(file_path)
      @ice_crystals.defragment_file(file_path)
    end

    def visualize_filesystem
      FrostPatterns.visualize_file_tree(self)
    end

    def thermal_imaging
      FrostPatterns.generate_heat_map(self)
    end

    def pattern_for_state(state)
      FrostPatterns.pattern_for_state(state)
    end

    def current_season
      @seasonal_thawing.current_season
    end

    def seasonal_thaw
      @seasonal_thawing.seasonal_thaw
    end

    def antifreeze_strength(file_path)
      @antifreeze.antifreeze_strength(file_path)
    end

    def has_antifreeze?(file_path)
      @antifreeze.has_antifreeze_properties?(file_path)
    end

    def send_to_glacier(file_path)
      @glacier_storage.send_to_glacier(file_path)
    end

    def restore_from_glacier(file_path)
      @glacier_storage.restore_from_glacier(file_path)
    end

    def glacier_recovery_cost(file_path)
      @glacier_storage.glacier_recovery_cost(file_path)
    end

    def set_freezing_algorithm(algorithm_name)
      @freezing_algorithm = select_freezing_algorithm(algorithm_name)
    end

    def seasonal_maintenance
      puts "Performing seasonal maintenance..."
      
      thaw_result = @seasonal_thawing.seasonal_thaw
      
      defrag_count = 0
      @metadata_manager.all_files.each do |file_path|
        if @ice_crystals.should_defragment?(file_path)
          @ice_crystals.defragment_file(file_path)
          defrag_count += 1
        end
      end
      
      glacier_count = 0
      @metadata_manager.files_by_state(:deep_frozen).each do |file_path|
        if rand < 0.1 
          @glacier_storage.send_to_glacier(file_path)
          glacier_count += 1
        end
      end
      
      {
        season: thaw_result[:season],
        thawed: thaw_result[:thawed],
        defragmented: defrag_count,
        archived: glacier_count
      }
    end

    def enhanced_read(file_path)
      frag_penalty = @ice_crystals.fragmentation_penalty(file_path)
      sleep(frag_penalty) if frag_penalty > 0
      
      read_file(file_path)
    end

    def batch_thaw(pattern = "**/*")
      thawed = []
      failed = []
      
      Dir.glob(File.join(@root_path, pattern)).each do |full_path|
        next if File.directory?(full_path)
        next if full_path.start_with?(@metadata_path)
        
        relative_path = full_path[@root_path.length + 1..-1]
        
        if file_state(relative_path) == :deep_frozen
          result = thaw_file(relative_path)
          if result[:success]
            thawed << relative_path
          else
            failed << relative_path
          end
        end
      end
      
      { thawed: thawed, failed: failed }
    end

    def list_files(state_filter = nil)
      if state_filter
        @metadata_manager.files_by_state(state_filter)
      else
        @metadata_manager.all_files
      end
    end

    def file_count_by_state
      state_stats
    end

    def total_file_count
      @metadata_manager.all_files.size
    end

    private

    def setup_filesystem
      FileUtils.mkdir_p(@root_path)
      FileUtils.mkdir_p(@metadata_path)
    end

    def initialize_core_components
      @metadata_manager = MetadataManager.new(@metadata_path)
      @state_manager = StateManager.new(@config, @metadata_manager)
      @file_ops = FileOperations.new(self, @state_manager, @metadata_manager)
    end

    def initialize_advanced_features
      @ice_crystals = IceCrystals.new(self)
      @frost_patterns = FrostPatterns
      @seasonal_thawing = SeasonalThawing.new(self)
      @antifreeze = Antifreeze.new(self)
      @glacier_storage = GlacierStorage.new(self, File.join(@root_path, '.glacier'))
      @freezing_algorithm = select_freezing_algorithm(@config.algorithm || 'standard')
    end

    def select_freezing_algorithm(algorithm_name)
      case algorithm_name.to_s
      when 'intelligent'
        FreezingAlgorithms::IntelligentFreezer.new(@config)
      when 'predictive'
        FreezingAlgorithms::PredictiveFreezer.new(@config)
      else
        FreezingAlgorithms::StandardFreezer.new(@config)
      end
    end
  end
end
