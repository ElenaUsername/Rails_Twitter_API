class MakeResourceDescriptionsPolymorphic < ActiveRecord::Migration[8.1]
  # Written as up/down rather than change: the inverse of a `remove_reference`
  # runs before the down-direction backfill, and adding a NOT NULL column to a
  # non-empty SQLite table raises ActiveRecord::NotNullViolation.
  def up
    add_reference :resource_descriptions, :resourceable, polymorphic: true

    execute <<~SQL.squish
      UPDATE resource_descriptions
      SET resourceable_type = 'Tweet', resourceable_id = tweet_id
    SQL

    change_column_null :resource_descriptions, :resourceable_type, false
    change_column_null :resource_descriptions, :resourceable_id, false

    remove_reference :resource_descriptions, :tweet, foreign_key: true
  end

  def down
    add_reference :resource_descriptions, :tweet, foreign_key: true

    execute "DELETE FROM resource_descriptions WHERE resourceable_type != 'Tweet'"
    execute "UPDATE resource_descriptions SET tweet_id = resourceable_id"

    change_column_null :resource_descriptions, :tweet_id, false

    remove_reference :resource_descriptions, :resourceable, polymorphic: true
  end
end
