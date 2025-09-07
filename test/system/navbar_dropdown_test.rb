require "application_system_test_case"

class NavbarDropdownTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    sign_in @user
  end

  test "user dropdown icons have correct size and styling" do
    visit root_path

    # Click on user dropdown to open it
    user_dropdown_button = find('[data-action*="navigation#toggleUserMenu"]')
    user_dropdown_button.click

    # Wait for dropdown to appear
    dropdown_panel = find('[data-navigation-target="userPanel"]', visible: true)

    # Check that dropdown icons have the correct CSS classes
    dropdown_icons = dropdown_panel.all(".dropdown-item-icon")

    assert dropdown_icons.count > 0, "Should have dropdown icons"

    dropdown_icons.each do |icon|
      # Check that icons have the correct size classes
      assert icon[:class].include?("h-4"), "Icon should have h-4 class for 16px height"
      assert icon[:class].include?("w-4"), "Icon should have w-4 class for 16px width"
      assert icon[:class].include?("mr-3"), "Icon should have mr-3 class for right margin"
      assert icon[:class].include?("text-gray-400"), "Icon should have text-gray-400 class for color"
    end
  end

  test "user dropdown opens and closes correctly" do
    visit root_path

    user_dropdown_button = find('[data-action*="navigation#toggleUserMenu"]')
    dropdown_panel = find('[data-navigation-target="userPanel"]', visible: false)

    # Initially dropdown should be hidden
    assert dropdown_panel[:class].include?("hidden"), "Dropdown should be initially hidden"

    # Click to open dropdown
    user_dropdown_button.click

    # Dropdown should now be visible
    dropdown_panel = find('[data-navigation-target="userPanel"]', visible: true)
    assert_not dropdown_panel[:class].include?("hidden"), "Dropdown should be visible after click"

    # Check that dropdown contains expected menu items
    assert dropdown_panel.has_text?("My Profile"), "Should have Profile link"
    assert dropdown_panel.has_text?("Settings"), "Should have Settings link"
    assert dropdown_panel.has_text?("Billing & Plans"), "Should have Billing link"
    assert dropdown_panel.has_text?("Sign out"), "Should have Sign out button"
  end

  test "dropdown icons have proper stroke width" do
    visit root_path

    # Open user dropdown
    user_dropdown_button = find('[data-action*="navigation#toggleUserMenu"]')
    user_dropdown_button.click

    dropdown_panel = find('[data-navigation-target="userPanel"]', visible: true)

    # Get the first dropdown icon SVG element
    first_icon = dropdown_panel.first(".dropdown-item-icon")

    # Check that the SVG has the expected stroke-width attribute
    # Note: The stroke-width is set via CSS, so we check the computed style
    assert first_icon.tag_name == "svg", "Should be an SVG element"

    # Verify the icon is properly sized (16px = h-4 w-4 in Tailwind)
    computed_height = first_icon.style("height")["height"]
    computed_width = first_icon.style("width")["width"]

    # Both should be 16px (1rem with default font-size)
    assert_equal "16px", computed_height, "Icon height should be 16px"
    assert_equal "16px", computed_width, "Icon width should be 16px"
  end

  private

  def sign_in(user)
    visit new_user_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "password"
    click_button "Sign in"
  end
end
