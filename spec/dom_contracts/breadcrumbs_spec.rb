# frozen_string_literal: true

require 'rails_helper'

# DOM contract for the breadcrumb partial: ids and semantics the docs screenshots and feature specs rely on.
RSpec.describe 'Breadcrumbs DOM contract', type: :view do # rubocop:disable RSpec/DescribeClass
  let(:crumb) { BetterTogether::BreadcrumbsHelper::Crumb }
  let(:trail) do
    [crumb.new(title: 'Home', url: '/en'), crumb.new(title: 'About', url: '/en/about'),
     crumb.new(title: 'Mission', url: nil)]
  end

  before do
    view.extend(BetterTogether::BreadcrumbsHelper)
    allow(view).to receive(:base_url).and_return('https://example.test')
  end

  it 'renders a labelled nav with an ordered list and marks the current page' do
    render partial: 'better_together/shared/breadcrumbs', locals: { trail:, current_url: 'https://example.test/en/about/mission' }
    doc = Nokogiri::HTML(rendered)

    expect(doc.at_css('nav#breadcrumbs[aria-label]')).to be_present
    expect(doc.css('ol#breadcrumbs-list > li').size).to eq(3)
    expect(doc.css('a.bt-breadcrumb-link').map { |a| a['href'] }).to eq(['/en', '/en/about'])
    expect(doc.at_css('li.active[aria-current="page"]').text.strip).to eq('Mission')
    expect(doc.at_css('script#breadcrumbs-json-ld[type="application/ld+json"]')).to be_present
  end

  it 'renders nothing for a single-entry trail' do
    render partial: 'better_together/shared/breadcrumbs', locals: { trail: trail.first(1), current_url: 'x' }

    expect(rendered.strip).to be_empty
  end
end
