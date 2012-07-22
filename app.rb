require "sinatra"
require 'koala'
require 'active_record'
require 'sinatra/activerecord'
require 'uri'

configure :development do
    set :database, 'mysql://root:toor@localhost/doodler'
    set :adapter, 'mysql'
end

configure :test do
    set :database, 'mysql://root:toor@localhost/doodler'
    set :adapter, 'mysql'
end

configure :production do
    db = URI.parse(ENV['DATABASE_URL'] || 'postgres://localhost/mydb')
    ActiveRecord::Base.establish_connection(
        :adapter  => db.scheme == 'postgres' ? 'postgresql' : db.scheme,
        :host     => db.host,
        :port     => db.port,
        :username => db.user,
        :password => db.password,
        :database => db.path[1..-1],
        :encoding => 'utf8'
    )
end

# Models
class Doodle < ActiveRecord::Base
    validates_presence_of :userid
    validates_presence_of :photoid
end

# Facebook BP Code
enable :sessions
set :raise_errors, false
set :show_exceptions, false

# Scope defines what permissions that we are asking the user to grant.
# In this example, we are asking for the ability to publish stories
# about using the app, access to what the user likes, and to be able
# to use their pictures.  You should rewrite this scope with whatever
# permissions your app needs.
# See https://developers.facebook.com/docs/reference/api/permissions/
# for a full list of permissions
FACEBOOK_SCOPE = 'user_likes,user_photos,user_photo_video_tags,publish_stream'

unless ENV["FACEBOOK_APP_ID"] && ENV["FACEBOOK_SECRET"]
    abort("missing env vars: please set FACEBOOK_APP_ID and FACEBOOK_SECRET with your app credentials")
end

before do
    # HTTPS redirect
    if settings.environment == :production && request.scheme != 'https'
        redirect "https://#{request.env['HTTP_HOST']}"
    end
end

helpers do
    def host
        request.env['HTTP_HOST']
    end

    def scheme
        request.scheme
    end

    def url_no_scheme(path = '')
        "//#{host}#{path}"
    end

    def url(path = '')
        "#{scheme}://#{host}#{path}"
    end

    def authenticator
        @authenticator ||= Koala::Facebook::OAuth.new(ENV["FACEBOOK_APP_ID"], ENV["FACEBOOK_SECRET"], url("/auth/facebook/callback"))
    end

    def fbinit
        # Get base API Connection
        @graph  = Koala::Facebook::API.new(session[:access_token])

        # Get public details of current application
        @app  =  @graph.get_object(ENV["FACEBOOK_APP_ID"])
        return @graph, @app
    end
end

# the facebook session expired! reset ours and restart the process
error(Koala::Facebook::APIError) do
    session[:access_token] = nil

    redirect "/auth/facebook"
end

get "/post" do
    # Get base API Connection
    @graph  = Koala::Facebook::API.new(session[:access_token])

    # Get public details of current application
    @app  =  @graph.get_object(ENV["FACEBOOK_APP_ID"])
    if session[:access_token]
        @graph.put_connections("me", "links", {:name => "le goog", :link => "www.google.com", :picture => "http://lh4.googleusercontent.com/-v0soe-ievYE/AAAAAAAAAAI/AAAAAAAAdPc/JRVJ5ihOy2U/photo.jpg?sz=116"});
    end
    "asdf"
end

get "/" do
    @graph, @app = fbinit()
    if session[:access_token]
        @user    = @graph.get_object("me")
        @photos  = @graph.get_connections('me', 'photos')
        @friends_using_app = @graph.fql_query("SELECT uid, name, is_app_user, pic_square FROM user WHERE uid in (SELECT uid2 FROM friend WHERE uid1 = me()) AND is_app_user = 1")
    end
    @recent_doodles = Doodle.find(:all, :order => "updated_at desc", :limit => 6).reverse
    erb :index
end

# used by Canvas apps - redirect the POST to be a regular GET
post "/" do
    redirect "/"
end

