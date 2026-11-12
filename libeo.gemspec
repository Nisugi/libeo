# frozen_string_literal: true

require_relative 'lib/libeo/install'

Gem::Specification.new do |spec|
  spec.name = 'libeo'
  spec.version = LibEO::Install.version
  spec.authors = ['Elanthia Online']
  spec.summary = 'The shared library for the e-scripts on Lich 5, and its installer'
  spec.description = <<~TEXT
    libeo is the library the e-scripts (ebounty, eloot, eherbs, ecleanse,
    eohunter) share: travel, command helpers, and the Adventurer's Guild task
    logic. This gem carries the library and an installer: `libeo install`
    copies it into a Lich install.
  TEXT
  spec.homepage = 'https://github.com/elanthia-online/libeo'
  spec.metadata = {
    'source_code_uri'       => spec.homepage,
    'rubygems_mfa_required' => 'true',
    # Lich's lich5-update loads this file and calls LibEO::Install.install(lich_dir)
    'lich_install'          => 'libeo/install#LibEO::Install'
  }
  # The installer is plain Ruby; any current Ruby runs it, not only Lich's.
  spec.required_ruby_version = '>= 3.0' # rubocop:disable Gemspec/RequiredRubyVersion

  spec.files = Dir['lib/**/*.rb', 'exe/*', 'README.md'] +
               LibEO::Install.payload_files(File.join(__dir__, 'scripts')).map { |rel| "scripts/#{rel}" }
  spec.bindir = 'exe'
  spec.executables = ['libeo']
  spec.require_paths = ['lib']
end
