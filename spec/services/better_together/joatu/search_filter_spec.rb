# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Joatu::SearchFilter, type: :service do
  shared_examples 'search filter' do |factory:, resource_class:|
    let(:klass) { resource_class }

    before do
      I18n.locale = :en
    end

    def call(params = {}, relation: nil)
      described_class.call(resource_class: klass, relation: (relation || klass.all), params: params)
    end

    it 'respects the base relation (policy scope)' do
      allowed = create(factory)
      _excluded = create(factory)

      out = call({}, relation: klass.where(id: allowed.id))
      expect(out.pluck(:id)).to eq([allowed.id])
    end

    it 'filters by category ids via types_filter[]' do
      cat1 = create(:better_together_joatu_category, name: 'Alpha')
      cat2 = create(:better_together_joatu_category, name: 'Beta')

      m1 = create(factory, categories: [cat1])
      _m2 = create(factory, categories: [cat2])

      out = call({ types_filter: [cat1.id] })
      expect(out).to contain_exactly(m1)
    end

    it 'searches by Mobility name' do
      match = create(factory, name: 'UniqueFoo')
      _other = create(factory, name: 'Bar')

      out = call({ q: 'unique' })
      expect(out).to include(match)
    end

    it 'searches by ActionText description' do
      match = create(factory, description: 'ZeldaAlpha content here')
      _other = create(factory, description: 'Other content')

      out = call({ q: 'zelda' })
      expect(out).to include(match)
    end

    it 'searches by category name (Mobility, with fallback)' do
      cat = create(:better_together_joatu_category, name: 'Electronics')
      match = create(factory, categories: [cat])
      _other = create(factory)

      out = call({ q: 'electro' })
      expect(out).to include(match)
    end

    it 'filters by status=open' do
      open = create(factory)
      closed = create(factory)
      closed.update!(status: :closed)

      out = call({ status: 'open' })
      expect(out).to include(open)
      expect(out).not_to include(closed)
    end

    it 'orders by oldest when requested' do
      older = create(factory, created_at: 3.days.ago)
      newer = create(factory, created_at: Time.current)

      out = call({ order_by: 'oldest' })
      expect(out.first).to eq(older)
      expect(out.last).to eq(newer)
    end

    it 'applies per_page when pagination is available' do
      create_list(factory, 12)
      out = call({ per_page: '10' })

      if out.respond_to?(:current_page)
        expect(out.size).to eq(10)
      else
        skip 'Pagination not available in this environment'
      end
    end
  end

  describe 'for offers' do
    include_examples 'search filter', factory: :better_together_joatu_offer, resource_class: BetterTogether::Joatu::Offer
  end

  describe 'for requests' do
    include_examples 'search filter', factory: :better_together_joatu_request, resource_class: BetterTogether::Joatu::Request
  end
end

