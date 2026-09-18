# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'better_together/joatu/agreements/_agreement_list_item' do
  it 'does not expose contribution and evidence governance details to agreement participants' do
    # Matches spec/requests/better_together/joatu/agreements_spec.rb's GET /index and
    # GET /show expectations — JOATU agreement pages intentionally keep governance/
    # editorial claim data (contributions, citations) out of the participant-facing UI.
    agreement = create(:joatu_agreement)
    create(:claim, claimable: agreement, statement: 'Agreements should expose evidence in listings.')
    create(:citation, citeable: agreement, reference_key: 'agreement_listing_summary', title: 'Agreement Listing Summary')

    render partial: 'better_together/joatu/agreements/agreement_list_item', locals: { agreement_list_item: agreement }

    expect(rendered).not_to include('Contributors:')
    expect(rendered).not_to include('Evidence:')
    expect(rendered).not_to include('Governance Bundle')
  end
end
