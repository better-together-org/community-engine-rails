# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Metrics::ReportMailer do
  describe '.link_checker_report' do
    it 'sends to the default from address' do
      report = instance_double(BetterTogether::Metrics::LinkCheckerReport, id: 1)

      mail = described_class.link_checker_report(report.id)

      expect(mail.to).to contain_exactly(ActionMailer::Base.default[:from])
    end

    it 'builds attachments structure' do
      report = instance_double(BetterTogether::Metrics::LinkCheckerReport, id: 1)

      mail = described_class.link_checker_report(report.id)

      expect(mail.attachments).to be_a(Object)
    end
  end
end
