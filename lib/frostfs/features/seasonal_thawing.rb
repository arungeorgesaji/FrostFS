module FrostFS
  class SeasonalThawing
    SEASONS = {
      spring: { thaw_rate: 0.8, target_state: :active },    
      summer: { thaw_rate: 0.5, target_state: :chilled },     
      autumn: { thaw_rate: 0.2, target_state: :frozen },    
      winter: { thaw_rate: 0.0, target_state: :deep_frozen } 
    }

    def initialize(filesystem)
      @fs = filesystem
    end

    def current_season
      month = Time.now.month
      case month
      when 3..5 then :spring
      when 6..8 then :summer
      when 9..11 then :autumn
      else :winter
      end
    end

    def seasonal_thaw
      season = current_season
      config = SEASONS[season]
      
      puts "Seasonal Thawing: #{season.capitalize}"
      puts "   Thaw rate: #{config[:thaw_rate] * 100}%"
      puts "   Target state: #{config[:target_state]}"
      
      files_to_thaw = @fs.metadata_manager.files_by_state(:deep_frozen)
      thaw_count = (files_to_thaw.size * config[:thaw_rate]).floor
      
      thawed = files_to_thaw.sample(thaw_count).map do |file_path|
        if @fs.thaw_file(file_path)[:success]
          if config[:target_state] != :active
            @fs.state_manager.force_state(file_path, config[:target_state], 'seasonal_thaw')
          end
          file_path
        end
      end.compact
      
      {
        season: season,
        attempted: thaw_count,
        thawed: thawed.size,
        files: thawed
      }
    end

    def should_thaw_file?(file_path, season)
      return false unless @fs.file_state(file_path) == :deep_frozen
      
      metadata = @fs.metadata_manager.get(file_path)
      rand < SEASONS[season][:thaw_rate] * (1 + metadata.thaw_count * 0.1)
    end
  end
end
