class CreateDoodle < ActiveRecord::Migration
  def up
      create_table :doodles do |t|
          t.string :userID
          t.string :photoID
          t.datetime :created_at
          t.datetime :updated_at
      end
  end

  def down
      drop_table :doodles
  end
end