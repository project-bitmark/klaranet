var adapter, credits, deposit_credits, exec, from_URI, fs, irc_server, last, prev, save, secret, slack_team, symbol, to_URI, transfer_credits, withdraw_credits

exec = require('child_process').exec

fs = require('fs')

credits = {}

symbol = '₥'

last = 'klaranet'

prev = {}

secret = process.env.HUBOT_DEPOSIT_SECRET

if (process.env.HUBOT_ADAPTER === 'irc') {
  adapter = 'irc'
  irc_server = process.env.HUBOT_IRC_SERVER
} else if (process.env.HUBOT_ADAPTER === 'slack') {
  adapter = 'slack'
  slack_team = process.env.HUBOT_SLACK_TEAM
} else if (process.env.HUBOT_ADAPTER === 'shell') {
  adapter = 'shell'
} else {
  throw new Error('HUBOT_ADAPTER env variable is required')
}

to_URI = function (id) {
  if (id.indexOf(':') !== -1 && id[id.length - 1] !== ':') {
    return id
  } else if (adapter === 'irc') {
    return 'irc://' + id + '@' + irc_server + '/'
  } else if (adapter === 'slack') {
    return 'https://' + slack_team + '.slack.com/team/' + id + '#this'
  } else if (adapter === 'shell') {
    return 'urn:shell:' + id
  } else {
    return id
  }
}

from_URI = function (URI) {
  if (URI.indexOf('irc://') === 0 && adapter === 'irc') {
    return URI.split(':')[1].substring(2).split('@')[0]
  } else if (URI.indexOf('https://' + slack_team + '.slack.com/team/') === 0 && URI.indexOf('#this') !== -1 && adapter === 'slack') {
    return 'http://klaranet.com/recent.php?uri=' + encodeURIComponent(URI) + '|' + URI.split(':')[1].substring(2).split('/')[2].split('#')[0]
  } else {
    return URI
  }
}

deposit_credits = function (msg, URI, amount, robot) {
  var base, command
  if ((base = robot.brain.data.credits)[URI] == null) {
    base[URI] = 0
  }
  robot.brain.data.credits[URI] += parseFloat(amount)
  command = 'credit insert -d klaranet -w https://klaranet.com/wallet.ttl#this bitmark:baGoXxccv75uWNvUCwFLbXuroccc7zhp2n ' + parseFloat(amount) + ' "https://w3id.org/cc#mark" "' + to_URI(msg.message.user.name) + '" '
  console.log(command)
  return exec(command, function (error, stdout, stderr) {
    console.log(error)
    console.log(stdout)
    console.log(stderr)
    return msg.send(amount + symbol + ' to ' + from_URI(URI))
  })
}

transfer_credits = function (msg, URI, amount, robot, comment) {
  var command
  command = 'credit balance ' + to_URI(msg.message.user.name) + ' -d klaranet -w https://klaranet.com/wallet.ttl#this  '
  console.log(command)
  return exec(command, function (error, stdout, stderr) {
    var balance
    console.log(error)
    console.log(stdout)
    console.log(stderr)
    balance = parseFloat(stdout)
    console.log('Transfer ' + msg.message.user.name + ' URI ' + to_URI(msg.message.user.name) + ' amount ' + amount)
    console.log('Balance is ' + balance)
    if (balance >= parseFloat(amount)) {
      if (comment === void 0) {
        comment = ''
      }
      msg.send(amount + symbol + ' has been awarded to ' + from_URI(URI) + ' ' + comment)
      command = 'credit insert -d klaranet -w https://klaranet.com/wallet.ttl#this ' + to_URI(msg.message.user.name) + ' ' + parseFloat(amount) + ' "https://w3id.org/cc#bit" "' + URI + '" "' + msg.message.user.room + '@' + adapter + ' ' + comment + '"'
      console.log(command)
      return exec(command, function (error, stdout, stderr) {
        console.log(error)
        console.log(stdout)
        return console.log(stderr)
      })
    } else {
      return msg.send('sorry, not enough funds')
    }
  })
}

withdraw_credits = function (msg, address, amount, robot) {
  var command
  if (robot.brain.data.credits[to_URI(msg.message.user.name)] >= parseFloat(amount)) {
    command = 'bitmark-cli sendtoaddress ' + address + ' ' + (parseFloat(amount) / 1000.0)
    console.log(command)
    return exec(command, function (error, stdout, stderr) {
      console.log('## ERROR: ' + error)
      console.log(stdout)
      console.log(stderr)
      if (error) {
        console.log(error)
        return msg.send('Withdrawl could not proceed, server may be down or invalid address')
      } else {
        robot.brain.data.credits[to_URI(msg.message.user.name)] -= parseFloat(amount)
        msg.send(stdout)
        command = 'credit insert -d klaranet -w https://klaranet.com/wallet.ttl#this ' + to_URI(msg.message.user.name) + ' ' + parseFloat(amount) + ' "https://w3id.org/cc#bit" bitmark:' + address
        console.log(command)
        return exec(command, function (error, stdout, stderr) {
          console.log(error)
          console.log(stdout)
          return console.log(stderr)
        })
      }
    })
  } else {
    return msg.send('not enough funds')
  }
}

