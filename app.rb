require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"
require "redcarpet"
require "fileutils"
require "yaml"
require "bcrypt"
require "date"

configure do 
  enable :sessions
  set :session_secret, SecureRandom.hex(32)
  set :erb, :escape_html => true 
end

before do 
  @users = YAML.load_file(credentials_path)
end

helpers do 
  def sort_by_date(visits)
    visits.sort_by do |visit|
      Date.parse(visit)
    end.reverse
  end

  def format(date)
    parsed = date.split("-")
    new_date = "#{parsed[1]}/#{parsed[0]}/#{parsed[2]}"
  end

  def all_registered_users 
    @registered_users = []
    @users.each_key do |user|
      unless user == session[:username]
        @registered_users << "#{@users[user]["last_name"]}, #{@users[user]["first_name"]}"
      end
    end
    @registered_users.sort
  end

  def last_name(full_name)
    full_name.downcase.split(",")[0]
  end

  def first_name(full_name)
    full_name.downcase.delete(" ").split(",")[1]
  end
end

def data_path 
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def credentials_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/users.yml", __FILE__)
  else
    File.expand_path("../users.yml", __FILE__)
  end
end

def render_markdown(text)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(text)
end

def valid_credentials?(username, password)
  if @users.key?(username)
    BCrypt::Password.new(@users[username]["password"]) == password
  end
end

def error_for_sign_in(username)
  if !@users.key?(username)
    "There is no account associated with the username '#{username}'. Please create an account below."
  else
    "Invalid Credentials. Please Try Again."
  end
end

def invalid_name?(name)
  name.empty?
end

def invalid_birthday?(birthday)
  birthday.empty?
end

def invalid_type?(type)
  type.empty?
end

def invalid_breed?(breed)
  breed.empty?
end

def create_directory(name)
  @file_path = File.join(data_path, name.downcase)
  FileUtils.mkdir_p(@file_path)
  FileUtils.mkdir_p(File.join(@file_path, "visits")) 
end

def delete_directory(name)
  FileUtils.rm_r("#{data_path}/#{name}")
end

def delete_pet(name) 
  delete_directory(name)
  @users[session[:username]]["pets"].delete(name)
  File.open(credentials_path, 'w') { |f| YAML.dump(@users, f) }
end


def add_pet(name, birthday, type, breed, weight, microchip)
  create_directory(name)

  @users[session[:username]]["pets"][name.downcase] = {
    "birthday" => birthday,
    "type" => type,
    "breed" => breed,
    "weight" => weight,
    "microchip" => microchip,
    "vaccines" => {
      "FeLV" => {
        "due" => "",
        "performed" => ""
      },
      "FVRCP" => {
        "due" => "", 
        "performed" => ""
      },
      "Rabies" => {
        "due" => "", 
        "performed" => ""
      },
      "DA2P" => {
        "due" => "", 
        "performed" => ""
      },
      "Lepto" => {
        "due" => "", 
        "performed" => ""
      },
      "Lyme" => {
        "due" => "", 
        "performed" => ""
      },
      "Influenza" => {
        "due" => "", 
        "performed" => ""
      },
      "Bordatella" => {
        "due" => "", 
        "performed" => ""
      },
      "Parvovirus" => {
        "due" => "", 
        "performed" => ""
      },
    }, 
    "prescriptions" => {}
  }
  File.open(credentials_path, 'w') { |f| YAML.dump(@users, f) }
end

def add_refill_request(name, prescription, info)
  @refill_requests = @users["admin@ppc.com"]["refill_requests"]
  if @refill_requests.key?(name)
    @refill_requests[name][prescription] = info["quantity"]
  else
    @refill_requests[name] = {
      prescription => info["quantity"]
    }
  end

  File.open(credentials_path, 'w') { |f| YAML.dump(@users, f) }
end

def birthday_today?(birthday, today) 
  today.month == birthday.month && today.day == birthday.day
end

def age(birthday, today) 
  today.year - birthday.year - ((today.month > birthday.month || (today.month == birthday.month && today.day >= birthday.day)) ? 0 : 1)  
end

def restrict_access
  redirect "/" if session[:username].nil?
end

def create_account(username, password, first_name, last_name, number)
  @users[username] = {
    "password" => password,
    "first_name" => first_name,
    "last_name" => last_name,
    "phone_number" => number, 
    "pets" => {}
  }
  File.open(credentials_path, 'w') { |f| YAML.dump(@users, f) }
end

not_found do 
  redirect "/"
end

get "/" do 
  if session[:username] == "admin@ppc.com"
    erb :admin_home
  elsif session[:username] 
    erb :home
  else
    redirect "/users/signin"
  end
end

get "/users/signin" do 
  erb :sign_in
end

post "/users/signin" do 
  @username = params[:username]
  @password = params[:password]

  if valid_credentials?(@username, @password)
    session[:username] = @username
    @client_name = @users[@username]["first_name"]
    session[:message] = "Welcome, #{@client_name}!"

    redirect "/"
  else
    session[:message] = error_for_sign_in(@username)
    status 422
    erb :sign_in
  end
end

post "/users/signout" do 
  session.delete(:username)
  session[:message] = "You have been signed out."
  redirect "/"
end

post "/:pet_name/delete" do 
  pet_name = params[:pet_name]
  delete_pet(pet_name)
  
  session[:message] = "#{pet_name.capitalize} has been deleted."
  redirect "/"
end 

get "/add_pet" do 
  restrict_access
  erb :new_pet
end

