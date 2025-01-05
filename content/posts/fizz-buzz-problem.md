+++
title = "The Fizz Buzz problem"
date = "2021-09-24"
render = false

[taxonomies]
tags=["haskell"]

[extra]
repo_view = false
comment = false
+++

This morning, I saw [this blog](https://twitter.com/cercerilla/status/1441994898870177796?s=20) by [@cercerilla](https://twitter.com/cercerilla/) on twitter. I was fascinated by her implementation but I couldn't believe how many lines of code it took to write such a simple program! The _Fizz Buzz_ problem can be implemented on the term level with only a few lines of code:

```haskell
fizz :: Int -> String
fizz n | n `mod` 15 == 0  = "FizzBuzz"
       | n `mod` 3  == 0  = "Fizz"
       | n `mod` 5  == 0  = "Buzz"
       | otherwise        = show n

main :: IO()
main = traverse_ (putStrLn . fizz) [1..100]
```

One of the main problems of type-level programming in Haskell is that you cannot implement higher-order functions on the type level (see [saturation restriction](https://github.com/ghc-proposals/ghc-proposals/blob/master/proposals/0242-unsaturated-type-families.rst#recap-saturation-restriction)). Therefore, we cannot abstract as much as we do on the term level using `traverse` and `[1..100]`. There is an accepted proposal [unsaturated type families](https://github.com/ghc-proposals/ghc-proposals/blob/master/proposals/0242-unsaturated-type-families.rst) but it still not merged into GHC.

Are we doomed to write a lot of boilerplate code as in `@cercerilla` example? The answer is no, there is a workaround to this problem called _defunctionalization_. Defunctionalization translates higher-order functions into first-order functions:

1. Instead of working with functions, work with symbols representing functions.
2. Build your final functions and values by composing and combining these symbols.
3. At the end of it all, have a single `apply` function interpret all of your symbols and produce the value you want.

This idea of defunctionalization is implemented in the [singletons](https://hackage.haskell.org/package/singletons) and in [first-class-families](https://hackage.haskell.org/package/first-class-families).

Below we present the implementation of _Fizz Buzz_ on the type-level using the `singletons` library(you can achieve a similar result using `fcf` package). The implementation is many times smaller than the one implemented using ad hoc higher-order combinators and easier to understand since most of the complexity is moved away to the singletons' library.

```haskell
{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE StandaloneKindSignatures #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE PolyKinds #-}
{-# LANGUAGE GADTs #-}

module FizzBuzz where

import Data.Singletons.TH
import Data.Singletons.Prelude
import Data.Singletons.TypeLits

$(singletons [d|
  type Divisible n by = Mod n by == 0

  type FizzBuzzElem :: Nat -> Symbol
  type FizzBuzzElem n =
      If
        (Divisible n 15)
        "FizzBuzz"
        ( If
            (Divisible n 3)
            "Fizz"
            ( If
                (Divisible n 5)
                "Buzz"
                (Show_ n)))

  |])

type FizzBuzz n = Fmap FizzBuzzElemSym0 (EnumFromTo 1 n)

-- |
-- >>> fizzBuzz @10
-- "[FizzBuzz,1,2,Fizz,4,Buzz,Fizz,7,8,Fizz]"
fizzBuzz :: forall (n :: Nat). (KnownSymbol (Show_ (FizzBuzz n))) => String
fizzBuzz = symbolVal (Proxy @(Show_ (FizzBuzz n)))
```

Type-level programming in Haskell is still a difficult task since the support for higher-order abstractions is still not available in the language. With the use of libraries such as `singletons` we can make this task less difficult reusing many higher-order abstractions on the type level.
