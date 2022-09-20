class YapiController < ApplicationController
  def index
	require 'json'
	require 'open-uri'

	@access_token = session[:request_token].get_access_token(:oauth_verifier=>session[:code])

	@url = CGI::unescape(params[:url]).gsub("|","/")

	url = "http://fantasysports.yahooapis.com/"+@url
	result=@access_token.get(url)
	@data = Hash.from_xml(result.body).to_json	
  end
end
