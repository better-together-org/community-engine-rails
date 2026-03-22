#!/usr/bin/env ruby
# frozen_string_literal: true

require 'date'
require 'fileutils'
require 'open3'
require 'optparse'
require 'yaml'

# Parses CLI arguments for `scripts/qa_issue_automator.rb`.
class QaIssueAutomatorCli
  DEFAULT_REPO = 'better-together-org/community-engine-rails'
  DEFAULT_ISSUE = 1249

  def self.parse(argv)
    options = default_options
    option_parser(options).parse!(argv)
    options
  end

  def self.default_options
    {
      repo: DEFAULT_REPO,
      issue: DEFAULT_ISSUE,
      apply: false,
      rules: File.expand_path('qa_issue_automator_rules.yml', __dir__),
      workdir: File.expand_path('..', __dir__),
      today: Date.today.iso8601,
      commit: nil
    }
  end

  def self.option_parser(options) # rubocop:disable Metrics/AbcSize
    OptionParser.new do |opts|
      opts.banner = 'Usage: scripts/qa_issue_automator.rb [options]'

      opts.on('--repo OWNER/REPO', 'GitHub repo (default: better-together-org/community-engine-rails)') { |v| options[:repo] = v }
      opts.on('--issue N', Integer, 'Issue number (default: 1249)') { |v| options[:issue] = v }
      opts.on('--rules PATH', 'Rules YAML path') { |v| options[:rules] = v }
      opts.on('--apply', 'Apply changes to issue (default: dry-run)') { options[:apply] = true }
      opts.on('--today YYYY-MM-DD', 'Override date used in evidence notes') { |v| options[:today] = v }
      opts.on('--commit SHA', 'Override commit SHA used in evidence notes (default: git HEAD)') { |v| options[:commit] = v }
    end
  end
end

# Parses and edits a GitHub issue body that contains sectioned QA checklists.
class QaIssueBody
  CHANGED_FILE_LINE_REGEX = %r{\[`([^`]+)`\]\(https://}

  def initialize(lines)
    @lines = lines
  end

  attr_reader :lines

  def changed_files_in_section(section_heading)
    section_lines = section_slice(section_heading)
    return [] unless section_lines

    extract_changed_files(section_lines)
  end

  def check_off!(checkbox_texts, evidence)
    @lines = checkbox_texts.reduce(@lines) do |acc, text|
      acc.map do |line|
        next line unless line.strip == "- [ ] #{text}"

        "- [x] #{text} (#{evidence})\n"
      end
    end
  end

  def flag_manual!(checkbox_texts)
    @lines = checkbox_texts.reduce(@lines) do |acc, text|
      acc.map do |line|
        next line unless line.strip == "- [ ] #{text}"
        next line if line.include?('(manual)')

        "- [ ] #{text} (manual)\n"
      end
    end
  end

  private

  def section_slice(heading)
    start_idx = @lines.find_index { |l| l.strip == "### #{heading}" || l.start_with?("### #{heading} ") }
    return nil unless start_idx

    end_idx = @lines[(start_idx + 1)..].find_index { |l| l.start_with?('### ') }
    end_idx = end_idx ? (start_idx + 1 + end_idx) : @lines.length

    @lines[start_idx...end_idx]
  end

  def extract_changed_files(section_lines)
    section_lines
      .grep(CHANGED_FILE_LINE_REGEX)
      .map { |l| l[/\[`([^`]+)`\]/, 1] }
      .compact
      .uniq
  end
end

