# frozen_string_literal: true

# MailerHtmlHelpers - Robust HTML content assertions for mailer specs
#
# This module provides helpers for checking mailer HTML content that properly handle
# HTML entity escaping (e.g., apostrophes ' → &#39; or &apos;).
#
# The key issue: expect(mail.body.encoded).to include(event.name) fails when
# event.name contains an apostrophe because HTML renders it as &#39;.
#
# Solution: Parse HTML with Nokogiri and check text content, which automatically
# handles entity decoding.
#
# Usage in mailer specs:
#   # Instead of:
#   expect(mail.body.encoded).to include(event.name)
#
#   # Use:
#   expect_mail_html_content(mail, event.name)
#
#   # Or multiple checks:
#   expect_mail_html_contents(mail, event.name, event.location_display_name)
#
# @example Basic usage
#   let(:mail) { EventMailer.with(event: event).event_reminder }
#
#   it 'includes event details' do
#     expect_mail_html_content(mail, event.name)  # Works with apostrophes
#   end
#
# @example Multiple checks
#   expect_mail_html_contents(mail, event.name, person.name, location.name)
#
module MailerHtmlHelpers
  # Initialize hash to compare by identity for proper caching
  def initialize
    super
    @parsed_mail_bodies = {}.compare_by_identity
  end

  # Parse mailer HTML body and cache for reuse
  #
  # @param mail [Mail::Message] The mail object
  # @return [Nokogiri::HTML::Document] Parsed HTML document
  def parsed_mail_body(mail)
    @parsed_mail_bodies ||= {}.compare_by_identity
    @parsed_mail_bodies[mail] ||= Nokogiri::HTML(mail.body.encoded)
  end

  # Get text content from mailer HTML (handles entity escaping automatically)
  #
  # @param mail [Mail::Message] The mail object
  # @return [String] Plain text content with HTML entities decoded
  # @example
  #   expect(mail_text(mail)).to include("O'Brien")  # Works even if HTML has O&#39;Brien
  def mail_text(mail)
    parsed_mail_body(mail).text
  end

  # Check if mailer HTML includes text (handles entity escaping)
  #
  # @param mail [Mail::Message] The mail object
  # @param text [String] Text to search for (unescaped)
  # @example
  #   expect_mail_html_content(mail, event.name)  # Works with apostrophes
  def expect_mail_html_content(mail, text)
    expect(mail_text(mail)).to include(text)
  end

  # Check if mailer HTML does not include text (handles entity escaping)
  #
  # @param mail [Mail::Message] The mail object
  # @param text [String] Text that should not be present
  # @example
  #   expect_no_mail_html_content(mail, private_info)
  def expect_no_mail_html_content(mail, text)
    expect(mail_text(mail)).not_to include(text)
  end

  # Check multiple texts in mailer (all must be present)
  #
  # @param mail [Mail::Message] The mail object
  # @param texts [Array<String>] Multiple texts to check
  # @example
  #   expect_mail_html_contents(mail, event.name, location.name)
  def expect_mail_html_contents(mail, *texts)
    text_content = mail_text(mail)
    texts.each do |text|
      expect(text_content).to include(text),
                              "Expected mail HTML to include '#{text}' but it was not found"
    end
  end

  # Check if none of the provided texts are in mailer
  #
  # @param mail [Mail::Message] The mail object
  # @param texts [Array<String>] Multiple texts that should not be present
  # @example
  #   expect_no_mail_html_contents(mail, private1, private2)
  def expect_no_mail_html_contents(mail, *texts)
    text_content = mail_text(mail)
    texts.each do |text|
      expect(text_content).not_to include(text),
                                  "Expected mail HTML not to include '#{text}' but it was found"
    end
  end

  # Check element text content in mailer by CSS selector
  #
  # @param mail [Mail::Message] The mail object
  # @param selector [String] CSS selector
  # @param text [String] Expected text content
  # @example
  #   expect_mail_element_content(mail, '.event-name', event.name)
  def expect_mail_element_content(mail, selector, text)
    element = parsed_mail_body(mail).at_css(selector)
    expect(element).to be_present, "Element '#{selector}' not found in mail"
    expect(element.text).to include(text)
  end

  # Count matching elements in mailer
  #
  # @param mail [Mail::Message] The mail object
  # @param selector [String] CSS selector
  # @param count [Integer] Expected count
  # @example
  #   expect_mail_element_count(mail, '.attendee', 5)
  def expect_mail_element_count(mail, selector, count)
    actual_count = parsed_mail_body(mail).css(selector).count
    expect(actual_count).to eq(count),
                            "Expected #{count} '#{selector}' elements but found #{actual_count}"
  end

  # Get array of text from matching elements in mailer
  #
  # @param mail [Mail::Message] The mail object
  # @param selector [String] CSS selector
  # @return [Array<String>] Array of text content
  # @example
  #   names = mail_element_texts(mail, '.member-name')
  #   expect(names).to include(person.name)
  def mail_element_texts(mail, selector)
    parsed_mail_body(mail).css(selector).map(&:text)
  end
end

RSpec.configure do |config|
  config.include MailerHtmlHelpers, type: :mailer
end
