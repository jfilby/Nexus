# Nexus generated file
import db_connector/db_postgres, options, sequtils, strutils
import nexus/core/data_access/data_utils
import nexus/social/types/model_types


# Forward declarations
proc rowToSMPostVoteUser*(row: seq[string]):
       SMPostVoteUser {.gcsafe.}


# Code
proc countSMPostVoteUser*(
       dbContext: NexusSocialDbContext,
       whereFields: seq[string] = @[],
       whereValues: seq[string] = @[]): int64 {.gcsafe.} =

  var selectStatement =
    "select count(1)" & 
    "  from sm_post_vote_user"
  var first = true

  for whereField in whereFields:

    var whereClause: string

    if first == false:
      whereClause = "   and " & whereField & " = ?"
    else:
      first = false
      whereClause = " where " & whereField & " = ?"

    selectStatement &= whereClause

  let row = getRow(dbContext.dbConn,
                   sql(selectStatement),
                   whereValues)

  return parseBiggestInt(row[0])


proc countSMPostVoteUser*(
       dbContext: NexusSocialDbContext,
       whereClause: string,
       whereValues: seq[string] = @[]): int64 {.gcsafe.} =

  var selectStatement =
    "select count(1)" & 
    "  from sm_post_vote_user"

  if whereClause != "":
    selectStatement &= " where " & whereClause

  let row = getRow(dbContext.dbConn,
                   sql(selectStatement),
                   whereValues)

  return parseBiggestInt(row[0])


proc createSMPostVoteUserReturnsPk*(
       dbContext: NexusSocialDbContext,
       smPostId: string,
       accountUserId: string,
       voteUp: bool,
       voteDown: bool,
       ignoreExistingPk: bool = false): (string, string) {.gcsafe.} =

  # Formulate insertStatement and insertValues
  var
    insertValues: seq[string]
    insertStatement = "insert into sm_post_vote_user ("
    valuesClause = ""

  # Field: SM Post Id
  insertStatement &= "sm_post_id, "
  valuesClause &= "?, "
  insertValues.add(smPostId)

  # Field: Account User Id
  insertStatement &= "account_user_id, "
  valuesClause &= "?, "
  insertValues.add(accountUserId)

  # Field: Vote Up
  insertStatement &= "vote_up, "
  valuesClause &= "?, "
  insertValues.add($voteUp)

  # Field: Vote Down
  insertStatement &= "vote_down, "
  valuesClause &= "?, "
  insertValues.add($voteDown)

  # Remove trailing commas and finalize insertStatement
  if insertStatement[len(insertStatement) - 2 .. len(insertStatement) - 1] == ", ":
    insertStatement = insertStatement[0 .. len(insertStatement) - 3]

  if valuesClause[len(valuesClause) - 2 .. len(valuesClause) - 1] == ", ":
    valuesClause = valuesClause[0 .. len(valuesClause) - 3]

  # Finalize insertStatement
  insertStatement &=
    ") values (" & valuesClause & ")"

  if ignoreExistingPk == true:
    insertStatement &= " on conflict (sm_post_id, account_user_id) do nothing"

  # Execute the insert statement and return the sequence values
  exec(
    dbContext.dbConn,
    sql(insertStatement),
    insertValues)

  return (smPostId, accountUserId)


proc createSMPostVoteUser*(
       dbContext: NexusSocialDbContext,
       smPostId: string,
       accountUserId: string,
       voteUp: bool,
       voteDown: bool,
       ignoreExistingPk: bool = false,
       copyAllStringFields: bool = true,
       convertToRawTypes: bool = true): SMPostVoteUser {.gcsafe.} =

  var smPostVoteUser = SMPostVoteUser()

  (smPostVoteUser.smPostId, smPostVoteUser.accountUserId) =
    createSMPostVoteUserReturnsPk(
      dbContext,
      smPostId,
      accountUserId,
      voteUp,
      voteDown,
      ignoreExistingPk)

  # Copy all fields as strings
  smPostVoteUser.voteUp = voteUp
  smPostVoteUser.voteDown = voteDown

  return smPostVoteUser


proc deleteSMPostVoteUserByPk*(
       dbContext: NexusSocialDbContext,
       smPostId: string,
       accountUserId: string): int64 {.gcsafe.} =

  var deleteStatement =
    "delete" & 
    "  from sm_post_vote_user" &
    " where sm_post_id = ?"&
    "   and account_user_id = ?"

  return execAffectedRows(
           dbContext.dbConn,
           sql(deleteStatement),
           smPostId,
           accountUserId)


