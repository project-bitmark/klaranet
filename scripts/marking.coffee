# Description:
#   Give and List User Marks
#
# Dependencies:
#   bitmarkd must be running
#   bitmark-cli must be in path
#   wallet must be funded
#
# Configuration:
#   None
#
# Commands:
#   mark     <user> <amount> <reason> - mark user amount
#   balance  [user]                   - balance for a user
#   top5                              - displays today's top5
#   +1                                - one mark to the last user, max 25
#   !seeAlso                          - http://klaranet.com/ , https://github.com/melvincarvalho/klaranet/wiki/Commands
#
# Author:
#   bitmark team
#


# requires
exec = require('child_process').exec;
fs = require('fs')


# init

credits  = {} # simple key value store or URI / balance for now
symbol   = '₥'
last     = 'klaranet'
prev     = {}
secret   = process.env.HUBOT_DEPOSIT_SECRET
if process.env.HUBOT_ADAPTER is 'irc'

  adapter = 'irc'
  irc_server = process.env.HUBOT_IRC_SERVER
else if process.env.HUBOT_ADAPTER is 'slack'
  adapter = 'slack'
  slack_team = process.env.HUBOT_SLACK_TEAM
else if process.env.HUBOT_ADAPTER is 'shell'
  adapter = 'shell'
else
  throw new Error('HUBOT_ADAPTER env variable is required')
  #adapter = 'slack'


# functions
to_URI = ( id ) ->
  if id.indexOf(':') != -1 and id[id.length-1] != ':'
    id
  else if adapter is 'irc'
    'irc://' + id + '@' + irc_server + '/'
  else if adapter is 'slack'
    'https://' + slack_team + '.slack.com/team/' + id + '#this'
  else if adapter is 'shell'
    'urn:shell:' + id
  else
     id

from_URI = ( URI ) ->
  if URI.indexOf('irc://') is 0 and adapter is 'irc'
    URI.split(":")[1].substring(2).split('@')[0]
  else if URI.indexOf('https://' + slack_team + '.slack.com/team/') is 0 and URI.indexOf('#this') != -1 and adapter is 'slack'
    'http://klaranet.com/recent.php?uri=' + encodeURIComponent(URI) + '|' + URI.split(":")[1].substring(2).split('/')[2].split('#')[0]
  else
    URI

#   deposit  <user> <amount> <secret> - deposit amount using shared secret
deposit_credits = (msg, URI, amount, robot) ->
  robot.brain.data.credits[URI] ?= 0
  robot.brain.data.credits[URI] += parseFloat(amount)
  command = 'credit insert -d klaranet -w https://klaranet.com/wallet.ttl#this bitmark:baGoXxccv75uWNvUCwFLbXuroccc7zhp2n ' + parseFloat(amount) + ' "https://w3id.org/cc#mark" "' + to_URI(msg.message.user.name) + '" '
  console.log(command)
  exec command, (error, stdout, stderr) ->
    console.log(error)
    console.log(stdout)
    console.log(stderr)
    msg.send amount + symbol + ' to ' + from_URI(URI)

transfer_credits = (msg, URI, amount, robot, comment) ->
  command = 'credit balance ' + to_URI(msg.message.user.name) + ' -d klaranet -w https://klaranet.com/wallet.ttl#this  '
  console.log(command)
  exec command, (error, stdout, stderr) ->
    console.log(error)
    console.log(stdout)
    console.log(stderr)
    balance = parseFloat(stdout)
    console.log("Transfer " + msg.message.user.name + " URI " + to_URI(msg.message.user.name) + " amount " + amount);
    console.log("Balance is " + balance)
    if balance >= parseFloat(amount)
      #robot.brain.data.credits[URI] ?= 0
      #robot.brain.data.credits[URI] += parseFloat(amount)
      #robot.brain.data.credits[to_URI(msg.message.user.name)] -= parseFloat(amount)
      if comment is undefined
        comment = ''
      msg.send amount + symbol + ' has been awarded to ' + from_URI(URI) + ' ' + comment
      command = 'credit insert -d klaranet -w https://klaranet.com/wallet.ttl#this ' + to_URI(msg.message.user.name) + ' ' + parseFloat(amount) + ' "https://w3id.org/cc#bit" "' + URI + '" "' + msg.message.user.room + '@' + adapter + ' ' + comment + '"'
      console.log(command)
      exec command, (error, stdout, stderr) ->
        console.log(error)
        console.log(stdout)
        console.log(stderr)
    else
      msg.send 'sorry, not enough funds'


withdraw_credits = (msg, address, amount, robot) ->
  if robot.brain.data.credits[to_URI(msg.message.user.name)] >= parseFloat(amount)
    command = 'bitmark-cli sendtoaddress ' + address + ' ' + ( parseFloat(amount) / 1000.0 )
    console.log(command)
    exec command, (error, stdout, stderr) ->
      console.log('## ERROR: ' + error)
      console.log(stdout)
      console.log(stderr)
      if (error)
        console.log(error);
        msg.send "Withdrawl could not proceed, server may be down or invalid address"
      else
        robot.brain.data.credits[to_URI(msg.message.user.name)] -= parseFloat(amount)
        msg.send stdout
        command = 'credit insert -d klaranet -w https://klaranet.com/wallet.ttl#this ' + to_URI(msg.message.user.name) + ' ' + parseFloat(amount) + ' "https://w3id.org/cc#bit" bitmark:' + address
        console.log(command)
        exec command, (error, stdout, stderr) ->
          console.log(error)
          console.log(stdout)
          console.log(stderr)
  else
    msg.send 'not enough funds'



