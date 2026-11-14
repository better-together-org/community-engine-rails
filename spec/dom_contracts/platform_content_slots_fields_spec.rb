# frozen_string_literal: true

require 'rails_helper'

# DOM contract for the content slot fields in the platform Appearance tab. Docs screenshot
# specs target these identifiers.
RSpec.describe 'Platform content slots fields DOM contract', :as_platform_manager, type: :request do # rubocop:disable RSpec/DescribeClass
  let(:host_platform) { BetterTogether::Platform.find_by(host: true) }

  it 'renders one fieldset per slot inside the Appearance pane, beside the Css block' do # rubocop:disable RSpec/MultipleExpectations
    get better_together.edit_platform_path(locale: I18n.default_locale, id: host_platform.slug)
    doc = parsed_response

    expect(doc.at_css('#platform-appearance #platform-content-slots')).to be_present
    BetterTogether::PlatformContentSlots::SLOTS.each_key do |slot|
      scope = "platform[content_slot_blocks_attributes][#{slot}]"
      fieldset = doc.at_css("#platform-appearance #platform-content-slot-field-#{slot.to_s.dasherize}")
      expect(fieldset).to be_present
      expect(fieldset.at_css("input[name='#{scope}[type]']")).to be_present
      expect(fieldset.at_css("[name^='#{scope}[content_']")).to be_present
    end
    expect(doc.at_css('#platform-appearance [name^="platform[css_block_attributes]"]')).to be_present
  end

  it 'does not expose identifier or privacy inputs for slot blocks' do
    get better_together.edit_platform_path(locale: I18n.default_locale, id: host_platform.slug)

    expect(parsed_response.css('#platform-content-slots [name$="[identifier]"], #platform-content-slots [name$="[privacy]"]')).to be_empty
  end
end
