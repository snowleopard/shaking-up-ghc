module Settings.Path (
    stageDirectory, buildPath, pkgDataFile, pkgHaddockFile, pkgLibraryFile,
    pkgLibraryFile0, pkgGhciLibraryFile, gmpContext, gmpBuildPath, gmpObjects,
    gmpLibraryH, gmpBuildInfoPath, generatedPath, libffiContext, libffiBuildPath,
    rtsContext, rtsBuildPath, rtsConfIn, shakeFilesPath,inplacePackageDbDirectory,
    pkgConfFile, packageDbStamp, bootPackageConstraints, packageDependencies,
    objectPath, inplaceBinPath, inplaceLibBinPath, inplaceLibPath,
    installPath, autogenPath, pkgInplaceConfig, ghcSplitPath, stripCmdPath
    ) where

import Base
import Context
import Expression
import GHC
import Oracles.PackageData
import Oracles.Config.Setting (setting, Setting(..))
import Oracles.Path (getTopDirectory)
import UserSettings

-- | Path to the directory containing the Shake database and other auxiliary
-- files generated by Hadrian.
shakeFilesPath :: FilePath
shakeFilesPath = buildRootPath -/- "hadrian"

-- | Boot package versions extracted from @.cabal@ files.
bootPackageConstraints :: FilePath
bootPackageConstraints = shakeFilesPath -/- "boot-package-constraints"

-- | Dependencies between packages extracted from @.cabal@ files.
packageDependencies :: FilePath
packageDependencies = shakeFilesPath -/- "package-dependencies"

-- | Path to the directory containing generated source files that are not
-- package-specific, e.g. @ghcplatform.h@.
generatedPath :: FilePath
generatedPath = buildRootPath -/- "generated"

-- | Relative path to the directory containing build artefacts of a given 'Stage'.
stageDirectory :: Stage -> FilePath
stageDirectory = stageString

-- | Directory for binaries that are built "in place".
inplaceBinPath :: FilePath
inplaceBinPath = "inplace/bin"

-- | Directory for libraries that are built "in place".
inplaceLibPath :: FilePath
inplaceLibPath = "inplace/lib"

-- | Directory for binary wrappers, and auxiliary binaries such as @touchy@.
inplaceLibBinPath :: FilePath
inplaceLibBinPath = "inplace/lib/bin"

-- | Path to the directory containing build artefacts of a given 'Context'.
buildPath :: Context -> FilePath
buildPath Context {..} = buildRootPath -/- stageDirectory stage -/- pkgPath package

-- | Path to the autogen directory generated by @ghc-cabal@ of a given 'Context'.
autogenPath :: Context -> FilePath
autogenPath context@Context {..}
    | isLibrary package   = autogen "build"
    | package == ghc      = autogen "build/ghc"
    | package == hpcBin   = autogen "build/hpc"
    | package == iservBin = autogen "build/iserv"
    | otherwise           = autogen $ "build" -/- pkgNameString package
  where
    autogen dir = buildPath context -/- dir -/- "autogen"

-- | Path to inplace package configuration of a given 'Context'.
pkgInplaceConfig :: Context -> FilePath
pkgInplaceConfig context = buildPath context -/- "inplace-pkg-config"

-- | Path to the @package-data.mk@ of a given 'Context'.
pkgDataFile :: Context -> FilePath
pkgDataFile context = buildPath context -/- "package-data.mk"

-- | Path to the haddock file of a given 'Context', e.g.:
-- "_build/stage1/libraries/array/doc/html/array/array.haddock".
pkgHaddockFile :: Context -> FilePath
pkgHaddockFile context@Context {..} =
    buildPath context -/- "doc/html" -/- name -/- name <.> "haddock"
  where name = pkgNameString package

-- | Path to the library file of a given 'Context', e.g.:
-- "_build/stage1/libraries/array/build/libHSarray-0.5.1.0.a".
pkgLibraryFile :: Context -> Action FilePath
pkgLibraryFile context@Context {..} = do
    extension <- libsuf way
    pkgFile context "libHS" extension

-- | Path to the auxiliary library file of a given 'Context', e.g.:
-- "_build/stage1/compiler/build/libHSghc-8.1-0.a".
pkgLibraryFile0 :: Context -> Action FilePath
pkgLibraryFile0 context@Context {..} = do
    extension <- libsuf way
    pkgFile context "libHS" ("-0" ++ extension)

-- | Path to the GHCi library file of a given 'Context', e.g.:
-- "_build/stage1/libraries/array/build/HSarray-0.5.1.0.o".
pkgGhciLibraryFile :: Context -> Action FilePath
pkgGhciLibraryFile context = pkgFile context "HS" ".o"

