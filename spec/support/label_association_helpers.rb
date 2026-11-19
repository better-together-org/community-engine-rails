# frozen_string_literal: true

require 'nokogiri'

# LabelAssociationHelpers - DOM contract checks that a rendered form is programmatically labelled.
#
# `expect_labels_resolved(html)` fails when a `label[for]` points at an id that is missing or
# repeated, or when a visible form control has no accessible name (WCAG 1.3.1 / 4.1.2).
# Pass `within:` (a CSS selector) to limit the check to one form.
module LabelAssociationHelpers
  UNNAMED_SKIP_TYPES = %w[hidden submit button image reset].freeze
  CONTROLS = 'input, select, textarea'

  def label_association_problems(html, within: nil)
    doc = html.is_a?(Nokogiri::XML::Node) ? html : Nokogiri::HTML(html)
    scope = within ? doc.css(within) : [doc]
    broken_label_targets(doc, scope) + unnamed_controls(doc, scope)
  end

  def expect_labels_resolved(html, within: nil)
    problems = label_association_problems(html, within:)

    expect(problems).to be_empty, "label association problems:\n#{problems.join("\n")}"
  end

  private

  def broken_label_targets(doc, scope)
    scope.flat_map { |node| node.css('label[for]').to_a }.filter_map do |label|
      count = doc.css('[id]').count { |el| el['id'] == label['for'] }
      "label for=#{label['for'].inspect} matches #{count} elements" unless count == 1
    end
  end

  def unnamed_controls(doc, scope)
    scope.flat_map { |node| node.css(CONTROLS).to_a }.select { |control| checked?(control) }.filter_map do |control|
      next if control_named?(doc, control)

      "control #{control.name}[name=#{control['name'].inspect}] id=#{control['id'].inspect} has no accessible name"
    end
  end

  # Hidden inputs, buttons and anything inside a hidden element need no label.
  def checked?(control)
    return false if UNNAMED_SKIP_TYPES.include?(control['type'].to_s.downcase)

    control.ancestors.none? { |a| a['hidden'] || a['style'].to_s.match?(/display:\s*none/) }
  end

  def control_named?(doc, control)
    inline_name?(control) || labelled_by?(doc, control) || wrapped_by_label?(control) || label_for?(doc, control['id'].to_s)
  end

  def inline_name?(control) = %w[aria-label title].any? { |attr| control[attr].to_s.strip != '' }

  def labelled_by?(doc, control) = control['aria-labelledby'].to_s.split.any? { |id| doc.at_css("[id='#{id}']") }

  def wrapped_by_label?(control) = control.ancestors('label').any?

  def label_for?(doc, id) = id != '' && doc.css('label[for]').any? { |label| label['for'] == id && label.text.strip != '' }
end

RSpec.configure do |config|
  config.include LabelAssociationHelpers, type: :request
end