post "/add_pet" do 
  @name = params[:name].strip
  @birthday = params[:birthday]
  @type = params[:type]
  @breed = params[:breed]
  @weight = params[:weight]
  @microchip = params[:microchip]

  if invalid_name?(@name)
    session[:message] = "Please enter a valid name"
    erb :new_pet
  elsif invalid_birthday?(@birthday) 
    session[:message] = "Please select a valid birthday."
    erb :new_pet
  elsif invalid_type?(@type) 
    session[:message] = "Please select a valid type."
    erb :new_pet
  elsif invalid_breed?(@breed) 
    session[:message] = "Please select a valid breed."
    erb :new_pet
  else
    add_pet(@name, @birthday, @type, @breed, @weight, @microchip)
    session[:message] = "#{@name} has been added"
    redirect "/"
  end
end

get "/:pet_name/edit" do 
  restrict_access
  @name = params[:pet_name]
  session[:original_name] = @name
  @info = @users[session[:username]]["pets"][@name.downcase]

  if @info.nil?
    redirect "/"
  else
    erb :edit_pet
  end
end

post "/edit" do 
  @name = params[:name].strip
  @birthday = params[:birthday]
  @type = params[:type]
  @breed = params[:breed]
  @weight = params[:weight]
  @microchip = params[:microchip]
  @info = @users[session[:username]]["pets"][@name.downcase]

  if invalid_name?(@name)
    session[:message] = "Please enter a valid name"
    erb :edit_pet
  elsif invalid_birthday?(@birthday) 
    session[:message] = "Please select a valid birthday."
    erb :edit_pet
  elsif invalid_type?(@type) 
    session[:message] = "Please select a valid type."
    erb :edit_pet
  elsif invalid_breed?(@breed) 
    session[:message] = "Please select a valid breed."
    erb :edit_pet
  else
    delete_pet(session[:original_name])
    add_pet(@name, @birthday, @type, @breed, @weight, @microchip)

    session[:message] = "#{@name.capitalize} has been updated."
    redirect "/"
  end
end

get "/:pet_name/dashboard" do 
  restrict_access
  @name = params[:pet_name]
  @info = @users[session[:username]]["pets"][@name.downcase]
  birthday = Date.parse(@info["birthday"])
  today = Time.now.utc.to_date
  @age = age(birthday, today)

  if birthday_today?(birthday, today) 
    session[:message] = "Happy Birthday, #{@name.capitalize}!"
  end

  erb :dashboard
end

get "/:pet_name/visit_history" do
  restrict_access
  @name = params[:pet_name]
  directory_path = File.join(data_path, "#{@name}/visits/*")
  @visits = Dir.glob(directory_path).map do |path|
    File.basename(path.gsub("_","-")).gsub(".md", "")
  end

  erb :visits
end

get "/:pet_name/add_visit" do 
  restrict_access
  @name = params[:pet_name]
  if session[:username] != "admin@ppc.com"
    session[:message] = "You do not have permission to do that."
    redirect "/#{@name}/visit_history"
  end
end

get "/:pet_name/:date/visit_summary" do 
  restrict_access  
  name = params[:pet_name]
  date = params[:date]
  file_path = File.join(data_path, "#{name}/visits/#{date}.md")
  content = File.read(file_path)

  erb render_markdown(content)
end

get "/:pet_name/vaccine_tracker" do 
  restrict_access
  @name = params[:pet_name]

  @info = @users[session[:username]]["pets"][@name.downcase]
  @vaccines = @info["vaccines"]

  erb :vaccines
end

get "/:pet_name/update_vaccines" do 
  restrict_access
  @name = params[:pet_name]
  if session[:username] != "admin@ppc.com"
    session[:message] = "You do not have permission to do that."
    redirect "/#{@name}/vaccine_tracker"
  end
end

get "/:pet_name/prescriptions" do 
  restrict_access
  @name = params[:pet_name]
  @info = @users[session[:username]]["pets"][@name.downcase]
  @prescriptions = @info["prescriptions"]  

  erb :prescriptions
end

get "/:pet_name/add_prescription" do 
  restrict_access
  @name = params[:pet_name]
  if session[:username] != "admin@ppc.com"
    session[:message] = "You do not have permission to do that."
    redirect "/#{@name}/prescriptions"
  end
end

get "/:pet_name/:prescription_name/prescriptions" do 
  restrict_access
  @name = params[:pet_name]
  @prescription = params[:prescription_name]  
  @info = @users[session[:username]]["pets"][@name.downcase]
  @prescription_info = @info["prescriptions"][@prescription]

  erb :prescription_info
end

post "/:pet_name/:prescription_name/request_refill" do
  @name = params[:pet_name]
  @prescription = params[:prescription_name] 
  @info = @users[session[:username]]["pets"][@name.downcase]
  @prescription_info = @info["prescriptions"][@prescription]

  add_refill_request(@name, @prescription, @prescription_info)

  session[:message] = "Your refill request for #{@prescription.capitalize} has been submitted! Please allow up to 48 hours for approval."

  redirect "/#{@name}/prescriptions"
end

get "/create_account" do 
  erb :sign_up
end

post "/create_account" do 
  @username = params[:username].strip
  @password = params[:password].strip
  @confirmed_password = params[:confirm_password].strip
  @first_name = params[:first_name].strip
  @last_name = params[:last_name].strip
  @phone_number = params[:phone_number].strip

  if @username.empty?
    session[:message] = "Please enter a valid username"
    erb :sign_up
  elsif @password.length < 8
    session[:message] = "Please enter a valid password."
    erb :sign_up
  elsif @password != @confirmed_password
    session[:message] = "Passwords must match."
    erb :sign_up
  elsif @first_name.empty? || @last_name.empty?
    session[:message] = "Please enter a valid name."
    erb :sign_up
  else
    create_account(@username, @password, @first_name, @last_name, @phone_number)

    session[:message] = "Your account has been created! You may now log in."
    redirect "/"
  end
end
