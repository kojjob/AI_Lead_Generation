class AddFieldsToKeywords < ActiveRecord::Migration[8.0]
  def change
    add_column :keywords, :platforms, :text
    add_column :keywords, :search_parameters, :jsonb
  end
end
