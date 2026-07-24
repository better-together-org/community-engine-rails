# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Users::RegistrationsController, :skip_host_setup, :user_registration do
  include BetterTogether::CapybaraFeatureHelpers

  routes { BetterTogether::Engine.routes }

  before do
    configure_host_platform
  end

  describe 'captcha hook methods', :no_auth do
    describe '#validate_captcha_if_enabled?' do
      let(:controller_instance) { described_class.new }

      it 'returns true by default (no captcha validation)' do
        expect(controller_instance.send(:validate_captcha_if_enabled?)).to be true
      end
    end

    describe '#handle_captcha_validation_failure' do
      let(:user) { build(:better_together_user) }
      let(:controller_instance) { described_class.new }

      before do
        allow(controller_instance).to receive(:respond_with)
      end

      it 'adds error to resource and calls respond_with' do
        controller_instance.send(:handle_captcha_validation_failure, user)

        expect(user.errors[:base]).to include('Security verification failed. Please try again.')
        expect(controller_instance).to have_received(:respond_with).with(user)
      end
    end
  end

  describe 'host community membership setup', :no_auth do
    let(:person) { create(:better_together_person) }
    let(:user) { build(:better_together_user) }
    let(:host_community) { BetterTogether::Community.find_by!(host: true) }
    let(:community_role) { BetterTogether::Role.find_by!(identifier: 'community_member') }

    before do
      allow(controller).to receive(:determine_community_role_from_invitations).and_return(community_role)
    end

    it 'creates an active host community membership for open registration' do
      host_community.update!(allow_membership_requests: false)

      expect do
        controller.send(:setup_community_membership, user, person)
      end.to change(BetterTogether::PersonCommunityMembership, :count).by(1)

      membership = host_community.person_community_memberships.find_by!(member: person, role: community_role)
      expect(membership.status).to eq('active')
    end

    it 'keeps request-mode host community registrations pending without an invitation' do
      host_platform = BetterTogether::Platform.find_by!(host: true)
      host_platform.update!(allow_membership_requests: true)
      host_community.update!(allow_membership_requests: true)

      expect do
        controller.send(:setup_community_membership, user, person)
      end.to change(BetterTogether::PersonCommunityMembership, :count).by(1)

      membership = host_community.person_community_memberships.find_by!(member: person, role: community_role)
      expect(membership.status).to eq('pending')
    end

    it 'activates an invited registration even when the host community accepts requests' do
      host_platform = BetterTogether::Platform.find_by!(host: true)
      host_platform.update!(allow_membership_requests: true)
      host_community.update!(allow_membership_requests: true)
      controller.instance_variable_set(:@platform_invitation, build_stubbed(:better_together_platform_invitation))

      expect do
        controller.send(:setup_community_membership, user, person)
      end.to change(BetterTogether::PersonCommunityMembership, :count).by(1)

      membership = host_community.person_community_memberships.find_by!(member: person, role: community_role)
      expect(membership.status).to eq('active')
    end

    it 'reactivates an existing pending host community membership when the desired status is active' do
      membership = create(
        :better_together_person_community_membership,
        joinable: host_community,
        member: person,
        role: community_role,
        status: 'pending'
      )

      expect do
        controller.send(:setup_community_membership, user, person)
      end.not_to change(BetterTogether::PersonCommunityMembership, :count)

      expect(membership.reload.status).to eq('active')
    end
  end

  # Integration test for the complete captcha flow will be handled in feature specs
end
