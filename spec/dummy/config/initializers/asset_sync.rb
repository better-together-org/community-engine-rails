# frozen_string_literal: true

if defined?(AssetSync)
  AssetSync.configure do |config|
    config.fog_provider = 'AWS'

    config.aws_access_key_id = ENV['AWS_ACCESS_KEY_ID']
    config.aws_secret_access_key = ENV['AWS_SECRET_ACCESS_KEY']

    config.aws_session_token = ENV['AWS_SESSION_TOKEN'] if ENV.key?('AWS_SESSION_TOKEN')

    # Ensure that aws_iam_roles is set to false if not explicitly required
    config.aws_iam_roles = ENV['AWS_IAM_ROLES'] == 'true'

    config.fog_directory = ENV['FOG_DIRECTORY']
    config.fog_region = ENV['FOG_REGION']

    # Additional configurations (commented out by default)
    # config.aws_reduced_redundancy = true
    # config.aws_signature_version = 4
    # config.aws_acl = nil
    # config.fog_host = "s3.amazonaws.com"
    # config.fog_port = "9000"
    config.fog_scheme = 'https'
    # config.cdn_distribution_id = ENV['CDN_DISTRIBUTION_ID'] if ENV.key?('CDN_DISTRIBUTION_ID')
    # config.invalidate = ['file1.js']
    # config.existing_remote_files = "keep"
    # config.gzip_compression = true
    # config.manifest = true
    # config.include_manifest = false
    # config.remote_file_list_cache_file_path = './.asset_sync_remote_file_list_cache.json'
    # config.remote_file_list_remote_path = '/remote/asset_sync_remote_file.json'
    # config.fail_silently = true
    config.log_silently = true
    config.concurrent_uploads = true
  end
end
