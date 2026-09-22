# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'better_together/joatu/agreements/_agreement_list_item' do
  it 'renders successfully' do
    agreement = create(:joatu_agreement)

    render partial: 'better_together/joatu/agreements/agreement_list_item', locals: { agreement_list_item: agreement }

    expect(rendered).to be_present
  end
end
