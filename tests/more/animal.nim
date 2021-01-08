import iface

iface *Animal:
  proc say(): string
  proc test2()
  proc getFriend(): Animal

iface *GenericAnimal[T]:
  ## comment
  proc getElem(): T
