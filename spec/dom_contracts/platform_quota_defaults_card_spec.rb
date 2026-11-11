# frozen_string_literal: true

require 'rails_helper'

# DOM contract for the "Quota defaults" card on the platform edit form. Docs screenshot
# specs and feature specs target these identifiers.
RSpec.describe 'Platform quota defaults card DOM contract', :as_platform_manager, type: :request do # rubocop:disable RSpec/DescribeClass
  let(:host_platform) { BetterTogether::Platform.find_by(host: true) }

  it 'renders the card, one fieldset per quota type and one input per owner kind' do # rubocop:disable RSpec/MultipleExpectations
    get better_together.edit_platform_path(locale: I18n.default_locale, id: host_platform.slug)

    body = response.body
    expect(body).to include("id=\"#{ActionView::RecordIdentifier.dom_id(host_platform, :quota_defaults)}\"")
    BetterTogether::Quotas::Type.registry.each_key do |type|
      expect(body).to include("id=\"#{ActionView::RecordIdentifier.dom_id(host_platform, "quota_defaults_#{type}")}\"")
      BetterTogether::Quotas::Defaults::OWNER_KINDS.each do |kind|
        expect(body).to include("name=\"platform[quota_default_limits][#{type}][#{kind}]\"")
      end
    end
  end

  it 'offers byte quotas as a slim-select of binary sizes with the override selected' do # rubocop:disable RSpec/MultipleExpectations
    host_platform.update!(quota_default_limits: { 'media_storage' => { 'person' => '536870912' } })

    get better_together.edit_platform_path(locale: I18n.default_locale, id: host_platform.slug)

    select = parsed_response.at_css('select[name="platform[quota_default_limits][media_storage][person]"]')
    expect(select['data-controller']).to eq('better_together--slim-select')
    expect(select.at_css('option[selected]').text).to eq('512 MiB')
    expect(select.css('option').map(&:text)).to include('Use default (250 MiB)', '250 MiB', '1 GiB', '1 TiB')
  end

  it 'is not rendered for an external platform' do
    external = create(:better_together_platform, :external)

    get better_together.edit_platform_path(locale: I18n.default_locale, id: external.slug)

    expect(response.body).not_to include(ActionView::RecordIdentifier.dom_id(external, :quota_defaults))
  end
end
