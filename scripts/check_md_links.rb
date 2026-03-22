#!/usr/bin/env ruby
# frozen_string_literal: true

require 'pathname'

root = Pathname.new(File.expand_path('..', __dir__))
scan_dir = root.join(ARGV[0] || 'docs')

broken = []

Dir.glob(scan_dir.join('**/*.md')).each do |file|
  base = Pathname.new(file).dirname
  File.read(file).scan(/\[[^\]]+\]\(([^)\s]+)(?:\s+"[^"]*")?\)/) do |m|
    href = m.first
    next if href.start_with?('#', 'http://', 'https://', 'mailto:')

    # Strip anchors like file.md#section
    path_part = href.split('#', 2).first
    # Normalize ./ and trailing slashes
    candidate = base.join(path_part).cleanpath
    broken << { file: file.sub("#{root}/", ''), link: href } unless candidate.file? || candidate.directory?
  end
end

if broken.empty?
  puts 'No broken internal links found.'
  exit 0
else
  puts 'Broken links:'
  broken.each { |b| puts "- #{b[:file]} -> (#{b[:link]})" }
  exit 1
end