# used to close the browser window opened to post to wall/send to friends
get "/close" do
    "<body onload='window.close();'/>"
end

get "/sign_out" do
    session[:access_token] = nil
    redirect '/'
end

get "/auth/facebook" do
    session[:access_token] = nil
    redirect authenticator.url_for_oauth_code(:permissions => FACEBOOK_SCOPE)
end

get '/auth/facebook/callback' do
    session[:access_token] = authenticator.get_access_token(params[:code])
    redirect '/'
end

get '/new' do
    @graph, @app = fbinit()
    if session[:access_token]
        @user    = @graph.get_object("me")
        if params[:page]
            fake_graph_collection = Koala::Facebook::GraphCollection.new({"data" => []}, @graph)
            url_params = fake_graph_collection.parse_page_url(params[:page])
            @photos = @graph.get_page(url_params)
        else
            @photos  = @graph.get_connections('me', 'photos')
        end
        @friends_using_app = @graph.fql_query("SELECT uid, name, is_app_user, pic_square FROM user WHERE uid in (SELECT uid2 FROM friend WHERE uid1 = me()) AND is_app_user = 1")
        @friends = @graph.get_connections('me', 'friends')
        erb :newdoodle
    else
        redirect '/'
    end
end

get '/:photoid/json' do |photoid|
    content_type :json
    @graph, @app = fbinit()
    @graph  = Koala::Facebook::API.new(session[:access_token])
    @doodles = Doodle.where("photoid = ?", photoid)

    response = []
    @doodles.each do |doodle|
        formatted_doodle = { data: doodle[:data],
            user_name: @graph.get_object(doodle[:userid])["name"],
            photo_url: @graph.get_object(doodle[:photoid])["source"],
            profile_photo_url: @graph.get_picture(doodle[:userid]),
            deleteable: doodle[:userid] == @graph.get_object("me")["id"]
        }
        response.push(formatted_doodle)
    end
    response.to_json
end

get '/friends' do
    @graph, @app = fbinit()
    if session[:access_token]
        @friends  = @graph.get_connections('me', 'friends')
    end
    erb :friends
end
post '/fetch_list' do
    @graph, @app = fbinit()
    if session[:access_token]
        @photos  = @graph.get_connections( params[:id] , 'photos')
    end
    string =  "<ul class='gridlist'>"
    @photos.each_with_index do |photo, index|
        string += "<li> " + "<a href='./"+photo['id']+"')'>" +
       " <img width='94px' height='70px' src='" + photo['picture'] + "' />" +
        "</a> </li>"
    end
        string = string + "</ul>"
end
post '/:photoid/save' do
    @graph, @app = fbinit()
    if session[:access_token]
        @userid = @graph.get_object("me")
        @photoid = photoid

        new_doodle = Doodle.new(userid: @userid["id"].to_s,
                                photoid: @photoid.to_s,
                                data: params[:data])
        new_doodle.save()
        redirect '/' + new_doodle[:photoid].to_s
    else
        redirect '/'
    end
end

get '/:photoid/:doodleid/delete' do |photoid, doodleid|
    @graph, @app = fbinit()
    if session[:access_token]
        @doodle = Doodle.find(doodleid)

        if @doodle[:userid] == @graph.get_object("me")["id"]
            @doodle.destroy()
            @doodle.save()
        end

        redirect '/' + photoid.to_s
    else
        redirect '/'
    end
end

get '/:photoid' do |photoid|
    @graph, @app = fbinit()
    @graph  = Koala::Facebook::API.new(session[:access_token])
    if session[:access_token]
        @user    = @graph.get_object("me")
        if /^[\d]+(\.[\d]+){0,1}$/ === photoid
            @doodles = Doodle.where("photoid = ?", photoid)
            if @doodles.length != 0
                erb :showdoodle
            else
                begin
                    @graph.get_object(photoid)
                rescue
                    redirect '/'
                end
                erb :showdoodle
            end
        else
            redirect '/'
        end
    else
        redirect '/'
    end
end


