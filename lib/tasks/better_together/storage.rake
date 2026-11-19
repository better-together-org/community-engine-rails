# frozen_string_literal: true

namespace :better_together do
  namespace :storage do
    desc 'Export a platform\'s own blobs: PLATFORM=<slug|id> DIR=<path>'
    task export_platform: :environment do
      platform = BetterTogether::Platform.friendly.find(ENV.fetch('PLATFORM'))
      config = platform.active_storage_configuration or abort('Platform has no storage configuration')
      result = BetterTogether::Storage::PlatformBlobs.new(config).export(ENV.fetch('DIR'))
      puts "exported #{result.blob_count} blobs (#{result.bytes} bytes), skipped #{result.skipped.size}"
    end

    desc 'Remove a platform\'s own blobs from its storage: PLATFORM=<slug|id> [APPLY=1]. Dry run by default'
    task purge_platform: :environment do
      platform = BetterTogether::Platform.friendly.find(ENV.fetch('PLATFORM'))
      config = platform.active_storage_configuration or abort('Platform has no storage configuration')
      abort('Refusing to purge the host platform') if platform.host?
      result = BetterTogether::Storage::PlatformBlobs.new(config).purge!(apply: ENV['APPLY'] == '1')
      puts "#{ENV['APPLY'] == '1' ? 'purged' : 'would purge'} #{result.blob_count} blobs (#{result.bytes} bytes)"
    end
  end
end
