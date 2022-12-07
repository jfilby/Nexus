import strformat
import nexus/cmd/service/generate/models/drivers/stdlib_dbi/data_access_helpers
import nexus/cmd/types/types


proc callCreateProc*(
       str: var string,
       model: Model) =

  str &= &"  # Call the create proc\n"

  var procName = "create"

  if model.longNames == true:
    procName &= model.nameInPascalCase

  # Proc definition
  let
    procLine =
      &"  let {model.nameInCamelCase} =\n" &
      &"        {procName}(\n" &
      &"           dbContext,\n"

    indent = "           "

  str &= procLine

  listModelFieldNames(
    str,
    model,
    indent = indent,
    skipAutoValue = true,
    withDefaults = false,
    withNimTypes = false)

  str &= &")\n" &
         &"\n"


proc callDeleteProc*(
       str: var string,
       model: Model,
       uniqueFields: seq[string],
       uniqueFieldsPascalCaseCase: string,
       withStringTypes: bool = false) =

  str &= &"  # Call the model's delete proc\n"

  # Get procName
  var procName = "delete"

  if model.longNames == true:
    procName &= model.nameInPascalCase

  if uniqueFields == model.pkFields:
    procName &= "ByPk"

  else:
    procName &= "By" & uniqueFieldsPascalCaseCase

  # Proc definition
  let
    procLine =
       "  let rowsDeleted = \n" &
      &"        {procName}(\n" &
      &"          dbContext,\n"

    indent = "          "

  str &= procLine

  if withStringTypes == false:

    listFieldNames(
      str,
      model,
      indent = indent,
      withNimTypes = false,
      listFields = uniqueFields)

  else:
    listFieldNames(
      str,
      model,
      indent = indent,
      withStringTypes = false,
      listFields = uniqueFields)

  str &= &")\n" &
         &"\n"


proc callExistsProc*(
       str: var string,
       model: Model,
       uniqueFields: seq[string],
       uniqueFieldsPascalCaseCase: string,
       withStringTypes: bool = false) =

  str &= &"  # Call the model's exists proc\n"

  # Get procName
  var procName = "exists"

  if model.longNames == true:
    procName &= model.nameInPascalCase

  if uniqueFields == model.pkFields:
    procName &= "ByPk"

  else:
    procName &= "By" & uniqueFieldsPascalCaseCase

  # Proc definition
  let
    procLine =
      &"  return {procName}(\n" &
      &"           dbContext,\n"

    indent = "           "

  str &= procLine

  if withStringTypes == false:

    listFieldNames(
      str,
      model,
      indent = indent,
      withNimTypes = false,
      listFields = uniqueFields)

  else:
    listFieldNames(
      str,
      model,
      indent = indent,
      withStringTypes = false,
      listFields = uniqueFields)

  str &= &")\n" &
         &"\n"


proc callFilterWithWhereClauseProc*(
       str: var string,
       model: Model) =

  str &= &"  # Call the model's filter proc\n"

  var procName = "filter"

  if model.longNames == true:
    procName &= model.nameInPascalCase

  # Proc definition
  let
    procLine = &"  let {model.namePluralInCamelCase} =\n" &
               &"        {procName}(\n" &
               &"          dbContext,\n"
    indent = "          "

  str &= procLine &
         &"{indent}whereClause,\n" &
         &"{indent}whereValues,\n" &
         &"{indent}orderByFields,\n" &
         &"{indent}limit)\n" &
         &"\n"


proc callFilterWithWhereFieldsProc*(
       str: var string,
       model: Model) =

  str &= &"  # Call the model's filter proc\n"

  var procName = "filter"

  if model.longNames == true:
    procName &= model.nameInPascalCase

  # Proc definition
  let
    procLine =
      &"  let {model.namePluralInSnakeCase} =\n" &
      &"        {procName}(\n" &
      &"          dbContext,\n"

    indent = "          "

  str &= procLine &
         &"{indent}whereFields,\n" &
         &"{indent}whereValues,\n" &
         &"{indent}orderByFields,\n" &
         &"{indent}limit)\n" &
         &"\n"


proc callGetProc*(
       str: var string,
       model: Model,
       uniqueFields: seq[string],
       uniqueFieldsPascalCaseCase: string,
       withStringTypes: bool = false) =

  str &= &"  # Call the model's get proc\n"

  # Get procName
  var procName = "get"

  if model.longNames == true:
    procName &= model.nameInPascalCase

  if uniqueFields == model.pkFields:
    procName &= "ByPk"

  else:
    procName &= "By" & uniqueFieldsPascalCaseCase

  # Proc definition
  let
    procLine =
      &"  let {model.nameInCamelCase} =\n" &
      &"        {procName}(\n" &
      &"          dbContext,\n"

    indent = "          "

  str &= procLine

  if withStringTypes == false:

    listFieldNames(
      str,
      model,
      indent = indent,
      withNimTypes = false,
      listFields = uniqueFields)

  else:
    listFieldNames(
      str,
      model,
      indent = indent,
      withStringTypes = false,
      listFields = uniqueFields)

  str &= &")\n" &
         &"\n"


proc callGetOrCreateProcByPk*(
       str: var string,
       model: Model,
       uniqueFields: seq[string]) =

  var procName = "getOrCreate"

  if model.longNames == true:
    procName &= model.nameInPascalCase

  # Proc definition
  str &= &"  let {model.nameInCamelCase} =\n" &
         &"        {procName}ByPk(\n" &
         &"          dbContext,\n"

  listModelFieldNames(
    str,
    model,
    indent = "          ",
    skipAutoValue = true,
    withNimTypes = false)

  str &= &")\n" &
         &"\n"


proc callGetOrCreateProcByUniqueFields*(
       str: var string,
       model: Model,
       uniqueFields: seq[string],
       uniqueFieldsPascalCaseCase: string) =

  var procName = "getOrCreate"

  if model.longNames == true:
    procName &= model.nameInPascalCase

  # Proc definition
  let
    uniqueFieldsPascalCaseCase =
      getFieldsAsPascalCaseCase(
        uniqueFields,
        model)

    procLine =
      &"  let {model.nameInCamelCase} =\n" &
      &"        {procName}By{uniqueFieldsPascalCaseCase}(\n" &
      &"          dbContext,\n"

    indent = "          "

  str &= procLine

  listModelFieldNames(
    str,
    model,
    indent = indent,
    skipAutoValue = true,
    withNimTypes = false)

  str &= &")\n" &
         &"\n"


proc callUpdateProc*(
       str: var string,
       model: Model) =

  str &= &"  # Call the model's update proc\n"

  var procName = "update"

  if model.longNames == true:
    procName &= model.nameInPascalCase

  procName &= "ByPk"

  # Proc definition
  let
    procLine =
      &"  let rowsUpdated =\n" &
      &"        {procName}(\n" &
      &"          dbContext,\n"

    indent = "          "

  str &= procLine &
         &"{indent}{model.nameInCamelCase},\n" &
         &"{indent}setFields)\n" &
         &"\n"

