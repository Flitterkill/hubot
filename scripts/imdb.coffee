#
# Description:
#   Get the movie poster and synposis for a given query
#
# Dependencies:
#   None
#
# Configuration:
#   None
#
# Commands:
#   hubot imdb the matrix
#
# Author:
#   orderedlist

module.exports = (robot) ->
  
  robot.respond /(imdb|movie)( me)? (.*+), (msg) ->
    query = msg.match[3]
    msg.http("http://omdbapi.com/")
      .query({
        t: query
        plot: full
      })
      .get() (err, res, body) ->
        movie = JSON.parse(body)
        if movie
          text = "*#{movie.Title}* - #{movie.Year}\n"
          text += "IMDB: #{movie.imdbRating} Metascore: #{movie.Metascore}\n"
          text += "#{movie.Plot}\n"
          text += "#{movie.Poster}\n" if movie.Poster
          msg.send text
        else
          msg.send "Couldn't find it. Sorry."
