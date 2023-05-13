import chronicles, strformat
import nexus/cmd/service/generate/models/gen_model_utils
import nexus/cmd/types/types
import data_access_helpers
import naming_utils


# Code
proc countProc*(str: var string,
                model: Model,
                pragmas: string) =

  # Proc name
  var procName = "count"

  if model.longNames == true:
    procName &= model.nameInPascalCase

  # Proc definition
  let returnDetails =
        getProcPostDetails(
          "int64",
          pragmas)

  str &= &"proc {procName}*(\n" &
         &"       dbContext: {model.module.nameInPascalCase}DbContext,\n" &
         &"       whereFields: seq[string] = @[],\n" &
         &"       whereValues: seq[string] = @[]){returnDetails} =\n" &
          "\n"

  # Select count query
  selectCountQuery(
    str,
    model)

  str &= "\n"

  # Where clause
  str &= &"  var first = true\n" &
          "\n"

  whereEqOnlyClause(
    str,
    "selectStatement")

  # Get the records
  str &= &"  let row = getRow(dbContext.dbConn,\n" &
         &"                   sql(selectStatement),\n" &
         &"                   whereValues)\n" &
          "\n"

  # Return the record count
  str &= &"  return parseBiggestInt(row[0])\n" &
         &"\n"


proc countWhereClauseProc*(
       str: var string,
       model: Model,
       pragmas: string) =

  # Proc name
  var procName = "count"

  if model.longNames == true:
    procName &= model.nameInPascalCase

  # Proc definition
  let returnDetails =
        getProcPostDetails(
          "int64",
          pragmas)

  str &= &"proc {procName}*(\n" &
         &"       dbContext: {model.module.nameInPascalCase}DbContext,\n" &
         &"       whereClause: string,\n" &
         &"       whereValues: seq[string] = @[]){returnDetails} =\n" &
          "\n"

  # Select count query
  selectCountQuery(
    str,
    model)

  str &= "\n" &
         "\n"

  # Where clause
  whereClause(str,
              "selectStatement")

  # Get the records
  str &= &"  let row = getRow(dbContext.dbConn,\n" &
          "                   sql(selectStatement),\n" &
          "                   whereValues)\n" &
          "\n"

  # Return the record count
  str &= "  return parseBiggestInt(row[0])\n" &
         "\n"


proc createProc*(str: var string,
                 pgTryInsertId: var bool,
                 model: Model,
                 pragmas: string) =

  # Proc name
  var procName = "create"

  if model.longNames == true:
    procName &= model.nameInPascalCase

  procName &= "ReturnsPk"

  # Proc definition
  str &= &"proc {procName}*(\n" &
         &"       dbContext: {model.module.nameInPascalCase}DbContext,\n"

  listModelFieldNames(
    str,
    model,
    indent = "       ",
    skipAutoValue = true,
    withDefaults = true,
    withNimTypes = true)

  str &= ",\n       ignoreExistingPk: bool = false"

  let returnDetails =
        getProcPostDetails(
          model.pkNimType,
          pragmas)

  str &= &"){returnDetails} =\n" &
          "\n"

  # Create insert SQL statement
  buildInsertSQLFromModelFieldNames(
    str,
    model,
    indent = "  ")

  # Exec the insert statement
  if model.fields[0].isAutoValue == true:
    pgTryInsertId = true

    case model.pkNimType:

      of "int":

        str &=  "  # Execute the insert statement and return the sequence values\n" &
                "  return tryInsertNamedIDReturningInt32(\n" &
               &"           dbContext.dbConn,\n" &
                "           sql(insertStatement),\n" &
               &"           \"{model.pkNameInSnakeCase}\",\n" &
                "           insertValues)\n"

      of "int64":

        str &=  "  # Execute the insert statement and return the sequence values\n" &
                "  return tryInsertNamedID(\n" &
               &"           dbContext.dbConn,\n" &
                "           sql(insertStatement),\n" &
               &"           \"{model.pkNameInSnakeCase}\",\n" &
                "           insertValues)\n"

  else:
    str &=  "  # Execute the insert statement and return the sequence values\n" &
            "  exec(\n" &
           &"    dbContext.dbConn,\n" &
            "    sql(insertStatement),\n" &
            "    insertValues)\n" &
            "\n" &
           &"  return {model.pkNameInCamelCase}\n"

  str &= "\n"


