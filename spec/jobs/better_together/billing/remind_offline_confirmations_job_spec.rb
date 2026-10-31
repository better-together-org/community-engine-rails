# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::RemindOfflineConfirmationsJob do
  include_context 'with offline payment fixtures'

  let(:order) { place_offline('cash') }
  let(:offline) { offline_for(order) }

  def run_job = deliver_now { described_class.perform_now }

  before do
    offline
    clear_notices
  end

  it 'runs on the billing queue' do
    expect(described_class.new.queue_name).to eq(BetterTogether::Billing::ApplicationJob.new.queue_name)
  end

  describe 'the seller' do
    it 'is reminded of a payment that has waited a day, whether or not the buyer claimed' do
      offline.update_columns(created_at: 2.days.ago) # rubocop:disable Rails/SkipsModelValidations

      run_job

      expect(kinds_for(steward)).to eq(['confirmation_reminder'])
      expect(kinds_for(other_steward)).to eq(['confirmation_reminder'])
      expect(offline.reload.last_reminded_at).to be_present
    end

    it 'is not reminded of a payment that is new' do
      run_job

      expect(kinds_for(steward)).to be_empty
    end

    it 'is reminded again the next day, but not twice in one day' do
      offline.update_columns(created_at: 3.days.ago) # rubocop:disable Rails/SkipsModelValidations
      run_job
      run_job
      expect(kinds_for(steward)).to eq(['confirmation_reminder'])

      travel_to(25.hours.from_now) { run_job }

      expect(kinds_for(steward)).to eq(%w[confirmation_reminder confirmation_reminder])
    end

    it 'is not reminded of a payment already dealt with' do
      offline.update_columns(created_at: 2.days.ago) # rubocop:disable Rails/SkipsModelValidations
      transition.receive(offline, by: other_steward)
      clear_notices

      run_job

      expect(kinds_for(steward)).to be_empty
    end
  end

  describe 'the buyer' do
    it 'is warned once when their hold is about to run out and they have not said they paid' do
      offline.update_columns(expires_at: 6.hours.from_now) # rubocop:disable Rails/SkipsModelValidations

      run_job
      run_job

      expect(kinds_for(buyer)).to eq(['hold_expiring'])
    end

    it 'is emailed even with emails off, since a lapsing hold is critical' do
      buyer.update!(notify_by_email: false)
      offline.update_columns(expires_at: 6.hours.from_now) # rubocop:disable Rails/SkipsModelValidations

      run_job

      expect(sent_mail.flat_map(&:to)).to include(buyer.email)
    end

    it 'is not warned when the hold is far off, already past, or they said they paid' do
      run_job
      expect(kinds_for(buyer)).to be_empty

      offline.update_columns(expires_at: 1.hour.ago) # rubocop:disable Rails/SkipsModelValidations
      run_job
      expect(kinds_for(buyer)).to be_empty

      offline.update_columns(expires_at: 6.hours.from_now) # rubocop:disable Rails/SkipsModelValidations
      transition.claim(offline.reload)
      clear_notices
      run_job
      expect(kinds_for(buyer)).to be_empty
    end
  end

  it 'never puts payment instructions or payee details in what it sends' do
    offline.update_columns(created_at: 2.days.ago, expires_at: 6.hours.from_now) # rubocop:disable Rails/SkipsModelValidations

    run_job

    sent = sent_mail.map { |mail| [mail.subject, mail.html_part&.body&.decoded, mail.text_part&.body&.decoded].join }.join
    inboxes = (inbox(buyer).to_a + inbox(steward).to_a).map do |notification|
      [notification.event.title, notification.event.body, notification.event.url].join
    end.join
    expect(sent + inboxes).not_to include('Alex', 'hall')
  end
end
