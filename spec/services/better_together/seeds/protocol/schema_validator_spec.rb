# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Seeds::Protocol::SchemaValidator do
  def violations(schema, value)
    described_class.new(schema).validate(value).map { |v| [v.pointer, v.message] }
  end

  it 'checks types, required keys and additionalProperties' do
    schema = { 'type' => 'object', 'required' => ['a'], 'properties' => { 'a' => { 'type' => 'integer' } },
               'additionalProperties' => false }

    expect(violations(schema, { 'a' => 'x', 'b' => 1 })).to contain_exactly(
      ['/a', 'must be of type integer'], ['/b', 'is not allowed']
    )
    expect(violations(schema, {})).to eq([['/a', 'is required']])
  end

  it 'checks enum, const, pattern, minLength and minimum' do
    expect(violations({ 'enum' => %w[a b] }, 'c')).not_to be_empty
    expect(violations({ 'const' => 'x' }, 'y')).not_to be_empty
    expect(violations({ 'type' => 'string', 'pattern' => '^a' }, 'b')).not_to be_empty
    expect(violations({ 'type' => 'string', 'minLength' => 2 }, 'b')).not_to be_empty
    expect(violations({ 'type' => 'integer', 'minimum' => 1 }, 0)).not_to be_empty
  end

  it 'checks array items with indexed pointers' do
    schema = { 'type' => 'array', 'minItems' => 1, 'items' => { 'type' => 'string' } }

    expect(violations(schema, ['a', 1])).to eq([['/1', 'must be of type string']])
    expect(violations(schema, [])).not_to be_empty
  end

  it 'resolves local refs and oneOf without leaking violations between options' do
    schema = { '$defs' => { 'n' => { 'type' => 'integer' } },
               'oneOf' => [{ '$ref' => '#/$defs/n' }, { 'type' => 'string' }] }

    expect(violations(schema, 3)).to be_empty
    expect(violations(schema, 'x')).to be_empty
    expect(violations(schema, [])).to eq([['', 'must match exactly one of the allowed shapes']])
  end
end
