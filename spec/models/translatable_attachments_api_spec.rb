# frozen_string_literal: true

# rubocop:disable RSpec/ExampleLength, RSpec/DescribeClass

require 'rails_helper'

RSpec.describe 'Translatable Attachments API parity' do
  before do
    # Create a temporary table for the dummy model
    ActiveRecord::Base.connection.create_table(:translatable_attachment_dummies, id: :uuid) do |t|
      t.string :dummy
    end

    dummy = Class.new(ActiveRecord::Base) do
      self.table_name = 'translatable_attachment_dummies'
      extend Mobility::DSL::Attachments

      translates_attached :hero_image
    end
    stub_const('TranslatableAttachmentDummy', dummy)
  end

  after do
    drop_table :translatable_attachment_dummies
  rescue StandardError
    nil
  end

  let(:model_class) { TranslatableAttachmentDummy }
  let(:locales) do
    Mobility.available_locales
  rescue StandardError
    I18n.available_locales
  end

  it 'defines locale-specific and non-locale accessors' do
    locales.each do |locale|
      la = Mobility.normalize_locale_accessor('hero_image', locale)
      expect(model_class).to be_method_defined(la)
      expect(model_class).to be_method_defined("#{la}=")
      expect(model_class).to be_method_defined("#{la}?")
      expect(model_class).to be_method_defined("#{la}_url")
    end

    # Non-locale delegating methods should be present
    expect(model_class).to be_method_defined('hero_image')
    expect(model_class).to be_method_defined('hero_image=')
    expect(model_class).to be_method_defined('hero_image?')
    expect(model_class).to be_method_defined('hero_image_url')
  end

  it 'delegates non-locale accessors to current Mobility.locale' do
    instance = TranslatableAttachmentDummy.new
    # No attachments yet
    expect(instance.hero_image).to be_nil
    expect(instance).not_to be_hero_image

    # Simulate attaching via locale writer: this is a smoke test for method dispatch
    # We won't create an actual blob here; just ensure no NoMethodError and methods route
    expect { instance.hero_image_en = nil }.not_to raise_error
    expect { instance.hero_image = nil }.not_to raise_error
  end
end

# rubocop:enable RSpec/ExampleLength, RSpec/MultipleExpectations, RSpec/DescribeClass