proc deleteSMPostVoteUser*(
       dbContext: NexusSocialDbContext,
       whereClause: string,
       whereValues: seq[string]): int64 {.gcsafe.} =

  var deleteStatement =
    "delete" & 
    "  from sm_post_vote_user" &
    " where " & whereClause

  return execAffectedRows(
           dbContext.dbConn,
           sql(deleteStatement),
           whereValues)


proc deleteSMPostVoteUser*(
       dbContext: NexusSocialDbContext,
       whereFields: seq[string],
       whereValues: seq[string]): int64 {.gcsafe.} =

  var deleteStatement =
    "delete" & 
    "  from sm_post_vote_user"

  var first = true

  for whereField in whereFields:

    var whereClause: string

    if first == false:
      whereClause = "   and " & whereField & " = ?"
    else:
      first = false
      whereClause = " where " & whereField & " = ?"

    deleteStatement &= whereClause

  return execAffectedRows(
           dbContext.dbConn,
           sql(deleteStatement),
           whereValues)


proc existsSMPostVoteUserByPk*(
       dbContext: NexusSocialDbContext,
       smPostId: string,
       accountUserId: string): bool {.gcsafe.} =

  var selectStatement =
    "select 1" & 
    "  from sm_post_vote_user" &
    " where sm_post_id = ?" &
    "   and account_user_id = ?"

  let row = getRow(
              dbContext.dbConn,
              sql(selectStatement),
              smPostId,
              accountUserId)

  if row[0] == "":
    return false
  else:
    return true


proc filterSMPostVoteUser*(
       dbContext: NexusSocialDbContext,
       whereClause: string = "",
       whereValues: seq[string] = @[],
       orderByFields: seq[string] = @[],
       limit: Option[int] = none(int)): SMPostVoteUsers {.gcsafe.} =

  var selectStatement =
    "select sm_post_id, account_user_id, vote_up, vote_down" & 
    "  from sm_post_vote_user"

  if whereClause != "":
    selectStatement &= " where " & whereClause

  if len(orderByFields) > 0:
    selectStatement &= " order by " & orderByFields.join(", ")

  if limit != none(int):
    selectStatement &= " limit " & $limit.get

  var smPostVoteUsers: SMPostVoteUsers

  for row in fastRows(dbContext.dbConn,
                      sql(selectStatement),
                      whereValues):

    smPostVoteUsers.add(rowToSMPostVoteUser(row))

  return smPostVoteUsers


proc filterSMPostVoteUser*(
       dbContext: NexusSocialDbContext,
       whereFields: seq[string],
       whereValues: seq[string],
       orderByFields: seq[string] = @[],
       limit: Option[int] = none(int)): SMPostVoteUsers {.gcsafe.} =

  var selectStatement =
    "select sm_post_id, account_user_id, vote_up, vote_down" & 
    "  from sm_post_vote_user"

  var first = true

  for whereField in whereFields:

    var whereClause: string

    if first == false:
      whereClause = "   and " & whereField & " = ?"
    else:
      first = false
      whereClause = " where " & whereField & " = ?"

    selectStatement &= whereClause

  if len(orderByFields) > 0:
    selectStatement &= " order by " & orderByFields.join(", ")

  if limit != none(int):
    selectStatement &= " limit " & $limit.get

  var smPostVoteUsers: SMPostVoteUsers

  for row in fastRows(dbContext.dbConn,
                      sql(selectStatement),
                      whereValues):

    smPostVoteUsers.add(rowToSMPostVoteUser(row))

  return smPostVoteUsers


proc getSMPostVoteUserByPk*(
       dbContext: NexusSocialDbContext,
       smPostId: string,
       accountUserId: string): Option[SMPostVoteUser] {.gcsafe.} =

  var selectStatement =
    "select sm_post_id, account_user_id, vote_up, vote_down" & 
    "  from sm_post_vote_user" &
    " where sm_post_id = ?" &
    "   and account_user_id = ?"

  let row = getRow(
              dbContext.dbConn,
              sql(selectStatement),
              smPostId,
              accountUserId)

  if row[0] == "":
    return none(SMPostVoteUser)

  return some(rowToSMPostVoteUser(row))


proc getOrCreateSMPostVoteUserByPk*(
       dbContext: NexusSocialDbContext,
       smPostId: string,
       accountUserId: string,
       voteUp: bool,
       voteDown: bool): SMPostVoteUser {.gcsafe.} =

  let smPostVoteUser =
        getSMPostVoteUserByPK(
          dbContext,
          smPostId,
          accountUserId)

  if smPostVoteUser != none(SMPostVoteUser):
    return smPostVoteUser.get

  return createSMPostVoteUser(
           dbContext,
           smPostId,
           accountUserId,
           voteUp,
           voteDown)


