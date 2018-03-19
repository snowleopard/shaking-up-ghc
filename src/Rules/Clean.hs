module Rules.Clean (clean, cleanSourceTree, cleanRules) where

import Base

clean :: Action ()
clean = do
    cleanSourceTree
    putBuild "| Remove Hadrian files..."
    path <- buildRoot
    removeDirectory $ path -/- generatedDir
    removeFilesAfter path ["//*"]
    putSuccess "| Done. "

cleanSourceTree :: Action ()
cleanSourceTree = do
    path <- buildRoot
    forM_ [Stage0 ..] $ removeDirectory . (path -/-) . stageString
    removeDirectory inplaceBinPath
    removeDirectory inplaceLibPath
    removeDirectory "sdistprep"
    cleanFsUtils

-- Clean all temporary fs files copied by configure into the source folder
cleanFsUtils :: Action ()
cleanFsUtils = do
    let dirs = [ "utils/lndir/"
               , "utils/unlit/"
               , "rts/"
               , "libraries/base/include/"
               , "libraries/base/cbits/"
               ]
    liftIO $ forM_ dirs (flip removeFiles ["fs.*"])


cleanRules :: Rules ()
cleanRules = "clean" ~> clean
