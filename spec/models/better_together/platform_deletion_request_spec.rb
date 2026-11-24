# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PlatformDeletionRequest do
  let!(:platform) { configure_host_platform }
  let(:steward_role) { BetterTogether::Role.find_by!(identifier: 'platform_steward') }
  let(:steward) do
    BetterTogether::PersonPlatformMembership.where(joinable: platform, role: steward_role).destroy_all
    create(:better_together_user, :confirmed, platform:).person.tap do |person|
      BetterTogether::PersonPlatformMembership.create!(member: person, joinable: platform, role: steward_role,
                                                       status: 'active')
    end
  end

  def build_request(by: steward)
    described_class.new(platform:, requested_by: by, requested_at: Time.current)
  end

  it 'is valid for a platform steward' do
    expect(build_request).to be_valid
  end

  it 'is invalid for someone who is not a steward' do
    steward
    other = create(:better_together_user, :confirmed, platform:).person

    expect(build_request(by: other)).not_to be_valid
  end

  it 'allows one pending request per platform', :aggregate_failures do
    build_request.save!

    expect(build_request).not_to be_valid
    expect { build_request.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it 'allows a new request after the first is cancelled' do
    build_request.tap(&:save!).cancel!

    expect(build_request).to be_valid
  end

  describe 'platform steward helpers' do
    it 'reports the last steward', :aggregate_failures do
      expect(platform.last_steward?(steward)).to be(true)
      second = create(:better_together_user, :confirmed, platform:).person
      BetterTogether::PersonPlatformMembership.create!(member: second, joinable: platform, role: steward_role,
                                                       status: 'active')
      expect(platform.last_steward?(steward)).to be(false)
    end
  end

  describe 'PersonDeletionRequest guard' do
    it 'refuses a request from the last steward' do
      request = steward.person_deletion_requests.build(requested_at: Time.current, platform:)

      expect(request).not_to be_valid
    end
  end
end
