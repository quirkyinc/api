class CreateTesters < ActiveRecord::Migration
  def change
    create_table :testers do |t|
      t.string :name
      t.string :last_name

      t.timestamps
    end
  end
end
