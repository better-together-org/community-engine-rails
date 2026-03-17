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
require 'openssl'
require 'base64'
require 'stringio'

# ── Helpers ────────────────────────────────────────────────────────────────────
# Top-level private methods so they are callable from within Rake task blocks.

def ce_js_rails_root
  # Rake.original_dir is the directory rake was invoked from (typically the
  # Rails root). This works both in the gem itself and in host apps.
  Rake.original_dir
end

def ce_js_resolve_version(arg_version)
  return arg_version.strip if arg_version&.match?(/\A\d+\.\d+\.\d+/)

  version_file = File.join(ce_js_rails_root, CE_JS_VERSION_FILE)
  unless File.exist?(version_file)
    raise "No version specified and #{CE_JS_VERSION_FILE} not found. " \
          'Run: rake ce_js:update[VERSION]'
  end

  File.read(version_file).strip
end

def ce_js_tarball_url_from_metadata(metadata, version)
  url = metadata.dig('versions', version, 'dist', 'tarball')
  return url if url

  known = metadata['versions']&.keys || []
  available = known.last(5).join(', ')
  raise "Version #{version} not found in registry. Recent versions: #{available.empty? ? 'none' : available}"
end

def ce_js_fetch_tarball_url(version)
  token = ENV.fetch('FORGEJO_NPM_TOKEN', nil)
  encoded_name = CE_JS_PACKAGE_NAME.gsub('/', '%2F').gsub('@', '%40')
  uri = URI("#{CE_JS_REGISTRY_BASE}/#{encoded_name}")
  response = ce_js_http_get(uri, token)
  unless response.is_a?(Net::HTTPSuccess)
    raise "Registry metadata fetch failed (#{response.code}): #{response.body.slice(0, 200)}"
  end

  ce_js_tarball_url_from_metadata(JSON.parse(response.body), version)
end

def ce_js_read_umd_from_tar(response)
  gz = Zlib::GzipReader.new(StringIO.new(response.body.b))
  Gem::Package::TarReader.new(gz) do |tar|
    tar.each do |entry|
      return entry.read if entry.file? && entry.full_name == CE_JS_UMD_TAR_PATH
    end
  end
  nil
end

def ce_js_extract_umd(tarball_url)
  token = ENV.fetch('FORGEJO_NPM_TOKEN', nil)
  response = ce_js_http_get(URI(tarball_url), token)
  raise "Tarball download failed (#{response.code})" unless response.is_a?(Net::HTTPSuccess)

  ce_js_read_umd_from_tar(response) ||
    raise("#{CE_JS_UMD_TAR_PATH} not found in tarball. " \
          'Check that the package builds dist/community-engine.umd.js.')
end

def ce_js_http_get(uri, token = nil)
  use_ssl = uri.scheme == 'https'
  Net::HTTP.start(uri.host, uri.port, use_ssl: use_ssl,
                                      read_timeout: 30, open_timeout: 10) do |http|
    req = Net::HTTP::Get.new(uri)
    req['Authorization'] = "Bearer #{token}" if token
    req['Accept']        = 'application/json'
    req['User-Agent']    = 'community-engine-rails/ce_js_rake_task'
    http.request(req)
  end
end

def ce_js_write_sri(umd_content, rails_root)
  sri = "sha384-#{Base64.strict_encode64(OpenSSL::Digest::SHA384.digest(umd_content))}"
  importmap_path = File.join(rails_root, 'config/importmap.rb')
  updated = File.read(importmap_path).gsub(
    /^(pin 'community_engine_js_umd'[^,\n]*)(?:,\s*integrity:\s*'sha\d+-[^']*')?/,
    "\\1, integrity: '#{sri}'"
  )
  File.write(importmap_path, updated)
  puts "  ✓ SRI: #{sri}"
  puts '  ✓ Updated config/importmap.rb'
end

def ce_js_print_version
  version_file = File.join(ce_js_rails_root, CE_JS_VERSION_FILE)
  msg = File.exist?(version_file) ? File.read(version_file).strip : '(unknown — config/community_engine_js_version not found)'
  puts msg
end

def ce_js_run_install(version, rails_root)
  puts "  Installing @better-together/community-engine-js@#{version} …"
  tarball_url = ce_js_fetch_tarball_url(version)
  puts "  Tarball: #{tarball_url}"
  umd_content = ce_js_extract_umd(tarball_url)
  dest = File.join(rails_root, CE_JS_VENDOR_DEST)
  File.write(dest, umd_content)
  puts "  ✓ Written #{umd_content.bytesize} bytes → #{CE_JS_VENDOR_DEST}"
  ce_js_write_sri(umd_content, rails_root)
end

# ── Tasks ──────────────────────────────────────────────────────────────────────

CE_JS_PACKAGE_NAME  = '@better-together/community-engine-js'
CE_JS_REGISTRY_BASE = 'https://git.btsdev.ca/api/packages/better-together/npm'
CE_JS_UMD_TAR_PATH  = 'package/dist/community-engine.umd.js'
CE_JS_VENDOR_DEST   = 'vendor/javascript/community-engine.umd.js'
CE_JS_VERSION_FILE  = 'config/community_engine_js_version'

namespace :ce_js do
  desc <<~DESC
    Install @better-together/community-engine-js UMD artifact into vendor/javascript/.
    Version arg is optional; defaults to config/community_engine_js_version.
    Set FORGEJO_NPM_TOKEN env var for authenticated registry access.
  DESC
  task :install, [:version] do |_, args|
    ce_js_run_install(ce_js_resolve_version(args[:version]), ce_js_rails_root)
  end

  desc 'Update @better-together/community-engine-js to VERSION and record in config/community_engine_js_version.'
  task :update, [:version] do |_, args|
    raise ArgumentError, 'Version required. Usage: rake ce_js:update[0.2.0]' unless args[:version]&.match?(/\A\d+\.\d+\.\d+/)

    version = args[:version]
    Rake::Task['ce_js:install'].invoke(version)

    version_file = File.join(ce_js_rails_root, CE_JS_VERSION_FILE)
    File.write(version_file, "#{version}\n")
    puts "  ✓ #{CE_JS_VERSION_FILE} → #{version}"
  end

  desc 'Print the currently installed community-engine-js version.'
  task :version do
    ce_js_print_version
  end
end
