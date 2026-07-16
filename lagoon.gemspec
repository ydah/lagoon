# frozen_string_literal: true

require_relative 'lib/lagoon/version'

Gem::Specification.new do |spec|
  spec.name = 'lagoon'
  spec.version = Lagoon::VERSION
  spec.authors = ['Yudai Takada']
  spec.email = ['t.yudai92@gmail.com']

  spec.summary = 'Generate Mermaid diagrams from Rails models and controllers'
  spec.description = 'Generate Mermaid class and ER diagrams from Rails models, controllers, and database metadata.'
  spec.homepage = 'https://github.com/ydah/lagoon'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.2.0'

  spec.metadata = {
    'bug_tracker_uri' => "#{spec.homepage}/issues",
    'changelog_uri' => "#{spec.homepage}/blob/main/CHANGELOG.md",
    'homepage_uri' => spec.homepage,
    'rubygems_mfa_required' => 'true',
    'source_code_uri' => "#{spec.homepage}/tree/v#{spec.version}"
  }

  gemspec = File.basename(__FILE__)
  files = begin
    IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
      ls.readlines("\x0", chomp: true)
    end
  rescue Errno::ENOENT
    []
  end
  if files.empty?
    files = Dir.glob('**/*', File::FNM_DOTMATCH, base: __dir__).reject do |file|
      File.directory?(File.join(__dir__, file))
    end
  end
  spec.files = files.reject do |file|
    (file == gemspec) ||
      file.start_with?(*%w[Gemfile Gemfile.lock .git/ .gitignore .rspec spec/ .github/ .rubocop.yml])
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'activesupport', '>= 6.1', '< 9'
  spec.add_dependency 'prism', '>= 1.0', '< 3'
  spec.add_dependency 'thor', '~> 1.0'
end
