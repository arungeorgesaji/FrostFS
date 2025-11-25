require "zlib"
require "fileutils"

module FrostFS
  class GlacierStorage
    def initialize(filesystem, archive_root)
      @fs = filesystem
      @archive_root = archive_root
      FileUtils.mkdir_p(@archive_root)
    end

    def send_to_glacier(file_path)
      return { error: :not_deep_frozen } unless @fs.file_state(file_path) == :deep_frozen

      full_path = File.join(@fs.root_path, file_path)
      return { error: :file_not_found } unless File.exist?(full_path)

      archive_path = File.join(@archive_root, "#{file_path}.gz")
      FileUtils.mkdir_p(File.dirname(archive_path))

      original_size = File.size(full_path)

      Zlib::GzipWriter.open(archive_path) do |gz|
        File.open(full_path, "rb") do |f|
          gz.write(f.read)
        end
      end

      archived_size = File.size(archive_path)

      File.delete(full_path)

      metadata = @fs.metadata_manager.get(file_path)
      metadata.update_state(:glacier, "archived")

      {
        success: true,
        original_size: original_size,
        archived_size: archived_size,
        compression_ratio: (archived_size.to_f / original_size).round(3),
        archive_path: archive_path
      }
    end

    def restore_from_glacier(file_path)
      archive_path = File.join(@archive_root, "#{file_path}.gz")
      return { error: :not_in_glacier } unless File.exist?(archive_path)

      full_path = File.join(@fs.root_path, file_path)
      FileUtils.mkdir_p(File.dirname(full_path))

      Zlib::GzipReader.open(archive_path) do |gz|
        File.write(full_path, gz.read, mode: "wb")
      end

      metadata = @fs.metadata_manager.get(file_path)
      metadata.record_access
      metadata.update_state(:active, "restored_from_glacier")

      File.delete(archive_path)

      {
        success: true,
        restored_size: File.size(full_path),
        restoration_time: Time.now
      }
    end

    def glacier_recovery_cost(file_path)
      archive_path = File.join(@archive_root, "#{file_path}.gz")
      return 0 unless File.exist?(archive_path)

      size = File.size(archive_path)
      (size / (1024.0**3)) * 0.01 + 0.03
    end
  end
end
