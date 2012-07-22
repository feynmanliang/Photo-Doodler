require "sinatra"
require 'koala'
require 'active_record'
require 'sinatra/activerecord'
require 'uri'

configure :development do
    set :database, 'mysql://root:toor@localhost/doodler'
end

configure :test do
    set :database, 'mysql://root:toor@localhost/doodler'
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
FACEBOOK_SCOPE = 'user_likes,user_photos,user_photo_video_tags'

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

get "/" do
    @graph, @app = fbinit()
    if session[:access_token]
        @user    = @graph.get_object("me")
        @photos  = @graph.get_connections('me', 'photos').first(24)
        @friends_using_app = @graph.fql_query("SELECT uid, name, is_app_user, pic_square FROM user WHERE uid in (SELECT uid2 FROM friend WHERE uid1 = me()) AND is_app_user = 1")
    end
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

get '/doodles' do
    @graph, @app = fbinit()
    if session[:access_token]
        @user    = @graph.get_object("me")
        @friends_using_app = @graph.fql_query("SELECT uid, name, is_app_user, pic_square FROM user WHERE uid in (SELECT uid2 FROM friend WHERE uid1 = me()) AND is_app_user = 1")
        erb :doodles
    else
        redirect '/'
    end
end

get '/doodles/new' do
    @graph, @app = fbinit()
    if session[:access_token]
        @user    = @graph.get_object("me")
        @photos  = @graph.get_connections('me', 'photos').first(24)
        @friends_using_app = @graph.fql_query("SELECT uid, name, is_app_user, pic_square FROM user WHERE uid in (SELECT uid2 FROM friend WHERE uid1 = me()) AND is_app_user = 1")
        @friends = @graph.get_connections('me', 'friends')
        erb :newdoodle
    else
        redirect '/'
    end
end

get '/doodles/new/:photoID' do
    @graph, @app = fbinit()
    if session[:access_token]
        @userID = @graph.get_object("me")
        @photoID = params[:photoID]

        thisDoodle = Doodle.new(userID: @userID,
                                photoID: @photoID,
                                data: "")
        thisDoodle.save()
        redirect '/doodles' + thisDoodle[:id]
    else
        redirect '/'
    end
end

get '/doodles/:doodleID' do |doodleID|
    @graph, @app = fbinit()
    if session[:access_token]
        @user    = @graph.get_object("me")
        @photos  = @graph.get_connections('me', 'photos').first(24)
        @friends_using_app = @graph.fql_query("SELECT uid, name, is_app_user, pic_square FROM user WHERE uid in (SELECT uid2 FROM friend WHERE uid1 = me()) AND is_app_user = 1")
    else
        redirect '/'
    end
    erb :showdoodle
end
