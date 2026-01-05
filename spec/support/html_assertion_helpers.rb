# frozen_string_literal: true

# HtmlAssertionHelpers - Robust HTML content assertions for request specs
#
# This module provides helpers for checking HTML content that properly handle
# HTML entity escaping (e.g., apostrophes ' → &#39; or &apos;).
#
# The key issue: expect(response.body).to include(person.name) fails when
# person.name is "O'Brien" because HTML renders it as "O&#39;Brien".
#
# Solution: Parse HTML with Nokogiri and check text content, which automatically
# handles entity decoding.
#
# Usage:
#   # Instead of:
#   expect(response.body).to include(person.name)
#
#   # Use:
#   expect_html_content(person.name)
#
#   # Or directly:
#   expect(response_text).to include(person.name)
#
# @example Multiple checks
#   expect_html_contents(person.name, role.name, event.name)
#
# @example Element-specific
#   expect_element_content('.member-name', person.name)
#
# @example Custom assertions
#   expect(response_text).to include("O'Brien")
#   expect(parsed_response.css('.member').count).to eq(5)
#
module HtmlAssertionHelpers
  # Parse response HTML once and cache for reuse within the same test
  #
  # @return [Nokogiri::HTML::Document] Parsed HTML document
  # @example
  #   parsed = parsed_response
  #   member_count = parsed.css('.member').count
  def parsed_response
    @parsed_response ||= Nokogiri::HTML(response.body)
  end

  # Get text content from parsed HTML (handles entity escaping automatically)
  #
  # @return [String] Plain text content with HTML entities decoded
  # @example
  #   expect(response_text).to include("O'Brien")  # Works even if HTML has O&#39;Brien
  def response_text
    parsed_response.text
  end

  # Check if HTML content includes text (handles entity escaping)
  #
  # @param text [String] Text to search for (unescaped)
  # @example
  #   expect_html_content(person.name)  # Works with apostrophes
  def expect_html_content(text)
    expect(response_text).to include(text)
  end

  # Check if HTML content does not include text (handles entity escaping)
  #
  # @param text [String] Text that should not be present
  # @example
  #   expect_no_html_content(private_user.name)
  def expect_no_html_content(text)
    expect(response_text).not_to include(text)
  end

  # Check multiple texts in one call (all must be present)
  #
  # @param texts [Array<String>] Multiple texts to check
  # @example
  #   expect_html_contents(member1.name, member2.name, member3.name)
  def expect_html_contents(*texts)
    text_content = response_text
    texts.each do |text|
      expect(text_content).to include(text),
                              "Expected HTML to include '#{text}' but it was not found"
    end
  end

  # Check if none of the provided texts are present
  #
  # @param texts [Array<String>] Multiple texts that should not be present
  # @example
  #   expect_no_html_contents(private_user1.name, private_user2.name)
  def expect_no_html_contents(*texts)
    text_content = response_text
    texts.each do |text|
      expect(text_content).not_to include(text),
                                  "Expected HTML not to include '#{text}' but it was found"
    end
  end

  # Check element text content by CSS selector
  #
  # @param selector [String] CSS selector
  # @param text [String] Expected text content
  # @raise [RSpec::Expectations::ExpectationNotMetError] if element not found
  # @example
  #   expect_element_content('.member-name', person.name)
  def expect_element_content(selector, text)
    element = parsed_response.at_css(selector)
    expect(element).to be_present, "Element '#{selector}' not found in HTML"
    expect(element.text).to include(text),
                            "Expected element '#{selector}' to include '#{text}' but found: #{element.text.strip}"
  end

  # Check if element exists with specific text (searches multiple elements)
  #
  # @param selector [String] CSS selector (may match multiple elements)
  # @param text [String] Text to find within matching elements
  # @raise [RSpec::Expectations::ExpectationNotMetError] if no matching element found
  # @example
  #   expect_element_with_text('.member-card', person.name)
  def expect_element_with_text(selector, text)
    elements = parsed_response.css(selector)
    expect(elements).not_to be_empty, "No elements found matching '#{selector}'"

    matching = elements.find { |el| el.text.include?(text) }
    expect(matching).to be_present,
                        "Expected to find element '#{selector}' containing '#{text}' but none found. " \
                        "Checked #{elements.count} elements."
  end

  # Check that element does NOT contain specific text
  #
  # @param selector [String] CSS selector
  # @param text [String] Text that should not be present
  # @example
  #   expect_element_without_text('.member-list', private_user.name)
  def expect_element_without_text(selector, text)
    element = parsed_response.at_css(selector)
    return if element.nil? # Element not present means text definitely not there

    expect(element.text).not_to include(text),
                                "Expected element '#{selector}' not to include '#{text}' but it was found"
  end

  # Check count of elements matching selector
  #
  # @param selector [String] CSS selector
  # @param count [Integer] Expected count
  # @example
  #   expect_element_count('.member-row', 5)
  def expect_element_count(selector, count)
    elements = parsed_response.css(selector)
    expect(elements.count).to eq(count),
                              "Expected #{count} elements matching '#{selector}' but found #{elements.count}"
  end

  # Get all text contents from elements matching selector
  #
  # @param selector [String] CSS selector
  # @return [Array<String>] Text content of each matching element
  # @example
  #   member_names = element_texts('.member-name')
  #   expect(member_names).to include(person.name)
  def element_texts(selector)
    parsed_response.css(selector).map(&:text)
  end
end

RSpec.configure do |config|
  # Include helpers in request specs
  config.include HtmlAssertionHelpers, type: :request

  # Clear cached parsed response after each test to prevent cross-test pollution
  config.after(:each, type: :request) do
    @parsed_response = nil
  end
end
