# frozen_string_literal: true

require_relative "lib/lagoon/version"

Gem::Specification.new do |spec|
  spec.name = "lagoon"
  spec.version = Lagoon::VERSION
  spec.authors = ["Yudai Takada"]
  spec.email = ["t.yudai92@gmail.com"]

  spec.summary = "Generate Mermaid diagrams from Rails models and controllers"
  spec.description = "A Ruby gem that generates Mermaid class diagrams and ER diagrams from Rails applications, inspired by RailRoady"
  spec.homepage = "https://github.com/ydah/lagoon"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["source_code_uri"] = "https://github.com/ydah/lagoon"
  spec.metadata["changelog_uri"] = "https://github.com/ydah/lagoon/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[Gemfile .gitignore .rspec spec/ .github/ .rubocop.yml sig/])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "activesupport", ">= 6.0"
  spec.add_dependency "thor", "~> 1.0"
end
