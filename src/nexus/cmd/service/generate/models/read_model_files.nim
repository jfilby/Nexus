import chronicles, os, sets, streams, strformat, strutils, tables, yaml
import nexus/core/service/format/case_utils
import nexus/cmd/service/generate/generator_info/generator_info_utils
import nexus/cmd/service/generate/migrations/gen_migration_utils
import nexus/cmd/service/generate/models/cached/gen_cached_data_access
import nexus/cmd/service/generate/models/uncached/gen_data_access
import nexus/cmd/service/generate/modules/gen_db_context_type
import nexus/cmd/service/generate/modules/module_utils
import nexus/cmd/service/generate/tmp_dict/tmp_dict_utils
import nexus/cmd/types/types
import gen_model_type
import gen_model_utils
import model_utils


# Forward declarations
proc writeModelTypes(
       fileModuleName: string,
       modelFiles: var seq[string],
       moduleMinimumImports: seq[string],
       modelImportsTable: var Table[string, seq[string]],
       modelModuleTypeTable: var Table[string, string],
       generatorInfo: GeneratorInfo)


# Code
proc createBasicModelTypesFile*(
       typesPath: string,
       typesFilename: string,
       module: Module) =

  var typeStr =
        "# Minimal model_types file (no models defined)with a DbContext definition\n" &
        "import db_connector/db_postgres\n" &
        "\n" &
        "type\n" &
       &"  {module.nameInPascalCase}DbContext* = object\n" &
        "    dbConn*: DbConn\n" &
        "\n"

  createDir(typesPath)

  writeFile(filename = typesFilename,
            typeStr)


proc createBasicDbContextFile(
       modelFiles: seq[string],
       module: Module,
       generatorInfo: var GeneratorInfo) =

  # Skip if already written
  if generatorInfo.modelTypesTable.hasKey(module.name):
    if generatorInfo.modelTypesTable[module.name].written == true:
      return

  # Vars
  let
    typesPath = &"{module.srcPath}{DirSep}types"
    typesFilename = &"{typesPath}{DirSep}model_types.nim"

  # Don't overwrite any valid file, or if created by this program instance
  if modelFiles.contains(typesFilename):
    return

  debug "createBasicDbContextFile()",
    typesFilename = typesFilename,
    modelFiles = modelFiles

  # Write a basic model_types.nim file
  echo ".. creating path: " & typesPath
  echo ".. writing: " & typesFilename

  createBasicModelTypesFile(
    typesPath,
    typesFilename,
    module)


proc createBasicDbContextFiles(
       modelFiles: seq[string],
       generatorInfo: var GeneratorInfo) =

  for webArtifact in generatorInfo.webArtifacts:

    let module =
          getModuleByWebArtifact(
            webArtifact,
            generatorInfo)

    if module.imported == false:

      createBasicDbContextFile(
        modelFiles,
        module,
        generatorInfo)

  for library in generatorInfo.libraries:

    let module =
          getModuleByLibrary(
            library,
            generatorInfo)

    if module.imported == false:

      createBasicDbContextFile(
        modelFiles,
        module,
        generatorInfo)


proc expandModelTypesImports(
        model: Model,
        modelImportsTable: var Table[string, seq[string]]) =

  var
    usesDateTimeTypes = modelUsesDateTimeTypes(model)
    usesJsonTypes = modelUsesJsonTypes(model)
    usesOptionTypes = modelUsesOptionalTypes(model)

  if usesDateTimeTypes == true or
     usesJsonTypes == true or
     usesOptionTypes == true:

    if not modelImportsTable.hasKey(model.module.name):
      modelImportsTable[model.module.name] = @[]

  if usesDateTimeTypes == true:
    if not modelImportsTable[model.module.name].contains("times"):
      modelImportsTable[model.module.name].add("times")

  if usesJsonTypes == true:
    if not modelImportsTable[model.module.name].contains("json"):
      modelImportsTable[model.module.name].add("json")

  if usesOptionTypes == true:
    if not modelImportsTable[model.module.name].contains("options"):
      modelImportsTable[model.module.name].add("options")