proc createWithTypeProc*(
       str: var string,
       model: Model,
       pragmas: string) =

  # Proc name
  var procName = "create"

  if model.longNames == true:
    procName &= model.nameInPascalCase

  # Proc definition
  str &= &"proc {procName}*(\n" &
         &"       dbContext: {model.module.nameInPascalCase}DbContext,\n"

  listModelFieldNames(
    str,
    model,
    indent = "       ",
    skipAutoValue = true,
    withDefaults = true,
    withNimTypes = true)

  # Move these options to a type that includes db
  str &= ",\n       ignoreExistingPk: bool = false" &
         ",\n       copyAllStringFields: bool = true" &
         ",\n       convertToRawTypes: bool = true"

  let returnDetails =
        getProcPostDetails(
          model.nameInPascalCase,
          pragmas)

  str &= &"){returnDetails} =\n" &
          "\n"

  # Init type
  initType(str,
           indent = "  ",
           model)

  # Debug
  debug "createWithTypeProc()",
    str = str

  # Create insert SQL and insert_values seq
  var indent = "  "

  if model.pkModelDNamesInCamelCase != "":

    if model.pkModelDNamesInCamelCase[0] == '(':
      str &= &"{indent}{model.pkModelDNamesInCamelCase} =\n"

    else:
      str &= &"{indent}{model.nameInCamelCase}.{model.pkNameInCamelCase} =\n"

    indent &= "  "

  str &= &"{indent}create{model.nameInPascalCase}ReturnsPk(\n" &
         &"{indent}  dbContext,\n"

  indent &= "  "

  listModelFieldNames(
    str,
    model,
    indent = indent,
    skipAutoValue = true)

  str &= &",\n{indent}ignoreExistingPk)\n" &
          "\n"

  setTypeFromFields(str,
                    model,
                    indent = "  ")

  str &= &"  return {model.nameInCamelCase}\n" &
          "\n"


proc deleteProcByPk*(
       str: var string,
       model: Model,
       uniqueFields: seq[string],
       withStringTypes: bool = false,
       pragmas: string): bool =

  debug "deleteProcByPk()",
    uniqueFields = uniqueFields

  let
    uniqueFieldsWithPkName =
      getFieldsWithPkNamed(
        uniqueFields,
        model)

    uniqueFieldsPascalCaseCase =
      getFieldsAsPascalCaseCase(
        uniqueFieldsWithPkName,
        model)

  # Proc name
  var procName = "delete"

  if model.longNames == true:
    procName &= model.nameInPascalCase

  if uniqueFields == model.pkFields:
    procName &= "ByPk"

    if len(model.pkFields) == 0:
      return false

  else:
    procName &= "By" & uniqueFieldsPascalCaseCase

  # Proc definition
  str &= &"proc {procName}*(\n" &
         &"       dbContext: " &
           &"{model.module.nameInPascalCase}DbContext,\n"

  if withStringTypes == false:
    listFieldNames(str,
                   model,
                   indent = "       ",
                   withNimTypes = true,
                   listFields = uniqueFields)

  else:
    listFieldNames(str,
                   model,
                   indent = "       ",
                   withStringTypes = true,
                   listFields = uniqueFields)

  let returnDetails = getProcPostDetails("int64",
                                         pragmas)

  str &= &"){returnDetails} =\n" &
          "\n"

  deleteQuery(str,
              whereFields = uniqueFields,
              model)

  str &= "\n"

  # Delete the record
  str &=  "  return execAffectedRows(\n" &
         &"           dbContext.dbConn,\n" &
          "           sql(deleteStatement),\n"

  listFieldNames(str,
                 model,
                 indent = "           ",
                 listFields = uniqueFields)

  str &= ")\n" &
         "\n"

  return true


proc deleteWhereClauseProc*(
       str: var string,
       model: Model,
       pragmas: string) =

  # Proc name
  var procName = "delete"

  if model.longNames == true:
    procName &= model.nameInPascalCase

  # Proc definition
  let returnDetails = getProcPostDetails("int64",
                                          pragmas)

  str &= &"proc {procName}*(\n" &
         &"       dbContext: {model.module.nameInPascalCase}DbContext,\n" &
          "       whereClause: string,\n" &
         &"       whereValues: seq[string]){returnDetails} =\n" &
          "\n"

  # Delete query
  deleteQueryWhereClause(
    str,
    model)

  # Exec the delete and return rows affected
  str &=  "  return execAffectedRows(\n" &
         &"           dbContext.dbConn,\n" &
          "           sql(deleteStatement),\n" &
          "           whereValues)\n" &
          "\n"


