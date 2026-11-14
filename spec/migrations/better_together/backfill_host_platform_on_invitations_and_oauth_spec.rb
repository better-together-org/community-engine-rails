# frozen_string_literal: true

require 'rails_helper'
require BetterTogether::Engine.root.join('db/migrate/20261112150000_backfill_host_platform_on_invitations_and_oauth')

# Existing invitations and OAuth applications belong to the host platform, never to an external
# platform row (OAuth providers, federation).
RSpec.describe BackfillHostPlatformOnInvitationsAndOauth, :no_auth do
  let!(:host_platform) { configure_host_platform }
  let(:external_platform) { create(:better_together_platform, external: true) }

  def run_migration
    ActiveRecord::Migration.suppress_messages { described_class.new.up }
  end

  it 'binds an OAuth application without a platform to the host platform' do
    app = create(:better_together_oauth_application, platform: host_platform)
    app.update_column(:platform_id, nil) # rubocop:disable Rails/SkipsModelValidations

    run_migration

    expect(app.reload.platform_id).to eq(host_platform.id)
  end

  it 'leaves records that already have a platform alone' do
    app = create(:better_together_oauth_application, platform: external_platform)

    run_migration

    expect(app.reload.platform_id).to eq(external_platform.id)
  end
end
