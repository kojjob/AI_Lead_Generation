require "application_system_test_case"

class AuthenticationInteractionsTest < ApplicationSystemTestCase
  test "password toggle functionality on login page" do
    visit new_user_session_path

    password_field = find('[data-password-toggle-target="input"]')
    toggle_button = find('[data-action*="password-toggle#toggle"]')

    # Initially password should be hidden
    assert_equal "password", password_field[:type]

    # Click toggle to show password
    toggle_button.click
    assert_equal "text", password_field[:type]

    # Click again to hide password
    toggle_button.click
    assert_equal "password", password_field[:type]
  end

  test "form validation on login page" do
    visit new_user_session_path

    email_field = find('[data-form-validation-target="email"]')
    password_field = find('[data-form-validation-target="password"]')
    submit_button = find('[data-form-validation-target="submit"]')

    # Submit button should be disabled initially
    assert submit_button[:disabled]

    # Enter invalid email
    email_field.fill_in with: "invalid"
    email_field.native.send_keys(:tab) # Trigger blur event

    # Should show error styling
    assert email_field[:class].include?("border-red-500")

    # Enter valid email
    email_field.fill_in with: "test@example.com"
    email_field.native.send_keys(:tab)

    # Should show success styling
    assert email_field[:class].include?("border-green-500")

    # Enter password
    password_field.fill_in with: "TestPassword123!"
    password_field.native.send_keys(:tab)

    # Submit button should be enabled with valid inputs
    assert_not submit_button[:disabled]
  end

  test "password strength indicator on signup page" do
    visit new_user_registration_path

    password_field = find('[data-password-strength-target="password"]')
    strength_bar = find('[data-password-strength-target="bar"]')
    strength_label = find('[data-password-strength-target="label"]')

    # Initially should show empty state
    assert_equal "0%", strength_bar.style("width")["width"]
    assert_equal "Enter a password", strength_label.text

    # Weak password
    password_field.fill_in with: "weak"
    sleep 0.1 # Allow for DOM update

    assert strength_bar.style("width")["width"] != "0%"
    assert strength_label.text.downcase.include?("weak")

    # Strong password
    password_field.fill_in with: "StrongPassword123!@#"
    sleep 0.1

    assert strength_bar.style("width")["width"].to_i > 50
    assert strength_label.text.downcase.include?("strong")
  end

  test "password confirmation validation on signup page" do
    visit new_user_registration_path

    password_field = find('[data-form-validation-target="password"]')
    confirmation_field = find('[data-form-validation-target="passwordConfirmation"]')

    # Enter password
    password_field.fill_in with: "TestPassword123!"
    password_field.native.send_keys(:tab)

    # Enter non-matching confirmation
    confirmation_field.fill_in with: "DifferentPassword"
    confirmation_field.native.send_keys(:tab)

    # Should show error styling
    assert confirmation_field[:class].include?("border-red-500")

    # Enter matching confirmation
    confirmation_field.fill_in with: "TestPassword123!"
    confirmation_field.native.send_keys(:tab)

    # Should show success styling
    assert confirmation_field[:class].include?("border-green-500")
  end

  test "all controllers work together on signup page" do
    visit new_user_registration_path

    email_field = find('[data-form-validation-target="email"]')
    password_field = find('[data-password-strength-target="password"]')
    confirmation_field = find('[data-form-validation-target="passwordConfirmation"]')
    toggle_button = find('[data-action*="password-toggle#toggle"]', match: :first)
    submit_button = find('[data-form-validation-target="submit"]')

    # Submit should be disabled initially
    assert submit_button[:disabled]

    # Fill in valid email
    email_field.fill_in with: "newuser@example.com"
    email_field.native.send_keys(:tab)

    # Fill in strong password
    password_field.fill_in with: "SuperStrong123!@#"
    password_field.native.send_keys(:tab)

    # Check password strength indicator updated
    strength_bar = find('[data-password-strength-target="bar"]')
    assert strength_bar.style("width")["width"].to_i > 70

    # Toggle password visibility
    assert_equal "password", password_field[:type]
    toggle_button.click
    assert_equal "text", password_field[:type]

    # Fill in matching confirmation
    confirmation_field.fill_in with: "SuperStrong123!@#"
    confirmation_field.native.send_keys(:tab)

    # Submit should be enabled with all valid inputs
    assert_not submit_button[:disabled]
  end
end
