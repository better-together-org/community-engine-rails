# frozen_string_literal: true

# lib/tasks/community_engine_js.rake
#
# Manages the @better-together/community-engine-js UMD artifact that is
# vendored in vendor/javascript/community-engine.umd.js and pinned in
# config/importmap.rb.
#
# Usage:
#   rake ce_js:install              — install version from config/community_engine_js_version
#   rake ce_js:install[0.2.0]       — install a specific version
#   rake ce_js:update[0.2.0]        — install + update config/community_engine_js_version
#
# Auth:
#   Set FORGEJO_NPM_TOKEN to a Forgejo personal access token with package:read
#   scope when fetching from a private registry. Omit for public packages.
#
# The task fetches the npm tarball from the Forgejo package registry, extracts
# dist/community-engine.umd.js, and writes it to vendor/javascript/.

require 'net/http'
require 'json'
require 'zlib'
require 'rubygems/package'
require 'uri'

namespace :ce_js do
  PACKAGE_NAME  = '@better-together/community-engine-js'
  REGISTRY_BASE = 'https://git.btsdev.ca/api/packages/better-together/npm'
  UMD_TAR_PATH  = 'package/dist/community-engine.umd.js'
  VENDOR_DEST   = 'vendor/javascript/community-engine.umd.js'
  VERSION_FILE  = 'config/community_engine_js_version'

  desc <<~DESC
    Install @better-together/community-engine-js UMD artifact into vendor/javascript/.
    Version arg is optional; defaults to config/community_engine_js_version.
    Set FORGEJO_NPM_TOKEN env var for authenticated registry access.
  DESC
  task :install, [:version] do |_, args|
    version = ce_js_resolve_version(args[:version])
    rails_root = ce_js_rails_root

    puts "  Installing @better-together/community-engine-js@#{version} …"

    tarball_url = ce_js_fetch_tarball_url(version)
    puts "  Tarball: #{tarball_url}"

    umd_content = ce_js_extract_umd(tarball_url)
    dest = File.join(rails_root, VENDOR_DEST)
    File.write(dest, umd_content)

    puts "  ✓ Written #{umd_content.bytesize} bytes → #{VENDOR_DEST}"
  end

  desc 'Update @better-together/community-engine-js to VERSION and record in config/community_engine_js_version.'
  task :update, [:version] do |_, args|
    raise ArgumentError, 'Version required. Usage: rake ce_js:update[0.2.0]' unless args[:version]&.match?(/\A\d+\.\d+\.\d+/)

    version = args[:version]
    Rake::Task['ce_js:install'].invoke(version)

    version_file = File.join(ce_js_rails_root, VERSION_FILE)
    File.write(version_file, "#{version}\n")
    puts "  ✓ #{VERSION_FILE} → #{version}"
  end

  desc 'Print the currently installed community-engine-js version.'
  task :version do
    version_file = File.join(ce_js_rails_root, VERSION_FILE)
    if File.exist?(version_file)
      puts File.read(version_file).strip
    else
      puts '(unknown — config/community_engine_js_version not found)'
    end
  end

  # ── Helpers (module_function so they're callable from task blocks) ──────────

  module_function

  def ce_js_rails_root
    # Rake.original_dir is the directory rake was invoked from (typically the
    # Rails root). This works both in the gem itself and in host apps.
    Rake.original_dir
  end

  def ce_js_resolve_version(arg_version)
    return arg_version.strip if arg_version&.match?(/\A\d+\.\d+\.\d+/)

    version_file = File.join(ce_js_rails_root, VERSION_FILE)
    unless File.exist?(version_file)
      raise "No version specified and #{VERSION_FILE} not found. " \
            'Run: rake ce_js:update[VERSION]'
    end

    File.read(version_file).strip
  end

  def ce_js_fetch_tarball_url(version)
    token = ENV['FORGEJO_NPM_TOKEN']
    # Forgejo npm registry uses %2F for scoped package names in the URL path
    encoded_name = PACKAGE_NAME.gsub('/', '%2F').gsub('@', '%40')
    uri = URI("#{REGISTRY_BASE}/#{encoded_name}")

    response = ce_js_http_get(uri, token)

    unless response.is_a?(Net::HTTPSuccess)
      raise "Registry metadata fetch failed (#{response.code}): #{response.body.slice(0, 200)}"
    end

    metadata = JSON.parse(response.body)
    url = metadata.dig('versions', version, 'dist', 'tarball')

    unless url
      available = metadata['versions']&.keys&.last(5)&.join(', ')
      raise "Version #{version} not found in registry. Recent versions: #{available || 'none'}"
    end

    url
  end

  def ce_js_extract_umd(tarball_url)
    token = ENV['FORGEJO_NPM_TOKEN']
    uri = URI(tarball_url)

    response = ce_js_http_get(uri, token)
    unless response.is_a?(Net::HTTPSuccess)
      raise "Tarball download failed (#{response.code})"
    end

    gz = Zlib::GzipReader.new(StringIO.new(response.body.b))
    Gem::Package::TarReader.new(gz) do |tar|
      tar.each do |entry|
        return entry.read if entry.file? && entry.full_name == UMD_TAR_PATH
      end
    end

    raise "#{UMD_TAR_PATH} not found in tarball. " \
          "Check that the package builds dist/community-engine.umd.js."
  end

  def ce_js_http_get(uri, token = nil)
    use_ssl = uri.scheme == 'https'
    Net::HTTP.start(uri.host, uri.port, use_ssl: use_ssl,
                    read_timeout: 30, open_timeout: 10) do |http|
      req = Net::HTTP::Get.new(uri)
      req['Authorization'] = "Bearer #{token}" if token
      req['Accept']        = 'application/json'
      req['User-Agent']    = "community-engine-rails/ce_js_rake_task"
      http.request(req)
    end
  end
end
