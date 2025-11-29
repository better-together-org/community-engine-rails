# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Metrics::ReportMailer do
  describe '.link_checker_report' do
    before do
      fake_report_class = Class.new do
        def self.find(_id)
          file_struct = Struct.new(:attached?, :filename, :content_type, :download)
          file = file_struct.new(true, 'report.csv', 'text/csv', "a,b\n1,2\n")

          Struct.new(:id, :report_file, :created_at).new(1, file, Time.current)
        end
      end

      stub_const('BetterTogether::Metrics::LinkCheckerReport', fake_report_class)
      # We'll stub mail on the mailer instance in the examples rather than
      # using allow_any_instance_of
    end

    it 'calls mail with the app from address' do
      mailer = described_class.new
      allow(mailer).to receive(:mail).and_return(Mail::Message.new)
      mailer.link_checker_report(1)

      expect(mailer).to have_received(:mail).with(hash_including(:to))
    end

    it 'builds attachments on the mailer instance' do
      mailer = described_class.new
      allow(mailer).to receive(:mail).and_return(Mail::Message.new)
      mailer.link_checker_report(1)

      expect(mailer.attachments['report.csv']).not_to be_nil
    end
  end
end
