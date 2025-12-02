module FrostFS
  class FileMetadata
    attr_reader :file_path, :created_at, :last_accessed, :last_modified,
                :access_count, :thaw_count, :state_history, :current_state

    def initialize(file_path)
      @file_path = file_path
      @created_at = Time.now.to_i
      @last_accessed = @created_at
      @last_modified = @created_at
      @access_count = 0
      @thaw_count = 0
      @state_history = []
      @current_state = :active
      
      record_state_change(:active, 'initial')
    end

    def record_access
      @last_accessed = Time.now.to_i
      @access_count += 1
    end

    def record_modification
      @last_modified = Time.now.to_i
      record_access
    end

    def record_thaw
      @thaw_count += 1
      @last_accessed = Time.now.to_i
    end

    def update_state(new_state, reason = 'automatic')
      return if @current_state == new_state
      
      old_state = @current_state
      @current_state = new_state
      record_state_change(new_state, reason)
      
      { old_state: old_state, new_state: new_state, reason: reason }
    end

    def to_h
      {
        file_path: @file_path,
        created_at: @created_at,
        last_accessed: @last_accessed,
        last_modified: @last_modified,
        access_count: @access_count,
        thaw_count: @thaw_count,
        current_state: @current_state,
        state_history: @state_history
      }
    end

    def self.from_h(file_path, hash)
      metadata = new(file_path)  
      metadata.instance_variable_set(:@created_at, hash['created_at'])
      metadata.instance_variable_set(:@last_accessed, hash['last_accessed'])
      metadata.instance_variable_set(:@last_modified, hash['last_modified'])
      metadata.instance_variable_set(:@access_count, hash['access_count'])
      metadata.instance_variable_set(:@thaw_count, hash['thaw_count'])
      metadata.instance_variable_set(:@current_state, hash['current_state'].to_sym)
      metadata.instance_variable_set(:@state_history, hash['state_history'])
      metadata
    end

    private

    def record_state_change(state, reason)
      @state_history << {
        state: state,
        timestamp: Time.now.to_i,
        reason: reason
      }
      
      @state_history = @state_history.last(100)
    end
  end
end
