ENV["RAILS_ENV"] ||= "test"

# Set up encryption keys for test environment
ENV["ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY"] = "uC6YskMwm6LT4MG8IKqR3f6pdMuxUac4"
ENV["ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY"] = "nYXektVbhrq2Vzn6sicaUTvTpDctVUZ6"
ENV["ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT"] = "jrPpTnq8yWkSHrmFmoMrQDvm6ByDKym6"

require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
