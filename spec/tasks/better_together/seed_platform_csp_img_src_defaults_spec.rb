# frozen_string_literal: true

require 'rails_helper'
require 'rake'

# rubocop:disable RSpec/DescribeClass, RSpec/SpecFilePathFormat
RSpec.describe 'better_together:seed:platform_csp_img_src_defaults', type: :task do
  before do
    Rake.application = Rake::Application.new
    # Pass an explicit (empty) `loaded` set — rake_require otherwise checks the file
    # against the process-global $LOADED_FEATURES and silently no-ops on every example
    # after the first, leaving later examples' fresh Rake::Application without the task.
    Rake.application.rake_require(
      'tasks/better_together/seed_platform_csp_img_src_defaults',
      [BetterTogether::Engine.root.join('lib').to_s],
      []
    )
    Rake::Task.define_task(:environment)
  end

  let(:task) { Rake::Task['better_together:seed:platform_csp_img_src_defaults'] }
  let(:required_sources) { BetterTogether::ContentSecurityPolicySources::DEFAULT_MAP_TILE_IMG_SOURCES }

  it 'adds missing default origins to a local platform that has none configured' do
    platform = create(:better_together_platform)
    platform.update_columns(settings: platform.settings.except('csp_img_src'))

    task.invoke

    expect(platform.reload.csp_img_src).to include(*required_sources)
  end

  it 'adds only the missing origins without disturbing an existing admin-configured value' do
    platform = create(:better_together_platform)
    platform.update_columns(
      settings: platform.settings.merge('csp_img_src' => ['https://images.example.com'])
    )

    task.invoke

    expect(platform.reload.csp_img_src).to include('https://images.example.com', *required_sources)
  end

  it 'does not touch a platform that already has every default origin configured' do
    platform = create(:better_together_platform)
    platform.update_columns(
      settings: platform.settings.merge('csp_img_src' => required_sources)
    )
    original_updated_at = platform.updated_at

    task.invoke

    expect(platform.reload.updated_at).to eq(original_updated_at)
  end

  it 'does not seed origins onto external platforms' do
    external_platform = create(:better_together_platform, :external)

    task.invoke

    expect(external_platform.reload.csp_img_src).to be_empty
  end

  it 'is safe to re-run and does not duplicate origins' do
    platform = create(:better_together_platform)
    platform.update_columns(settings: platform.settings.except('csp_img_src'))

    task.invoke
    task.reenable
    task.invoke

    required_sources.each do |source|
      expect(platform.reload.csp_img_src.count(source)).to eq(1)
    end
  end
end
# rubocop:enable RSpec/DescribeClass, RSpec/SpecFilePathFormat
