# frozen_string_literal: true

# Billing notifications for orders: a buyer, two stewards of the host platform, and the helpers to run
# the deliveries a notification enqueues.
RSpec.shared_context 'with billing notifications' do
  include_context 'with orders fixtures'
  include ActiveJob::TestHelper

  let(:password) { 'SecureTest123!@#' }
  let(:buyer_user) { find_or_create_test_user("notify-buyer-#{SecureRandom.hex(4)}@example.test", password) }
  let(:steward_user) { find_or_create_test_user("notify-steward-#{SecureRandom.hex(4)}@example.test", password, :platform_manager) }
  let(:other_steward_user) { find_or_create_test_user("notify-steward2-#{SecureRandom.hex(4)}@example.test", password, :platform_manager) }
  let(:buyer) { buyer_user.person }
  let(:steward) { steward_user.person }
  let(:other_steward) { other_steward_user.person }

  # Runs a block and the deliveries it queued, returning what each person was sent.
  def deliver_now(&)
    perform_enqueued_jobs(&)
  end

  # Only billing notifications: people have others (a new membership, say) that are not our business here.
  def inbox(person)
    Noticed::Notification.joins(:event).where(recipient: person, noticed_events: { type: 'BetterTogether::Billing::Notifier' }).includes(:event)
  end

  def kinds_for(person) = inbox(person).map { |notification| notification.event.params['kind'] || notification.event.params[:kind] }

  def sent_mail = ActionMailer::Base.deliveries
end
