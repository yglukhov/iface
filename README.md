# iface - Dynamic dispatch on steroids [![Build Status](https://github.com/yglukhov/iface/workflows/CI/badge.svg?branch=main)](https://github.com/yglukhov/iface/actions?query=branch%3Amain)


Nim `method`s no longer needed :).

- Go-like interfaces, implemented through fat pointers with vTbl. Allows implementing any interface for any (ref) type anywhere in the code.
- Works with default GC and `--gc:orc`.
- Works with all nim backends
- ~~Works in VM (compile time or nimscript)~~ Currently blocked by [nim#16613](https://github.com/nim-lang/Nim/issues/16613) and [nim#18613](https://github.com/nim-lang/Nim/pull/18613)
- Works across DLL boundaries
- Provides compile time reflection API, which can be used for e.g. auto-generating proxy RPC callers/servers and such
- Allows generic interfaces. [Example](tests/test2_generics.nim).

### Usage:
```nim
import iface

iface Animal: # Define the interface
  proc say(): string

type
  Dog = ref object of RootRef # The Dog doesn't explicitly inherit Animal

proc say(d: Dog): string = "bark" # But it implements Animal interface by defining its procs
proc doSmth(a: Animal): string = a.say() # Here we're working with an animal
assert(doSmth(Dog()) == "bark") # Since Dog implements Animal it can be converted implcitly
```

### Caveats:
- Converting to generic interfaces must be explicit, unlike example above. Above example should be rewritten as `Dog().to(MyGenericAnimal[int])`
