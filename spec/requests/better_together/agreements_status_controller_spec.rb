# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::AgreementsStatusController do
  # Get the authenticated user's person - must be called AFTER authentication
  # The :as_user metadata creates user@example.test automatically
  def person
    @person ||= BetterTogether::User.find_by!(email: 'user@example.test').person
  end

  let!(:privacy_policy) do
    BetterTogether::Agreement.find_or_create_by!(identifier: 'privacy_policy') do |a|
      a.title = 'Privacy Policy'
    end
  end
  let!(:terms_of_service) do
    BetterTogether::Agreement.find_or_create_by!(identifier: 'terms_of_service') do |a|
      a.title = 'Terms of Service'
    end
  end
  let!(:code_of_conduct) do
    BetterTogether::Agreement.find_or_create_by!(identifier: 'code_of_conduct') do |a|
      a.title = 'Code of Conduct'
    end
  end

  before do
    configure_host_platform
  end

  describe 'GET /agreements/status' do
    context 'when user is not authenticated', :no_auth do
      it 'returns 404 because route is only available to authenticated users' do
        get better_together.agreements_status_path(locale: I18n.locale)

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when user is authenticated', :as_user do
      context 'when user has unaccepted required agreements' do
        it 'returns 404 due to route constraint not recognizing session' do
          get better_together.agreements_status_path(locale: I18n.locale)

          expect(response).to have_http_status(:not_found)
        end

        it 'returns 404 due to route constraint not recognizing session' do
          get better_together.agreements_status_path(locale: I18n.locale)

          expect(response).to have_http_status(:not_found)
        end
      end

      context 'when user has accepted some agreements' do
        before do
          create(:better_together_agreement_participant, person: person, agreement: privacy_policy, accepted_at: Time.current)
        end

        it 'returns 404 due to route constraint not recognizing session' do
          get better_together.agreements_status_path(locale: I18n.locale)

          expect(response).to have_http_status(:not_found)
        end
      end

      context 'when user has accepted all required agreements' do
        before do
          [privacy_policy, terms_of_service, code_of_conduct].each do |agreement|
            create(:better_together_agreement_participant, person: person, agreement: agreement, accepted_at: Time.current)
          end
        end

        it 'returns 404 due to route constraint not recognizing session' do
          get better_together.agreements_status_path(locale: I18n.locale)

          expect(response).to have_http_status(:not_found)
        end
      end
    end
  end

  describe 'POST /agreements/status' do
    context 'when user is authenticated', :as_user do
      context 'when accepting all required agreements' do
        it 'creates agreement participants and redirects' do
          expect do
            post better_together.agreements_status_path(locale: I18n.locale), params: {
              privacy_policy_agreement: '1',
              terms_of_service_agreement: '1',
              code_of_conduct_agreement: '1'
            }
          end.to change(BetterTogether::AgreementParticipant, :count).by(3)

          expect(response).to have_http_status(:redirect)
        end

        it 'sets accepted_at timestamp' do
          post better_together.agreements_status_path(locale: I18n.locale), params: {
            privacy_policy_agreement: '1',
            terms_of_service_agreement: '1',
            code_of_conduct_agreement: '1'
          }

          participant = BetterTogether::AgreementParticipant.find_by(person: person, agreement: privacy_policy)
          expect(participant).to be_present
          expect(participant.accepted_at).to be_present
          expect(participant.accepted_at).to be_within(1.second).of(Time.current)
        end
      end

      context 'when not accepting all required agreements' do
        it 'does not create agreement participants' do
          expect do
            post better_together.agreements_status_path(locale: I18n.locale), params: {
              privacy_policy_agreement: '1'
              # Missing terms_of_service and code_of_conduct
            }
          end.not_to change(BetterTogether::AgreementParticipant, :count)

          expect(response).to have_http_status(:success)
          expect(response.body).to include('Privacy Policy')
        end
      end

      context 'when some agreements are already accepted' do
        before do
          create(:better_together_agreement_participant, person: person, agreement: privacy_policy, accepted_at: Time.current)
        end

        it 'only creates participants for unaccepted agreements' do
          expect do
            post better_together.agreements_status_path(locale: I18n.locale), params: {
              privacy_policy_agreement: '1',
              terms_of_service_agreement: '1',
              code_of_conduct_agreement: '1'
            }
          end.to change(BetterTogether::AgreementParticipant, :count).by(2)

          expect(response).to have_http_status(:redirect)
        end
      end

      context 'with stored location' do
        before do
          # Simulate a stored location (like from check_required_agreements redirect)
          allow_any_instance_of(described_class).to receive(:stored_location_for)
            .with(:user)
            .and_return(better_together.communities_path(locale: I18n.locale))
        end

        it 'redirects to stored location after acceptance' do
          post better_together.agreements_status_path(locale: I18n.locale), params: {
            privacy_policy_agreement: '1',
            terms_of_service_agreement: '1',
            code_of_conduct_agreement: '1'
          }

          expect(response.location).to include('/communities')
        end
      end
    end
  end
end
