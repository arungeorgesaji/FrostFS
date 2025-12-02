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
    attr_reader :root_path, :metadata_path, :config
    attr_reader :metadata_manager, :state_manager, :file_ops
    attr_reader :ice_crystals, :frost_patterns, :seasonal_thawing
    attr_reader :antifreeze, :glacier_storage, :freezing_algorithm

    def initialize(root_path, config = {})
      @root_path = File.expand_path(root_path)
      @metadata_path = File.join(@root_path, ".frostfs")
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

    def list_files(state_filter = nil)
      state_filter ? @metadata_manager.files_by_state(state_filter) :
                     @metadata_manager.all_files
    end

    def total_file_count
      @metadata_manager.all_files.size
    end

    def fragmentation_level(path)
      @ice_crystals.calculate_fragmentation(path)
    end

    def fragmentation_penalty(path)
      @ice_crystals.fragmentation_penalty(path)
    end

    def should_defragment?(path)
      @ice_crystals.should_defragment?(path)
    end

    def defragment_file(path)
      @ice_crystals.defragment_file(path)
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

    def antifreeze_strength(path)
      @antifreeze.antifreeze_strength(path)
    end

    def has_antifreeze?(path)
      @antifreeze.has_antifreeze_properties?(path)
    end

    def send_to_glacier(path)
      @glacier_storage.send_to_glacier(path)
    end

    def restore_from_glacier(path)
      @glacier_storage.restore_from_glacier(path)
    end

    def glacier_recovery_cost(path)
      @glacier_storage.glacier_recovery_cost(path)
    end

    def set_freezing_algorithm(name)
      @freezing_algorithm = select_freezing_algorithm(name)
    end

    def batch_thaw(pattern = "**/*")
      thawed = []
      failed = []

      Dir.glob(File.join(@root_path, pattern)).each do |full|
        next if File.directory?(full)
        next if full.start_with?(@metadata_path)

        relative = full[@root_path.length + 1..]

        if file_state(relative) == :deep_frozen
          result = thaw_file(relative)
          result[:success] ? thawed << relative : failed << relative
        end
      end

      { thawed: thawed, failed: failed }
    end

    def seasonal_maintenance
      thaw_result = @seasonal_thawing.seasonal_thaw

      defragged = @metadata_manager.all_files.count do |f|
        if @ice_crystals.should_defragment?(f)
          @ice_crystals.defragment_file(f)
          true
        else
          false
        end
      end

      archived = @metadata_manager.files_by_state(:deep_frozen).count do |f|
        rand < 0.1 && @glacier_storage.send_to_glacier(f)
      end

      {
        season: thaw_result[:season],
        thawed: thaw_result[:thawed],
        defragmented: defragged,
        archived: archived
      }
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
      @glacier_storage = GlacierStorage.new(self, File.join(@root_path, ".glacier"))
      @freezing_algorithm = select_freezing_algorithm(@config.algorithm || "standard")
    end

    def select_freezing_algorithm(name)
      case name.to_s
      when "intelligent" then FreezingAlgorithms::IntelligentFreezer.new(@config)
      when "predictive"  then FreezingAlgorithms::PredictiveFreezer.new(@config)
      else                   FreezingAlgorithms::StandardFreezer.new(@config)
      end
    end
  end
end
