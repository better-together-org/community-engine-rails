# frozen_string_literal: true

require 'rubygems/package'
require 'zlib'

# Writes blobs and a matching MANIFEST.json into a packet directory.
module SeedBlobHelpers
  def write_blob(dir, bytes)
    sha = Digest::SHA256.hexdigest(bytes)
    FileUtils.mkdir_p(File.join(dir, 'blobs'))
    File.binwrite(File.join(dir, 'blobs', sha), bytes)
    sha
  end

  def write_manifest(dir, media_types: {})
    files = Dir.glob('**/*', base: dir).select { |f| File.file?(File.join(dir, f)) && f != 'MANIFEST.json' }.sort.map do |relative|
      bytes = File.binread(File.join(dir, relative))
      sha = Digest::SHA256.hexdigest(bytes)
      { 'path' => relative, 'sha256' => sha, 'size' => bytes.bytesize,
        'media_type' => media_types.fetch(relative, relative.start_with?('blobs/') ? 'application/pdf' : 'application/yaml') }
    end
    File.write(File.join(dir, 'MANIFEST.json'), JSON.pretty_generate('schema' => '2.0', 'algorithm' => 'sha256', 'files' => files))
  end

  def tar_gz(path, entries)
    File.open(path, 'wb') do |file|
      Zlib::GzipWriter.wrap(file) do |gz|
        tar = Gem::Package::TarWriter.new(gz)
        entries.each do |name, content, type|
          if type == :symlink
            tar.add_symlink(name, content, 0o644)
          else
            tar.add_file_simple(name, 0o644, content.bytesize) { |io| io.write(content) }
          end
        end
        tar.close
      end
    end
    path
  end
end

RSpec.configure { |config| config.include SeedBlobHelpers }
