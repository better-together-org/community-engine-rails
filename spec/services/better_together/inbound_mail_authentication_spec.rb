# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::InboundMailAuthentication do
  def trusted
    'mail.communityengine.app'
  end

  def mail_with_headers(*header_lines)
    Mail.new(<<~MAIL)
      From: sender@example.test
      To: agent+someone@communityengine.app
      Subject: Test
      #{header_lines.join("\n")}
      Content-Type: text/plain

      Body
    MAIL
  end

  describe '#spf_result' do
    it 'reads the leading token from Received-SPF' do
      mail = mail_with_headers('Received-SPF: Pass (mailfrom) identity=mailfrom')
      auth = described_class.new(mail, trusted_authserv_id: trusted)
      expect(auth.spf_result).to eq(:pass)
    end

    it 'maps Softfail to :softfail' do
      mail = mail_with_headers('Received-SPF: Softfail (mailfrom) identity=mailfrom')
      auth = described_class.new(mail, trusted_authserv_id: trusted)
      expect(auth.spf_result).to eq(:softfail)
    end

    it 'maps Fail to :fail' do
      mail = mail_with_headers('Received-SPF: Fail (mailfrom) identity=mailfrom')
      auth = described_class.new(mail, trusted_authserv_id: trusted)
      expect(auth.spf_result).to eq(:fail)
    end

    it 'is :unknown when the header is absent' do
      mail = mail_with_headers
      auth = described_class.new(mail, trusted_authserv_id: trusted)
      expect(auth.spf_result).to eq(:unknown)
    end

    it 'is :unknown when no mail is given' do
      auth = described_class.new(nil, trusted_authserv_id: trusted)
      expect(auth.spf_result).to eq(:unknown)
    end
  end

  describe '#dkim_result and #dmarc_result' do
    it 'reads dkim= and dmarc= from separate trusted Authentication-Results instances' do
      mail = mail_with_headers(
        "Authentication-Results: #{trusted}; dkim=pass header.d=example.test",
        "Authentication-Results: #{trusted}; dmarc=fail (p=reject) header.from=example.test"
      )
      auth = described_class.new(mail, trusted_authserv_id: trusted)
      expect(auth.dkim_result).to eq(:pass)
      expect(auth.dmarc_result).to eq(:fail)
    end

    it 'reads both from a single combined Authentication-Results instance' do
      mail = mail_with_headers("Authentication-Results: #{trusted}; dkim=pass; dmarc=pass")
      auth = described_class.new(mail, trusted_authserv_id: trusted)
      expect(auth.dkim_result).to eq(:pass)
      expect(auth.dmarc_result).to eq(:pass)
    end

    it 'is :unknown when the header is absent' do
      mail = mail_with_headers
      auth = described_class.new(mail, trusted_authserv_id: trusted)
      expect(auth.dkim_result).to eq(:unknown)
      expect(auth.dmarc_result).to eq(:unknown)
    end

    it 'is :unknown when no trusted_authserv_id is configured, even with a real-looking header' do
      mail = mail_with_headers("Authentication-Results: #{trusted}; dkim=fail")
      auth = described_class.new(mail, trusted_authserv_id: nil)
      expect(auth.dkim_result).to eq(:unknown)
    end

    it 'ignores a forged Authentication-Results header with a mismatched authserv-id (anti-spoofing)' do
      mail = mail_with_headers('Authentication-Results: attacker-controlled-id; dkim=pass; dmarc=pass')
      auth = described_class.new(mail, trusted_authserv_id: trusted)
      expect(auth.dkim_result).to eq(:unknown)
      expect(auth.dmarc_result).to eq(:unknown)
    end

    it 'trusts only the matching instance when a forged header and the real one both exist' do
      mail = mail_with_headers(
        'Authentication-Results: attacker-controlled-id; dkim=pass; dmarc=pass',
        "Authentication-Results: #{trusted}; dkim=fail; dmarc=fail"
      )
      auth = described_class.new(mail, trusted_authserv_id: trusted)
      expect(auth.dkim_result).to eq(:fail)
      expect(auth.dmarc_result).to eq(:fail)
    end
  end

  describe '#hard_fail?' do
    it 'is true when any mechanism explicitly failed' do
      mail = mail_with_headers("Authentication-Results: #{trusted}; dkim=fail")
      auth = described_class.new(mail, trusted_authserv_id: trusted)
      expect(auth).to be_hard_fail
    end

    it 'is false when results are merely absent (most domains do not publish DKIM/DMARC)' do
      mail = mail_with_headers
      auth = described_class.new(mail, trusted_authserv_id: trusted)
      expect(auth).not_to be_hard_fail
    end

    it 'is false for softfail/neutral SPF results' do
      mail = mail_with_headers('Received-SPF: Softfail (mailfrom) identity=mailfrom')
      auth = described_class.new(mail, trusted_authserv_id: trusted)
      expect(auth).not_to be_hard_fail
    end

    it 'is false with no mail at all' do
      auth = described_class.new(nil, trusted_authserv_id: trusted)
      expect(auth).not_to be_hard_fail
    end
  end
end
