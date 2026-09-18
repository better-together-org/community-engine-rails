# frozen_string_literal: true

# Test helpers for specs covering agreement-gated self-service creation.
module AgreementTestHelpers # :nodoc:
  # Records acceptance of the content publishing agreement for the given
  # participant (Person or Robot). Matches the idiom already used in
  # spec/requests/better_together/communities_controller_spec.rb for granting
  # the community creation agreement.
  def grant_content_publishing_agreement(participant)
    agreement = BetterTogether::Agreement.find_or_create_by!(
      identifier: BetterTogether::PublicVisibilityGate::AGREEMENT_IDENTIFIER
    )
    BetterTogether::AgreementParticipant.find_or_create_by!(
      agreement: agreement, participant: participant
    ) { |p| p.accepted_at = Time.current }
  end

  # Records acceptance of the community creation agreement for the given
  # participant (Person or Robot).
  def grant_community_creation_agreement(participant)
    agreement = BetterTogether::Agreement.find_or_create_by!(
      identifier: BetterTogether::ChecksRequiredAgreements::COMMUNITY_CREATION_AGREEMENT_IDENTIFIER
    )
    BetterTogether::AgreementParticipant.find_or_create_by!(
      agreement: agreement, participant: participant
    ) { |p| p.accepted_at = Time.current }
  end
end

RSpec.configure do |config|
  config.include AgreementTestHelpers
end
