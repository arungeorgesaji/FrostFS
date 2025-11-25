module FrostFS
  class StateManager
    STATES = {
      active: 0,
      chilled: 1, 
      frozen: 2,
      deep_frozen: 3
    }.freeze

    attr_reader :config

    def initialize(config, metadata_manager)
      @config = config
      @metadata_manager = metadata_manager
    end

    def calculate_state(file_path)
      metadata = @metadata_manager.get(file_path)
      now = Time.now.to_i
      time_since_access = now - metadata.last_accessed

      if time_since_access >= config.deep_freeze_time
        :deep_frozen
      elsif time_since_access >= config.freeze_time
        :frozen
      elsif time_since_access >= config.chill_time
        :chilled
      else
        :active
      end
    end

    def update_state(file_path, reason = 'automatic')
      metadata = @metadata_manager.get(file_path)
      new_state = calculate_state(file_path)
      
      transition = metadata.update_state(new_state, reason)
      
      @metadata_manager.save if @config.metadata_auto_save
      
      transition
    end

    def current_state(file_path)
      metadata = @metadata_manager.get(file_path)
      metadata.current_state
    end

    def access_delay(file_path)
      state = current_state(file_path)
      @config.access_delay[state] || 0.0
    end

    def force_state(file_path, target_state, reason = 'manual')
      metadata = @metadata_manager.get(file_path)
      now = Time.now.to_i
      
      case target_state
      when :active
        metadata.record_access
      when :chilled
        metadata.instance_variable_set(:@last_accessed, now - @config.chill_time - 3600)
      when :frozen
        metadata.instance_variable_set(:@last_accessed, now - @config.freeze_time - 3600)
      when :deep_frozen
        metadata.instance_variable_set(:@last_accessed, now - @config.deep_freeze_time - 3600)
      else
        raise "Unknown state: #{target_state}"
      end
      
      transition = metadata.update_state(target_state, reason)
      @metadata_manager.save if @config.metadata_auto_save
      
      transition
    end

    def requires_thaw?(file_path)
      current_state(file_path) == :deep_frozen
    end

    def thaw_file(file_path)
      metadata = @metadata_manager.get(file_path)
      
      if metadata.current_state == :deep_frozen
        metadata.record_thaw
        metadata.update_state(:active, 'thawed')
        @metadata_manager.save if @config.metadata_auto_save
        true
      else
        false
      end
    end

    def update_all_states
      transitions = {}
      
      @metadata_manager.all_files.each do |file_path|
        transition = update_state(file_path, 'batch_update')
        transitions[file_path] = transition if transition
      end
      
      transitions
    end

    def state_statistics
      stats = Hash.new(0)
      
      @metadata_manager.all_files.each do |file_path|
        state = current_state(file_path)
        stats[state] += 1
      end
      
      stats
    end
  end
end
