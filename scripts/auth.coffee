# Description:
#   Auth allows you to assign roles to users which can be used by other scripts
#   to restrict access to Hubot commands
#
# Dependencies:
#   None
#
# Configuration:
#   HUBOT_AUTH_ADMIN - A comma separate list of user IDs
#
# Commands:
#   hubot <user> has <role> role - Assigns a role to a user
#   hubot <user> doesn't have <role> role - Removes a role from a user
#   hubot what role does <user> have - Find out what roles are assigned to a specific user
#   hubot who has admin role - Find out who's an admin and can assign roles
#
# Notes:
#   * Call the method: robot.auth.hasRole(msg.envelope.user,'<role>')
#   * returns bool true or false
#
#   * the 'admin' role can only be assigned through the environment variable
#   * roles are all transformed to lower case
#
#   * The script assumes that user IDs will be unique on the service end as to
#     correctly identify a user. Names were insecure as a user could impersonate
#     a user
#
# Author:
#   alexwilliamsca, tombell

module.exports = (robot) ->

  unless process.env.HUBOT_AUTH_ADMIN?
    robot.logger.warning 'The HUBOT_AUTH_ADMIN environment variable not set'

  if process.env.HUBOT_AUTH_ADMIN?
    admins = process.env.HUBOT_AUTH_ADMIN.split ','
  else
    admins = []

  class Auth
    hasRole: (user, roles) ->
      user = robot.brain.userForId(user.id)
      if user? and user.roles?
        roles = [roles] if typeof roles is 'string'
        for role in roles
          return true if role in user.roles
      return false

    usersWithRole: (role) ->
      users = []
      for own key, user of robot.brain.data.users
        if robot.auth.hasRole(user, role)
          users.push(user)
      users
      
    cancan: (roles, msg) ->
      user = msg.envelope.user
      return true if robot.auth.hasRole(user, 'admin')
      #msg.send "Checking #{user.id} for #{roles.join(', ')}"
      for role in roles
        return true if robot.auth.hasRole(user, role)
      msg.send "You don't have permission. Contact #{roles.join(', ')}"
      return false

  robot.auth = new Auth

  getAmbiguousUserText = (users) ->
    "Be more specific, I know #{users.length} people named like that: #{(user.name for user in users).join(", ")}"

  robot.respond /@?(.+) (has) (["'\w: -_]+) (role)/i, (msg) ->
    name    = msg.match[1].trim()
    newRole = msg.match[3].trim().toLowerCase()

    unless name.toLowerCase() in ['', 'who', 'what', 'where', 'when', 'why']
      users = robot.brain.usersForFuzzyName(name)
      if users.length is 1
        user = users[0]
        user.roles = user.roles or [ ]
        if newRole in user.roles
          msg.reply "#{name} already has the '#{newRole}' role."
        else
          if msg.message.user.id.toString() in admins
            user.roles.push(newRole)
            msg.reply "Ok, #{name} has the '#{newRole}' role."
      else if users.length > 1
        msg.send getAmbiguousUserText users
      else
        msg.send "I don't know anything about #{name}."

  robot.respond /@?(.+) (doesn't have|does not have) (["'\w: -_]+) (role)/i, (msg) ->
    name    = msg.match[1].trim()
    newRole = msg.match[3].trim().toLowerCase()

    unless name.toLowerCase() in ['', 'who', 'what', 'where', 'when', 'why']
      user = robot.brain.userForName(name)
      return msg.reply "#{name} does not exist" unless user?
      user.roles or= []

      if newRole is 'admin'
        msg.reply "Sorry, the 'admin' role can only be removed from the HUBOT_AUTH_ADMIN env variable."
      else
        myRoles = msg.message.user.roles or []
        if msg.message.user.id.toString() in admins
          user.roles = (role for role in user.roles when role isnt newRole)
          msg.reply "Ok, #{name} doesn't have the '#{newRole}' role."

  robot.respond /(what role does|what roles does|who is) @?(.+) (have)?\?*$/i, (msg) ->
    name = msg.match[2].trim()
    user = robot.brain.userForName(name)
    return msg.reply "#{name} does not exist" unless user?
    user.roles or= []
    displayRoles = user.roles

    if user.id.toString() in admins
      displayRoles.push('admin')

    if displayRoles.length == 0
      msg.reply "#{name} has no roles."
    else
      msg.reply "#{name} has the following roles: #{displayRoles.join(', ')}."
      
  robot.respond /what role(s)? I have$/i, (msg) ->
    user = robot.brain.userForId(msg.message.user.id)
    return msg.reply "Strange... You dont not exist" unless user?
    user.roles or= []
    displayRoles = user.roles

    if displayRoles.length == 0
      msg.reply "You have no roles."
    else
      msg.reply "You have following roles: #{displayRoles.join(', ')}."

  robot.respond /who has admin role\?*$/i, (msg) ->
    adminNames = []
    for admin in admins
      user = robot.brain.userForId(admin)
      adminNames.push user.name if user?

    if adminNames.length > 0
      msg.reply "The following people have the 'admin' role: #{adminNames.join(', ')}"
    else
      msg.reply "There are no people that have the 'admin' role."
