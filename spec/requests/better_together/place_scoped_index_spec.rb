# frozen_string_literal: true

require 'rails_helper'

# ?settlement=<identifier> narrows the events and posts indexes to what is located in that place (the lists behind
# the Events and Posts tabs of a settlement page). See BetterTogether::PlaceScopedIndex.
RSpec.describe 'Place-scoped indexes', :as_platform_manager do # rubocop:disable RSpec/DescribeClass
  let(:locale) { I18n.default_locale }
  let(:settlement) { create(:geography_settlement) }
  let(:elsewhere) { create(:geography_settlement) }

  describe 'GET /events?settlement=' do
    let!(:event_here) do
      create(:better_together_event, name: 'Harbour Festival', starts_at: 2.days.from_now,
                                     ends_at: 2.days.from_now + 1.hour)
    end
    let!(:event_there) do
      create(:better_together_event, name: 'Hilltop Market', starts_at: 3.days.from_now,
                                     ends_at: 3.days.from_now + 1.hour)
    end

    before do
      event_here.create_location!(location: settlement)
      event_there.create_location!(location: elsewhere)
    end

    it 'lists only the events located in the settlement' do
      get better_together.events_path(locale:, settlement: settlement.identifier)

      expect_html_content('Harbour Festival')
    end

    it 'leaves out events located elsewhere' do
      get better_together.events_path(locale:, settlement: settlement.identifier)

      expect_no_html_content('Hilltop Market')
    end

    it 'titles the list with the settlement name' do
      get better_together.events_path(locale:, settlement: settlement.identifier)

      expect_html_content(
        I18n.t('better_together.geography.place_scoped_index.events_heading', name: settlement.name, locale:)
      )
    end

    it 'keeps the scope through the filter form' do
      get better_together.events_path(locale:, settlement: settlement.identifier)

      expect(parsed_response.at_css('input[type="hidden"][name="settlement"]')['value'])
        .to eq(settlement.identifier)
    end

    it 'lists every event when no settlement is given' do
      get better_together.events_path(locale:)

      expect_html_contents('Harbour Festival', 'Hilltop Market')
    end

    it 'is not found for an unknown settlement' do
      get better_together.events_path(locale:, settlement: 'nowhere-at-all')

      expect(response).to have_http_status(:not_found)
    end

    it 'is not found when the param is not a plain identifier' do
      get better_together.events_path(locale:), params: { settlement: { name: 'x' } }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET /posts?settlement=' do
    let(:community_here) { create(:better_together_community, privacy: 'public') }
    let(:community_there) { create(:better_together_community, privacy: 'public') }

    before do
      community_here.create_location!(location: settlement)
      community_there.create_location!(location: elsewhere)
      create(:better_together_post, :public, :published, title: 'Harbour Notes', community: community_here)
      create(:better_together_post, :public, :published, title: 'Hilltop Notes', community: community_there)
    end

    it 'lists the posts of communities located in the settlement' do
      get better_together.posts_path(locale:, settlement: settlement.identifier)

      expect_html_content('Harbour Notes')
    end

    it 'leaves out posts of communities located elsewhere' do
      get better_together.posts_path(locale:, settlement: settlement.identifier)

      expect_no_html_content('Hilltop Notes')
    end

    it 'titles the list with the settlement name' do
      get better_together.posts_path(locale:, settlement: settlement.identifier)

      expect_html_content(
        I18n.t('better_together.geography.place_scoped_index.posts_heading', name: settlement.name, locale:)
      )
    end

    it 'is not found for an unknown settlement' do
      get better_together.posts_path(locale:, settlement: 'nowhere-at-all')

      expect(response).to have_http_status(:not_found)
    end
  end
end
