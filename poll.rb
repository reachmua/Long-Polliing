# poll.rb
# Beget: 11/26/2017

require 'colorize'
require 'typhoeus'
require 'json'

HEADER_OPTIONS = {
  # Expires every 60 minutes. 'developer_token = Generate in app.box.com'
  headers: {"Authorization" => "Bearer developer_token"}
}

# Determine current stream position.
def get_current_location
  puts 'get me'.yellow
  response = Typhoeus.get("https://api.box.com/2.0/events?stream_position=now",
    HEADER_OPTIONS
  )
  puts "Response: #{response.body}"
  response = JSON.parse(response.body)
  current_location = response['next_stream_position']
  puts "The current location is: #{current_location}".blue
  current_location
end

def get_long_poll_url
  response = Typhoeus.options("https://api.box.com/2.0/events", HEADER_OPTIONS)
  puts "23: Response: #{response.body}".yellow
  response = JSON.parse(response.body)
  long_poll_url = response['entries'][0]['url']
  long_poll_url
end

# Ping server and collect any changes.
def collect_and_print_event_details(stream_position)
  puts 'Alright. Time to get event details'.yellow
  response = Typhoeus.get("https://api.box.com/2.0/events?stream_position=#{stream_position}", HEADER_OPTIONS)
  puts "32: Response: #{response.body}".yellow
  response = JSON.parse(response.body)
  entries = response['entries']
  entries.each do |entry|
      puts "#{entry['event_id']} | #{entry['event_type']}".magenta
  end
end

def listen_to_long_poll_url(url, stream_position)
  full_url = "#{url}&stream_position=#{stream_position}"

  request = Typhoeus::Request.new(url)

  request.on_complete do |response|
    if response.success?
      # hell yeah
      puts "There might be a new event. Let us reconnect and begin all over.".green
      puts response.body
      collect_and_print_event_details(stream_position)
    elsif response.timed_out?
      # aw hell no
      puts "Got a weird time out. Should not happen".red
    elsif response.code == 0
      # Could not get an http response, something's wrong.
      puts "Bad situation reached: #{response.return_message}"
    else
      # Received a non-successful http response.
        puts "HTTP request failed: #{response.code.to_s}"
    end
  end

  request.run
end

# Keep polling till stopped.
puts 'Starting Script.'.blue
loop do
  # Get Current Stream Position.
  current_stream_position = get_current_location
  # Get The long Poll URL.
  long_poll_url = get_long_poll_url
  # Listen to long poll URL
  listen_to_long_poll_url(long_poll_url, current_stream_position)

  # We can also consolidate above line to read:
  # listen_to_long_poll_url(get_long_poll_url, get_current_location)
  # Reconnect
  puts 'Reconnecting..'.yellow
end