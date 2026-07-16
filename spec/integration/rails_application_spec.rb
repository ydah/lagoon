# frozen_string_literal: true

require 'json'
require 'open3'
require 'rbconfig'

RSpec.describe 'minimal Rails application integration' do
  let(:script) { File.expand_path('../fixtures/rails_app/verify.rb', __dir__) }

  def generate_diagrams
    stdout, stderr, status = Open3.capture3(
      { 'DB_ADAPTER' => ENV.fetch('DB_ADAPTER', 'sqlite3') },
      RbConfig.ruby,
      script
    )
    raise "Fixture failed:\n#{stderr}" unless status.success?

    JSON.parse(stdout)
  end

  it 'generates all diagram types from real framework metadata' do
    diagrams = generate_diagrams

    expect(diagrams.dig('models', 'content')).to include(
      'class ApplicationRecord',
      'ApplicationRecord <|-- User',
      'User "1" --> "*" Post : has_many posts',
      '+display_name()'
    )
    expect(diagrams.dig('controllers', 'content')).to include(
      'ApplicationController <|-- UsersController',
      '+index()',
      '-set_user()'
    )
    expect(diagrams.dig('er', 'content')).to include(
      'USERS ||..o{ POSTS : "has many"',
      'string email UK',
      'int user_id FK'
    )
    expect(diagrams.dig('controller_models', 'content')).to include(
      'UsersController ..> Post : show',
      'UsersController ..> User : index, show'
    )
  end

  it 'is byte-for-byte deterministic' do
    first = generate_diagrams.transform_values { |result| result.fetch('content') }
    second = generate_diagrams.transform_values { |result| result.fetch('content') }

    expect(second).to eq(first)
  end
end
