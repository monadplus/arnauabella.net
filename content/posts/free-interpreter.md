+++
title = "Free Monads in the real world"
date = "2022-04-19"

[taxonomies]
tags=["haskell"]

[extra]
repo_view = false
comment = false
+++

After finishing my master's degree, I applied to several companies I was interested in. During one of the selection processes, the interviewer asked me to do the following exercise:

_"Write a stack-based interpreted language that includes: literals, arithmetic operations, variables, and control flow primitives. As a bonus, add asynchronous primitives such as fork and await."_

Fortunately, I was already familiar with the assignment because I implemented a [statically typed programming language](https://github.com/monadplus/CPP-lang) a year ago. Consequently, I decided to take this as a chance and do something different than the rest of the candidates. Spoiler: haskell + free monads!

> The source code from this blog can be found [here](https://github.com/monadplus/free-monads-by-example). My recommendation is to have both opened side-by-side.

# Free monads

The concept of a _free monad_ comes from the field of Category Theory (CT). The [formal definition](https://ncatlab.org/nlab/show/free+monad) is hard to grasp without a background in CT. In terms of programming, a more pragmatic definition is

**Def**. For any functor $f$, there exists a _uniquely_ determined monad called the _free monad_ of the functor $f$ [^1]

In plain words, we can transform _any_ functor $f$ into a monad...And you may be wondering "how is that useful to write an interpreter in Haskell? You'll see in a bit, stick with me.

## Free monads encoded in Haskell

Let's show how free monads is translated into Haskell. We are going to base our work on the encoding of free monads of the haskell package [free](https://hackage.haskell.org/package/free) by Edward Kmett. The definition is as follows:

```haskell
data Free f a = Pure a | Free (f (Free f a))
```

You can think of `Free f`  as a stack of layers `f` on top of a value `a`. 

We will encode our interpreted language as a set of free monadic actions (instructions) represented as a datatype with a functorial shape. And our programs will be just a stack of thes instructions.

The interesting part about `Free f` is that `Free f` is a [monad](https://hackage.haskell.org/package/base-4.14.1.0/docs/Control-Monad.html#t:Monad) as long as `f` is a [functor](https://hackage.haskell.org/package/base-4.14.1.0/docs/Data-Functor.html#t:Functor):

```haskell
instance Functor f => Monad (Free f) where
  return = pure
  Pure a >>= f = f a
  Free m >>= f = Free ((>>= f) <$> m)
```

This will allow us to compose programs for free[^2]. 
On top of that, do-notation gives us a nice syntax to compose 'em all!

In the next section, we will finally see how to put this into practise.

# Solving the assignment

When modeling a language[^3] using free monads, you usually divide the problem in two parts:
1. Define your language. 
2. Define the interpreter for your language.

## Defining our eDSL

First, we need to define our language. We are free to model any kind of language, but the type that represents our language must be a functor. Otherwise, our language will not be able to be composed using bind `(=<<)`. 

Here is the sum type representing our byte code language:

```haskell
type ByteCode = Free ByteCodeF

data ByteCodeF next
  = Lit Value next
  | Load Var next
  | Write Var next
  | BinaryOp OpCode next
  | Loop (ByteCode Bool) (ByteCode ()) next
  | Ret (Value -> next)
  | NewChan (Channel -> next)
  | Send Channel next
  | Recv Channel next
  | Fork (ByteCode ()) (Future () -> next)
  | Await (Future ()) next
  deriving (Functor)

data Value
  = B Bool
  | I Integer
  deriving stock (Eq, Show, Ord)

newtype Chan a = Chan { getChan :: MVar a}
  deriving newtype (Eq)

data Future a where
  Future :: Exception e => Async (Either e a) -> Future a
```

- `Lit` instruction to instantiate literals (integer and boolean values).
- `Load`/`Write` instructions to load and write variables, respectively.
- `BinaryOp` instruction to apply binary operations (+, *, <) on the top values of the stack.
- `Loop` instruction to execute a set of instructions iteratively based on a certain condition.
- `Ret` instruction to stop the program and return the value on top of the stack.
- `Fork`/`Await` instructions to start and await an asynchronous program, respectively.
- `NewChan`/`Send`/`Recv` instructions to create a new asynchronous channel, send and receive a value through the channel, respectively. This channel allow to independent asynchronous programs to communicate.

The careful reader may have notice that our type `ByteCodeF` has a type parameter `next :: Type`. This type parameter is required for `ByteCodeF` to be a functor. We can think of `next` as the next instruction in our program. In fact, when we interpret the `ByteCode` free monad, next will be replaced by the (evaluated) next instruction of our program.

Next, for each constructor of our `ByteCodeF`, we need a function that lifts `ByteCodeF` into `ByteCode`. For example, here is the definition of that function for `Lit`:

```haskell
lit :: Value -> ByteCode ()
lit v = Free (Lit v (Pure ()))
```

Implementing this for each constructor is tedious and error prone. This problem can be solved with metaprogramming. In particular, with [template haskell](https://hackage.haskell.org/package/template-haskell-2.17.0.0/docs/Language-Haskell-TH.html) (for an introduction to template haskell see my [blog post](https://monadplus.pro/haskell/2021/10/14/th/)). Fortunately, this is already implemented in [Control.Monad.Free.TH](https://hackage.haskell.org/package/free-5.1.7/docs/Control-Monad-Free-TH.html). 

Therefore, we are going to use `makeFree` to automatically derive all these free monadic actions

```haskell
$(makeFree ''ByteCodeF)
```

which generates the following code[^4]

```haskell
lit      :: Value                         -> ByteCode ()
load     :: Var                           -> ByteCode ()
write    :: Var                           -> ByteCode ()
loop     :: ByteCode Value -> ByteCode () -> ByteCode ()
newChan  ::                                  ByteCode Channel
send     :: Channel                       -> ByteCode ()
recv     :: Channel                       -> ByteCode ()
fork     :: ByteCode ()                   -> ByteCode (Async ())
await    :: Async ()                      -> ByteCode ()
```

Once we have the basic building blocks of our language, we can start building programs by composing smaller programs using monadic composition!

```haskell
loopN :: Integer -> ByteCode ()
loopN until = do
  let {n = "n"; i = "i"}
  litI until
  write n
  litI 1
  write i
  loop (i < n) (i ++)

(<) i n = do
  load n
  load i
  lessThan
  ret
  
(++) i = do
  litI 1
  load i
  add
  write i
```

## Interpreting our program

Now that we have the building blocks to construct our domain specific programs, it is only remaining to implement an interpreter to evaluate this embedded DSL in our host language Haskell.

The interpreter is usually implemented using [iterM](https://hackage.haskell.org/package/free-5.1.7/docs/Control-Monad-Free.html#v:iterM), which allows us to collapse our `Free f` into a monadic value `m a` by providing a function `f (m a) -> m a` (usually called an _algebra_) that operates on a single layer of our free monad. If you are familiar with recursion schemes, `iterM` is a specialization of [cataA](https://hackage.haskell.org/package/recursion-schemes-5.2.2.2/docs/Data-Functor-Foldable.html#v:cataA). This may sound confusing at first, but it is easier than it sounds.

First of all, we need to choose the monadic value `m`. For our interpreted language, we choose `m ~ Interpreter`

```haskell
newtype Interpreter a = Interpreter 
  { runInterpreter :: StateT Ctx (ExceptT Err IO) a }

data Ctx = Ctx
  { stack :: [Value],
    variables :: Map Var Value
  }

data Err
  = VariableNotFound Var
  | StackIsEmpty
  | BinaryOpExpectedTwoOperands
  | AsyncException Text
  | WhoNeedsTypes
```

where `Ctx` is the current context of our program i.e. the state of the stack and the memory registers. 
Then, we specialize `iterM` to our example

```haskell
--       <---------------- algebra ----------------->
iterm :: (ByteCodeF (Interpreter a) -> Interpreter a) -> ByteCode a -> Interpreter a
```

The last step and usually the most difficult one is to implement the _algebra_ of our DSL

```haskell
algebra :: ByteCodeF (Interpreter a) -> Interpreter a
algebra = \case
  Ret f -> popI >>= f
  Lit i k -> pushI i >> k
  Load var k -> loadI var >>= pushI >> k
  Write var k -> popI >>= storeI var >> k
  BinaryOp op k ->
    do
      catchError
        (liftA2 (applyOp op) popI popI >>= either throwError pushI)
        ( \case
            StackIsEmpty -> throwError BinaryOpExpectedTwoOperands
            e -> throwError e
        )
      >> k
  Loop cond expr k ->
    fix $ \rec -> do
      b <- interpret cond
      if b
        then interpret expr >> rec
        else k
  NewChan f ->
    liftIO getChan >>= f
  Send chan k ->
    popI >>= (liftIO . sendChan chan) >> k
  Recv chan k ->
    liftIO (recvChan chan) >>= pushI >> k
  Fork branch k ->
    future branch >>= k
  Await (Future async') k -> do
    ea <- liftIO $ waitCatch async'
    case ea of
      Left (SomeException ex) -> throwError (AsyncException (T.pack $ show ex))
      Right (Left ex) -> throwError (AsyncException (T.pack $ show ex))
      Right _r -> k
```

Finally, we combine `iterM` and `algebra` to obtain

```haskell
interpret :: ByteCode a -> Interpreter a
interpret = iterM algebra
```

which allow us to _interpret_ our embedded language in our host language. The result of `interpret` can be composed with other effectful programs and it can also be evaluated using `runByteCode`:

```haskell
runByteCode :: ByteCode a -> Either Err a
runByteCode = unsafePerformIO . runExceptT . flip evalStateT emptyCtx . runInterpreter . interpret
```

## All together

So far, we have built the following components:
1. An (embedded) stack-based language in Haskell with primitives like: `lit`, `load`, `write`, `loop` ...
2. An interpreter for that language: `interpret` and `runByteCode`.

Now that we have all the ingredients to create embedded stack-based programs and interpret them, we can put this into practise. 

```haskell
program :: ByteCode Value
program = do
  chan1 <- newChan
  chan2 <- newChan
  _ <- fork $ do
    loopN 100000
    litI 1
    send chan1
  _ <- fork $ do
    loopN 100000
    litI 1
    send chan2
  loopN 10
  recv chan1
  recv chan2
  add
  ret

main :: IO ()
main = case runByteCode program of
  Left err -> throw err
  Right res -> putStrLn $ "Result = " <> show res
```

The following `program` creates two asynchronous tasks that after a period of time, return the integer `1` through an asynchronous channel. The main program waits for these two asynchronous tasks to finish and outputs the sum of the results of the asynchronous tasks.

# Conclusion

In this post, we have introduced free monads and how they can be used to implement embedded domain specific languages. In particular, we have seen how to embed a stack-based language in Haskell. To see other examples of domain specific languages, we refer the reader to the [examples of the free package](https://github.com/ekmett/free/tree/master/examples).

This post only covered a half of the [free](https://hackage.haskell.org/package/free) package. In the next post of this series, we'll explore the other half: church encoding, applicative free, cofree...

[^1]: The term "free" in the context of CT refers to the fact that we have not added structure to the original object. Don't confuse the term with the adjective free: "costing nothing".

[^2]: Pun intended.

[^3]: Technically you are defining an embedded domain specific language (eDSL).

[^4]: The actual signatures use [MonadFree](https://hackage.haskell.org/package/free-5.1.7/docs/Control-Monad-Free.html#t:MonadFree) which is an mtl-style class that allow us to compose [FreeT](https://hackage.haskell.org/package/free-5.1.7/docs/Control-Monad-Trans-Free.html#t:FreeT) with other monad transformers. We were able to monomorphize the return value `MonadFree f m => m ~ Free ByteCodeF` thanks to the instance `Functor f => MonadFree f (Free f)`.
