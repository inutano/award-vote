class CreateBallots < ActiveRecord::Migration
  def up
    create_table(:ballots) do |t|
      t.string :mail
      t.string :db
      t.string :tool
      t.string :web
      t.string :mes
      t.timestamps
    end
  end

  def down
    drop_table(:ballots)
  end
end
