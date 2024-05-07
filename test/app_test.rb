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
    @users = YAML.load_file(credentials_path)
  end

  def session
    last_request.env["rack.session"]
  end

  def admin_session 
    { "rack.session" => {username: "admin@ppc.com"} }
  end

  def teardown 
    FileUtils.rm_rf(data_path)
  end

  def test_home
    get "/" 
    assert_equal 302, last_response.status

    get last_response["location"]
    assert_equal 200, last_response.status
    assert_includes last_response.body, "Sign In"
    assert_includes last_response.body, "Create New Account"
  end

  def test_create_account_form 
    get "/create_account"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "<form"
    assert_includes last_response.body, "<button"
  end 

  def test_sign_in_page
    get "/users/signin"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, "<button"
  end

  def test_successful_sign_in
    post "/users/signin", username: "cherry243", password: "cherrypie!"
    assert_equal 302, last_response.status
    assert_equal "Welcome, Alea!", session[:message]
    assert_equal "cherry243", session[:username]

    get last_response["location"]
    assert_equal 200, last_response.status
    assert_includes last_response.body, "Signed in as, Alea"
    assert_includes last_response.body, "Sign Out"
  end

  def test_unsuccessful_sign_in 
    post "/users/signin", username: "destinyschild", password: "beyonce3000"
    assert_equal 422, last_response.status
    assert_nil session[:username]
    assert_includes last_response.body, "Please create an account"
  end
end