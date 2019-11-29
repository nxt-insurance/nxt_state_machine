require_relative 'article_workflow'

class Article < ActiveRecord::Base
  TYPES = %w[manual_approval auto_approval]
  self.inheritance_column = nil

  validates_inclusion_of :status, in: ArticleWorkflow.state_machine.states.keys
  validates_inclusion_of :type, in: TYPES
end
