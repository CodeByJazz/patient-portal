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
    "There is no account associated with #{username}. Please create an account below."
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

def birthday_today?(birthday, today) 
  today.month == birthday.month && today.day == birthday.day
end

def age(birthday, today) 
  today.year - birthday.year - ((today.month > birthday.month || (today.month == birthday.month && today.day >= birthday.day)) ? 0 : 1)  
end
# not_found do 
#   redirect "/"
# end

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

post "/:pet_name/delete" do 
  pet_name = params[:pet_name]
  delete_pet(pet_name)
  
  session[:message] = "#{pet_name.capitalize} has been deleted."
  redirect "/"
end 

get "/add_pet" do 
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
  @name = params[:pet_name]
  directory_path = File.join(data_path, "#{@name}/visits/*")
  @visits = Dir.glob(directory_path).map do |path|
    File.basename(path.gsub("_","-")).gsub(".md", "")
  end

  erb :visits
end

get "/:pet_name/:date/visit_summary" do 
  name = params[:pet_name]
  date = params[:date]
  file_path = File.join(data_path, "#{name}/visits/#{date}.md")
  content = File.read(file_path)

  erb render_markdown(content)
end

get "/:pet_name/vaccine_tracker" do 
  name = params[:pet_name]

  @info = @users[session[:username]]["pets"][name.downcase]
  @vaccines = @info["vaccines"]

  erb :vaccines
end

get "/:pet_name/prescriptions" do 
  @name = params[:pet_name]
  @info = @users[session[:username]]["pets"][@name.downcase]
  @prescriptions = @info["prescriptions"]  

  erb :prescriptions
end

get "/:pet_name/:prescription_name/prescriptions" do 
  @name = params[:pet_name]
  @prescription = params[:prescription_name]  
  @info = @users[session[:username]]["pets"][@name.downcase]
  @prescription_info = @info["prescriptions"][@prescription]

  erb :prescription_info
end

post "/:pet_name/:prescription_name/request_refill" do
  @name = params[:pet_name]
  @prescription = params[:prescription_name] 

  session[:message] = "Your refill request for #{@prescription.capitalize} has been submitted! Please allow up to 48 hours for approval."

  redirect "/#{@name}/prescriptions"
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
  -When a user clicks the `Add New Pet` link:
    -They should be redirected to "/:client_name/add_pet" page that contains:
      -A title that says `Patient Information`
      -A form that asks the user for their pet's:
        -Name: 
        -Birthday: 
        -Type: 
        -Breed:
        -Weight (if known):
        -Microchip # (if known):
      -A button that says `Add Patient`
  -Redirect user to "/" (patient should now appear on homepage)
  -Display message that says "#pet_name has been added.""

  --------IMPLEMENTATION FOR ADD PET PAGE---------
  -Create a view template called new_pet 
    -Add a form that asks for the pet's: 
      -Name: 
      -Birthday: 
        -Input type should be "date"
          -(use birthday to calculate age in the dashboard)
      -Type: 
       -Input should be a dropdown menu with different selections (Canine, Feline, Snake, Rabbit, Hamster)
      -Breed:
       -Input should be a dropdown menu with different selections (Yorkie, Chiahuahu, Corgi, Husky, Poodle)
      -Weight:
        -Set the default parameter to be ""
      -Microchip:
        -Set the default parameter to be ""
    -Add a button that says "Add Pet" and submits the form
  -Create a post route for "/add_pet"
    -Assign the parameters to corresponding variables 
      -Validate the name of the pet 
        -Create a method called valid_name? with one parameter: name
          -Check to see if the given name is NOT an empty string
      -Validate the microchip #
        -Create a method called valid_microchip?
          -Check to see if the microchip number is all digits
            -Convert the string to an integer to a string
            -If the converted string is equal to the original string 
              -if the string length is 9, 10, or 15 digits return true 
            -Otherwise return false
    -If valid_name? && valid_microchip is true
      -Add the pet to the pets hash for the current user 
        -Create a key in the pets hash with the given name 
        -Assign the value to a hash that includes all the pet's info
        -Add this new key-value pair back into the YAML file 
      -Set the session[:message] to "#{pet_name}" has been added."
      -Redirect the user "/"
    -Otherwise 
      -set the session message to "Please enter a valid microchip number."
      -set the session message to "Please enter a valid name."



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

--------IMPLEMENTATION FOR ADD PET PAGE---------