save = (robot) ->
  robot.brain.data.credits = robot.brain.data.credits


# MAIN
module.exports = (robot) ->
  robot.brain.on 'loaded', ->
    credits = robot.brain.data.credits or {}
    robot.brain.resetSaveInterval(1)

  # DEPOSIT
  robot.hear /^deposit\s+(\d+)\s+([\w\S]+)\s+([\w\S]*)$/i, (msg) ->
    if msg.match[3] is secret
      msg.send 'deposit to ' + msg.match[2] + ' ' + msg.match[1]
      deposit_credits(msg, to_URI(msg.match[2]), msg.match[1], robot)
      save(robot)

  # TRANSFER
  robot.hear /^(transfer|#transfer|mark|#mark|bitmark|#bitmark)\s+@?([\w\S]+?):?\s*$/i, (msg) ->
    transfer_credits(msg, to_URI(msg.match[2]), 5, robot)
    save(robot)

  robot.hear /^(transfer|#transfer|mark|#mark|bitmark|#bitmark)\s+@?([\w\S]+?):?\s+(\d+)\s*$/i, (msg) ->
    transfer_credits(msg, to_URI(msg.match[2]), msg.match[3], robot)
    save(robot)

  robot.hear /^(transfer|#transfer|mark|#mark|bitmark|#bitmark)\s+@?([\w\S]+?):?\s+(\d+)\s+([\w\S]+.*)\s*$/i, (msg) ->
    transfer_credits(msg, to_URI(msg.match[2]), msg.match[3], robot, msg.match[4])
    save(robot)


  robot.hear /^\+(\d+)\s*$/i, (msg) ->
    plus = msg.match[1]
    to = prev[msg.message.user.room] || 'klaranet'
    if plus <= 25
      transfer_credits(msg, to_URI(to), plus, robot)
    else
      msg.send 'Max is +25'
    save(robot)

  # WITHDRAW
  robot.hear /^withdraw\s+(\d+)\s+([\w\S]+)\s*$/i, (msg) ->
    destination = msg.match[2]
    if destination is 'foundation'
      destination = 'bQmnzVS5M4bBdZqBTuHrjnzxHS6oSUz6cG'
    #withdraw_credits(msg, destination, msg.match[1], robot)
    save(robot)

  # BALANCE
  robot.hear /^balance\s+@?([\w\S]+):?\s*$/i, (msg) ->
    #redis-brain.getData()
    URI = to_URI(msg.match[1])
    #msg.send('to URI is : ' + URI)
    #msg.send('from URI is : ' + from_URI(URI))
    #robot.brain.data.credits[URI] ?= 0
    command = 'credit balance ' + URI + ' -d klaranet -w https://klaranet.com/wallet.ttl#this  '

    console.log(command)
    exec command, (error, stdout, stderr) ->
      console.log(error)
      console.log(stdout)
      console.log(stderr)
      balance = parseFloat(stdout)
      #robot.brain.data.credits[URI] = balance
      msg.send ' ' + from_URI(URI) + ' has ' + balance + symbol

  robot.hear /^balance\s*$/i, (msg) ->
    URI = to_URI(msg.message.user.name)
    #msg.send('to URI is : ' + URI)
    #msg.send('from URI is : ' + from_URI(URI))
    #robot.brain.data.credits[URI] ?= 0
    command = 'credit balance ' + to_URI(msg.message.user.name) + ' -d klaranet -w https://klaranet.com/wallet.ttl#this  '

    console.log(command)
    exec command, (error, stdout, stderr) ->
      console.log(error)
      console.log(stdout)
      console.log(stderr)
      balance = parseFloat(stdout)
      msg.send ' ' + from_URI(URI) + ' has ' + balance + symbol
      #robot.brain.data.credits[URI] = balance


  robot.hear /^top5\s*$/i, (msg) ->
    #msg.send('to URI is : ' + URI)
    #msg.send('from URI is : ' + from_URI(URI))
    command = './top.sh '
    console.log(command)
    exec command, (error, stdout, stderr) ->
      console.log(error)
      console.log(stdout)
      console.log(stderr)
      j = JSON.parse(stdout)
      str = "*Today's top 5 by Reputation*\n"
      for i in j
        if i != null
          str += ' ' + from_URI(i.source) + ' ' + i.amount + '\n'
      msg.send str




  # WEB
  robot.router.get "/marks", (req, res) ->
    res.end JSON.stringify(robot.brain.data.credits)


  # LISTEN
  robot.hear /.*/i, (msg) ->
    last = msg.message.user.name
    prev[msg.message.user.room] = msg.message.user.name
    console.log(JSON.stringify(msg.message))
    console.log("[" + (new Date).toLocaleTimeString() + "] " + msg.message.text)
    