proc deleteWhereEqOnlyProc*(
       str: var string,
       model: Model,
       pragmas: string) =

  # Proc name
  var procName = "delete"

  if model.longNames == true:
    procName &= model.nameInPascalCase

  # Proc definition
  let returnDetails = getProcPostDetails("int64",
                                          pragmas)

  str &= &"proc {procName}*(\n" &
         &"       dbContext: {model.module.nameInPascalCase}DbContext,\n" &
          "       whereFields: seq[string],\n" &
         &"       whereValues: seq[string]){returnDetails} =\n" &
          "\n"

  # Delete query
  deleteFromOnly(
    str,
    model)

  # Where and order by clauses
  str &= "  var first = true\n" &
         "\n"

  whereEqOnlyClause(
    str,
    "deleteStatement")

  # Exec the delete and return rows affected
  str &=  "  return execAffectedRows(\n" &
         &"           dbContext.dbConn,\n" &
          "           sql(deleteStatement),\n" &
          "           whereValues)\n" &
          "\n"


proc existsProc*(str: var string,
                 model: Model,
                 uniqueFields: seq[string],
                 withStringTypes: bool = false,
                 pragmas: string): bool =

  debug "existsProc()",
    uniqueFields = uniqueFields

  let
    uniqueFieldsWithPkName =
      getFieldsWithPkNamed(
        uniqueFields,
        model)

    uniqueFieldsPascalCaseCase =
      getFieldsAsPascalCaseCase(
        uniqueFieldsWithPkName,
        model)

  # Proc name
  var procName = "exists"

  if model.longNames == true:
    procName &= model.nameInPascalCase

  if uniqueFields == model.pkFields:
    procName &= "ByPk"

    if len(model.pkFields) == 0:
      return false

  else:
    procName &= "By" & uniqueFieldsPascalCaseCase

  # Proc definition
  str &= &"proc {procName}*(\n" &
         &"       dbContext: {model.module.nameInPascalCase}DbContext,\n"

  if withStringTypes == false:
    listFieldNames(str,
                   model,
                   indent = "       ",
                   withNimTypes = true,
                   listFields = uniqueFields)

  else:
    listFieldNames(str,
                   model,
                   indent = "       ",
                   withStringTypes = true,
                   listFields = uniqueFields)

  let returnDetails =
        getProcPostDetails(
          "bool",
          pragmas)

  str &= &"){returnDetails} =\n" &
          "\n"

  selectQuery(str,
              selectFields = @[ "1" ],
              whereFields = uniqueFields,
              model)

  str &= "\n"

  # Get the record
  str &=  "  let row = getRow(\n" &
         &"              dbContext.dbConn,\n" &
          "              sql(selectStatement),\n"

  listFieldNamesWithDbToStringFuncs(
    str,
    model,
    indent = "              ",
    listFields = uniqueFields)

  str &= &")\n" &
         &"\n"

  # Return the record
  str &= "  if row[0] == \"\":\n" &
         "    return false\n" &
         "  else:\n" &
         "    return true\n" &
         "\n"

  return true


proc rowToModelTypeDecl*(
       str: var string,
       model: Model,
       pragmas: string) =

  # Proc name
  var procName = &"rowTo{model.nameInPascalCase}"

  # Proc definition
  let returnDetails =
        getProcPostDetails(
          model.nameInPascalCase,
          pragmas,
          withColon = false)

  str &= &"proc {procName}*(row: seq[string]):\n" &
         &"       {returnDetails}\n"


proc rowToModelType*(str: var string,
                     model: Model,
                     pragmas: string) =

  # Proc name
  var procName = &"rowTo{model.nameInPascalCase}"

  # Proc definition
  let returnDetails =
        getProcPostDetails(
          model.nameInPascalCase,
          pragmas,
          withColon = false)

  str &= &"proc {procName}*(row: seq[string]):\n" &
         &"       {returnDetails} =\n" &
          "\n" &
         &"  var {model.nameInCamelCase} = {model.nameInPascalCase}()\n" &
          "\n"

  # Create insert SQL statement
  buildAssignModelTypeFieldsFromRow(
    str,
    model,
    indent = "  ")

  str &= &"  return {model.nameInCamelCase}\n" &
          "\n"


