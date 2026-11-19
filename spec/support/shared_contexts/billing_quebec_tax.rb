# frozen_string_literal: true

# Needs 'with orders fixtures'. A Quebec sale: GST (5%) under the federal number, QST (9.975%) under Quebec's own.
RSpec.shared_context 'with quebec tax' do
  let(:quebec_address) { { country_iso: 'CA', region_code: 'QC' } }

  before do
    create(:better_together_billing_tax_registration, platform: host_platform, country_iso: 'CA', registration_number: '123456789RT0001')
    create(:better_together_billing_tax_registration, platform: host_platform, country_iso: 'CA', region_code: 'QC',
                                                      registration_number: '1234567890TQ0001')
    create(:better_together_billing_tax_rate, platform: host_platform, label: 'GST', rate: 0.05,
                                              tax_zone: create(:better_together_billing_tax_zone, platform: host_platform, country_iso: 'CA'))
    create(:better_together_billing_tax_rate, platform: host_platform, label: 'QST', rate: 0.09975,
                                              tax_zone: create(:better_together_billing_tax_zone, platform: host_platform, country_iso: 'CA',
                                                                                                  region_code: 'QC'))
  end
end
