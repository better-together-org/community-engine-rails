# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Platform, '#quota_default_limits' do
  include AutomaticTestConfiguration
  include ActiveJob::TestHelper

  before { configure_host_platform }

  let(:platform) { create(:better_together_platform) }

  it 'is empty by default' do
    expect(platform.quota_default_limits).to eq({})
  end

  it 'keeps only known types, known owner kinds and non-negative integers' do
    platform.quota_default_limits = {
      'media_storage' => { 'person' => '100', 'community' => '', 'robot' => '5', 'platform' => '-3' },
      'bogus' => { 'person' => '1' }
    }

    expect(platform.quota_default_limits).to eq('media_storage' => { 'person' => 100 })
  end

  it 'clears overrides when every field is blank' do
    platform.update!(quota_default_limits: { 'media_storage' => { 'person' => '100' } })
    platform.update!(quota_default_limits: { 'media_storage' => { 'person' => '' } })

    expect(platform.reload.quota_default_limits).to eq({})
  end

  it 'is a permitted attribute' do
    expect(described_class.permitted_attributes.grep(Hash).any? { |entry| entry.key?(:quota_default_limits) }).to be true
  end

  it 'enqueues the apply job when the override changes on a local platform' do
    expect do
      platform.update!(quota_default_limits: { 'media_storage' => { 'person' => '100' } })
    end.to have_enqueued_job(BetterTogether::Quotas::ApplyPlatformDefaultsJob).with(platform.id)
  end

  it 'does not enqueue the job for unrelated updates' do
    expect { platform.update!(time_zone: 'America/St_Johns') }
      .not_to have_enqueued_job(BetterTogether::Quotas::ApplyPlatformDefaultsJob)
  end

  it 'does not enqueue the job for an external platform' do
    external = create(:better_together_platform, :external)

    expect { external.update!(quota_default_limits: { 'media_storage' => { 'person' => '100' } }) }
      .not_to have_enqueued_job(BetterTogether::Quotas::ApplyPlatformDefaultsJob)
  end
end