proc processModel(
       model: var Model,
       srcPath: string,
       moduleMinimumImports: seq[string],
       modelImportsTable: var Table[string, seq[string]],
       modelModuleTypeTable: var Table[string, string],
       generatorInfo: var GeneratorInfo) =

  # Ref string for filename

  # Create data access file for object model
  generateDataAccessFile(
    model,
    dataAccessFilename =
      &"{srcPath}{DirSep}data_access{DirSep}" &
      &"{model.nameInSnakeCase}_data.nim")

  # Create cached data access file
  if model.modelOptions.contains("cacheable"):

    generateCachedDataAccessFile(
      model,
      cached_dataAccessFilename =
        &"{srcPath}{DirSep}cached_data_access{DirSep}" &
        &"{model.nameInSnakeCase}_cached_data.nim")

  # Add to generatorInfo
  generatorInfo.models.add(model)

  # Add/append to modelTypesStr
  var
    modelTypesStr = ""
    keyExists = false

  if generatorInfo.modelTypesTable.hasKey(model.module.name):
    keyExists = true
    modelTypesStr = generatorInfo.modelTypesTable[model.module.name].str

  # Append model type definition to model types file
  generateModelTypes(modelTypesStr,
                     model)

  # Set modelTypesStr in modelTypesTable
  if keyExists == false:

    generatorInfo.modelTypesTable[model.module.name] =
      TypeInfo(path: &"{srcPath}{DirSep}types",
               written: false)

  if not modelImportsTable.hasKey(model.module.name):
    modelImportsTable[model.module.name] = moduleMinimumImports

  else:
    for `import` in moduleMinimumImports:

      if not modelImportsTable[model.module.name].contains(`import`):
        modelImportsTable[model.module.name].add(`import`)

  generatorInfo.modelTypesTable[model.module.name].str = modelTypesStr

  # Get/create module type
  var moduleType = ""

  if not modelModuleTypeTable.hasKey(model.module.name):
    moduleType = generateDbContextTypeHeader(model.module)

  else:
    moduleType = modelModuleTypeTable[model.module.name]

  generateDbContextTypeModel(
    moduleType,
    model)

  modelModuleTypeTable[model.module.name] = moduleType


# Note: if no models are specified, then the module definition typically found
# in model_types.nim is not defined.
proc readModelFile(modelFiles: var seq[string],
                   confPath: string,
                   filename: string,
                   generatorInfo: var GeneratorInfo) =

  debug "readModelFile()",
    confPath = confPath,
    filename = filename

  # Import model YAML
  var
    modelCollection: ModelsYAML
    modelImportsTable: Table[string, seq[string]]  # [ model.module, imports ]
    modelModuleTypeTable: Table[string, string]    # [ model.module, moduleType definition ]
    fileModuleName = ""
    moduleMinimumImports =
      @[ "db_connector/db_postgres",
         "tables" ]

  # Validate
  if getFileSize(filename) == 0:

    raise newException(
            ValueError,
            &"File has 0 size: {filename}")

  # Load YAML
  echo "reading model file: " & filename

  var s = newFileStream(filename)

  load(s, modelCollection)
  s.close()

  # Assume the current package
  let package = generatorInfo.package

  # Loop through the models, generating cached data access files, data access
  # files and type information.
  for modelYAML in modelCollection:

    # Define the module paths using the selected module
    let (moduleName,
         basePath,
         srcPath) = getModuleAndBasePathAndSrcPathByProgram(
                      package,
                      modelYAML.module,
                      generatorInfo)

    # Migrations path
    let
      moduleSnakeCaseName = inSnakeCase(moduleName)

      migrationsPath =
        &"{basePath}{DirSep}data{DirSep}{moduleSnakeCaseName}{DirSep}db" &
        &"{DirSep}create_objects"

    createDir(&"{srcPath}{DirSep}cached_data_access")
    createDir(&"{srcPath}{DirSep}data_access")
    createDir(&"{srcPath}{DirSep}types")
    createDir(migrationsPath)

    # Info message
    debug "readModelFile()",
      name = modelYAML.name,
      moduleName = modelYAML.module,
      basePath = basePath,
      srcPath = srcPath,
      migrationsPath = migrationsPath

    fileModuleName = modelYAML.module

    # Get Model from ModelYAML
    var
      baseModel: Model
      modelObject: Option[Model]
      modelRef: Option[Model]

    # Which types to include
    if modelYAML.modelOptions.contains("object"):

      modelObject =
        some(getModel(modelYAML,
                      generatorInfo,
                      isRef = false))

      baseModel = modelObject.get

      expandModelTypesImports(
        modelObject.get,
        modelImportsTable)

    if modelYAML.modelOptions.contains("ref"):

      modelRef =
        some(getModel(modelYAML,
                      generatorInfo,
                      isRef = true))

      baseModel = modelRef.get

      expandModelTypesImports(
        modelRef.get,
        modelImportsTable)

    if modelObject == none(Model) and
       modelRef == none(Model):

      raise newException(ValueError,
                         &"Model: {modelYAML.name}: " &
                          "has neither object nor ref specified")

    # Create DML file
    createMigrationsFile(baseModel,
                         migrationsPath)

    # Process object models
    if modelObject != none(Model):

      processModel(modelObject.get,
                   srcPath,
                   moduleMinimumImports,
                   modelImportsTable,
                   modelModuleTypeTable,
                   generatorInfo)

    # Process ref models
    if modelRef != none(Model):

      processModel(modelRef.get,
                   srcPath,
                   moduleMinimumImports,
                   modelImportsTable,
                   modelModuleTypeTable,
                   generatorInfo)

  # Write model types files per module
  writeModelTypes(fileModuleName,
                  modelFiles,
                  moduleMinimumImports,
                  modelImportsTable,
                  modelModuleTypeTable,
                  generatorInfo)

  # Update timestamp
  updateTmpDictFileWritten(
    filename,
    generatorInfo.tmpDict)


