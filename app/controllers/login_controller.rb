class LoginController < ApplicationController
  def index
	# http://oauth.rubyforge.org
	# http://developer.apps.yahoo.com/projects/RM9aza50
	# http://developer.yahoo.com/fantasysports/guide/game-resource.html
	# http://json.parser.online.fr
	
	@consumer=::OAuth::Consumer.new( "DELETED","DELETED", {
		:site=>"https://api.login.yahoo.com",
		:request_token_path=>"/oauth/v2/get_request_token",
		:access_token_path => '/oauth/v2/get_token', 
		:authorize_path => '/oauth/v2/request_auth', 
		:signature_method => 'HMAC-SHA1', 
		:oauth_version => '1.0'
	})
	@request_token=@consumer.get_request_token
	session[:request_token]=@request_token
#	'open #{@request_token.authorize_url}'
#	redirect_to @request_token.authorize_url
	
  end
end
