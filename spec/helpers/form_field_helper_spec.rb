# frozen_string_literal: true

require 'rails_helper'

class DummyModel
  include ActiveModel::Model
  attr_accessor :name
  validates :name, presence: true
end

RSpec.describe FormFieldHelper, type: :helper do
  let(:dummy) { DummyModel.new }

  it 'renders invalid feedback when attribute has errors' do
    dummy.validate
    render inline: "<%= form_with model: dummy do |f| %><%= form_field f, :name, input_class: 'form-control' %><% end %>", locals: { dummy: dummy }
    node = Capybara::Node::Simple.new(rendered)
    expect(node).to have_css('input.is-invalid')
    expect(node).to have_css('div.invalid-feedback', text: "can't be blank")
  end

  it 'renders help text when provided' do
    render inline: "<%= form_with model: dummy do |f| %><%= form_field f, :name, input_class: 'form-control', help_text: 'Enter name' %><% end %>", locals: { dummy: dummy }
    node = Capybara::Node::Simple.new(rendered)
    expect(node).to have_text('Enter name')
  end
end
