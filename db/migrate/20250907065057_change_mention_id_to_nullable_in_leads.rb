class ChangeMentionIdToNullableInLeads < ActiveRecord::Migration[8.0]
  def up
    change_column_null :leads, :mention_id, true
  end

  def down
    # Note: This down migration might fail if there are leads without mention_id
    # You may need to clean up data before running this
    change_column_null :leads, :mention_id, false
  end
end
