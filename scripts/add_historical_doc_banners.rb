# frozen_string_literal: true

# Adds (or with --remove, strips) a "Historical document" banner to dated assessments, plans, implementation
# notes and meta inventories. Idempotent: the banner is fenced by a marker comment. Dates come from git history.
#
#   ruby scripts/add_historical_doc_banners.rb            # add missing banners
#   ruby scripts/add_historical_doc_banners.rb --dry-run  # list files that would change
#   ruby scripts/add_historical_doc_banners.rb --remove   # strip banners
require 'open3'
require 'pathname'

# Banner insertion for historical documentation.
module HistoricalDocBanners
  ROOT = Pathname.new(__dir__).join('..').expand_path
  PREFIXES = %w[docs/assessments docs/plans docs/implementation docs/meta].freeze
  MARKER = '<!-- historical-doc-banner -->'
  MARKER_END = '<!-- /historical-doc-banner -->'
  INDEX = 'docs/table_of_contents.md'

  module_function

  def git(*) = Open3.capture2('git', *, chdir: ROOT.to_s).first.strip

  def files = PREFIXES.flat_map { |p| git('ls-files', p).split("\n") }.grep(/\.md\z/).sort

  def banner(path)
    created = git('log', '--diff-filter=A', '--format=%as', '--', path).split("\n").last
    updated = git('log', '-1', '--format=%as', '--', path)
    depth = path.count('/') - 1
    link = ('../' * depth) + INDEX.delete_prefix('docs/')
    dates = created == updated ? "Written on #{created}" : "Written on #{created} (last edited #{updated})"
    "#{MARKER}\n> **Historical document.** #{dates}. It records the code, plans and findings as they stood then and is " \
      "not maintained for later releases. For current behaviour see the [documentation index](#{link}).\n#{MARKER_END}\n"
  end

  def strip(text) = text.gsub(/#{Regexp.escape(MARKER)}.*?#{Regexp.escape(MARKER_END)}\n\n?/m, '')

  def with_banner(path, text)
    lines = text.lines
    idx = lines.index { |l| l.start_with?('# ') } || -1
    insert_at = idx + 1
    lines.insert(insert_at, "\n", banner(path))
    lines.insert(insert_at + 2, "\n") unless lines[insert_at + 2].to_s.strip.empty?
    lines.join
  end

  def rewrite(path, text, remove)
    return strip(text) if remove
    return text if text.include?(MARKER)

    with_banner(path, text)
  end

  def run(argv)
    remove = argv.include?('--remove')
    dry = argv.include?('--dry-run')
    changed = files.filter_map do |path|
      text = ROOT.join(path).read
      updated = rewrite(path, text, remove)
      next if updated == text

      ROOT.join(path).write(updated) unless dry
      path
    end
    puts "#{dry ? 'would change' : 'changed'} #{changed.size} of #{files.size} files"
  end
end

HistoricalDocBanners.run(ARGV)
