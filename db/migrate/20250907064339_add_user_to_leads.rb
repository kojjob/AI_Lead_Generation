class AddUserToLeads < ActiveRecord::Migration[8.0]
  def change
    add_reference :leads, :user, null: false, foreign_key: true
  end
end
