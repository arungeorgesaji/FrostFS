module FrostFS
  VERSION = '0.1.0'.freeze
end

require_relative 'frostfs/models/frost_config'
require_relative 'frostfs/models/file_metadata'
require_relative 'frostfs/core/metadata_manager'
require_relative 'frostfs/core/filesystem'
