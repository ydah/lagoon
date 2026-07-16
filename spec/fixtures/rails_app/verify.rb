# frozen_string_literal: true

require "json"
require "logger"
require "pathname"
require "tmpdir"
require "active_record"
require "action_controller"
require "rails"
require "lagoon"

FIXTURE_ROOT = Pathname.new(__dir__).freeze

def database_configuration
  case ENV.fetch("DB_ADAPTER", "sqlite3")
  when "postgresql"
    {
      adapter: "postgresql",
      host: ENV.fetch("DB_HOST", "127.0.0.1"),
      database: ENV.fetch("DB_NAME", "lagoon_test"),
      username: ENV.fetch("DB_USER", "postgres"),
      password: ENV.fetch("DB_PASSWORD", "postgres")
    }
  when "mysql2"
    {
      adapter: "mysql2",
      host: ENV.fetch("DB_HOST", "127.0.0.1"),
      database: ENV.fetch("DB_NAME", "lagoon_test"),
      username: ENV.fetch("DB_USER", "root"),
      password: ENV.fetch("DB_PASSWORD", "root")
    }
  else
    { adapter: "sqlite3", database: ":memory:" }
  end
end

ActiveRecord::Base.establish_connection(database_configuration)
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  drop_table :posts, if_exists: true
  drop_table :users, if_exists: true

  create_table(:users) do |table|
    table.string :email, null: false
    table.timestamps null: false
  end
  add_index :users, :email, unique: true

  create_table(:posts) do |table|
    table.references :user, null: false, foreign_key: true
    table.string :title, null: false
    table.boolean :published, null: false, default: false
    table.string :legacy_id
    table.timestamps null: false
  end
end

Rails.define_singleton_method(:root) { FIXTURE_ROOT }

Dir[FIXTURE_ROOT.join("app/models/*.rb")].each { |file| require file }
Dir[FIXTURE_ROOT.join("app/controllers/*.rb")].each { |file| require file }

Dir.mktmpdir do |output_directory|
  results = {
    models: Lagoon.generate_model_diagram(
      output: File.join(output_directory, "models.mermaid"),
      eager_load: false,
      show_methods: true,
      show_belongs_to: true
    ),
    controllers: Lagoon.generate_controller_diagram(
      output: File.join(output_directory, "controllers.mermaid"),
      eager_load: false
    ),
    er: Lagoon.generate_er_diagram(
      output: File.join(output_directory, "er.mermaid"),
      eager_load: false
    ),
    controller_models: Lagoon.generate_controller_model_diagram(
      output: File.join(output_directory, "controller_models.mermaid"),
      eager_load: false
    )
  }

  puts JSON.generate(results.transform_values { |result| { content: result.content, counts: result.counts } })
end
