# frozen_string_literal: true

SCHEMA_DIR = File.expand_path('data/schemas', __dir__)

desc 'Compile the GSettings schema'
task :schema do
  sh 'glib-compile-schemas', SCHEMA_DIR
end

desc 'Run the test suite'
task test: :schema do
  %w[
    test/resource_test.rb
    test/cli_test.rb
    test/desktop_entry_test.rb
    test/window_test.rb
    test/url_test.rb
    test/welcome_test.rb
  ].each do |script|
    puts "\n== #{script}"
    sh({ 'GSETTINGS_SCHEMA_DIR' => SCHEMA_DIR }, 'ruby', script)
  end
end

desc 'Run the app'
task run: :schema do
  sh(
    { 'GSETTINGS_SCHEMA_DIR' => SCHEMA_DIR },
    'ruby',
    'bin/junction-rb',
    *ARGV.drop(1),
  )
end

desc 'Lint'
task :lint do
  sh 'rubocop'
end

task default: %i[schema test lint]
