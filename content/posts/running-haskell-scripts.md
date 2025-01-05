+++
title = "Running a Haskell script without GHC"
date = "2020-03-10"

[taxonomies]
tags=["haskell","nix"]

[extra]
repo_view = false
comment = false
+++

# Introduction

Given the following haskell script `generate-random-samples.hs` that requires [mwc-random](https://hackage.haskell.org/package/mwc-random-0.14.0.0)

```haskell
{-# LANGUAGE ScopedTypeVariables #-}

import System.Random.MWC
import Data.Vector.Unboxed
import Control.Monad.ST

main = do
  vs <- withSystemRandom $
        \(gen::GenST s) -> uniformVector gen 20 :: ST s (Vector Int)
  print vs
```

... how do you run it without having to globally install the package or having to build a whole cabal project ?

# Initial approach

One of the simplest approaches using nix is the following:

```bash
$ nix-shell --packages 'haskellPackages.ghcWithHoogle (pkgs: with pkgs; [ mwc-random ])'
nix-shell> runghc generate-random-samples.hs
```

In order to reuse the command so other people can run the script, you can add the following `shell.nix`:

```nix
{ compiler ? "ghc881" }:
let

  pkgs = import (builtins.fetchGit {
    url = "https://github.com/NixOS/nixpkgs.git";
    rev = "890440b0273caab258b38c0873c3fe758318bb4f";
    ref = "master";
  }) {};

  ghc = pkgs.haskell.packages.${compiler}.ghcWithPackages (ps: with ps; [
          mwc-random
        ]);

in

pkgs.stdenv.mkDerivation {
  name = "ghc-env";
  buildInputs = [ ghc pkgs.cabal-install ];
  shellHook = "eval $(egrep ^export ${ghc}/bin/ghc)";
}
```

So now you only need to call `$ nix-shell` to enter into a pure shell with a specific GHC version that includes all your dependencies:

```bash
$ nix-shell
nix-shell> runghc generate-random-samples.hs
```

# Improving the first approach

The only __issue__ is that you must be aware of __how nix work__ in order to be able to run the script.

But these could be solved using bash _shebangs_ in your haskell script:

```haskell
#!/usr/bin/env nix-shell
#!nix-shell -i runghc
{-# LANGUAGE ScopedTypeVariables #-}

import System.Random.MWC
import Data.Vector.Unboxed
import Control.Monad.ST

main = do
  vs <- withSystemRandom $
        \(gen::GenST s) -> uniformVector gen 20 :: ST s (Vector Int)
  print vs
```

So now, you can run your haskell script in an environment without ghc:

```bash
./generate-random-samples.hs
[6052359640365008112,3693984866634705670,6521947999724514858,640433474764908030,-4262896110044960033,-1795671341099353119,-2220462704949887998,-248182841640258167,709016591698961687,-3622504171575206589,5987258113070378446,-159251391303273987,-8449937247808153766,6165509553180365166,-8199532339362621783,-9187765480154042269,-2389922548196927048,-4842141643835297495,-1106748185069026877,826927505518387091]
```

# Update: 11-03-2020

After reading the following [comment in reddit](https://www.reddit.com/r/haskell/comments/fgdngc/running_a_haskell_script_without_ghc_using_nix/fk56fut/), I think it is worth mentioning that you can achieve _better modularity_ in exchange of _maintainability_, by having everything on the haskell script, without having to depend on a `shell.nix` file:

```haskell
#!/usr/bin/env nix-shell
#!nix-shell -i runghc -p "haskellPackages.ghcWithPackages (pkgs: with pkgs; [ mwc-random ])"
#!nix-shell -I nixpkgs=https://github.com/NixOS/nixpkgs/archive/d373d80b1207d52621961b16aa4a3438e4f98167.tar.gz
{-# LANGUAGE ScopedTypeVariables #-}

import System.Random.MWC
import Data.Vector.Unboxed
import Control.Monad.ST

main = do
  vs <- withSystemRandom $
        \(gen::GenST s) -> uniformVector gen 20 :: ST s (Vector Int)
  print vs
```
