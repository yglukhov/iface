import macros, tables

type
  Interface*[VTable] = object
    private_vTable*: ptr VTable
    private_obj*: RootRef

  CTWrapper[T] = ref object of RootRef
    v: T

proc createVTable(VTable: typedesc, T: typedesc): VTable =
  mixin initVTable
  initVTable(result, T)

proc getVTable(VTable: typedesc, T: typedesc): ptr VTable {.inline.} =
  var tab {.global.} = createVTable(VTable, T)
  addr tab

template unpackObj[T](f: RootRef, res: var T) =
  when T is RootRef:
    res = T(f)
  else:
    res = CTWrapper[T](f).v

proc packObj[T](v: T): RootRef {.inline.} =
  when T is RootRef:
    result = RootRef(v)
  else:
    result = CTWrapper[T](v: v)

macro checkRequiredMethod(call: typed, typ: typed): untyped =
  let impl = getImpl(call[0])
  if impl.kind == nnkProcDef and impl.params.len > 1 and impl.params[1][^2] == typ:
    error "Object does not implement required interface method: " & repr(call)
  result = call

template forceReturnValue(retType: typed, someCall: typed): untyped =
  when retType is void:
    someCall
  else:
    return someCall

type
  InterfaceReflection = object
    body: NimNode
    constr: NimNode
    genericParams: NimNode
    parent: NimNode

var interfaceReflection {.compileTime.} = initTable[string, InterfaceReflection]()

proc getInterfaceKey(sym: NimNode): string =
  let t = getTypeImpl(sym)
  expectKind(t, nnkBracketExpr)
  assert(t.len == 2)
  assert t[0].eqIdent("typedesc")
  signatureHash(t[1])

macro registerInterfaceDecl(sym: typed, body, constr: untyped) =
  interfaceReflection[getInterfaceKey(sym)] = InterfaceReflection(body: body, constr: constr)

proc to*[T: ref](a: T, I: typedesc[Interface]): I {.inline.} =
  when T is I:
    a
  else:
    I(private_vTable: getVTable(I.VTable, T), private_obj: packObj(a))

proc to*[T: ref](i: Interface, t: typedesc[T]): t {.inline.} =
  ## Extracts concrete type `t` from interface `i`, or `nil` if `i` is not of `t`
  when t is RootRef:
    if i.private_obj of t:
      t(i.private_obj)
    else:
      nil
  else:
    if i.private_obj of CTWrapper[t]:
      CTWrapper[t](i.private_obj).v
    else:
      nil

proc parseArgs(arg1, arg2, moreArgs: NimNode): tuple[name: string, genericParams: NimNode, isPublic: bool, parents, body: NimNode] =
  var def = arg1
  result.genericParams = newEmptyNode()
  result.parents = newEmptyNode()

  if def.kind == nnkInfix:
    if def.len == 3 and $def[0] == "of":
      result.parents = newTree(nnkStmtList, def[2])
      def = def[1]
    else:
      assert(false, "Unexpected node")

  if def.kind == nnkPrefix:
    if def.len == 2 and $def[0] == "*":
      result.isPublic = true
      def = def[1]
    else:
      assert(false, "Unexpected node")

  if def.kind == nnkBracketExpr:
    result.genericParams = newNimNode(nnkGenericParams)
    for i in 1 ..< def.len:
      result.genericParams.add(newIdentDefs(def[i], newEmptyNode()))

    def = def[0]

  result.name = $def

  if moreArgs.len == 0:
    result.body = arg2
  else:
    result.body = moreArgs[^1]
    doAssert(result.parents.len == 1, "Unexpected parents")
    result.parents.add(arg2)
    for i in 0 ..< moreArgs.len - 1:
      result.parents.add(moreArgs[i])

proc genericParamsToBracket(subj, params: NimNode): NimNode =
  params.expectKind({nnkEmpty, nnkGenericParams})
  if params.kind == nnkEmpty:
    result = subj
  else:
    result = newTree(nnkBracketExpr, subj)
    for p in params:
      p.expectKind(nnkIdentDefs)
      result.add(p[0])

proc makePublic(name: NimNode, isPublic: bool): NimNode =
  if isPublic:
    newTree(nnkPostfix, ident"*", name)
  else:
    name

