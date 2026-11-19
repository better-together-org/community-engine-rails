# frozen_string_literal: true

# People in the roles the weather steward specs check: a host steward, an ordinary host member and
# a steward of another platform. Include with :weather_stewards.
module WeatherStewardHelpers
  def weather_host_platform
    BetterTogether::Platform.find_by(host: true) || configure_host_platform
  end

  def weather_user_with_role(role_identifier, platform: weather_host_platform)
    BetterTogether::AccessControlBuilder.seed_data
    user = create(:better_together_user, :confirmed)
    role = BetterTogether::Role.find_by!(identifier: role_identifier)
    platform.person_platform_memberships.create!(member: user.person, role:, status: 'active')
    user
  end

  def weather_host_steward
    weather_user_with_role('platform_steward')
  end

  def weather_host_member
    weather_user_with_role('platform_member')
  end

  def weather_other_platform_steward
    weather_user_with_role('platform_steward', platform: create(:better_together_platform))
  end
end

RSpec.shared_examples 'a host steward weather policy' do |actions|
  it 'allows host stewards' do
    policy = described_class.new(weather_host_steward, record)
    actions.each { |action| expect(policy.public_send(action)).to be(true), action.to_s }
  end

  it 'denies ordinary host members' do
    policy = described_class.new(weather_host_member, record)
    actions.each { |action| expect(policy.public_send(action)).to be(false), action.to_s }
  end

  it "denies another platform's steward" do
    policy = described_class.new(weather_other_platform_steward, record)
    actions.each { |action| expect(policy.public_send(action)).to be(false), action.to_s }
  end

  it 'denies anonymous visitors' do
    policy = described_class.new(nil, record)
    actions.each { |action| expect(policy.public_send(action)).to be(false), action.to_s }
  end

  it 'never allows creating or destroying' do
    policy = described_class.new(weather_host_steward, record)
    expect([policy.create?, policy.destroy?]).to eq([false, false])
  end
end

RSpec.configure { |config| config.include WeatherStewardHelpers, :weather_stewards }