proc filterProc*(str: var string,
                 model: Model,
                 pragmas: string) =

  var procName = "filter"

  if model.longNames == true:
    procName &= model.nameInPascalCase

  # Proc definition
  let returnDetails =
        getProcPostDetails(
          model.namePluralInPascalCase,
          pragmas)

  str &= &"proc {procName}*(\n" &
         &"       dbContext: {model.module.nameInPascalCase}DbContext,\n" &
          "       whereClause: string = \"\",\n" &
          "       whereValues: seq[string] = @[],\n" &
          "       orderByFields: seq[string] = @[],\n" &
         &"       limit: Option[int] = none(int)){returnDetails} =\n" &
          "\n"

  # Select query
  selectQuery(str,
              selectFields = @[],
              whereFields = @[],
              model)

  str &= "\n"

  # Where and order by clauses
  whereClause(str,
              "selectStatement")

  orderByClause(str,
                "selectStatement")

  str &= "\n"

  limitClause(
    str,
    "selectStatement")

  str &= "\n"

  # Get the records
  str &= &"  var {model.namePluralInCamelCase}: {model.namePluralInPascalCase}\n" &
         "\n" &
         &"  for row in fastRows(dbContext.dbConn,\n" &
          "                      sql(selectStatement),\n" &
          "                      whereValues):\n" &
         "\n" &
         &"    {model.namePluralInCamelCase}.add(rowTo{model.nameInPascalCase}(row))\n" &
         &"\n"

  # Return the record
  str &= &"  return {model.namePluralInCamelCase}\n" &
          "\n"


proc filterWhereEqOnlyProc*(
       str: var string,
       model: Model,
       pragmas: string) =

  # Proc name
  var procName = "filter"

  if model.longNames == true:
    procName &= model.nameInPascalCase

  # Proc definition
  let returnDetails =
        getProcPostDetails(
          model.namePluralInPascalCase,
          pragmas)

  str &= &"proc {procName}*(\n" &
         &"       dbContext: {model.module.nameInPascalCase}DbContext,\n" &
          "       whereFields: seq[string],\n" &
          "       whereValues: seq[string],\n" &
          "       orderByFields: seq[string] = @[],\n" &
         &"       limit: Option[int] = none(int)){returnDetails} =\n" &
          "\n"

  # Select query
  selectQuery(str,
              selectFields = @[],
              whereFields = @[],
              model)

  str &= "\n"

  # Where and order by clauses
  str &= "  var first = true\n" &
         "\n"

  whereEqOnlyClause(
    str,
    "selectStatement")

  orderByClause(
    str,
    "selectStatement")

  str &= "\n"

  limitClause(
    str,
    "selectStatement")

  str &= "\n"

  # Get the records
  str &= &"  var {model.namePluralInCamelCase}: {model.namePluralInPascalCase}\n" &
          "\n" &
         &"  for row in fastRows(dbContext.dbConn,\n" &
          "                      sql(selectStatement),\n" &
          "                      whereValues):\n" &
          "\n" &
         &"    {model.namePluralInCamelCase}.add(rowTo{model.nameInPascalCase}(row))\n" &
          "\n"

  # Return the record
  str &= &"  return {model.namePluralInCamelCase}\n" &
          "\n"


proc getProc*(str: var string,
             model: Model,
             uniqueFields: seq[string],
             withStringTypes: bool = false,
             pragmas: string): bool =

  debug "getProc()",
    uniqueFields = uniqueFields

  var
    uniqueFieldsWithPkName =
      getFieldsWithPkNamed(
        uniqueFields,
        model)

    uniqueFieldsPascalCaseCase =
      getFieldsAsPascalCaseCase(
        uniqueFieldsWithPkName,
        model)

  # Proc name
  var procName = "get"

  if model.longNames == true:
    procName &= model.nameInPascalCase

  if uniqueFields == model.pkFields:
    procName &= "ByPk"

    if len(model.pkFields) == 0:
      return false

  else:
    procName &= "By" & uniqueFieldsPascalCaseCase

  # Proc definition
  str &= &"proc {procName}*(\n" &
         &"       dbContext: {model.module.nameInPascalCase}DbContext,\n"

  if withStringTypes == false:
    listFieldNames(
      str,
      model,
      indent = "       ",
      withNimTypes = true,
      skipNimTypeOptionsForFields = uniqueFields,
      listFields = uniqueFields)

  else:
    listFieldNames(
      str,
      model,
      indent = "       ",
      withStringTypes = true,
      listFields = uniqueFields)

  let returnDetails =
        getProcPostDetails(&"Option[{model.nameInPascalCase}]",
                           pragmas)

  str &= &"){returnDetails} =\n" &
          "\n"

  selectQuery(str,
              selectFields = @[],
              whereFields = uniqueFields,
              model)

  str &= "\n"

  # Get the record
  str &=  "  let row = getRow(\n" &
         &"              dbContext.dbConn,\n" &
          "              sql(selectStatement),\n"

  listFieldNames(str,
                 model,
                 indent = "              ",
                 listFields = uniqueFields)

  str &= ")\n" &
         "\n"

  # Return the record
  str &=  "  if row[0] == \"\":\n" &
         &"    return none({model.nameInPascalCase})\n" &
          "\n" &
         &"  return some(rowTo{model.nameInPascalCase}(row))\n" &
          "\n"

  return true