save = function (robot) {
  return robot.brain.data.credits = robot.brain.data.credits
}

module.exports = function (robot) {
  robot.brain.on('loaded', function () {
    credits = robot.brain.data.credits || {}
    return robot.brain.resetSaveInterval(1)
  })
  robot.hear(/^deposit\s+(\d+)\s+([\w\S]+)\s+([\w\S]*)$/i, function (msg) {
    if (msg.match[3] === secret) {
      msg.send('deposit to ' + msg.match[2] + ' ' + msg.match[1])
      deposit_credits(msg, to_URI(msg.match[2]), msg.match[1], robot)
      return save(robot)
    }
  })
  robot.hear(/^(transfer|#transfer|mark|#mark|bitmark|#bitmark)\s+@?([\w\S]+?):?\s*$/i, function (msg) {
    transfer_credits(msg, to_URI(msg.match[2]), 5, robot)
    return save(robot)
  })
  robot.hear(/^(transfer|#transfer|mark|#mark|bitmark|#bitmark)\s+@?([\w\S]+?):?\s+(\d+)\s*$/i, function (msg) {
    transfer_credits(msg, to_URI(msg.match[2]), msg.match[3], robot)
    return save(robot)
  })
  robot.hear(/^(transfer|#transfer|mark|#mark|bitmark|#bitmark)\s+@?([\w\S]+?):?\s+(\d+)\s+([\w\S]+.*)\s*$/i, function (msg) {
    transfer_credits(msg, to_URI(msg.match[2]), msg.match[3], robot, msg.match[4])
    return save(robot)
  })
  robot.hear(/^\+(\d+)\s*$/i, function (msg) {
    var plus, to
    plus = msg.match[1]
    to = prev[msg.message.user.room] || 'klaranet'
    if (plus <= 25) {
      transfer_credits(msg, to_URI(to), plus, robot)
    } else {
      msg.send('Max is +25')
    }
    return save(robot)
  })
  robot.hear(/^withdraw\s+(\d+)\s+([\w\S]+)\s*$/i, function (msg) {
    var destination
    destination = msg.match[2]
    if (destination === 'foundation') {
      destination = 'bQmnzVS5M4bBdZqBTuHrjnzxHS6oSUz6cG'
    }
    return save(robot)
  })
  robot.hear(/^balance\s+@?([\w\S]+):?\s*$/i, function (msg) {
    var URI, command
    URI = to_URI(msg.match[1])
    command = 'credit balance ' + URI + ' -d klaranet -w https://klaranet.com/wallet.ttl#this  '
    console.log(command)
    return exec(command, function (error, stdout, stderr) {
      var balance
      console.log(error)
      console.log(stdout)
      console.log(stderr)
      balance = parseFloat(stdout)
      return msg.send(' ' + from_URI(URI) + ' has ' + balance + symbol)
    })
  })
  robot.hear(/^balance\s*$/i, function (msg) {
    var URI, command
    URI = to_URI(msg.message.user.name)
    command = 'credit balance ' + to_URI(msg.message.user.name) + ' -d klaranet -w https://klaranet.com/wallet.ttl#this  '
    console.log(command)
    return exec(command, function (error, stdout, stderr) {
      var balance
      console.log(error)
      console.log(stdout)
      console.log(stderr)
      balance = parseFloat(stdout)
      return msg.send(' ' + from_URI(URI) + ' has ' + balance + symbol)
    })
  })
  robot.hear(/^top5\s*$/i, function (msg) {
    var command
    command = './top.sh '
    console.log(command)
    return exec(command, function (error, stdout, stderr) {
      var i, j, k, len, str
      console.log(error)
      console.log(stdout)
      console.log(stderr)
      j = JSON.parse(stdout)
      str = "*Today's top 5 by Reputation*\n"
      for (k = 0, len = j.length; k < len; k++) {
        i = j[k]
        if (i !== null) {
          str += ' ' + from_URI(i.source) + ' ' + i.amount + '\n'
        }
      }
      return msg.send(str)
    })
  })
  robot.router.get('/marks', function (req, res) {
    return res.end(JSON.stringify(robot.brain.data.credits))
  })
  return robot.hear(/.*/i, function (msg) {
    var id
    last = msg.message.user.name
    prev[msg.message.user.room] = msg.message.user.name
    console.log(JSON.stringify(msg.message))
    console.log('[' + (new Date).toLocaleTimeString() + '] ' + msg.message.text)
  })
}
