# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'better_together/joatu/agreements/_agreement_list_item' do
  it 'renders contribution and evidence summaries for JOATU agreements' do
    agreement = create(:joatu_agreement)
    create(:claim, claimable: agreement, statement: 'Agreements should expose evidence in listings.')
    create(:citation, citeable: agreement, reference_key: 'agreement_listing_summary', title: 'Agreement Listing Summary')

    render partial: 'better_together/joatu/agreements/agreement_list_item', locals: { agreement_list_item: agreement }

    expect(rendered).to include('Contributors:')
    expect(rendered).to include('Evidence:')
    expect(rendered).to include('Governance Bundle')
  end
end
