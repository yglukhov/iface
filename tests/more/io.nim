import iface
import std/options

iface *Reader[T]:
  proc read(buffer: openArray[T]): Option[int]

iface *WriterTo[T]:
  proc write_to(r: Reader[T]): Option[int]

iface *Writer[T]:
  proc write(buffer: openArray[T], num: var int)

iface *ReaderFrom[T]:
  proc read_from(w: Writer[T], num: var int)

iface *Closer[T]:
  proc close()