proc getOrCreateProc*(str: var string,
                      model: Model,
                      uniqueFields: seq[string],
                      pragmas: string): bool =

  debug "getOrCreateProc()",
    uniqueFields = uniqueFields

  # Proc name
  var procName = "getOrCreate"

  if model.longNames == true:
    procName &= model.nameInPascalCase

  # Proc definition
  if uniqueFields == model.pkFields:
    procName &= "ByPk"

    if len(model.pkFields) == 0:
      return false

  else:
    let uniqueFieldsPascalCaseCase =
          getFieldsAsPascalCaseCase(
            uniqueFields,
            model)

    procName &= "By" & uniqueFieldsPascalCaseCase

  str &= &"proc {procName}*(\n" &
         &"       dbContext: {model.module.nameInPascalCase}DbContext,\n"

  listModelFieldNames(
    str,
    model,
    indent = "       ",
    skipAutoValue = true,
    withNimTypes = true,
    skipNimTypeOptionsForFields = uniqueFields)  # Prevents doubling up Option[..]

  let returnDetails =
        getProcPostDetails(
          model.nameInPascalCase,
          pragmas)

  str &= &"){returnDetails} =\n" &
          "\n"

  # Are the unique fields the PK fields?
  var getByFields: string

  if uniqueFields == model.pkFields:
    getByFields = "PK"

  else:
    getByFields =
      getFieldsAsPascalCaseCase(
        uniqueFields,
        model)

  # Select one
  str &= &"  let {model.nameInCamelCase} =\n" &
         &"        get{model.nameInPascalCase}By{getByFields}(\n" &
         &"          dbContext,\n"

  listFieldNames(str,
                 model,
                 indent = "          ",
                 listFields = uniqueFields)

  str &= ")\n" &
         "\n"

  # Return if a record was found
  str &= &"  if {model.nameInCamelCase} != none({model.nameInPascalCase}):\n" &
         &"    return {model.nameInCamelCase}.get\n" &
          "\n"

  # Create uniqueFieldsWithOnlyOptionalTypes
  var uniqueFieldsWithOnlyOptionalTypes =
        fieldListWithOnlyOptionalFields(
          model,
          uniqueFields)

  # Call create (no record found) and return the type
  str &= &"  return create{model.nameInPascalCase}(\n" &
         &"           dbContext,\n"

  listModelFieldNames(
    str,
    model,
    indent = "           ",
    skipAutoValue = true,
    addNimTypeOptionsForFields = uniqueFieldsWithOnlyOptionalTypes)

  str &= &")\n" &
         &"\n"

  return true


proc truncate*(str: var string,
               model: Model,
               pragmas: string) =

  var procName = "truncate"

  if model.longNames == true:
    procName &= model.nameInPascalCase

  let sql = &"truncate table {model.baseNameInSnakeCase} restart identity"

  str &= &"proc {procName}*(\n" &
         &"       dbContext: {model.module.nameInPascalCase}DbContext,\n" &
          "       cascade: bool = false) =\n" &
          "\n" &
          "  if cascade == false:\n" &
         &"    exec(dbContext.dbConn,\n" &
         &"         sql(\"{sql};\"))\n" &
          "\n" &
          "  else:\n" &
         &"    exec(dbContext.dbConn,\n" &
         &"         sql(\"{sql} cascade;\"))\n" &
          "\n"


