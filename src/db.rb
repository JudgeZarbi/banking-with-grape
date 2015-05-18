require 'rubygems'
require 'bundler/setup'
require_relative 'return'
require_relative 'process'
require_relative 'email'

module Banking
  module DB
    # Class to mount all of the API components together
    class Main < Grape::API
      mount Banking::DB::Return
      mount Banking::DB::Process
      mount Banking::Email
    end
  end
end
