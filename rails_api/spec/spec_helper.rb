RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = "spec/examples.txt"
  config.disable_monkey_patching!
  config.warnings = true

  # Suppress known harmless warnings from third-party gems (cgi, mail) that are
  # incompatible with Ruby 3.2's stricter warnings. These gems are already at
  # their latest versions and the warnings don't affect functionality.
  # This keeps warnings enabled for application code while filtering gem warnings.
  if RUBY_VERSION >= "3.2"
    original_warn = Warning.method(:warn)
    Warning.define_singleton_method(:warn) do |message, category: nil|
      # Filter out known harmless warnings from gem paths
      return if message.include?('/gems/') || message.include?('/bundle/')
      original_warn.call(message, category: category)
    end
  end

  if config.files_to_run.one?
    config.default_formatter = "doc"
  end

  config.profile_examples = 10
  config.order = :random
  Kernel.srand config.seed
end

