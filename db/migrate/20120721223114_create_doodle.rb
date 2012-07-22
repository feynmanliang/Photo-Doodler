class CreateDoodle < ActiveRecord::Migration
  def up
      create_table :doodles do |t|
          t.text :data, { limit: nil }
          t.string :userid
          t.string :photoid
          t.datetime :created_at
          t.datetime :updated_at
      end
      add_index :doodles, :photoid
  end

  def down
      drop_table :doodles
  end
end
