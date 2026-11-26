# frozen_string_literal: true

# Lets a spec treat a hosted platform as having agreed to the host's billing terms, without going through the screens.
module HostedBillingHelpers
  # Activates the host's hosted billing agreements and has `platform` accept them. `modes` defaults to billing and local.
  def grant_hosted_billing(platform, host: BetterTogether::Platform.find_by(host: true), modes: %i[billing local])
    agreements = BetterTogether::Billing::HostedAgreementSeeds.call(host)
    agreements.each_value { |agreement| agreement.update!(lifecycle_state: 'active') }
    modes.each { |mode| BetterTogether::Billing::HostedBilling.accept!(platform:, mode:, person: nil) }
    Current.billing_enabled = nil
  end
end

RSpec.configure { |config| config.include HostedBillingHelpers }
