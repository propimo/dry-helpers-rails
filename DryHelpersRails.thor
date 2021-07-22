require("thor")
require ("./lib/dry/helpers/rails.rb")
class DryHelpersRails < Thor
  desc "call", "call main func"
  def call

    puts Dry::Helpers::Rails::findEqualDefinitionsOfFunctionsInRubyFiles(Dir.pwd)
  end
end
