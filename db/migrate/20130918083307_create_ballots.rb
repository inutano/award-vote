class CreateBallots < ActiveRecord::Migration
  def up
    create_table(:ballots) do |t|
      t.string :db
      t.string :sw
      t.string :web
      t.string :mail
      t.string :mes
      t.timestamps
    end
  end

  def down
  end
end