proc readModelFilesPath(
       modelFiles: var seq[string],
       confPath: string,
       modelsPath: string,
       generatorInfo: var GeneratorInfo) =

  debug "readModelFilesPath()",
    modelsPath = modelsPath

  for kind, path in walkDir(modelsPath,
                            relative = false):

    if @[ pcFile,
          pcLinkToFile ].contains(kind):

      if find(path,
              "models.yaml") < 0:
        continue

      debug "readModelFilesPath()",
        path = path

      readModelFile(modelFiles,
                    confPath,
                    filename = path,
                    generatorInfo)

    if @[ pcDir,
          pcLinkToDir ].contains(kind):

      readModelFilesPath(modelFiles,
                         confPath,
                         path,
                         generatorInfo)


proc readModelFilesPaths*(
       modelFiles: var seq[string],
       confPath: string,
       modelPaths: seq[string],
       generatorInfo: var GeneratorInfo) =

  debug "readModelFilesPaths()",
    modelPaths = modelPaths

  for modelsPath in modelPaths:

    readModelFilesPath(
      modelFiles,
      confPath,
      modelsPath,
      generatorInfo)

  # Create a basic model file (module def only) if no model files read (this
  # proc doesn't overwrite valid files).
  createBasicDbContextFiles(
    modelFiles,
    generatorInfo)


proc writeModelTypes(
       fileModuleName: string,
       modelFiles: var seq[string],
       moduleMinimumImports: seq[string],
       modelImportsTable: var Table[string, seq[string]],
       modelModuleTypeTable: var Table[string, string],
       generatorInfo: GeneratorInfo) =

  var fileContents: Table[string, string]

  # Iterate modules
  for module in generatorInfo.modules:

    if fileModuleName != module.shortName:
      continue

    if module.imported == true:
      continue

    if generatorInfo.modelTypesTable.hasKey(module.name):

      if generatorInfo.modelTypesTable[module.name].written == true:
        continue

    # Debug
    let
      moduleName = module.name
      moduleImported = module.imported

    debug "writeModelTypes()",
      moduleName = moduleName,
      moduleImported = moduleImported

    discard moduleName
    discard moduleImported

    # Generate typeStr
    var importedName = ""

    if module.imported == true:
      importedName = &"_{module.nameInSnakeCase}"

    let
      typesPath = &"{module.srcPath}{DirSep}types"
      typesFilename = &"{typesPath}{DirSep}model_types{importedName}.nim"

    var typeStr = ""

    # for moduleName, typeInfo in generatorInfo.modelTypesTable:

    if modelImportsTable.contains(module.name):
      typeStr &= initModelTypesStr(modelImportsTable[module.name])

    else:
      typeStr &= &"import " & moduleMinimumImports.join(", ") & "\n" &
                  "\n" &
                  "\n"

    typeStr &= &"type\n" &
                generatorInfo.modelTypesTable[module.name].str &
                modelModuleTypeTable[module.name] & &"\n"

    echo ".. creating path: " & typesPath

    createDir(typesPath)

    if fileContents.hasKey(typesFilename):
      fileContents[typesFilename] &= typeStr

    else:
      fileContents[typesFilename] = typeStr

    # Set as written (ahead of time, but when module is known)
    generatorInfo.modelTypesTable[module.name].written = true

  # Write files
  for filename, contents in fileContents.pairs:

    echo ".. writing: " & filename

    writeFile(filename,
              contents)

    # Add to list of written files
    modelFiles.add(filename)

