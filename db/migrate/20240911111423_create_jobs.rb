class CreateJobs < ActiveRecord::Migration[7.2]
  def change
    create_table :jobs do |t|
      t.string :gen_id
      t.string :action_name
      t.string :class_name
      t.string :file_path
      t.integer :status, default: 0
      t.jsonb :params_sent

      t.timestamps
    end
  end
end
