+++
title = "Template Haskell use cases"
date = "2021-10-14"

[taxonomies]
tags=["haskell"]

[extra]
repo_view = false
comment = false
+++

# Introduction

_Template Haskell_ (TH) is an extension of [GHC](https://www.haskell.org/ghc/) that allows the user to do type-safe compile-time meta-programming in _Haskell_. The idea behind template haskell comes from the paper ["Template Meta-programming for Haskell"](https://www.microsoft.com/en-us/research/wp-content/uploads/2016/02/meta-haskell.pdf) by S.P. Jones and T. Sheard. Template Haskell was shipped with [GHC version 6.0](https://www.haskell.org/ghc/download_ghc_600.html). The compiler extension has evolved a lot since 2003 and its current state is well described at the [GHC: User Manual](https://downloads.haskell.org/ghc/latest/docs/html/users_guide/exts/template_haskell.html) and [template-haskell](https://hackage.haskell.org/package/template-haskell) package.

Initially, TH offered the ability to generate code at compile time and allowed the programmer to manipulate the _abstract syntax tree_ (AST) of the program. The addition of new capabilities such as [lifting](https://hackage.haskell.org/package/template-haskell-2.17.0.0/docs/Language-Haskell-TH-Syntax.html#t:Lift), [TExp](https://hackage.haskell.org/package/template-haskell-2.17.0.0/docs/Language-Haskell-TH.html#t:TExp) , [runIO](https://hackage.haskell.org/package/template-haskell-2.17.0.0/docs/Language-Haskell-TH-Syntax.html#v:runIO), and [quasiquoting](https://hackage.haskell.org/package/template-haskell-2.17.0.0/docs/Language-Haskell-TH-Quote.html) opened a bunch of new use cases to explore.

In this blog post, we are going explore a bunch of interesting Template Haskell's use cases:

- Type Class Derivation
- N-ary Function Generation
- Compile-time Static Input Validation
- Arbitrary IO at Compile Time

This article assumes some familiarity with Haskell and, in particular, with Template Haskell. There are many well-written tutorials on the internet such as [A Practical Template Haskell Tutorial](https://wiki.haskell.org/A_practical_Template_Haskell_Tutorial) or [Template Haskell Tutorial](https://markkarpov.com/tutorial/th.html).  We strongly recommend reading the previously mentioned tutorials before continuing with the reading.

# Use Cases

Before we start, these are the list of _language extensions_ and _imports_ that we are going to use in the following sections:

```haskell
{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE ViewPatterns #-}
```

```haskell
import Codec.Picture
import Control.Applicative (ZipList (..))
import Control.Monad (replicateM, when)
import Data.ByteString (ByteString)
import qualified Data.ByteString as BS
import Data.Char (isSpace)
import Data.Data hiding (cast)
import Data.Foldable
import qualified Data.Text as T
import Data.Word
import Instances.TH.Lift ()
import Language.Haskell.TH
import Language.Haskell.TH.Quote
import Language.Haskell.TH.Syntax
import Network.HTTP.Req
import Text.Read (readMaybe)
import qualified Text.URI as URI
```

## Ex 1: Type Class Derivation

Automatic derivation of type class instances is one of many problems that TH can solve. Although this problem can also be solved by [generics](https://hackage.haskell.org/package/base-4.15.0.0/docs/GHC-Generics.html), the compilation times are usually longer. For this reason, template haskell is still the preferred way to generate type class instances at compile time.

Here we present an example of how to derive the type class [Foldable](https://hackage.haskell.org/package/base-4.14.1.0/docs/Data-Foldable.html#t:Foldable) for arbitrary datatypes.

```haskell
data List a 
  = Nil 
  | Cons a (List a)
deriveFoldable ''List
```

The implementation is as follows:

```haskell
data Deriving = Deriving { tyCon :: Name, tyVar :: Name }
  deriving (Typeable)

deriveFoldable :: Name -> Q [Dec]
deriveFoldable ty = do
  (TyConI tyCon) <- reify ty
  (tyConName, tyVars, cs) <- case tyCon of
    DataD _ nm tyVars _ cs _   -> return (nm, tyVars, cs)
    NewtypeD _ nm tyVars _ c _ -> return (nm, tyVars, [c])
    _ -> fail "deriveFoldable: tyCon may not be a type synonym."

  let (KindedTV tyVar StarT) = last tyVars
  putQ $ Deriving tyConName tyVar

  let instanceType = conT ''Foldable `appT` foldl' apply (conT tyConName) (init tyVars)
  foldableD <- instanceD (return []) instanceType [genFoldMap cs]
  return [foldableD]

  where
    apply t (PlainTV name)    = appT t (varT name)
    apply t (KindedTV name _) = appT t (varT name)

genFoldMap :: [Con] -> Q Dec
genFoldMap cs = funD 'foldMap (genFoldMapClause <$> cs)

genFoldMapClause :: Con -> Q Clause
genFoldMapClause (NormalC name fieldTypes)
  = do f          <- newName "f"
       fieldNames <- replicateM (length fieldTypes) (newName "x")

       let pats = varP f : [conP name (map varP fieldNames)]
           newFields = newField f <$> zip fieldNames (snd <$> fieldTypes)
           body = normalB $
             foldl' (\ b x -> [| $b <> $x |]) (varE 'mempty) newFields

       clause pats body []
genFoldMapClause _ = error "Not supported yet"

newField :: Name -> (Name, Type) -> ExpQ
newField f (x, fieldType) = do
  Just (Deriving typeCon typeVar) <- getQ
  case fieldType of
    VarT typeVar' | typeVar' == typeVar ->
      [| $(varE f) $(varE x) |]

    AppT ty (VarT typeVar') | leftmost ty == ConT typeCon && typeVar' == typeVar ->
        [| foldMap $(varE f) $(varE x) |]

    _ -> [| mempty |]
    
leftmost :: Type -> Type
leftmost (AppT ty1 _) = leftmost ty1
leftmost ty           = ty
```

## Ex 2: N-ary Function Generation

Have you ever written a function like `snd3 :: (a, b, c) -> b` or `snd4 :: (a, b, c, d) -> b` ? Then, you can do better by letting the compiler write those boilerplate and error-prone functions for you.

Here we present an example of how to write an arbitrary-sized [zipWith](https://hackage.haskell.org/package/base-4.15.0.0/docs/GHC-OldList.html#v:zipWith). 
We have chosen `zipWith` since it is a fairly simple function but complex enough to be used as the base to write more complex functions.

Here is a first implementation of `zipWithN`:

```haskell
zipWithN :: Int -> Q [Dec]
zipWithN n
  | n >= 2 = sequence [funD name [cl1, cl2]]
  | otherwise = fail "zipWithN: argument n may not be < 2."
  where
    name = mkName $ "zipWith" ++ show n

    cl1 = do
      f <- newName "f"
      xs <- replicateM n (newName "x")
      yss <- replicateM n (newName "ys")
      let argPatts = varP f : consPatts
          consPatts = [ [p| $(varP x) : $(varP ys) |]
                      | (x, ys) <- xs `zip` yss
                      ]
          apply = foldl (\ g x -> [| $g $(varE x) |])
          first = apply (varE f) xs
          rest = apply (varE name) (f:yss)
      clause argPatts (normalB [| $first : $rest |]) []

    cl2 = clause (replicate (n+1) wildP) (normalB (conE '[])) []
```

This implementation works fine but the compiler will `warn` you about a missing signature on a top-level definition.
In order to fix this, we need to add a type signature to the generated term:

```haskell
zipWithN :: Int -> Q [Dec]
zipWithN n
  | n >= 2 = sequence [ sigD name ty, funD name [cl1, cl2] ]
  ...
  where
    ...

    ty = do
      as <- replicateM (n+1) (newName "a")
      let apply = foldr (appT . appT arrowT)
          funTy = apply (varT (last as)) (varT <$> init as)
          listsTy = apply (appT listT (varT (last as))) (appT listT . varT <$> init as)
      appT (appT arrowT funTy) listsTy
    
    ...
```

Now you can use `zipWithN` to generate arbitrary-sized `zipWith` functions:

```haskell
...
$(zipWithN 6)
$(zipWithN 7)
$(zipWithN 8)
...
```

Manually generating each instance partially defeats the purpose of `zipWithN`.
In order to address this issue, we need the auxiliary function `genZipWith`. Notice, we will use an alternative simplified definition of `zipWithN` that exploits slicing and lifting to showcase.

```haskell
genZipWith :: Int -> Q [Dec]
genZipWith n = traverse mkDec [1..n]
  where
    mkDec ith = do
      let name = mkName $ "zipWith" ++ show ith ++ "'"
      body <- zipWithN ith
      return $ FunD name [Clause [] (NormalB body) []]

zipWithN :: Int -> Q Exp
zipWithN n = do
    xss <- replicateM n (newName "xs")
    [| \f ->
        $(lamE (varP <$> xss)
                [| getZipList
                    $(foldl'
                        (\ g xs -> [| $g <*> $xs |])
                        [| pure f |]
                        (fmap (\xs -> [| ZipList $(varE xs) |]) xss)
                    )
                |])
    |]
```

Now, we can generate arbitrary sized `zipWith` functions

```haskell
$(genZipWith' 20)
```

which will produce `zipWith1`, `zipWith2`, ..., `zipWith19`, `zipWith20`.

## Ex 3: Compile-time Input Validation

Static input data is expected to be "correct" on a strongly typed programming language. 
For example, assigning the decimal number `256` to a variable of type `Byte` is expected to fail at compile time.
So, let's try it on Haskell:

```
ghci> :m +Data.Word
ghci> 256 :: Word8
<interactive>:2:1: warning: [-Woverflowed-literals]
    Literal 256 is out of the Word8 range 0..255
0
```

Ops! Indeed, the code has compiled with an unexpected overflow. 
The keen-eyed reader may be thinking that this bug could have been prevented with the appropriate GHC flags `-Wall` and `-Werror`.
Here we present a more general approach to validate static input data from the user using [quasiquoting](https://hackage.haskell.org/package/template-haskell-2.17.0.0/docs/Language-Haskell-TH-Quote.html). This example can be easily adapted to all sorts of input data.

```haskell
word :: QuasiQuoter
word = QuasiQuoter
  { quoteExp  = parseWord
  , quotePat  = notHandled "patterns"
  , quoteType = notHandled "types"
  , quoteDec  = notHandled "declarations"
  }
  where notHandled things = error $
          things ++ " are not handled by the word quasiquoter."

parseWord :: String -> Q Exp
parseWord (trim -> str) =
  case words str of
    [w] ->
      case break (== 'u') w of
        (lit, size) ->
          case readMaybe @Integer lit of
            Just int -> do
              when (int < 0) $ fail "words are strictly positive"
              case size of
                "u8" -> castWord @Word8 ''Word8 int
                "u16" -> castWord @Word16 ''Word16 int
                "u32" -> castWord @Word32 ''Word32 int
                "u64" -> castWord @Word64 ''Word64 int
                _ -> fail ("size " <> size <> " is not one of {u8, u16, u32, u64}")
            Nothing -> fail (lit <> " cannot be parsed as Integer")

    _ -> fail ("Unexpected word: " <> str)
  where
    castWord :: forall a. (Show a, Bounded a, Integral a) => Name -> Integer -> ExpQ
    castWord ty int
      | int <= fromIntegral (maxBound @a) = sigE [|int|] (conT ty)
      | otherwise = fail (pprint ty <> " is outside of bound: [0," <> show (maxBound @a) <> "]")

trim :: String -> String
trim = f . f where
  f = reverse . dropWhile isSpace
```

The `word` quasiquoter can validate static input data 

```
ghci> [word| 255u8 |]
255 :: Word8
```

and emit a compilation-time error if the data is not valid

```
ghci> [word| 256u8 |]
<interactive>:315:7-15: error:
    * GHC.Word.Word8 is outside of bound: [0,255]
    * In the quasi-quotation: [word| 256u8 |]
```

## Ex 4: Arbitrary IO at Compile Time

Running arbitrary IO on compile-time is one of the features of TH. This allows the user to make compilation dependant on external conditions such as the database schema, the current git branch or a local file content.

In this last example, we are going to use `runIO` and `quasiquoting` to get static pictures from remote and local files at compile-time. Notice, this example has been simplified to avoid all the overhead of proper error handling.

1. Try to parse the input string as an _url_
  1. If it succeeds, request the content of the url as a bytestring
  2. Otherwise, interpret the input string as a _file path_ and read its content.
2. Decode the contents as a  [DynamicImage](https://hackage.haskell.org/package/JuicyPixels-3.3.6/docs/Codec-Picture.html#t:DynamicImage)
3. Lift the `DynamicImage`

```haskell
img :: QuasiQuoter
img = QuasiQuoter {
    quoteExp  = imgExpQ
  , quotePat  = notHandled "patterns"
  , quoteType = notHandled "types"
  , quoteDec  = notHandled "declarations"
  }
  where notHandled things = error $
          things ++ " are not handled by the img quasiquoter."

imgExpQ :: String -> ExpQ
imgExpQ str = do
  uri' <- URI.mkURI (T.pack str)
  bs <- runIO $ do
    (bs, dynImg) <- 
      case useURI uri' of
        Nothing -> BS.readFile str
        Just (Left (url, _)) -> requestBs url
        Just (Right (url, _)) -> requestBs url
    either fail (pure . (bs,)) $ decodeImage bs
  liftDynamicImage bs

liftDynamicImage :: ByteString -> Q Exp
liftDynamicImage bs = [| either error id (decodeImage bs) |]

requestBs :: Url scheme -> IO ByteString
requestBs url =
  runReq defaultHttpConfig $ do
    r <- req
            GET
            url
            NoReqBody
            bsResponse
            mempty
    return (responseBody r)
```

The `img` quasiquoter can be used to load pictures as static data inside your binary

```haskell
dynImg1 :: DynamicImage
dynImg1 = [img|https://httpbin.org/image/jpeg|]

dynImg2 :: DynamicImage
dynImg2 = [img|./resources/pig.png|]
```

# Conclusion

During this blog post, we have seem some of the use cases of template haskell and how to implement them.
We encourage the reader to use our examples to build new and more compelling use cases of template haskell and to share them with the community.

We hope you enjoyed this post and don't forget to share your own use cases for template haskell in the comments.
