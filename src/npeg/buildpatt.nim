
import tables
import macros

import common
import codegen
import patt


type

  Grammar* = TableRef[string, Patt]


# Recursively compile a PEG rule to a Pattern

proc buildPatt*(nn: NimNode, symTab: Grammar = nil): Patt =

  proc aux(n: NimNode): Patt =

    template krak(n: NimNode, msg: string) =
      error "NPeg: " & msg & ": " & n.repr & "\n" & n.astGenRepr, n

    case n.kind:

      of nnKPar, nnkStmtList:
        if n.len == 1: return aux n[0]
        elif n.len == 2:
          result = newCapPatt(aux n[0], ckAction)
          result[result.high].capAction = n[1]
          echo result.repr
        else: krak n, "Too many expressions in parenthesis"
      of nnkIntLit: return newIntLitPatt(n.intVal)
      of nnkStrLit: return newStrLitPatt(n.strval)
      of nnkCharLit: return newStrLitPatt($n.intVal.char)
      of nnkCall:
        if n.len == 2:
          let p = aux n[1]
          if n[0].eqIdent "Js":   return newCapPatt(p, ckJString)
          elif n[0].eqIdent "Ji": return newCapPatt(p, ckJInt)
          elif n[0].eqIdent "Jf": return newCapPatt(p, ckJFloat)
          elif n[0].eqIdent "Ja": return newCapPatt(p, ckJArray)
          elif n[0].eqIdent "Jo": return newCapPatt(p, ckJObject)
          elif n[0].eqIdent "Jt": return newCapPatt(p, ckJFieldDynamic)
          else: krak n, "Unhandled capture type"
        elif n.len == 3:
          if n[0].eqIdent "Jf":
            result = newCapPatt(aux n[2], ckJFieldFixed)
            result[0].capName = n[1].strVal
          else: krak n, "Unhandled capture type"
      of nnkPrefix:
        let p = aux n[1]
        if n[0].eqIdent("?"): return ?p
        elif n[0].eqIdent("+"): return +p
        elif n[0].eqIdent("*"): return *p
        elif n[0].eqIdent("!"): return !p
        elif n[0].eqIdent(">"): return >p
        else: krak n, "Unhandled prefix operator"
      of nnkInfix:
        if n[0].eqIdent("%"):
          result = newCapPatt(aux n[1], ckAction)
          result[result.high].capAction = n[2]
        else:
          let (p1, p2) = (aux n[1], aux n[2])
          if n[0].eqIdent("*"): return p1 * p2
          elif n[0].eqIdent("-"): return p1 - p2
          elif n[0].eqIdent("|"): return p1 | p2
          else: krak n, "Unhandled infix operator"
      of nnkCurlyExpr:
        let p = aux(n[0])
        if n[1].kind == nnkIntLit:
          return p{n[1].intVal}
        elif n[1].kind == nnkInfix and n[1][0].eqIdent(".."):
          return p{n[1][1].intVal..n[1][2].intVal}
        else: krak n, "syntax error"
      of nnkIdent:
        let name = n.strVal
        if name in symTab:
          return symTab[name]
        else:
          return newCallPatt(name)
      of nnkCurly:
        var cs: CharSet
        for nc in n:
          if nc.kind == nnkCharLit:
            cs.incl nc.intVal.char
          elif nc.kind == nnkInfix:
            if nc[0].kind == nnkIdent and nc[0].eqIdent(".."):
              for c in nc[1].intVal..nc[2].intVal:
                cs.incl c.char
            else:
              krak n, "syntax error"
          else:
            krak n, "syntax error"
        if cs.card == 0:
          return newIntLitPatt(1)
        else:
          return newSetPatt(cs)
      of nnkCallStrLit:
        if n[0].eqIdent("i"): return newStrLitPatt(n.strval)
        else: krak n, "unhandled string prefix"
      else:
        krak n, "syntax error"

  result = aux(nn)



