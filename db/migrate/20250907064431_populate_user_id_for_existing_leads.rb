class PopulateUserIdForExistingLeads < ActiveRecord::Migration[8.0]
  def up
    # Populate user_id for existing leads based on their mention's keyword's user
    execute <<-SQL
      UPDATE leads
      SET user_id = keywords.user_id
      FROM mentions, keywords
      WHERE leads.mention_id = mentions.id
      AND mentions.keyword_id = keywords.id
      AND leads.user_id IS NULL
    SQL
  end

  def down
    # No need to reverse this data migration
  end
end