proc ifaceImpl*(name: string, genericParams: NimNode, isPublic: bool, parents, body: NimNode, addConverter: bool): NimNode =
  result = newNimNode(nnkStmtList)

  if parents.len != 0:
    error "Interface inheritance is not implemented yet", parents[0]

  let
    iName = ident(name)
    iNameWithGenericParams = genericParamsToBracket(iName, genericParams)
    converterName = makePublic(ident("to" & name), isPublic)
    vTableTypeName = ident("InterfaceVTable" & name)
    vTableTypeWithGenericParams = genericParamsToBracket(vTableTypeName, genericParams)
    tIdent = ident"t"
    vTableConstr = newTree(nnkStmtList)
    genericT = ident("TIfaceUnpackedThis#")
    functions = newNimNode(nnkStmtList)
    mixins = newNimNode(nnkStmtList)
    upackedThis = ident"ifaceUnpackedThis#"
    ifaceDecl = newNimNode(nnkStmtList)
    vTableType = newNimNode(nnkRecList)

  for i, p in body:
    if p.kind in {nnkCommentStmt}: continue
    p.expectKind(nnkProcDef)
    ifaceDecl.add(copyNimTree(p))
    mixins.add(newTree(nnkMixinStmt, p.name))
    let pt = newTree(nnkProcTy, copyNimTree(p.params), newEmptyNode())
    pt.addPragma(ident"nimcall")
    var retType = pt[0][0]
    if retType.kind == nnkEmpty: retType = ident"void"
    pt[0].insert(1, newIdentDefs(ident"this", ident"RootRef"))
    let fieldName = ident("<" & $i & ">" & $p.name)
    vTableType.add(newIdentDefs(makePublic(fieldName, isPublic), pt))

    let lambdaCall = newCall(p.name)
    lambdaCall.add(upackedThis)

    let vCall = newTree(nnkCall, newTree(nnkDotExpr, newTree(nnkDotExpr, ident"this", ident"private_vTable"), fieldName))
    vCall.add(newTree(nnkDotExpr, ident"this", ident"private_obj"))

    for a in 1 ..< p.params.len:
      let par = p.params[a]
      for b in 0 .. par.len - 3:
        lambdaCall.add(par[b])
        vCall.add(par[b])

    let lambdaBody = quote do:
      var `upackedThis`: `genericT`
      unpackObj(this, `upackedThis`)
      forceReturnValue(`retType`, checkRequiredMethod(`lambdaCall`, `iName`))

    let lam = newTree(nnkLambda, newEmptyNode(), newEmptyNode(), newEmptyNode(), pt[0], newEmptyNode(), newEmptyNode(), lambdaBody)
    # lam.addPragma(newTree(nnkExprColonExpr, ident"stackTrace", ident"off"))

    vTableConstr.add newAssignment(newDotExpr(tIdent, fieldName), lam)

    p.name = makePublic(p.name, isPublic)

    if p[2].kind != nnkEmpty:
      error("interface proc can not be generic (but interface can)", p[2])
    p[2] = genericParams

    p.params.insert(1, newIdentDefs(ident"this", iNameWithGenericParams))

    p.body = vCall
    p.addPragma(ident"inline")
    p.addPragma(newTree(nnkExprColonExpr, ident"stackTrace", ident"off"))

    functions.add(p)

  let typeSection = newTree(nnkTypeSection)

  # Add interface type definition
  typeSection.add newTree(nnkTypeDef, makePublic(iName, isPublic), genericParams, newTree(nnkBracketExpr, ident"Interface", vTableTypeWithGenericParams))

  # Add vTable type definition
  typeSection.add newTree(nnkTypeDef, vTableTypeName, genericParams, newTree(nnkObjectTy, newEmptyNode(), newEmptyNode(), vTableType))

  let initVTableProc = newProc(makePublic(ident"initVTable", isPublic), params = [newEmptyNode(), newIdentDefs(tIdent, newTree(nnkVarTy, vTableTypeWithGenericParams)), newIdentDefs(genericT, ident"typedesc")])
  initVTableProc[2] = genericParams
  initVTableProc.body = quote do:
    `mixins`
    `vTableConstr`

  result.add quote do:
    `typeSection`
    `initVTableProc`
    `functions`

  if addConverter and genericParams.kind == nnkEmpty:
    result.add quote do:
      converter `converterName`[T: ref](a: T): `iName` {.inline.} =
        to(a, `iName`)

  result.add quote do:
    registerInterfaceDecl(`iName`, `ifaceDecl`, `vTableConstr`)

macro iface*(arg1, arg2: untyped, moreArgs: varargs[untyped] = []): untyped =
  let (name, genericParams, isPublic, parents, body) = parseArgs(arg1, arg2, moreArgs)
  result = ifaceImpl(name, genericParams, isPublic, parents, body, true)
  # echo repr result

proc getInterfaceDecl*(interfaceTypedescSym: NimNode): NimNode =
  interfaceReflection[getInterfaceKey(interfaceTypedescSym)].body

macro localIfaceConvert*(ifaceType: typedesc[Interface], o: typed): untyped =
  let constr = interfaceReflection[getInterfaceKey(ifaceType)].constr
  let genericT = ident"TIfaceUnpackedThis#"
  result = quote do:
    type `genericT` = type(`o`)
    var t {.global, inject.}: `ifaceType`.VTable
    var inited {.global.} = false
    if not inited:
      `constr`
      inited = true
    `ifaceType`(private_vTable: unsafeAddr t, privateObj: packObj(`o`))
  # echo repr result

macro ifaceFindMethodAux(ifaceType: typedesc[Interface], methodName: string): int =
  let decl = getInterfaceDecl(ifaceType)
  result = newTree(nnkCaseStmt, methodName)
  for i, p in decl:
    result.add newTree(nnkOfBranch, newLit($p.name), newLit(i))
  result.add newTree(nnkElse, newLit(-1))

proc ifaceFindMethod*(ifaceType: typedesc[Interface], methodName: string): int =
  # Returns index of method with name in the interface, or -1 if not found
  ifaceFindMethodAux(ifaceType, methodName)

macro privateTestParseArgs*(arg1, arg2: untyped, moreArgs: varargs[untyped] = []): untyped =
  let (name, genericParams, isPublic, parents, body) = parseArgs(arg1, arg2, moreArgs)
  let sName = $name
  let sGenericParams = repr genericParams
  let sParents = repr parents
  let sBody = repr body
  result = quote do:
    let name {.inject.} = `sName`
    let genericParams {.inject.} = `sGenericParams`
    let isPublic {.inject.} = bool(`isPublic`)
    let parents {.inject.} = `sParents`
    let body {.inject.} = `sBody`
