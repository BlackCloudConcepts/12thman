class WelcomeController < ApplicationController
  def index
	require 'json'

	@myname = "Scott"

	# http://oauth.rubyforge.org
	# http://developer.apps.yahoo.com/projects/RM9aza50
	# http://developer.yahoo.com/fantasysports/guide/game-resource.html
	# http://json.parser.online.fr
	
	if (params[:step] == "1")
		@consumer=::OAuth::Consumer.new( "dj0yJmk9MEdkWXZHdTFoTXdiJmQ9WVdrOVVrMDVZWHBoTlRBbWNHbzlNVEkyTVRnNU5UYzJNZy0tJnM9Y29uc3VtZXJzZWNyZXQmeD1jZA--","992785c3d4bd3170262f8d544702f9fbcd48d5ea", {
			:site=>"https://api.login.yahoo.com",
			:request_token_path=>"/oauth/v2/get_request_token",
			:access_token_path => '/oauth/v2/get_token', 
			:authorize_path => '/oauth/v2/request_auth', 
			:signature_method => 'HMAC-SHA1', 
			:oauth_version => '1.0'
		})
		@request_token=@consumer.get_request_token
		session[:request_token]=@request_token
		redirect_to @request_token.authorize_url
	end
	
	if (params[:step] == "2")	
		@access_token = session[:request_token].get_access_token(:oauth_verifier=>"stwqma")
		
		# game
#		url = "http://fantasysports.yahooapis.com/fantasy/v2/game/273"
		url = " http://fantasysports.yahooapis.com/fantasy/v2/game/nfl"
		result=@access_token.get(url)
		@data = Hash.from_xml(result.body).to_json
		@data = JSON.parse(@data);
		@gameid = @data['fantasy_content']['game']['game_id']

		# user
		url = "http://fantasysports.yahooapis.com/fantasy/v2/users;use_login=1/games;game_keys="+@gameid+"/leagues"
		result=@access_token.get(url)
                @data = Hash.from_xml(result.body).to_json
		@data = JSON.parse(@data)
		@leagueid = @data['fantasy_content']['users']['user']['games']['game']['leagues']['league']['league_id']
		@leaguename = @data['fantasy_content']['users']['user']['games']['game']['leagues']['league']['name']
		
		# teams
		url = "http://fantasysports.yahooapis.com/fantasy/v2/users;use_login=1/games;game_keys="+@gameid+"/teams"
		result=@access_token.get(url)
                @data = Hash.from_xml(result.body).to_json
                @data = JSON.parse(@data)
		@teamid = @data['fantasy_content']['users']['user']['games']['game']['teams']['team']['team_key']
		@teamname = @data['fantasy_content']['users']['user']['games']['game']['teams']['team']['name']
		@teamlogo = @data['fantasy_content']['users']['user']['games']['game']['teams']['team']['team_logos']['team_logo']['url']

		# roster
		url = "http://fantasysports.yahooapis.com/fantasy/v2/team/"+@teamid+"/roster/players"
		result=@access_token.get(url)
                @data = Hash.from_xml(result.body).to_json
#		@output = @data
                @data = JSON.parse(@data)
		@arr = @data['fantasy_content']['team']['roster']['players']['player']
		@roster = Array.new
		@arr.length.times do |i|
			@roster << {
				'name' => @arr[i]['name']['full'],
				'position' => @arr[i]['display_position'],
				'picture' => @arr[i]['headshot']['url'],
				'teamabbr' => @arr[i]['editorial_team_abbr'],
				'playerid' => @arr[i]['editorial_player_key']
			}
		end
		
	end

	if (params[:step] == "3")
		
	end

  end
end
