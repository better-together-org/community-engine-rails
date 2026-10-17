# frozen_string_literal: true

# rubocop:disable Metrics/ModuleLength, Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/BlockLength, Layout/LineLength

# Builds the documentation coverage manifest and gap report.
#
# Input:  tmp/rails_surface.json (from scripts/dump_rails_surface.rb), the repo tree and git history.
# Output: docs/reference/ce_documentation_coverage_manifest.json  (machine-readable, every row)
#         docs/reference/ce_documentation_coverage_manifest.md    (summary tables)
#         docs/reference/documentation_gap_report.md              (per-audience gaps and removed-code references)
#
# Coverage is heuristic text matching, not proof of accuracy: a "strong" doc mention means a living doc names the
# controller/model class (or a backticked short name), not that the doc is correct. Staleness compares git
# last-touch times of the artifact and the code it covers. Run via bin/export_documentation_coverage_manifest.

require 'json'
require 'yaml'
require 'pathname'
require 'open3'

# Collects coverage rows for views, models, concerns and workflows and renders the manifest and gap report.
module CeDocumentationCoverage
  ROOT = Pathname.new(__dir__).join('..').expand_path
  BASELINE = ENV.fetch('DOC_COVERAGE_BASELINE', 'v0.10.0')
  OUT_DIR = ROOT.join('docs/reference')
  WORKFLOWS_FILE = OUT_DIR.join('ce_documentation_workflows.yml')
  # outputs of this script must not count as documentation of themselves
  GENERATED_OUTPUTS = %w[docs/reference/ce_documentation_coverage_manifest.md docs/reference/documentation_gap_report.md].freeze

  # docs that describe history, plans or generated output rather than current behaviour
  HISTORICAL_PREFIXES = %w[docs/assessments docs/plans docs/implementation docs/releases docs/meta docs/diagrams/reference docs/screenshots].freeze
  AUDIENCE_DOC_DIRS = {
    'developer' => %w[docs/developers docs/development docs/api docs/reference docs/generators docs/examples],
    'platform_manager' => %w[docs/platform_organizers docs/organizers docs/production docs/privacy docs/security],
    'community_organizer' => %w[docs/community_organizers],
    'content_moderator' => %w[docs/content_moderators docs/support_staff],
    'end_user' => %w[docs/end_users docs/users]
  }.freeze

  # first match wins; anything unmatched is an end-user surface. Hand corrections live in AUDIENCE_OVERRIDES.
  AUDIENCE_RULES = [
    [%r{\Abetter_together/(api|mcp|oauth|webhook)}, 'developer'],
    [%r{\Abetter_together/(host|platforms|platform_|setup_wizard|wizard|roles|resource_permissions|navigation|metrics|content/(blocks|css|html)|pages|categories|geography|infrastructure|robots|seeds|uploads|short_links|joatu/(categories)|settings|feature|invitations|inbound|bot_|content_security|translations|accounts)}, 'platform_manager'],
    [%r{\Abetter_together/(reports|safety|moderat|content_security|person_deletion|person_data)}, 'content_moderator'],
    [%r{\Abetter_together/(communities|community_|membership|person_community)}, 'community_organizer']
  ].freeze
  AUDIENCE_OVERRIDES = {}.freeze

  REMOVED_TERMS = {
    'elasticsearch' => /elasticsearch|default_elasticsearch_index|as_indexed_json/i,
    'sentry' => /\bsentry\b|sentry-(rails|ruby)/i,
    'e2ee_signal' => /e2ee|signal protocol|one_time_prekey|one-time prekey/i,
    'claims_evidence' => /evidence[_ ]?links?|claim[_ ]citation|\bcitations?\b.*\bclaims?\b/i,
    'ruby_openai' => /ruby[-_]openai/i
  }.freeze

  module_function

  def sh(*cmd)
    out, status = Open3.capture2(*cmd, chdir: ROOT.to_s)
    raise "command failed: #{cmd.join(' ')}" unless status.success?

    out
  end

  def camelize(str) = str.split('_').map(&:capitalize).join

  def underscore(str) = str.gsub('::', '/').gsub(/([A-Z]+)([A-Z][a-z])/, '\\1_\\2').gsub(/([a-z\d])([A-Z])/, '\\1_\\2').downcase

  def read(path) = File.read(ROOT.join(path), encoding: 'UTF-8', invalid: :replace, undef: :replace)

  def files(glob) = Dir.glob(ROOT.join(glob).to_s).map { |f| Pathname.new(f).relative_path_from(ROOT).to_s }.sort

  def last_touch
    @last_touch ||= begin
      map = {}
      stamp = nil
      sh('git', 'log', '--name-only', '--format=@%ct', 'HEAD').each_line do |line|
        line = line.chomp
        if line.start_with?('@') then stamp = line[1..].to_i
        elsif !line.empty? then map[line] ||= stamp
        end
      end
      map
    end
  end

  def changed_since_baseline
    @changed_since_baseline ||= sh('git', 'diff', '--name-status', "#{BASELINE}..HEAD").each_line.to_h do |line|
      status, path = line.chomp.split("\t", 2)
      [path, status[0]]
    end
  end

  def change_label(paths)
    states = paths.filter_map { |p| changed_since_baseline[p] }
    return 'unchanged' if states.empty?

    states.all?('A') ? 'new' : 'changed'
  end

  def touch(paths) = paths.filter_map { |p| last_touch[p] }.max

  def corpus
    @corpus ||= begin
      docs = (files('docs/**/*.md') - GENERATED_OUTPUTS) + %w[README.md].select { |f| ROOT.join(f).exist? }
      docs.to_h { |f| [f, read(f)] }
    end
  end

  def living_docs = corpus.reject { |f, _| HISTORICAL_PREFIXES.any? { |p| f.start_with?(p) } }

  # Audience docs rarely name controllers, so a doc can declare what it covers with an HTML comment:
  #   <!-- doc-coverage: better_together/short_links, better_together/reports#new -->
  # A bare controller path covers every action of that controller.
  def coverage_annotations
    @coverage_annotations ||= living_docs.transform_values do |text|
      text.scan(/<!--\s*doc-coverage:\s*(.*?)\s*-->/m).flatten.flat_map { |list| list.split(',').map(&:strip) }
    end
  end

  def annotated_docs(controller_path, action)
    coverage_annotations.select { |_f, tokens| tokens.include?(controller_path) || tokens.include?("#{controller_path}##{action}") }.keys
  end

  def diagram_sources
    @diagram_sources ||= files('docs/diagrams/source/*.mmd').to_h { |f| [f, read(f)] }
  end

  def axe_specs
    @axe_specs ||= files('spec/**/*_spec.rb').select { |f| (t = read(f)).include?('be_axe_clean') && t }.to_h { |f| [f, read(f)] }
  end

  def docs_screenshot_specs
    @docs_screenshot_specs ||= files('spec/docs_screenshots/**/*_spec.rb')
  end

  def matches_any?(text, patterns) = patterns.any? { |pat| text.include?(pat) }

  def matching(set, patterns) = set.select { |_f, text| matches_any?(text, patterns) }.keys.sort

  def audience_for(controller_path)
    return AUDIENCE_OVERRIDES[controller_path] if AUDIENCE_OVERRIDES.key?(controller_path)

    AUDIENCE_RULES.each { |rx, who| return who if controller_path.match?(rx) }
    'end_user'
  end

  def audience_docs(paths)
    AUDIENCE_DOC_DIRS.filter_map { |who, dirs| who if paths.any? { |p| dirs.any? { |d| p.start_with?("#{d}/") } } }
  end

  def view_files(controller_path, action)
    base = "app/views/#{controller_path}"
    candidates = files("#{base}/#{action}.*")
    candidates += files("#{base}/_#{action}.*")
    candidates
  end

  def coverage_status(doc_hits, shot_hits, _diagram_hits, needs_visual:, stale:)
    score = [doc_hits.any?, (needs_visual ? shot_hits.any? : true)].count(true)
    base = case score
           when 2 then 'covered'
           when 1 then 'partial'
           else 'missing'
           end
    return base if base == 'missing' || !stale

    'stale'
  end

  def surface = @surface ||= JSON.parse(ROOT.join('tmp/rails_surface.json').read)

  def build_views
    shots_by_action = Hash.new { |h, k| h[k] = [] }
    surface['screenshot_routes'].each do |sidecar, meta|
      next unless meta['controller']

      shots_by_action["#{meta['controller']}##{meta['action']}"] << sidecar
    end
    controller_files = surface['controllers'].to_h { |c| [c['controller_path'], c['file']] }

    surface['routes'].group_by { |r| [r['controller'], r['action']] }.sort.filter_map do |(controller, action), routes|
      next if controller.start_with?('rswag', 'sidekiq', 'doorkeeper')

      cpath = controller
      views = view_files(cpath, action)
      html = views.any? { |v| v.end_with?('.html.erb') || (v.end_with?('.erb') && !v.include?('.turbo_stream')) }
      short = camelize(controller.split('/').last)
      klass_names = ["BetterTogether::#{controller.sub('better_together/', '').split('/').map { |p| camelize(p) }.join('::')}Controller", "#{short}Controller"]
      helpers = routes.filter_map { |r| r['name'] }.uniq.flat_map { |n| ["#{n}_path", "#{n}_url"] }
      doc_hits = (matching(living_docs, klass_names + [cpath]) + annotated_docs(cpath, action)).uniq.sort
      doc_hits = doc_hits.reject { |f| f.start_with?('docs/diagrams/') }
      diag_hits = matching(diagram_sources, klass_names)
      axe_hits = helpers.empty? ? [] : matching(axe_specs, helpers)
      shot_sidecars = shots_by_action["#{controller}##{action}"]
      shot_files = shot_sidecars.map { |s| s.sub(/\.json\z/, '.png') }
      source_specs = shot_sidecars.filter_map { |s| surface['screenshot_routes'][s]['source_spec']&.delete_prefix('./') }.uniq.sort
      ctrl_file = controller_files[cpath]&.sub(%r{\A.*?/(app/)}, '\1')
      code_paths = views + [ctrl_file].compact
      code_touch = touch(code_paths)
      changed = change_label(code_paths) != 'unchanged'
      stale_artifacts = if changed
                          (doc_hits.select { |f| (t = last_touch[f]) && code_touch && t < code_touch } +
                                                 shot_sidecars.select { |f| (t = last_touch[f]) && code_touch && t < code_touch }).sort
                        else
                          []
                        end
      audience = audience_for(cpath)
      {
        'route' => routes.map { |r| "#{r['verb']} #{r['path']}" }.uniq.sort.first(4),
        'controller_action' => "#{controller}##{action}",
        'audience' => audience,
        'html_view' => html,
        'views' => views,
        'change_vs_baseline' => change_label(code_paths),
        'docs' => doc_hits.first(8),
        'diagrams' => diag_hits.first(5),
        'screenshots' => shot_files.first(6),
        'screenshot_count' => shot_files.size,
        'screenshot_specs' => source_specs,
        'axe_specs' => axe_hits.first(4),
        'stale_artifacts' => stale_artifacts.first(8),
        'status' => coverage_status(doc_hits, shot_files, diag_hits, needs_visual: html, stale: stale_artifacts.any?)
      }
    end
  end

  def build_models
    erd_text = diagram_sources.select { |f, _| f.include?('erd') || f.include?('schema') }
    dbml = read('db/community-engine-db.dbml')
    concerns_dir = files('app/models/concerns/**/*.rb')
    concerns = concerns_dir.map do |f|
      name = f.sub(%r{\Aapp/models/concerns/}, '').sub(/\.rb\z/, '').split('/').map { |p| camelize(p) }.join('::')
      short = name.split('::').last
      doc_hits = matching(living_docs, [name, name.delete_prefix('BetterTogether::'), "`#{short}`"])
      { 'concern' => name, 'file' => f, 'change_vs_baseline' => change_label([f]), 'docs' => doc_hits.first(6),
        'status' => doc_hits.any? ? 'covered' : 'missing' }
    end
    models = surface['models'].sort_by { |m| m['name'] }.map do |m|
      short = m['name'].split('::').last
      file = m['file']&.sub(%r{\A.*?/(app/)}, '\1')
      doc_hits = matching(living_docs, [m['name'], m['name'].delete_prefix('BetterTogether::'), "`#{short}`"]).reject { |f| f.start_with?('docs/diagrams/') }
      erd_hits = matching(erd_text, [m['name'], m['table'], "#{short} "]).first(4)
      in_dbml = dbml.include?(m['table'])
      diag_hits = matching(diagram_sources, [m['name'], m['table']]).first(5)
      score = [doc_hits.any?, erd_hits.any? || in_dbml].count(true)
      {
        'model' => m['name'], 'table' => m['table'], 'file' => file, 'concerns' => m['concerns'],
        'change_vs_baseline' => change_label([file].compact),
        'docs' => doc_hits.first(6), 'erd_diagrams' => erd_hits, 'in_dbml' => in_dbml, 'diagrams' => diag_hits,
        'status' => { 2 => 'covered', 1 => 'partial', 0 => 'missing' }[score]
      }
    end
    [models, concerns]
  end

  def build_workflows(views, models)
    return [] unless WORKFLOWS_FILE.exist?

    known_controllers = surface['controllers'].to_set { |c| c['name'] }
    known_models = models.to_set { |m| m['model'] }
    YAML.safe_load(WORKFLOWS_FILE.read).fetch('workflows').map do |wf|
      unknown = wf.fetch('controllers', []).reject { |c| known_controllers.include?(c) } +
                wf.fetch('models', []).reject { |m| known_models.include?(m) }
      raise "workflow #{wf['id']} references unknown names: #{unknown.join(', ')}" if unknown.any?

      cpaths = wf.fetch('controllers', []).map { |c| underscore(c.delete_prefix('BetterTogether::').delete_suffix('Controller')) }
      v_rows = views.select { |v| cpaths.any? { |c| v['controller_action'].start_with?("better_together/#{c}#") } && v['html_view'] }
      m_rows = models.select { |m| wf.fetch('models', []).include?(m['model']) }
      needle = [wf['title'], wf['id'].tr('_', ' ')].compact
      doc_hits = matching(living_docs, needle.map { |n| n }).first(6)
      {
        'id' => wf['id'], 'title' => wf['title'], 'audiences' => wf['audiences'],
        'screens' => v_rows.size, 'screens_with_screenshots' => v_rows.count { |v| v['screenshot_count'].positive? },
        'screens_with_docs' => v_rows.count { |v| v['docs'].any? },
        'models' => m_rows.size, 'models_documented' => m_rows.count { |m| m['docs'].any? },
        'workflow_docs' => doc_hits,
        'status' => workflow_status(v_rows, m_rows, doc_hits)
      }
    end
  end

  def workflow_status(v_rows, m_rows, doc_hits)
    parts = [v_rows.empty? || v_rows.any? { |v| v['screenshot_count'].positive? },
             v_rows.empty? || v_rows.any? { |v| v['docs'].any? },
             m_rows.empty? || m_rows.any? { |m| m['docs'].any? }, doc_hits.any?]
    { 4 => 'covered', 0 => 'missing' }.fetch(parts.count(true), 'partial')
  end

  def build_removed_references
    paths = corpus.keys + diagram_sources.keys + %w[AGENTS.md CLAUDE.md].select { |f| ROOT.join(f).exist? } +
            files('.github/**/*.md')
    REMOVED_TERMS.to_h do |key, rx|
      living = []
      historical = []
      paths.uniq.each do |f|
        text = corpus[f] || diagram_sources[f] || read(f)
        count = text.scan(rx).size
        next if count.zero?

        entry = { 'file' => f, 'matches' => count }
        (HISTORICAL_PREFIXES.any? { |p| f.start_with?(p) } || f == 'CHANGELOG.md' ? historical : living) << entry
      end
      [key, { 'living' => living.sort_by { |e| -e['matches'] }, 'historical_files' => historical.size }]
    end
  end

  def summarize(rows, key = 'status')
    rows.group_by { |r| r[key] }.transform_values(&:size).sort.to_h
  end

  def run
    views, = [build_views]
    models, concerns = build_models
    workflows = build_workflows(views, models)
    removed = build_removed_references
    manifest = {
      'baseline' => BASELINE,
      'method' => 'Heuristic text matching over living docs, diagram sources, screenshot sidecars and specs; staleness from git last-touch times.',
      'summary' => {
        'views' => summarize(views), 'models' => summarize(models), 'concerns' => summarize(concerns),
        'workflows' => summarize(workflows)
      },
      'views' => views, 'models' => models, 'concerns' => concerns, 'workflows' => workflows,
      'removed_references' => removed
    }
    OUT_DIR.mkpath
    OUT_DIR.join('ce_documentation_coverage_manifest.json').write("#{JSON.pretty_generate(manifest)}\n")
    OUT_DIR.join('ce_documentation_coverage_manifest.md').write(render_summary(manifest))
    OUT_DIR.join('documentation_gap_report.md').write(render_gap_report(manifest))
    puts "manifest: #{views.size} view actions, #{models.size} models, #{concerns.size} concerns, #{workflows.size} workflows"
    puts "views #{manifest['summary']['views']} | models #{manifest['summary']['models']}"
  end

  def table(headers, rows)
    ([headers, headers.map { '---' }] + rows).map { |r| "| #{r.join(' | ')} |" }.join("\n")
  end

  def render_summary(manifest)
    s = manifest['summary']
    rows = s.map { |k, v| [k, v.map { |st, n| "#{st}: #{n}" }.join(', ')] }
    <<~MD
      <!-- Generated by scripts/export_documentation_coverage_manifest.rb. Do not hand-edit; regenerate with bin/export_documentation_coverage_manifest. -->
      # Documentation coverage manifest

      Row-level data is in [`ce_documentation_coverage_manifest.json`](ce_documentation_coverage_manifest.json); gaps by audience are in [`documentation_gap_report.md`](documentation_gap_report.md). Baseline for "new" and "changed": `#{manifest['baseline']}`.

      ## How coverage is decided

      - **View action**: a route's `controller#action`. `covered` = a living doc names the controller (class or controller path) and, for HTML views, a docs screenshot sidecar resolves to the action's route. `partial` = one of the two. `missing` = neither. `stale` = covered or partial, the controller or view changed since the baseline, and a linked doc or screenshot was last committed before that change.
      - **Doc coverage annotations**: a living doc can declare the screens it covers with an HTML comment, `<!-- doc-coverage: better_together/short_links, better_together/reports#new -->`. A bare controller path covers every action of that controller. Use it in audience guides, which rarely name controllers.
      - **Model**: `covered` = a living doc names the model (with or without the `BetterTogether::` prefix) and an ERD source or the DBML names its table; `partial` = one of the two.
      - **Concern**: `covered` when a living doc names it.
      - **Workflow**: curated in [`ce_documentation_workflows.yml`](ce_documentation_workflows.yml); `covered` needs a screenshot, a doc and a documented model across its screens, plus a doc that names the workflow.
      - Living docs exclude `docs/assessments`, `plans`, `implementation`, `releases`, `meta`, generated diagram references and screenshots. Matching is textual, so a mention is evidence of coverage, not of accuracy.

      ## Summary

      #{table(%w[Surface Status], rows)}
    MD
  end

  def top(rows, limit) = rows.first(limit)

  def render_gap_report(manifest)
    views = manifest['views']
    out = ['<!-- Generated by scripts/export_documentation_coverage_manifest.rb. Do not hand-edit. -->', '# Documentation gap report', '',
           "Baseline `#{manifest['baseline']}`. Generated from [`ce_documentation_coverage_manifest.json`](ce_documentation_coverage_manifest.json). Lists are capped; the JSON has every row.", '']
    out << '## Views and actions by audience' << ''
    rows = %w[developer platform_manager community_organizer content_moderator end_user].map do |who|
      v = views.select { |r| r['audience'] == who && r['html_view'] }
      by = v.group_by { |r| r['status'] }
      [who, v.size, by.fetch('covered', []).size, by.fetch('partial', []).size, by.fetch('stale', []).size, by.fetch('missing', []).size,
       v.count { |r| r['change_vs_baseline'] == 'new' }]
    end
    out << table(['Audience', 'HTML actions', 'covered', 'partial', 'stale', 'missing', 'new since baseline'], rows) << ''
    out << 'Audience is derived from the controller namespace (see `AUDIENCE_RULES` in the generator) and needs a human pass.' << ''
    %w[platform_manager community_organizer content_moderator end_user developer].each do |who|
      gaps = views.select { |r| r['audience'] == who && r['html_view'] && %w[missing partial stale].include?(r['status']) }
                  .sort_by { |r| [r['change_vs_baseline'] == 'new' ? 0 : 1, r['status'] == 'missing' ? 0 : 1, r['controller_action']] }
      next if gaps.empty?

      out << "### #{who.tr('_', ' ')}: top gaps (#{gaps.size} total)" << ''
      out << table(%w[Action Change Status Docs Screenshots], top(gaps, 25).map { |r| ["`#{r['controller_action']}`", r['change_vs_baseline'], r['status'], r['docs'].size, r['screenshot_count']] }) << ''
    end
    out << '## Models and concerns' << ''
    models = manifest['models']
    newer = models.select { |m| m['change_vs_baseline'] == 'new' && m['status'] != 'covered' }
    out << "#{models.count { |m| m['status'] == 'covered' }} of #{models.size} models are covered (doc plus ERD or DBML). New since baseline and not covered: **#{newer.size}**." << ''
    out << table(%w[Model Table Doc ERD/DBML], top(newer, 60).map { |m| ["`#{m['model']}`", "`#{m['table']}`", m['docs'].any? ? 'yes' : 'no', m['erd_diagrams'].any? || m['in_dbml'] ? 'yes' : 'no'] }) << ''
    conc = manifest['concerns'].select { |c| c['change_vs_baseline'] != 'unchanged' && c['status'] == 'missing' }
    out << "Concerns new or changed since baseline with no doc mention: **#{conc.size}**." << ''
    out << table(%w[Concern Change], top(conc, 40).map { |c| ["`#{c['concern']}`", c['change_vs_baseline']] }) << ''
    out << '## Workflows' << ''
    out << table(['Workflow', 'Audiences', 'Screens', 'Screenshots', 'Docs', 'Models documented', 'Status'],
                 manifest['workflows'].map { |w| [w['title'], Array(w['audiences']).join(', '), w['screens'], w['screens_with_screenshots'], w['screens_with_docs'], "#{w['models_documented']}/#{w['models']}", w['status']] }) << ''
    out << '## References to removed code (input for the accuracy pass)' << ''
    out << 'Living = rewrite to current behaviour. Historical (assessments, plans, release notes, CHANGELOG) = add a banner, keep content.' << ''
    out << table(['Term group', 'Living files', 'Living matches', 'Historical files'],
                 manifest['removed_references'].map { |k, v| [k, v['living'].size, v['living'].sum { |e| e['matches'] }, v['historical_files']] }) << ''
    manifest['removed_references'].each do |k, v|
      next if v['living'].empty?

      out << "<details><summary>#{k}: living files</summary>" << ''
      v['living'].first(60).each { |e| out << "- `#{e['file']}` (#{e['matches']})" }
      out << '' << '</details>' << ''
    end
    "#{out.join("\n")}\n"
  end
end

CeDocumentationCoverage.run

# rubocop:enable Metrics/ModuleLength, Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/BlockLength, Layout/LineLength
