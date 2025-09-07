require "test_helper"

class MentionsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:one)
    @keyword = keywords(:one)
    @mention = mentions(:one)
    sign_in @user
  end

  test "should get index" do
    get keyword_mentions_url(@keyword)
    assert_response :success
  end

  test "should get show" do
    get keyword_mention_url(@keyword, @mention)
    assert_response :success
  end
end
