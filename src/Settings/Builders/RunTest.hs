module Settings.Builders.RunTest (runTestBuilderArgs) where

import Hadrian.Utilities
import Hadrian.Haskell.Cabal

import Flavour
import Rules.Test
import Settings.Builders.Common
import Settings.Builders.Ghc

-- Arguments to send to the runtest.py script.
runTestBuilderArgs :: Args
runTestBuilderArgs = mconcat
    [ builder RunTest ? do
        pkgs     <- expr $ stagePackages Stage1
        libTests <- expr $ filterM doesDirectoryExist $ concat
                [ [ pkgPath pkg -/- "tests", pkgPath pkg -/- "tests-ghc" ]
                | pkg <- pkgs, isLibrary pkg, pkg /= rts, pkg /= libffi ]

        debugged          <- ghcDebugged <$> expr flavour

        withNativeCodeGen <- expr ghcWithNativeCodeGen
        withInterpreter   <- expr ghcWithInterpreter
        unregisterised    <- expr $ flag GhcUnregisterised
        withSMP           <- expr ghcWithSMP

        windows  <- expr windowsHost
        darwin   <- expr osxHost

        threads  <- shakeThreads <$> expr getShakeOptions
        verbose  <- shakeVerbosity <$> expr getShakeOptions

        top      <- expr topDirectory
        compiler <- expr $ builderPath $ Ghc CompileHs Stage2
        ghcPkg   <- expr $ builderPath $ GhcPkg Update Stage1
        haddock  <- expr $ builderPath $ Haddock BuildPackage
        hp2ps    <- expr $ builderPath $ Hp2Ps
        hpc      <- expr $ builderPath $ Hpc

        ghcFlags    <- expr runTestGhcFlags
        timeoutProg <- expr buildRoot <&> (-/- timeoutProgPath)

        mconcat [ arg $ "testsuite/driver/runtests.py"
                , arg $ "--rootdir=" ++ ("testsuite" -/- "tests")
                , pure ["--rootdir=" ++ test | test <- libTests]
                , arg "-e", arg $ "windows=" ++ show windows
                , arg "-e", arg $ "darwin=" ++ show darwin
                , arg "-e", arg $ "config.speed=2"                        -- Use default value in GHC's test.mk
                , arg "-e", arg $ "config.local=True"
                , arg "-e", arg $ "config.cleanup=False"                  -- Don't clean up.
                , arg "-e", arg $ "config.compiler_debugged=" ++ quote (yesNo debugged)
                , arg "-e", arg $ "ghc_debugged=" ++ quote (yesNo debugged)
                , arg "-e", arg $ "ghc_with_native_codegen=" ++ zeroOne withNativeCodeGen

                , arg "-e", arg $ "config.have_interp=" ++ show withInterpreter
                , arg "-e", arg $ "config.unregisterised=" ++ show unregisterised

                , arg "-e", arg $ "ghc_compiler_always_flags=" ++ quote ghcFlags
                , arg "-e", arg $ "ghc_with_vanilla=1"                    -- TODO: do we always build vanilla?
                , arg "-e", arg $ "ghc_with_dynamic=0"                    -- TODO: support dynamic
                , arg "-e", arg $ "ghc_with_profiling=0"                  -- TODO: support profiling

                , arg "-e", arg $ "config.have_vanilla=1"                 -- TODO: support other build context
                , arg "-e", arg $ "config.have_dynamic=0"                 -- TODO: support dynamic
                , arg "-e", arg $ "config.have_profiling=0"               -- TODO: support profiling
                , arg "-e", arg $ "ghc_with_smp=" ++ zeroOne withSMP
                , arg "-e", arg $ "ghc_with_llvm=0"                       -- TODO: support LLVM

                , arg "-e", arg $ "ghc_with_threaded_rts=0"               -- TODO: support threaded
                , arg "-e", arg $ "ghc_with_dynamic_rts=0"                -- TODO: support dynamic
                , arg "-e", arg $ "config.ghc_dynamic_by_default=False"   -- TODO: support dynamic
                , arg "-e", arg $ "config.ghc_dynamic=False"              -- TODO: support dynamic

                , arg "-e", arg $ "config.in_tree_compiler=True"          -- Use default value, see https://github.com/ghc/ghc/blob/master/testsuite/mk/boilerplate.mk

                , arg "--config-file=testsuite/config/ghc"
                , arg "--config", arg $ "compiler="     ++ show (top -/- compiler)
                , arg "--config", arg $ "ghc_pkg="      ++ show (top -/- ghcPkg)
                , arg "--config", arg $ "haddock="      ++ show (top -/- haddock)
                , arg "--config", arg $ "hp2ps="        ++ show (top -/- hp2ps)
                , arg "--config", arg $ "hpc="          ++ show (top -/- hpc)
                , arg "--config", arg $ "gs=gs"                           -- Use the default value as in test.mk
                , arg "--config", arg $ "timeout_prog=" ++ show (top -/- timeoutProg)
                , arg $ "--threads=" ++ show threads
                , arg $ "--verbose=" ++ show (fromEnum verbose)
                , getTestArgs -- User-provided arguments from command line.
                ]

    -- TODO
    , builder Validate ? pure [] ]