pkgFile :: Context -> String -> String -> Action FilePath
pkgFile context prefix suffix = do
    let path = buildPath context
    componentId <- pkgData $ ComponentId path
    return $ path -/- prefix ++ componentId ++ suffix

-- | RTS is considered a Stage1 package. This determines RTS build directory.
rtsContext :: Context
rtsContext = vanillaContext Stage1 rts

-- | Path to the RTS build directory.
rtsBuildPath :: FilePath
rtsBuildPath = buildPath rtsContext

-- | Path to RTS package configuration file, to be processed by HsCpp.
rtsConfIn :: FilePath
rtsConfIn = pkgPath rts -/- "package.conf.in"

-- | GMP is considered a Stage1 package. This determines GMP build directory.
gmpContext :: Context
gmpContext = vanillaContext Stage1 integerGmp

-- | Build directory for in-tree GMP library.
gmpBuildPath :: FilePath
gmpBuildPath = buildRootPath -/- stageDirectory (stage gmpContext) -/- "gmp"

-- | Path to the GMP library header.
gmpLibraryH :: FilePath
gmpLibraryH = gmpBuildPath -/- "include/ghc-gmp.h"

-- | Path to the GMP library object files.
gmpObjects :: FilePath
gmpObjects = gmpBuildPath -/- "objs"

-- | Path to the GMP library buildinfo file.
gmpBuildInfoPath :: FilePath
gmpBuildInfoPath = pkgPath integerGmp -/- "integer-gmp.buildinfo"

-- | Libffi is considered a Stage1 package. This determines its build directory.
libffiContext :: Context
libffiContext = vanillaContext Stage1 libffi

-- | Build directory for in-tree Libffi library.
libffiBuildPath :: FilePath
libffiBuildPath = buildPath libffiContext

-- | Path to package database directory of a given 'Stage'. Note: StageN, N > 0,
-- share the same packageDbDirectory.
inplacePackageDbDirectory :: Stage -> FilePath
inplacePackageDbDirectory Stage0 = buildRootPath -/- "stage0/bootstrapping.conf"
inplacePackageDbDirectory _      = "inplace/lib/package.conf.d"

-- | We use a stamp file to track the existence of a package database.
packageDbStamp :: Stage -> FilePath
packageDbStamp stage = inplacePackageDbDirectory stage -/- ".stamp"

-- | Path to the configuration file of a given 'Context'.
pkgConfFile :: Context -> Action FilePath
pkgConfFile context@Context {..} = do
    componentId <- pkgData . ComponentId $ buildPath context
    return $ inplacePackageDbDirectory stage -/- componentId <.> "conf"

-- | Given a 'FilePath' to a source file, return 'True' if it is generated.
-- The current implementation simply assumes that a file is generated if it
-- lives in 'buildRootPath'. Since most files are not generated the test is
-- usually very fast.
isGeneratedSource :: FilePath -> Bool
isGeneratedSource = (buildRootPath `isPrefixOf`)

-- | Given a 'Context' and a 'FilePath' to a source file, compute the 'FilePath'
-- to its object file. For example:
-- * "Task.c"                              -> "_build/stage1/rts/Task.thr_o"
-- * "_build/stage1/rts/cmm/AutoApply.cmm" -> "_build/stage1/rts/cmm/AutoApply.o"
objectPath :: Context -> FilePath -> FilePath
objectPath context@Context {..} src
    | isGeneratedSource src = obj
    | "*hs*" ?== extension  = buildPath context -/- obj
    | otherwise             = buildPath context -/- extension -/- obj
  where
    extension = drop 1 $ takeExtension src
    obj       = src -<.> osuf way

-- | Given a 'Package', return the path where the corresponding program is
-- installed. Most programs are installed in 'programInplacePath'.
installPath :: Package -> FilePath
installPath pkg
    | pkg == touchy = inplaceLibBinPath
    | pkg == unlit  = inplaceLibBinPath
    | otherwise     = inplaceBinPath

-- | @ghc-split@ is a Perl script used by GHC with @-split-objs@ flag. It is
-- generated in "Rules.Generators.GhcSplit".
ghcSplitPath :: FilePath
ghcSplitPath = inplaceLibBinPath -/- "ghc-split"

-- | Command line tool for stripping
-- ref: mk/config.mk
stripCmdPath :: Context -> Action FilePath
stripCmdPath ctx = do
    targetPlatform <- setting TargetPlatform
    top <- interpretInContext ctx getTopDirectory
    case targetPlatform of
        "x86_64-unknown-mingw32" ->
             return (top -/- "inplace/mingw/bin/strip.exe")
        "arm-unknown-linux" ->
             return ":" -- HACK: from the make-based system, see the ref above
        _ -> return "strip"
