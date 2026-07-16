# frozen_string_literal: true

require "json"
require "open3"
require "rbconfig"
require "shellwords"
require "tmpdir"

RSpec.describe "generated Mermaid syntax" do
  it "is accepted by Mermaid CLI" do
    command = ENV["MERMAID_CLI"]
    skip "Set MERMAID_CLI to run Mermaid parser validation" unless command

    fixture_script = File.expand_path("../fixtures/rails_app/verify.rb", __dir__)
    stdout, fixture_error, fixture_status = Open3.capture3(RbConfig.ruby, fixture_script)
    raise "Fixture failed:\n#{fixture_error}" unless fixture_status.success?

    diagrams = JSON.parse(stdout).values.map { |result| result.fetch("content") }

    Dir.mktmpdir do |directory|
      input = File.join(directory, "diagrams.md")
      output = File.join(directory, "rendered.md")
      puppeteer_config = File.join(directory, "puppeteer.json")
      markdown = diagrams.map { |diagram| "```mermaid\n#{diagram}\n```" }.join("\n\n")
      File.write(input, markdown)
      browser_options = { args: ["--no-sandbox"] }
      if ENV["PUPPETEER_EXECUTABLE_PATH"]
        browser_options[:executablePath] = ENV["PUPPETEER_EXECUTABLE_PATH"]
      end
      File.write(puppeteer_config, JSON.generate(browser_options))

      _stdout, stderr, status = Open3.capture3(
        *Shellwords.split(command),
        "--input", input,
        "--output", output,
        "--puppeteerConfigFile", puppeteer_config
      )

      expect(status).to be_success, stderr
    end
  end
end
