require("thor")
require ("./lib/dry/helpers/rails.rb")
class DryHelpersRails < Thor
  desc "rails-dry-helpers", "call main func"
  def call

    puts Dry::Helpers::Rails::findEqualDefinitionsOfFunctionsInRubyFiles
  end
end
