class_name Relationships

static func attacking_players():
    return Relationship.new(C_IsAttacking.new(), Player)

static func chasing_players():
    return Relationship.new(C_IsChasing.new(), Player)