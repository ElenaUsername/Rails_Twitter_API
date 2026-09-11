class AddUniqueIndexToUuids < ActiveRecord::Migration[8.1]
  def change
    add_index :tweets, :uuid, unique: true
    add_index :comments, :uuid, unique: true
  end
end
