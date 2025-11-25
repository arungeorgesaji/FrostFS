module FrostFS
  class FrostConfig
    DEFAULT_CONFIG = {
      chill_time: 7 * 24 * 3600,      
      freeze_time: 30 * 24 * 3600,      
      deep_freeze_time: 90 * 24 * 3600, 
      access_delay: {
        active: 0.0,
        chilled: 0.1,     
        frozen: 1.0,      
        deep_frozen: 5.0  
      },
      metadata_auto_save: true,
      max_thaw_count: 1000
    }.freeze

    attr_accessor :chill_time, :freeze_time, :deep_freeze_time, 
                  :access_delay, :metadata_auto_save, :max_thaw_count

    def initialize(config = {})
      full_config = DEFAULT_CONFIG.merge(config)
      
      @chill_time = full_config[:chill_time]
      @freeze_time = full_config[:freeze_time]
      @deep_freeze_time = full_config[:deep_freeze_time]
      @access_delay = full_config[:access_delay]
      @metadata_auto_save = full_config[:metadata_auto_save]
      @max_thaw_count = full_config[:max_thaw_count]
    end

    def to_h
      {
        chill_time: @chill_time,
        freeze_time: @freeze_time,
        deep_freeze_time: @deep_freeze_time,
        access_delay: @access_delay,
        metadata_auto_save: @metadata_auto_save,
        max_thaw_count: @max_thaw_count
      }
    end
  end
end
