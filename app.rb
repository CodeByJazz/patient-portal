require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"
require "redcarpet"
require "fileutils"
require "yaml"
require "bcrypt"

configure do 
  enable :sessions
  set :session_secret, SecureRandom.hex(32)
  set :erb, :escape_html => true 
end

before do 
  @users = YAML.load_file(credentials_path)
  # pattern = File.join(data_path, "*")
  # @files = Dir.glob(pattern).map do |path|
  #   File.basename(path)
  # end
end

# def data_path 
#   if ENV["RACK_ENV"] == "test"
#     File.expand_path("../test/data", __FILE__)
#   else
#     File.expand_path("../data", __FILE__)
#   end
# end

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
    "There is no account associated with this username. Please create an account below."
  else
    "Invalid Credentials. Please Try Again."
  end
end

get "/" do 
  if session[:username] 
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
















=begin   

-Pet Patient Portal

  -Pet owners can login and view any relevant information about their pets

  ---HOMEPAGE---
  -The homepage should include a link to `Login` or `Create New Account`
    -Users should be able to login using their email address and password
  -When a client logs in they should be greeted with a "Hello, client name!" message
    -There should also be a link to `Sign Out`
  -The homepage should include a picture of their pets (names for now)
  -There should be a link under each picture that says the pets name 
  -When they click it they should be taken to that pets "dashboard"

  ---DASHBOARD---
  -The dashboard should include information about the pet such as their:
    -Account #
    -Name
    -Birthday (if it's their birthday a message should pop up that says "Happy Birthday, pet name!")
    -Pet type (canine/feline/etc.)
    -Breed
    -Age (calculated by the birthday)
    -Weight 
    -Microchip #
  -It should include a seperate secion with links to view their:
    -Visit history (w/ links for each visit to view doctors notes)
    -Vaccine Tracker (table that shows when they were performed/ if they're due)
    -RX Prescriptions (how to use instructions, dosage, quantity, expiration, etc.)
      -Patients will later be able to request scripts via the app
      -When they do, they'll be prompted to rate the medication based on its: effectiveness, changes in behavior, and any remaining concerns
    -Medical Documents (doctors can upload health certs, external records, etc.)

---FEATURES TO BE ADDED---
    -Pet Patient Portal 
      
      -This button should take them to a page titled `Client Information` with a form that asks for and validates their:
        -Name
        -Phone #
        -Email Address 
        -Password 
      -When they click the `Next` button they should be redirected to a page titled `Patient Information` that asks for and validates their pets:
        -Name
        -Birthday 
        -Pet type 
        -Breed
        -Age
        -Weight (if known)
        -Microchip # (if known)

      
  -There should be a `Create New Account` Button on the homepage if the user isn't signed in 


  -Doctor Patient Portal 

    -Doctors can login and view any relevant information about their clients (owners/pets)
  
  ---HOMEPAGE---
  -The homepage should include a list of all registered users 
    -Doctors will later be able to filter users by doctor to make for easy viewing
  -Doctors should be able to add new prescriptions, edit vaccine tracker, and add visit date and notes 
    
=end

=begin

------------------CLIENT SIDE------------------
Pet owners can login and view any relevant information about their pets


---HOMEPAGE---
  -When a SIGNED OUT user requests the homepage:
    -They should be redirected to the `Sign In` page

  -When a SIGNED IN user requests the homepage: 
    -The following should be displayed in the home view template
      -A message that says "Hello, #client_name!"
      -A link that says "Add New Pet"
      -A picture of their pets (names for now)
      -A link under each picture that says the pets name, edit, and delete
      -A `Sign Out` link that signs out the user
        -When a user clicks the `Sign Out` link:
          -They should be redirected to the homepage 
          -A message that says "You have been signed out." should appear
        
--------IMPLEMENTATION FOR HOMEPAGE---------
-Add a link to "/add_pet"
-Display a unordered list of each pet associated with the current user
  -Create an unordered list
  -Iterate through the `pets` hash for the current user 
    -For each pet create a list item with the following anchor tags:
      -The name of the current pet with an href to `/pet_name/dashboard`
      -Edit with an href to `/pet_name/edit`
      -Delete with an href to `/pet_name/delete`
-Add text at the bottom that says "Signed in as, @client_name "
-Add a `Sign Out` button that signs out the user
  -Create a post route to "/users/signout"
    -Delete username from the session
    -Set the sessage message to: "You have been signed out." 
    -Redirect the user "/"


---SIGN IN PAGE---
  -The `Sign In` page should include a form for the username and password 
  -There should be two buttons below it:
    -`Sign In`
    -`Create New Account`

  -When a user clicks the `Sign In` button with the correct credentials:
    -They should be redirected to the homepage (Look above for more info!)
  
  -When a user clicks the `Sign In` button with invalid credentials:
    -A message should be displayed that says "Invalid Credentials. Please try again."
    -The `Sign In` form should be displayed again with the last username used - as a placeholder  

  --------IMPLEMENTATION FOR SIGN IN PAGE---------
  -Create a `before` block 
    -Within it, load the credentials from users.yml
    -Assign the return value to @users

  -Create a sign_in view template 
  -Add a form with the action "/sign_in" and the method "post"
  -Add input for the username and password 
  -Store the input username as the placeholder value for "username"

  -Create a post route for "/users/sign_in"
  -Assign the params[:username] to @username 
  -Assign the params[:password] to @password
  -Check to see if the credentials are valid 
    -Create a method called `valid_credentials?` with two parameters: username, password
      -If the username exists as a key in @users
        -Return true if the stored password matches the given password (Bcrypt::Password#==)
  -If the credentials are valid
    -Assign session[:username] to @username
    -Assign session[:message] to: "Hello, #{@users[@username][:first_name]}!"
    -Redirect the user to the homepage ("/")
  -Otherwise 
    -Call the `error_for_sign_in` method 
    -Assign the return value to session[:message]
    -Return a status code of 422 (invalid data)
    -Render the `sign_in` view template again

  -Create a method called `error_for_sign_in` with one parameter: username
    -If the username does not exist in @users
      -Assign the session[:message] to: "There is no account associated with this username. Please create an account."
    -Otherwise 
      -Assign the session[:message] to: "Invalid Credentials. Please try again."    

---CREATE ACCOUNT PAGE---  
  -When a user clicks the `Create New Account` button:
    -They should be redirected to the "/create_account" page that contains:
      -A title that says `Client Information`
      -A form that asks the user for their:
        -First Name:
        -Last Name:
        -Phone Number:
        -Email Address:
        -Password:
      -A button titled 'Create Account`
  -Redirect user to "/sign_in" 
  -Display a message that says "Your account has been created. You may now sign in."

---ADD PET PAGE---
  -When a user clicks the `Add New Patient` link:
    -They should be redirected to "/:client_name/add_patient" page that contains:
      -A title that says `Patient Information`
      -A form that asks the user for their pet's:
        -Name: 
        -Birthday: 
        -Type: 
        -Breed:
        -Weight (if known):
        -Microchip # (if known):
      -A button that says `Add Patient` (patient should appear on homepage)
  -Redirect user to "/" 
  -Display message that says "#pet_name has been added.""

---EDIT PET INFO PAGE---
  -When a user clicks the `edit` link:
    -They should be redirected to "/:client_name/:patient_name/edit" page that contains:
      -A title that says `Edit Patient Information`
      -A form that asks the user for their pet's new:
        -Name: 
        -Birthday: 
        -Type: 
        -Breed:
        -Weight (if known):
        -Microchip # (if known):
        (placeholders should be info associated with patient already)
      -A button that says `edit` (patient's info should be updated.)
  -Redirect user to "/" 
  -Display message that says "#pet_name's profile has been updated."

---DASHBOARD---
  -When a user clicks the `Pet_Name` link:
    -They should be redirected to "/:client_name/:patient_name/dashboard" page that contains:
      -A title that says `Dashboard`
      -A table with the selected pet's:
        -Name
        -Birthday (if it's their birthday a message should pop up that says "Happy Birthday, pet name!")
        -Pet type (canine/feline/etc.)
        -Breed
        -Age (calculated by the birthday)
        -Weight 
        -Microchip #
      -A seperate secion with links to view their:
        -Visit history (w/ links for each visit to view doctors notes)
        -Vaccine Tracker (table that shows when they were performed/ if they're due)
        -RX Prescriptions (how to use instructions, dosage, quantity, expiration etc.)

=end

=begin  
------------------FEATURES TO BE ADDED------------------
  -Generate a random number (1-10000) and assign it to be the users account #
    -Append it to the users hash in users.yml (MAYBE???)
  -Add a drop down for selecting the pets breed, type, and weight
    -Add the option for `unknown` for parents that aren't sure 
  -Add a pop up calendar to select the pets birthday 
  -Allow the client to edit their information (email address & phone #)
  -If there is no account associated with the email the user gave us, a message should appear that says "There is no account associated with your email address. Please create an account."
  -Patients will later be able to request scripts via the app
    -When they do, they'll be prompted to rate the medication based on its: effectiveness, changes in behavior, and any remaining concerns
    -Medical Documents (doctors can upload health certs, external records, etc)
  -Doctors will later be able to filter users by doctor to make for easy viewing

----DOCTOR SIDE----
Doctors can login and view any relevant information about their clients (owners/pets)

-When a doctor clicks the `Sign In` button with the admin credentials:
    -The following should be displayed in the home view template
      -A message that says "Hello, #client_name!"
      -A list of all registered clients
      -A `Sign Out` link that signs out the user
        -When a user clicks the `Sign Out` link:
          -They should be redirected to the homepage 
          -A message that says "You have been signed out." should appear

---DASHBOARD--
-When a doctor clicks on a client name from the list of clients
  -They should be redirected to the "/admin/:client_name/dashboard" page that contains:
    -Client info
    -Pet info
  -Doctors should be able to add new prescriptions for pets, edit vaccine tracker, and add visit date and notes 
  
Passwords: 
Jay = finalfantasy7
Jazz = ilovepie!
Jill = rosesarered
=end