-Create a get route that renders the edit_pet page 
-Add a title that says `Edit Patient Information`
-Create a form that asks the user for their pet's new:
  -Name: 
  -Birthday: 
  -Type: 
  -Breed:
  -Weight(lbs):
  -Microchip #:
    -Add exisiting info associated with the specific pet on each part of the form
      -In the get route, access the pet_name name provided by the url
      -Access the hash for the specified pet in the users pets array 
      -Use the appropriate values for each part of the form 
-Add a button that says `Save Changes` to update patient info
  -Create a post route that does the steps outlined for the add new pet page
-Set the session[:message] to "#pet_name's profile has been updated."
-Redirect the user home 
-updated pet info should be displayed on the dashboard and homepage 

    

---DASHBOARD---
  -When a user clicks the `Pet_Name` link:
    -They should be redirected to "/:patient_name/dashboard" page that contains:
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


--------IMPLEMENTATION FOR DASHBOARD PAGE---------
-Create a get route for "/:patient_name/dashboard"
-Create an erb template called dashboard
  -Add a title called Dashboard 
  -Create a table with a row for the pet's:
    -Name
    -Birthday (if it's their birthday a message should pop up that says "Happy Birthday, pet name!")
      -If the current month and day are equal to the pet's birth month and day 
        -Set the session message to be "Happy Birthday #{pet_name}!"
    -Pet type (canine/feline/etc.)
    -Breed
    -Age (calculated by the birthday)
      -Calculate the age of the pet 
        -Require the date class in the application 
        -Create a method called age with one parameter(dob)
          -Get the current date 
          -Subtract the current year from the dob year 
          -Use the following code: 
            require 'date'

            def age(dob)
              now = Time.now.utc.to_date
              now.year - dob.year - ((now.month > dob.month || (now.month == dob.month && now.day >= dob.day)) ? 0 : 1)
            end
    -Weight 
    -Microchip #
  -Add the following links to the bottom of the page:
    -Visit history (w/ links for each visit to view doctors notes)
    -Vaccine Tracker (table that shows when they were performed/ if they're due)
    -RX Prescriptions (how to use instructions, dosage, quantity, expiration etc.)  



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
  -When a certain pet type is selected, make the breed dropdown menu specific to that pet type 
  -Ask for confirmation before deleting a pet from the patient portal

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
  

  ----TODO LIST---
  -VISIT HISTORY PAGE
    -Add a link that says 'Add Visit Summary' to the bottom of the `Visit History` page 
      -This should redirect the user to a form that asks for the visit `Month, Day, and Year` 
      -There should also be a text box for the user to input details about the visit 
      (Only admins are able to add a visit summary)
      -When the user clicks submit, they should be redirected to the `Visit History` page 
      -The new visit should appear in the list of visits on the 'Visit History' page 
      -When the user clicks it, it should load the contents of the rendered .md file created for that visit
  -VACCINE TRACKER PAGE 
    -Add a link that says 'Update Vaccines' to the bottom of the `Vaccine Tracker` page 
      -This should redirect the user to a form that asks for the due date and performed date for each vaccine 
        -The default values should be what is already associated with the due and performed date for each vaccine
      -(Only admins are able to update vaccines)
      -When the user clicks submit, they should be redirected to the `Vaccine Tracker` page 
      -The dates for the updated vaccines should appear in the table
  -RX PRESCRIPTIONS PAGE    
    -Create a get route for the 'RX prescriptions' page 
    -It should display a list of each Prescription associated with that pet
    -Each prescription should be a link
      -When the user clicks it they should be taken to a page that lists the:
        -Name of the medication 
        -Dosage 
        -Refills Remaining
        -Quantity 
        -Instructions
    -There should be a link at the bottom of the page that says "Add Prescription"
    -Only admins should be allowed to add prescriptions for a pet 
    -There should be at the bottom that says request refill 
    -This should take the user to a page that says "Refill Request Form"
      -A form should be rendered that contains:
      -Please select the name of the medication you would like to have refilled:
        -With a dropdown menu with all of the medications currently prescribed to the pet
      -Has #{pet_name} experienced any negative side effects with this medication?
        -Yes or No
      -A submit button that says "Submit Request"
    -After they submit the request, they should be redirected to the 'RX Prescriptions' page
    -A message should pop up that says "Your refill request for #{medication_name} has been submitted! Please allow up to 48 hours for approval. "
    ---TO BE ADDED--
     -The name of the medication should be a section that says Pending Refills
       
           

=end