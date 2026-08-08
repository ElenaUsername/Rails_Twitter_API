class CreateResourceDescriptions < ActiveRecord::Migration[8.1]
  def change
    create_table :resource_descriptions do |t|
      t.references :tweet, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description, null: false
      t.string :url, null: false
      t.string :image_url
      t.integer :byte_size

      t.timestamps
    end
  end
end
