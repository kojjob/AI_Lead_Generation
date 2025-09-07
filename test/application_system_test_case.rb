require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

  # Include Devise test helpers if available
  include Devise::Test::IntegrationHelpers if defined?(Devise)

  # Helper method to sign in a user for system tests
  def sign_in(user)
    if defined?(Devise)
      # Use Devise's sign_in helper
      super(user)
    else
      # Simple implementation for testing without Devise
      visit "/login"
      fill_in "Email", with: user.email
      fill_in "Password", with: "password123"
      click_button "Sign in"
    end
  end
end
