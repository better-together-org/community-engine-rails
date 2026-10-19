# frozen_string_literal: true

require 'rails_helper'
require 'rake'

# @hermetic
RSpec.describe 'better_together:provision_tenant rake task', type: :task do
  before do
    Rake.application&.clear
    Rake.application = Rake::Application.new
    load BetterTogether::Engine.root.join('lib/tasks/better_together/provision_tenant.rake')
    Rake::Task.define_task(:environment)
  end

  after do
    Rake.application&.clear
  end

  let(:task) { Rake::Task['better_together:provision_tenant'] }
  let(:host_url) { "https://tenant-#{SecureRandom.hex(6)}.example.com" }
  let(:steward_email) { "steward-#{SecureRandom.hex(4)}@example.com" }

  it 'provisions a platform via the steward: keyword (not the removed admin: keyword)' do
    expect(BetterTogether::TenantPlatformProvisioningService).to receive(:call).with(
      name: 'Test Tenant',
      host_url:,
      time_zone: 'America/St_Johns',
      steward: {
        email: steward_email,
        password: 'Secur3Pass!wordXYZ',
        password_confirmation: 'Secur3Pass!wordXYZ',
        name: 'Steward Person'
      },
      privacy: 'private'
    ).and_call_original

    expect do
      task.invoke('Test Tenant', host_url, 'America/St_Johns', steward_email, 'Secur3Pass!wordXYZ', 'Steward Person')
    end.to output(/steward_user|Steward\s+:/i).to_stdout
  end

  it 'provisions successfully without steward args' do
    expect do
      task.invoke('Test Tenant', host_url)
    end.to output(/✅ Platform provisioned/).to_stdout

    expect(BetterTogether::Platform.find_by(host_url:)).to be_persisted
  end

  it 'aborts when name is missing' do
    expect { task.invoke(nil, host_url) }.to raise_error(SystemExit)
  end

  it 'aborts when host_url is missing' do
    expect { task.invoke('Test Tenant', nil) }.to raise_error(SystemExit)
  end
end
