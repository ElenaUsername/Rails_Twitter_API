class RefactorResourceDescriptionsAndAddImage < ActiveRecord::Migration[8.1]
  def change
    remove_column :resource_descriptions, :byte_size, :integer
    remove_column :resource_descriptions, :image_url, :string

    add_reference :resource_descriptions, :image, null: false, foreign_key: true
  end
end
