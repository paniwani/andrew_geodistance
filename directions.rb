require 'httparty'
require 'json'
require 'pry'
require 'csv'

PI = 3.1415926535
RAD_PER_DEG = 0.017453293

Rkm = 6371              # radius in kilometers
Rmeters = Rkm * 1000    # radius in meters  

# Geocoded location of Chokwe District Hospital
DESTINATION_LAT = -24.529887
DESTINATION_LON = 32.996639

GOOGLE_DIRECTIONS_API_URL = "http://maps.googleapis.com/maps/api/directions/json"

# Haversine formula to compute crow flies distance
# http://en.wikipedia.org/wiki/Haversine_formula
# http://en.wikipedia.org/wiki/Great-circle_distance
# http://www.esawdust.com/blog/gps/files/HaversineFormulaInRuby.html
def haversine_distance( lat1, lon1, lat2, lon2 )
  dlon = lon2 - lon1
  dlat = lat2 - lat1

  dlon_rad = dlon * RAD_PER_DEG 
  dlat_rad = dlat * RAD_PER_DEG

  lat1_rad = lat1 * RAD_PER_DEG
  lon1_rad = lon1 * RAD_PER_DEG

  lat2_rad = lat2 * RAD_PER_DEG
  lon2_rad = lon2 * RAD_PER_DEG

  a = (Math.sin(dlat_rad/2))**2 + Math.cos(lat1_rad) * Math.cos(lat2_rad) * (Math.sin(dlon_rad/2))**2
  c = 2 * Math.atan2( Math.sqrt(a), Math.sqrt(1-a))

  dMeters = Rmeters * c     # delta in meters

  return dMeters
end

# Use Google Directions API to return distance and duration
# https://developers.google.com/maps/documentation/directions/
def google_distance_duration(origin, mode)
  # Query Google Directions API
  params = { origin: origin, destination: "#{DESTINATION_LAT},#{DESTINATION_LON}", mode: mode, sensor: "false" }
  results = JSON.parse(HTTParty.get(GOOGLE_DIRECTIONS_API_URL, query: params).body)

  # Parse JSON output to get distance and duration
  route = results["routes"][0]

  distance = route.nil? ? "n/a" : route["legs"][0]["distance"]["value"]
  duration = route.nil? ? "n/a" : route["legs"][0]["duration"]["value"]/60

  return [distance, duration]
end

# Load data
input_data = CSV.read("ChockweShortGPS_2013_06_26_21_08_33_gps_only.csv")
input_data.delete_at(0) # remove header

count = 0

# Write output to CSV file
CSV.open("ChockweShortGPS_2013_06_26_21_08_33_gps_only_RESULTS.csv", "wb") do |csv|

  # Write header
  csv << ["UID", "Name", "Origin", "Haversine Distance (m)", "Google Driving Distance (m)", "Google Driving Duration (min)", "Google Walking Distance (m)", "Google Walking Duration (min)"]

  # Iterate through each patient
  input_data.each_with_index do |row, uid|
    
    # Get data and ignore patients without GPS data
    name = row[4]
    lat  = row[6]
    lon  = row[7]

    next if lat == "n/a" or lon == "n/a"

    lat  = lat.to_f
    lon  = lon.to_f

    # Get haversine distance
    hd = haversine_distance(lat, lon, DESTINATION_LAT, DESTINATION_LON )

    # Set origin coordinates
    origin = "#{lat},#{lon}"

    # Get google driving and walking distances and durations
    driving_dist, driving_dur = google_distance_duration(origin, "driving")
    walking_dist, walking_dur = google_distance_duration(origin, "walking")

    # Write output to CSV
    csv << [ uid, name, origin, hd, driving_dist, driving_dur, walking_dist, walking_dur ]

    count = count + 1
    puts "Completed #{count} patients"

    break if count >= 100
  end
end