# Verifies groups of checklist items by mapping changed files -> spec files and running them.
class QaSpecMappedGroupVerifier
  def initialize(repo_root:)
    @repo_root = repo_root
  end

  def verify(issue_body:, section_heading:, changed_file_prefix:, spec_prefix:, spec_label:)
    changed_files = changed_rb_files(issue_body, section_heading, changed_file_prefix)
    return skip_result(spec_label) if changed_files.empty?

    spec_paths = map_to_spec_paths(changed_files, changed_file_prefix, spec_prefix)
    missing_specs = missing_spec_paths(spec_paths)
    return fail_result(spec_label, missing_specs) if missing_specs.any?

    run_prspec(spec_paths)
  end

  private

  def run_prspec(spec_paths)
    cmd = ['bin/dc-run', 'bundle', 'exec', 'prspec'] + spec_paths
    _stdout, status = Open3.capture2e(*cmd, chdir: @repo_root)

    if status.success?
      { 'status' => 'pass', 'evidence' => "ran #{cmd.join(' ')}" }
    else
      { 'status' => 'fail', 'evidence' => "failed #{cmd.join(' ')}" }
    end
  end

  def changed_rb_files(issue_body, section_heading, changed_file_prefix)
    issue_body
      .changed_files_in_section(section_heading)
      .grep(/\A#{Regexp.escape(changed_file_prefix)}.*\.rb\z/)
  end

  def map_to_spec_paths(changed_files, changed_file_prefix, spec_prefix)
    changed_files.map do |path|
      path.sub(/\A#{Regexp.escape(changed_file_prefix)}/, spec_prefix).sub(/\.rb\z/, '_spec.rb')
    end
  end

  def missing_spec_paths(spec_paths)
    spec_paths.reject { |p| File.exist?(File.join(@repo_root, p)) }
  end

  def skip_result(spec_label)
    { 'status' => 'skip', 'evidence' => "No changed #{spec_label.downcase} files found" }
  end

  def fail_result(spec_label, missing_specs)
    { 'status' => 'fail', 'evidence' => "Missing #{spec_label.downcase} specs: #{missing_specs.join(', ')}" }
  end
end

# Automates checking off QA issue checklist items when they can be objectively verified.
class QaIssueAutomator
  GROUP_DEFS = {
    'models' => {
      section_heading: 'Models',
      changed_file_prefix: 'app/models/',
      spec_prefix: 'spec/models/',
      spec_label: 'Model'
    },
    'policies' => {
      section_heading: 'Policies',
      changed_file_prefix: 'app/policies/',
      spec_prefix: 'spec/policies/',
      spec_label: 'Policy'
    }
  }.freeze

  def self.from_argv(argv)
    new(QaIssueAutomatorCli.parse(argv))
  end

  def initialize(options)
    @options = options
    @repo_root = @options[:workdir]
    @tmp_dir = File.join(@repo_root, 'tmp')
    @rules = YAML.safe_load_file(@options[:rules])
  end

  def run
    FileUtils.mkdir_p(@tmp_dir)
    issue_body_path, updated_body_path = issue_paths

    issue_body = QaIssueBody.new(fetch_issue_body_lines!(issue_body_path))
    commit = @options[:commit] || git_head_short_sha

    verifier = QaSpecMappedGroupVerifier.new(repo_root: @repo_root)
    verifications = verify_groups(issue_body, verifier, commit)

    flag_manual_items(issue_body)

    File.write(updated_body_path, issue_body.lines.join)
    apply_or_report!(updated_body_path)
    print_summary(verifications)
  end

  private

  def flag_manual_items(issue_body)
    manual_flags = @rules.fetch('manual_flags', [])
    return if manual_flags.empty?

    issue_body.flag_manual!(manual_flags)
  end

  def fetch_issue_body_lines!(dest_path)
    cmd = ['gh', 'issue', 'view', @options[:issue].to_s, '-R', @options[:repo], '--json', 'body', '-q', '.body']
    stdout, status = Open3.capture2(*cmd)
    raise "Failed to fetch issue body (exit #{status.exitstatus})" unless status.success?

    File.write(dest_path, stdout)
    stdout.lines
  end

  def issue_paths
    issue_body_path = File.join(@tmp_dir, "qa_issue_#{@options[:issue]}_body.md")
    updated_body_path = File.join(@tmp_dir, "qa_issue_#{@options[:issue]}_body_updated.md")
    [issue_body_path, updated_body_path]
  end

  def git_head_short_sha
    stdout, status = Open3.capture2('git', '-C', @repo_root, 'rev-parse', '--short', 'HEAD')
    return stdout.strip if status.success?

    'unknown'
  end

  def verify_groups(issue_body, verifier, commit)
    verifications = []

    @rules.fetch('groups', {}).each do |group_name, group|
      verification = verification_for_group(group_name, verifier, issue_body)
      next unless verification

      verifications << verification.merge('group' => group_name)
      next unless verification['status'] == 'pass'

      evidence = "confirmed locally #{@options[:today]}; commit #{commit}; #{verification['evidence']}"
      issue_body.check_off!(group.fetch('check_texts', []), evidence)
    end

    verifications
  end

  def verification_for_group(group_name, verifier, issue_body)
    group_def = GROUP_DEFS[group_name]
    return nil unless group_def

    verifier.verify(issue_body:, **group_def)
  end

  def apply_or_report!(body_file)
    if @options[:apply]
      cmd = ['gh', 'issue', 'edit', @options[:issue].to_s, '-R', @options[:repo], '--body-file', body_file]
      _stdout, status = Open3.capture2e(*cmd)
      raise "Failed to apply issue body (exit #{status.exitstatus})" unless status.success?

      puts "Applied update to #{@options[:repo]}##{@options[:issue]}"
    else
      puts "Dry-run only. Updated body written to: #{body_file}"
    end
  end

  def print_summary(verifications)
    puts "\nVerification summary:"
    verifications.each do |v|
      puts "- #{v['group']}: #{v['status']} (#{v['evidence']})"
    end
  end
end

QaIssueAutomator.from_argv(ARGV).run