proc rowToSMPostVoteUser*(row: seq[string]):
       SMPostVoteUser {.gcsafe.} =

  var smPostVoteUser = SMPostVoteUser()

  smPostVoteUser.smPostId = row[0]
  smPostVoteUser.accountUserId = row[1]
  smPostVoteUser.voteUp = parsePgBool(row[2])
  smPostVoteUser.voteDown = parsePgBool(row[3])

  return smPostVoteUser


proc truncateSMPostVoteUser*(
       dbContext: NexusSocialDbContext,
       cascade: bool = false) =

  if cascade == false:
    exec(dbContext.dbConn,
         sql("truncate table sm_post_vote_user restart identity;"))

  else:
    exec(dbContext.dbConn,
         sql("truncate table sm_post_vote_user restart identity cascade;"))


proc updateSMPostVoteUserSetClause*(
       smPostVoteUser: SMPostVoteUser,
       setFields: seq[string],
       updateStatement: var string,
       updateValues: var seq[string]) {.gcsafe.} =

  updateStatement =
    "update sm_post_vote_user" &
    "   set "

  for field in setFields:

    if field == "sm_post_id":
      updateStatement &= "       sm_post_id = ?,"
      updateValues.add(smPostVoteUser.smPostId)

    elif field == "account_user_id":
      updateStatement &= "       account_user_id = ?,"
      updateValues.add(smPostVoteUser.accountUserId)

    elif field == "vote_up":
        updateStatement &= "       vote_up = " & pgToBool(smPostVoteUser.voteUp) & ","

    elif field == "vote_down":
        updateStatement &= "       vote_down = " & pgToBool(smPostVoteUser.voteDown) & ","

  updateStatement[len(updateStatement) - 1] = ' '



proc updateSMPostVoteUserByPk*(
       dbContext: NexusSocialDbContext,
       smPostVoteUser: SMPostVoteUser,
       setFields: seq[string],
       exceptionOnNRowsUpdated: bool = true): int64 {.gcsafe.} =

  var
    updateStatement: string
    updateValues: seq[string]

  updateSMPostVoteUserSetClause(
    sm_post_vote_user,
    setFields,
    updateStatement,
    updateValues)

  updateStatement &= " where sm_post_id = ?"
  updateStatement &= "   and account_user_id = ?"

  updateValues.add($smPostVoteUser.smPostId)
  updateValues.add($smPostVoteUser.accountUserId)

  let rowsUpdated = 
        execAffectedRows(
          dbContext.dbConn,
          sql(updateStatement),
          updateValues)

  # Exception on no rows updated
  if rowsUpdated == 0 and
     exceptionOnNRowsUpdated == true:

    raise newException(ValueError,
                       "no rows updated")

  # Return rows updated
  return rowsUpdated


proc updateSMPostVoteUserByWhereClause*(
       dbContext: NexusSocialDbContext,
       smPostVoteUser: SMPostVoteUser,
       setFields: seq[string],
       whereClause: string,
       whereValues: seq[string]): int64 {.gcsafe.} =

  var
    updateStatement: string
    updateValues: seq[string]

  updateSMPostVoteUserSetClause(
    sm_post_vote_user,
    setFields,
    updateStatement,
    updateValues)

  if whereClause != "":
    updateStatement &= " where " & whereClause

  return execAffectedRows(
           dbContext.dbConn,
           sql(updateStatement),
           concat(updateValues,
                  whereValues))


proc updateSMPostVoteUserByWhereEqOnly*(
       dbContext: NexusSocialDbContext,
       smPostVoteUser: SMPostVoteUser,
       setFields: seq[string],
       whereFields: seq[string],
       whereValues: seq[string]): int64 {.gcsafe.} =

  var
    updateStatement: string
    updateValues: seq[string]

  updateSMPostVoteUserSetClause(
    sm_post_vote_user,
    setFields,
    updateStatement,
    updateValues)

  var first = true

  for whereField in whereFields:

    var whereClause: string

    if first == false:
      whereClause = "   and " & whereField & " = ?"
    else:
      first = false
      whereClause = " where " & whereField & " = ?"

    updateStatement &= whereClause

  return execAffectedRows(
           dbContext.dbConn,
           sql(updateStatement),
           concat(updateValues,
                  whereValues))


