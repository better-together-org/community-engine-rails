# frozen_string_literal: true

# Agreement rows survive :deletion cleanup, so a :js/:feature spec that activated the seeded purchase
# agreements leaves them active for later examples. Seeds plant drafts, so put them back.
module BillingAgreementLeakReset
  module_function

  def call
    leaked = BetterTogether::Agreement.where(agreement_kind: 'transactional_agreement').where.not(lifecycle_state: 'draft')
    leaked.update_all(lifecycle_state: 'draft') if leaked.exists? # rubocop:disable Rails/SkipsModelValidations
  end
end
