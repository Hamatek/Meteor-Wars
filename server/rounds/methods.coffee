Meteor.methods
  'round/nextTurn': (roundId) ->
    return if Meteor.isClient
    return unless roundId
    return unless @userId

    return unless round = Rounds.findOne roundId
    return unless player = Players.findOne userId: @userId, roundId: roundId
    # return if player._id isnt round.getCurrentPlayer()._id

    round.nextTurn()

  'round/surrender': (roundId) ->
    player = Players.findOne
      roundId: roundId
      userId: @userId

    if player
      Units.remove playerId: player._id
