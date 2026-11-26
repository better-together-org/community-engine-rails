# frozen_string_literal: true

require 'rails_helper'

# The names people read in billing are Mobility translations, one string per language.
RSpec.describe 'Billing translated attributes' do # rubocop:disable RSpec/DescribeClass
  it 'stores plan, category, zone, rate and promotion names in each language', :aggregate_failures do
    plan = create(:better_together_billing_plan, name: 'Member', name_fr: 'Membre', name_uk: 'Член')
    category = create(:better_together_billing_tax_category, name: 'Standard', name_fr: 'Standard fr')
    rate = create(:better_together_billing_tax_rate, label: 'GST', label_fr: 'TPS')

    expect(plan.name(locale: :fr)).to eq('Membre')
    expect(I18n.with_locale(:uk) { plan.name }).to eq('Член')
    expect(category.name(locale: :fr)).to eq('Standard fr')
    expect(I18n.with_locale(:fr) { rate.label }).to eq('TPS')
  end

  it 'keeps short strings in the string table and long copy in the text table', :aggregate_failures do
    plan = create(:better_together_billing_plan, description: 'Long copy', name: 'Short')

    expect(Mobility::Backends::ActiveRecord::KeyValue::StringTranslation.where(translatable: plan, key: 'name')).to exist
    expect(Mobility::Backends::ActiveRecord::KeyValue::TextTranslation.where(translatable: plan, key: 'description')).to exist
  end

  it 'makes translated plan fields writable per language in strong parameters', :aggregate_failures do
    keys = BetterTogether::Billing::Plan.permitted_attributes_for_create

    expect(keys).to include(:name, :name_fr, :description_uk, :participant_benefits_es, :solidarity_description_fr)
  end

  it 'defaults new translated attributes to strings', :aggregate_failures do
    untyped = Class.new(BetterTogether::ApplicationRecord) do
      self.table_name = 'better_together_billing_tax_categories'
      include BetterTogether::Translatable

      translates :name
    end

    expect(untyped.mobility_backend_class(:name).options[:type]).to eq(:string)
    expect(BetterTogether::AgreementTerm.mobility_backend_class(:summary).options[:type]).to eq(:text)
  end

  it 'gives billing records a readable name and a cache key that changes with the language', :aggregate_failures do
    plan = create(:better_together_billing_plan, name: 'Member')

    expect(plan.to_s).to eq('Member')
    expect(I18n.with_locale(:fr) { plan.cache_key }).not_to eq(I18n.with_locale(:en) { plan.cache_key })
  end

  it 'resolves a platform language' do
    expect(BetterTogether::Billing.platform_locale(nil)).to eq(I18n.default_locale)
  end
end
