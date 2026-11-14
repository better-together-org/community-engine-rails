# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PlatformSnippetPolicy do
  let(:platform) { BetterTogether::Platform.find_by(host: true) }
  let(:record) { BetterTogether::PlatformSnippet.new(platform:) }

  def user_with_platform_role(identifier)
    user = create(:better_together_user, :confirmed)
    role = BetterTogether::Role.find_by!(identifier:)
    platform.person_platform_memberships.create!(member: user.person, role:, status: 'active')
    user
  end

  before { BetterTogether::AccessControlBuilder.seed_data }

  it 'denies stewards and managers: manage_platform is not enough' do # rubocop:disable RSpec/MultipleExpectations
    %w[platform_steward platform_manager].each do |role|
      policy = described_class.new(user_with_platform_role(role), record)

      expect(policy.index?).to be(false), "#{role} index"
      expect(policy.create?).to be(false), "#{role} create"
    end
  end

  it 'allows the platform code manager role on that platform only' do # rubocop:disable RSpec/MultipleExpectations
    user = user_with_platform_role('platform_code_manager')
    other = create(:better_together_platform)

    expect(described_class.new(user, record)).to be_create
    expect(described_class.new(user, BetterTogether::PlatformSnippet.new(platform: other))).not_to be_create
  end

  it 'denies signed-out visitors' do
    expect(described_class.new(nil, record)).not_to be_index
  end

  it 'needs manage_platform_security as well to widen the CSP' do # rubocop:disable RSpec/MultipleExpectations
    user = user_with_platform_role('platform_code_manager')
    expect(described_class.new(user, record).allow_origin?).to be(false)

    role = BetterTogether::Role.find_by!(identifier: 'platform_steward')
    platform.person_platform_memberships.create!(member: user.person, role:, status: 'active')
    expect(described_class.new(user.reload, record).allow_origin?).to be(true)
  end

  it 'gives stewards no manage_platform_code permission in the seed data' do
    steward = BetterTogether::Role.find_by!(identifier: 'platform_steward')

    expect(steward.resource_permissions.pluck(:identifier)).not_to include('manage_platform_code')
  end
end
