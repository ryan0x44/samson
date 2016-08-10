class AddDuplicableToStages < ActiveRecord::Migration
  def change
    add_column :stages, :duplicable, :boolean, null: false, default: false
  end
end
