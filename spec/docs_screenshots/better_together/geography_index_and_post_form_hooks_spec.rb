# frozen_string_literal: true

require 'rails_helper'

# Capture command (run from repo root):
#   bin/dc-run bash -c 'RUN_DOCS_SCREENSHOTS=1 bundle exec prspec \
#     spec/docs_screenshots/better_together/geography_index_and_post_form_hooks_spec.rb'
#
# The hooks are empty in the engine, so the annotated captures render a host override (a labelled box) to show where
# it lands; the plain captures are the engine default.
RSpec.describe 'Documentation screenshots for the geography index and post form hooks', # rubocop:disable RSpec/SpecFilePathSuffix
               :as_platform_manager,
               :docs_screenshot,
               :js,
               retry: 0,
               type: :feature do
  let(:locale) { I18n.default_locale }
  let(:override_dir) { Rails.root.join('tmp/geography_hooks_screenshot_views') }
  let(:controllers) { [BetterTogether::Geography::RegionsController, BetterTogether::PostsController] }
  let!(:original_paths) { controllers.index_with(&:view_paths) }

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    create(:better_together_geography_region, name: 'Harbour Region') if FactoryBot.factories.registered?(:better_together_geography_region)
  end

  after do
    original_paths.each { |controller, paths| controller.view_paths = paths }
    FileUtils.rm_rf(override_dir)
  end

  def install_override(path, locals, body)
    dir = override_dir.join(File.dirname(path))
    FileUtils.mkdir_p(dir)
    File.write(override_dir.join(path), "<%# locals: (#{locals}) -%>\n#{body}\n")
    controllers.each { |controller| controller.prepend_view_path(override_dir.to_s) }
  end

  def metadata(flow)
    { locale:, role: 'platform_manager', feature_set: 'geography_index_and_post_form_hooks', flow:,
      source_spec: self.class.metadata[:file_path] }
  end

  def capture(name, selector:, title:, bullet:, &)
    BetterTogether::CapybaraScreenshotEngine.capture(
      name, device: :both, metadata: metadata(name),
            callouts: [{ id: 'hook', selector:, title:, bullets: [bullet] }],
            narrative: { title:, audience: %w[platform_manager developer],
                         journey_step: "As a host app developer, I add content here: #{title.downcase}.",
                         callouts: [{ id: 'hook', title:, description: bullet }],
                         accessibility_notes: 'The default markup is unchanged; hooks only add override points.' },
      &
    )
  end

  it 'captures the regions index hook with a host override' do
    install_override('better_together/geography/regions/_index_extra.html.erb', 'records:',
                     '<div id="host-index-extra" class="alert alert-info my-3">Host content: a map of <%= records.size %> regions</div>')
    capture('geography_index_hook', selector: '#host-index-extra', title: 'Index extra',
                                    bullet: 'Between the heading and the list; empty unless a host overrides the partial.') do
      capybara_login_as_platform_manager
      visit better_together.geography_regions_path(locale:)
      expect(page).to have_css('#host-index-extra')
    end
  end

  it 'captures the plain regions index' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'geography_index_hook_plain', device: :both, metadata: metadata('index_plain')
    ) do
      capybara_login_as_platform_manager
      visit better_together.geography_regions_path(locale:)
      expect(page).to have_css('table.table')
    end
  end

  it 'captures the post form hook with a host override' do
    install_override('better_together/posts/_form_extra.html.erb', 'form:, post:',
                     '<div id="host-post-form-extra" class="alert alert-info">Host field: a location picker</div>')
    capture('post_form_hook', selector: '#host-post-form-extra', title: 'Post form extra',
                              bullet: 'Before the publishing date; empty unless a host overrides the partial.') do
      capybara_login_as_platform_manager
      visit better_together.new_post_path(locale:)
      expect(page).to have_css('#host-post-form-extra')
      page.execute_script("document.querySelector('#host-post-form-extra').scrollIntoView({block: 'center'})")
    end
  end

  it 'captures the plain post form' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'post_form_hook_plain', device: :both, metadata: metadata('form_plain')
    ) do
      capybara_login_as_platform_manager
      visit better_together.new_post_path(locale:)
      expect(page).to have_css('[name="post[published_at]"]')
    end
  end
end
