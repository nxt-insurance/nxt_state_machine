ActiveRecord::Schema.define do
  self.verbose = false

  create_table :articles, :force => true do |t|
    t.string :status
    t.string :type
    t.string :headline
    t.text :text
    t.datetime :deleted_at

    t.timestamps
  end

  create_table :applications, :force => true do |t|
    t.string :status
    t.string :content
    t.string :error
    t.datetime :received_at
    t.datetime :processed_at
    t.datetime :accepted_at
    t.datetime :rejected_at

    t.timestamps
  end

  create_table :workflows, :force => true do |t|
    t.string :status
    t.string :comment, default: ''

    t.timestamps
  end

  create_table :error_workflows, :force => true do |t|
    t.string :status
    t.string :comment, default: ''

    t.timestamps
  end
end
