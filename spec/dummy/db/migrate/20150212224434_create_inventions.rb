class CreateInventions < ActiveRecord::Migration
  def change
    create_table :inventions do |t|
      t.string :title
      t.string :state
      t.integer :creator_id

      t.timestamps
    end
  end
end
