ENV["RACK_ENV"] = "test"

require "fileutils"
require "minitest/autorun"
require "rack/test"

require_relative "../app"

class AppTest < Minitest::Test
  include Rack::Test::Methods

  def app 
    Sinatra::Application 
  end

  def setup 
    FileUtils.mkdir_p(data_path)
    YAML.load_file(credentials_path)
  end

  def session
    last_request.env["rack.session"]
  end

  def admin_session 
    { "rack.session" => {username: "admin"} }
  end

  def teardown 
    FileUtils.rm_rf(data_path)
  end
end