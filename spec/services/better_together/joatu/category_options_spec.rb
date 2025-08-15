# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Joatu::CategoryOptions, type: :service do
  it 'returns [name, id] pairs sorted by translated name with mobility fallbacks' do
    I18n.locale = :en
    cat1 = create(:better_together_joatu_category, name: 'Zeta')
    cat2 = create(:better_together_joatu_category, name: 'Alpha')

    opts = described_class.call(BetterTogether::Joatu::Category.where(id: [cat1.id, cat2.id]))
    expect(opts.map(&:last)).to eq([cat2.id, cat1.id])
    expect(opts.map(&:first)).to eq(['Alpha', 'Zeta'])
  end
end

