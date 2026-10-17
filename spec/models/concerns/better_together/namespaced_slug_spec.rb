# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::NamespacedSlug do
  def page_with_slug(slug)
    BetterTogether::Page.new(title: 'EXPLORA III', slug:, privacy: 'private')
  end

  it 'is part of the page model' do
    expect(BetterTogether::Page.included_modules).to include(described_class)
  end

  it 'keeps the forward slash in a namespaced slug', :aggregate_failures do
    page = page_with_slug('ships/mt-explora-iii')

    expect(page).to be_valid
    expect(page.slug).to eq('ships/mt-explora-iii')
  end

  it 'parameterizes each segment on its own' do
    page = page_with_slug('Ships/MT Explora III')
    page.valid?

    expect(page.slug).to eq('ships/mt-explora-iii')
  end

  describe 'a saved namespaced page' do
    let(:page) { create(:better_together_page, title: 'EXPLORA III', slug: 'ships/mt-explora-iii', privacy: 'private') }

    before { page.update!(title: 'EXPLORA III (renamed)') }

    it 'keeps the slash in its slug and identifier after reloading and retitling', :aggregate_failures do
      expect(page.reload.slug).to eq('ships/mt-explora-iii')
      expect(page.identifier).to eq('ships/mt-explora-iii')
    end

    it 'is found by its namespaced slug' do
      expect(BetterTogether::Page.friendly.find('ships/mt-explora-iii')).to eq(page)
    end
  end

  it 'leaves an ordinary slug unchanged' do
    page = page_with_slug('about-us')
    page.valid?

    expect(page.slug).to eq('about-us')
  end

  it 'still derives a slug from the title when none is given' do
    page = BetterTogether::Page.new(title: 'Corner Brook Weather', privacy: 'private')
    page.valid?

    expect(page.slug).to eq('corner-brook-weather')
  end
end
