class CreateDoodle < ActiveRecord::Migration
  def up
      create_table :doodles do |t|
          t.string :data
          t.string :userID
          t.string :photoID
          t.datetime :created_at
          t.datetime :updated_at
      end
      add_index :doodles, :photoID
  end

  def down
      drop_table :doodles
  end
end