proc updateByPkProc*(str: var string,
                     model: Model,
                     pragmas: string): bool =

  # Proc name
  var procName = "update"

  if model.longNames == true:
    procName &= model.nameInPascalCase

  if len(model.pkFields) == 0:
    return false

  # Proc definition
  let returnDetails =
        getProcPostDetails(
          "int64",
          pragmas)

  str &= &"proc {procName}ByPk*(\n" &
         &"       dbContext: {model.module.nameInPascalCase}DbContext,\n" &
         &"       {model.nameInCamelCase}: {model.nameInPascalCase},\n" &
          "       setFields: seq[string],\n" &
         &"       exceptionOnNRowsUpdated: bool = true){returnDetails} =\n" &
          "\n"

  # Update call clause
  updateCallClause(str,
                   procName,
                   "update",
                   model)

  # Where clause
  wherePkClause(str,
                "updateStatement",
                "update",
                model)

  # Exec the update and return rows affected
  str &=  "  let rowsUpdated = \n" &
          "        execAffectedRows(\n" &
         &"          dbContext.dbConn,\n" &
          "          sql(updateStatement),\n" &
          "          updateValues)\n" &
          "\n" &
          "  # Exception on no rows updated\n" &
          "  if rowsUpdated == 0 and\n" &
          "     exceptionOnNRowsUpdated == true:\n" &
          "\n" &
          "    raise newException(ValueError,\n" &
          "                       \"no rows updated\")\n" &
          "\n" &
          "  # Return rows updated\n" &
          "  return rowsUpdated\n" &
          "\n"

  return true


proc updateSetClause*(str: var string,
                      model: Model,
                      pragmas: string) =

  # Proc name
  var procName = "update"

  if model.longNames == true:
    procName &= model.nameInPascalCase

  # Proc definition
  let returnDetails =
        getProcPostDetails(
          "",
          pragmas)

  str &= &"proc {procName}SetClause*(\n" &
         &"       {model.nameInCamelCase}: {model.nameInPascalCase},\n" &
          "       setFields: seq[string],\n" &
          "       updateStatement: var string,\n" &
         &"       updateValues: var seq[string]){returnDetails} =\n" &
          "\n" &
          "  updateStatement =\n" &
         &"    \"update {getTableName(model)}\" &\n"

  setClause(str,
            "update",
            model)

  str &= "\n"


proc updateWhereClauseProc*(
       str: var string,
       model: Model,
       pragmas: string) =

  # Proc name
  var procName = "update"

  if model.longNames == true:
    procName &= model.nameInPascalCase

  # Proc definition
  let returnDetails =
        getProcPostDetails(
          "int64",
          pragmas)

  str &= &"proc {procName}ByWhereClause*(\n" &
         &"       dbContext: " &
           &"{model.module.nameInPascalCase}DbContext,\n" &
         &"       {model.nameInCamelCase}: {model.nameInPascalCase},\n" &
          "       setFields: seq[string],\n" &
          "       whereClause: string,\n" &
         &"       whereValues: seq[string]){returnDetails} =\n" &
          "\n"

  # Update call clause
  updateCallClause(str,
                   procName,
                   "update",
                   model)

  whereClause(str,
              "updateStatement")

  # Exec the update and return rows affected
  str &=  "  return execAffectedRows(\n" &
         &"           dbContext.dbConn,\n" &
          "           sql(updateStatement),\n" &
          "           concat(updateValues,\n" &
          "                  whereValues))\n" &
          "\n"


proc updateWhereEqOnlyProc*(
       str: var string,
       model: Model,
       pragmas: string) =

  # Proc name
  var procName = "update"

  if model.longNames == true:
    procName &= model.nameInPascalCase

  # Proc definition
  let returnDetails =
        getProcPostDetails(
          "int64",
          pragmas)

  str &= &"proc {procName}ByWhereEqOnly*(\n" &
         &"       dbContext: " &
           &"{model.module.nameInPascalCase}DbContext,\n" &
         &"       {model.nameInCamelCase}: {model.nameInPascalCase},\n" &
          "       setFields: seq[string],\n" &
          "       whereFields: seq[string],\n" &
         &"       whereValues: seq[string]){returnDetails} =\n" &
          "\n"

  # Update call clause
  updateCallClause(str,
                   procName,
                   "update",
                   model)

  str &= &"  var first = true\n" &
         &"\n"

  whereEqOnlyClause(str,
                    "updateStatement")

  # Exec the update and return rows affected
  str &=  "  return execAffectedRows(\n" &
         &"           dbContext.dbConn,\n" &
          "           sql(updateStatement),\n" &
          "           concat(updateValues,\n" &
          "                  whereValues))\n" &
          "\n"

