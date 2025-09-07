class AddLeadManagementFields < ActiveRecord::Migration[8.0]
  def change
    add_column :leads, :name, :string
    add_column :leads, :email, :string
    add_column :leads, :phone, :string
    add_column :leads, :company, :string
    add_column :leads, :position, :string
    add_column :leads, :qualification_score, :integer, default: 0
    add_column :leads, :priority, :string, default: 'medium'
    add_column :leads, :contacted_by, :string
    add_column :leads, :contact_method, :string
    add_column :leads, :conversion_value, :decimal, precision: 10, scale: 2
    add_column :leads, :next_follow_up, :datetime
    add_column :leads, :lead_stage, :string, default: 'prospect'
    add_column :leads, :source_platform, :string
    add_column :leads, :source_url, :text
    add_column :leads, :interaction_count, :integer, default: 0
    add_column :leads, :last_interaction_at, :datetime
    add_column :leads, :assigned_to, :string
    add_column :leads, :temperature, :string, default: 'cold'

    add_index :leads, :email
    add_index :leads, :status
    add_index :leads, :priority
    add_index :leads, :lead_stage
    add_index :leads, :qualification_score
    add_index :leads, :created_at
  end
end
