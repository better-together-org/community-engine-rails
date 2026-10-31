# frozen_string_literal: true

require 'rails_helper'

# Billing records are reached only through their platform (`platform.billing_plans`,
# `platform.billing_events`) or by a single id the caller already holds. A bare class-level
# read such as `Plan.all`, `Plan.where(...)` or `Event.order(...)` in a controller, policy
# or job is how one tenant ends up reading another's rows, so it fails here.
RSpec.describe 'Billing tenant isolation guard' do # rubocop:disable RSpec/DescribeClass
  let(:root) { BetterTogether::Engine.root }
  let(:guarded) do
    %w[app/controllers/better_together/billing app/controllers/concerns/better_together/billing
       app/policies/better_together/billing app/jobs/better_together/billing]
  end
  # `find` / `find_by(id:` take a single id the caller holds; the id is then used with the
  # record's own platform. Everything else on the class itself is a cross-tenant read.
  let(:bare_read) do
    /\b(?:Billing::)?
      (?:Plan|Event|ProcessorSetting|Order|OrderLine|OrderAgreementAcceptance|AgreementRequirement|NotificationReceipt|Payment|Refund)\.
      (?!find\(|find_by\(id:|permitted_attributes|assignable_owner_types|new\b|name\b|model_name\b)\w+/x
  end
  let(:pay_read) { /\bPay::(?:Customer|Subscription|Charge)\.(?!find\(|find_by\(id:)\w+/ }
  # Maintenance sweeps are the only cross-tenant operations; each acts on one record at a time.
  let(:sweep_jobs) { %w[dead_letter_stale_billing_events_job redact_expired_event_payloads_job prune_stale_pay_webhooks_job expire_orders_job] }

  def guarded_files
    guarded.flat_map { |dir| Dir[root.join(dir, '**/*.rb')] }.sort
  end

  def code_lines(file)
    File.readlines(file).each_with_index.reject { |line, _| line.strip.start_with?('#') }
  end

  it 'would catch a bare read (the pattern itself is checked)' do
    expect(bare_read.match?('Plan.where(active: true)')).to be(true)
    expect(bare_read.match?('BetterTogether::Billing::Event.all')).to be(true)
    expect(bare_read.match?('billing_owner.billing_plans.find(id)')).to be(false)
    expect(bare_read.match?('Plan.find(params[:id])')).to be(false)
    expect(bare_read.match?('Billing::ProcessorSetting.enabled')).to be(true)
    expect(bare_read.match?('Billing::Order.where(id: 1)')).to be(true)
    expect(bare_read.match?('Payment.find(id)')).to be(false)
    expect(pay_read.match?('Pay::Customer.where(id: 1)')).to be(true)
  end

  it 'finds the files it guards' do
    expect(guarded_files).not_to be_empty
  end

  it 'has no bare class-level Plan/Event reads in controllers, policies or non-sweep jobs' do
    offenders = guarded_files.reject { |file| sweep_jobs.include?(File.basename(file, '.rb')) }.flat_map do |file|
      code_lines(file).filter_map do |line, index|
        "#{file.delete_prefix("#{root}/")}:#{index + 1}: #{line.strip}" if line.match?(bare_read)
      end
    end

    expect(offenders).to eq([])
  end

  it 'has no unscoped Plan or Event class reads through Pay either' do
    offenders = guarded_files.flat_map do |file|
      code_lines(file).filter_map do |line, index|
        "#{file.delete_prefix("#{root}/")}:#{index + 1}: #{line.strip}" if line.match?(pay_read)
      end
    end

    expect(offenders).to eq([])
  end

  it 'never resolves a class from a string in the billing controllers' do
    offenders = guarded_files.select { |file| File.read(file).match?(/\b(?:safe_)?constantize\b/) }

    expect(offenders).to eq([])
  end

  it 'reaches plans in controllers only through the billing owner' do
    controller = root.join('app/controllers/better_together/billing/plans_controller.rb').read

    expect(controller).to include('billing_owner.billing_plans')
  end
end
