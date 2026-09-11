class CreateComments < ActiveRecord::Migration[8.1]
  def change
    create_table :comments do |t|
      t.string :uuid
      t.text :content
      t.references :tweet, null: false, foreign_key: true

      t.timestamps
    end
  end
end
