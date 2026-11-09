# frozen_string_literal: true

require 'rails_helper'

# The search behind every billing person select: members of this platform, for the platform's stewards only.
RSpec.describe BetterTogether::Billing::PeopleController do
  include_context 'with offline payment fixtures'
  include_context 'with billing switched on'

  let(:locale) { :en }
  let(:member) do
    create(:better_together_person_platform_membership, joinable: host_platform, member: other_buyer)
    other_buyer
  end

  def search(term) = get better_together.billing_people_path(locale:, search: term), as: :json

  it 'sends a visitor to sign in' do
    search('ab')

    expect(response).to have_http_status(:found).or have_http_status(:unauthorized)
  end

  it 'turns a signed-in non-steward away' do
    sign_in buyer_user

    search('ab')

    expect(response).not_to have_http_status(:ok)
  end

  context 'when signed in as a steward' do
    before { sign_in steward_user }

    it 'finds platform members by the start of a handle' do
      search(member.identifier[0, 5])

      expect(response.parsed_body).to include(a_hash_including('value' => member.id, 'text' => member.select_option_title))
    end

    it 'finds platform members by part of a name' do
      search(member.name[1, 4])

      expect(response.parsed_body.pluck('value')).to include(member.id)
    end

    it 'returns nothing for a term shorter than two characters, so it cannot list everyone' do
      search('a')

      expect(response.parsed_body).to eq([])
    end

    it 'leaves out people who are not members of this platform' do
      stranger = create(:better_together_person)

      search(stranger.identifier)

      expect(response.parsed_body.pluck('value')).not_to include(stranger.id)
    end

    it 'returns at most 20 people' do
      create_list(:better_together_person_platform_membership, 22, joinable: host_platform).each do |membership|
        membership.member.update!(identifier: "zq-#{SecureRandom.hex(4)}")
      end

      search('zq')

      expect(response.parsed_body.size).to eq(20)
    end
  end
end
