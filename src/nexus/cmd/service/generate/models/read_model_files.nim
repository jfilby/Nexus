import chronicles, os, sets, streams, strformat, strutils, tables, yaml
import nexus/core/service/format/name_utils
import nexus/cmd/service/generate/generator_info/generator_info_utils
import nexus/cmd/service/generate/migrations/gen_migration_utils
import nexus/cmd/service/generate/modules/gen_module_type
import nexus/cmd/service/generate/modules/module_utils
import nexus/cmd/service/generate/tmp_dict/tmp_dict_utils
import nexus/cmd/types/types
import gen_cached_data_access
import gen_data_access
import gen_model_type
import gen_model_utils


# Types
type
  TypeInfo = object
    str*: string
    path*: string


# Forward declarations
proc writeModelTypes(
       fileModuleName: string,
       modelFiles: var seq[string],
       moduleMinimuMimports: seq[string],
       modelImportsTable: Table[string, OrderedSet[string]],
       modelTypesTable: Table[string, TypeInfo],
       modelModuleTypeTable: var Table[string, string],
       generatorInfo: GeneratorInfo)


# Code
proc createBasicModuleFile(
       modelFiles: seq[string],
       module: Module) =

  let
    typesPath = &"{module.srcPath}{DirSep}types"
    typesFilename = &"{typesPath}{DirSep}model_types.nim"

  # Don't overwrite any valid file
  if modelFiles.contains(typesFilename):
    return

  debug "createBasicModuleFile()",
    typesFilename = typesFilename,
    modelFiles = modelFiles

  # Write a basic model_types.nim file
  echo ".. creating path: " & typesPath
  echo ".. writing: " & typesFilename

  var typeStr =
    &"# Basic model_types file (no models defined) with only a basic module definition\n" &
    &"import db_postgres\n" &
    "\n" &
    &"type\n" &
    &"  {module.nameInPascalCase}Module* = object\n" &
    &"    db*: DbConn\n" &
    &"\n"

  createDir(typesPath)

  writeFile(filename = typesFilename,
            typeStr)


proc createBasicModuleFiles(
       modelFiles: seq[string],
       generatorInfo: GeneratorInfo) =

  for webArtifact in generatorInfo.webArtifacts:

    let module =
          getModuleByWebArtifact(
            webArtifact,
            generatorInfo)

    createBasicModuleFile(
      modelFiles,
      module)

  for library in generatorInfo.libraries:

    let module =
          getModuleByLibrary(
            library,
            generatorInfo)

    createBasicModuleFile(
      modelFiles,
      module)


proc processModel(
       model: var Model,
       srcPath: string,
       moduleMinimuMimports: OrderedSet[string],
       modelImportsTable: var Table[string, OrderedSet[string]],
       modelTypesTable: var Table[string, TypeInfo],
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

  if modelTypesTable.hasKey(model.module.name):
    keyExists = true
    modelTypesStr = modelTypesTable[model.module.name].str

  # Append model type definition to model types file
  generateModelTypes(modelTypesStr,
                     model)

  # Set modelTypesStr in modelTypesTable
  if keyExists == false:

    modelTypesTable[model.module.name] = TypeInfo()
    modelTypesTable[model.module.name].path = &"{srcPath}{DirSep}types"
    modelImportsTable[model.module.name] = moduleMinimuMimports

  modelTypesTable[model.module.name].str = modelTypesStr

  # Get/create module type
  var moduleType = ""

  if not modelModuleTypeTable.hasKey(model.module.name):
    moduleType = generateModuleTypeHeader(model.module)

  else:
    moduleType = modelModuleTypeTable[model.module.name]

  generateModuleTypeModel(
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
    modelImportsTable: Table[string, OrderedSet[string]]  # [ model.module, imports ]
    modelTypesTable: Table[string, TypeInfo]              # [ model.module, typeInfo ]
    modelModuleTypeTable: Table[string, string]           # [ model.module, moduleType definition ]
    fileModuleName = ""
    moduleMinimuMimports = @[ "db_postgres",
                              "options",
                              "json",
                              "tables",
                              "times" ]

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
  # files and type information
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
      moduleSnakeCaseName = getSnakeCaseName(moduleName)

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

      modelObject = some(getModel(modelYAML,
                                  generatorInfo,
                                  isRef = false))

      baseModel = modelObject.get

    if modelYAML.modelOptions.contains("ref"):

      modelRef = some(getModel(modelYAML,
                               generatorInfo,
                               isRef = true))

      baseModel = modelRef.get

    if modelObject == none(Model) and
       modelRef == none(Model):

      raise newException(ValueError,
                         &"Model: {modelYAML.name}: " &
                          "has neither object nor ref specified")

    # Create DML file
    createMigrationsFile(baseModel,
                         migrationsPath)

    if modelObject != none(Model):

      processModel(modelObject.get,
                   srcPath,
                   toOrderedSet(moduleMinimuMimports),
                   modelImportsTable,
                   modelTypesTable,
                   modelModuleTypeTable,
                   generatorInfo)

    # Create data access file for ref model
    if modelRef != none(Model):

      processModel(modelRef.get,
                   srcPath,
                   toOrderedSet(moduleMinimuMimports),
                   modelImportsTable,
                   modelTypesTable,
                   modelModuleTypeTable,
                   generatorInfo)

  # Write model types files per module
  writeModelTypes(fileModuleName,
                  modelFiles,
                  moduleMinimuMimports,
                  modelImportsTable,
                  modelTypesTable,
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

  # Create a basic model file (module def only) if no model files read (this proc doesn't overwrite valid files)
  createBasicModuleFiles(
    modelFiles,
    generatorInfo)


proc writeModelTypes(
       fileModuleName: string,
       modelFiles: var seq[string],
       moduleMinimuMimports: seq[string],
       modelImportsTable: Table[string, OrderedSet[string]],
       modelTypesTable: Table[string, TypeInfo],
       modelModuleTypeTable: var Table[string, string],
       generatorInfo: GeneratorInfo) =

  var fileContents: Table[string, string]

  # Iterate modules
  for module in generatorInfo.modules:

    if fileModuleName != module.shortName:
      continue

    if module.imported == true and
       not module.generate.contains("models"):

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

    for moduleName, typeInfo in modelTypesTable:

      if modelImportsTable.hasKey(module.name):
        typeStr &= initModelTypesStr(modelImportsTable[module.name])

      else:
        typeStr &= &"import " & moduleMinimuMimports.join(", ") & "\n" &
                    "\n" &
                    &"\n"

      typeStr &= &"type\n" &
                  typeInfo.str &
                  modelModuleTypeTable[moduleName] & &"\n"

    echo ".. creating path: " & typesPath

    createDir(typesPath)

    if fileContents.hasKey(typesFilename):
      fileContents[typesFilename] &= typeStr

    else:
      fileContents[typesFilename] = typeStr

  # Write files
  for filename, contents in fileContents.pairs:

    echo ".. writing: " & filename

    writeFile(filename,
              contents)

    # Add to list of written files
    modelFiles.add(filename)

