# coding: utf-8

from collections import defaultdict
from itertools import combinations
import json, sys

class Poset(object):
    def __init__(self):
        self.graph = defaultdict(set)

    @classmethod
    def fromText(cls, text):
        self = cls()
        for line in text.split("\n"):
            if line.startswith("#"):
                continue
            chain = [w.strip() for w in line.split("≤")]
            self.addChain(chain)
        return self

    @classmethod
    def fromJSON(cls, text):
        labels, packed = json.loads(text)
        self = cls()
        for i, (u, v) in enumerate(combinations(labels, 2)):
            if packed & (1 << i):
                self.graph[u].add(v)
        return self

    def addChain(self, chain):
        for u, v in zip(chain, chain[1:]):
            self.graph[u].add(v)

    def verts(self):
        rv = set(self.graph.keys())
        for v in self.graph.itervalues():
            rv |= v
        return rv

    def iteredges(self):
        for u in self.graph.keys():
            for v in self.graph[u]:
                yield u, v

    def tarjan(self):
        # This delightful gem:
        # https://en.wikipedia.org/wiki/Tarjan's_strongly_connected_components_algorithm
        stack = []
        indices = {}
        links = {}

        rv = []

        def go(v, index=[0]):
            indices[v] = links[v] = index[0]
            index[0] += 1
            stack.append(v)

            for u in self.graph.get(v, []):
                if u not in indices:
                    go(u)
                    links[v] = min(links[v], links[u])
                elif u in stack:
                    links[v] = min(links[v], indices[u])

            if links[v] == indices[v]:
                s = set()
                while True:
                    u = stack.pop()
                    s.add(u)
                    if u == v:
                        break
                rv.append(s)

        for v in self.verts():
            go(v)

        return rv

    def incoming(self, v):
        return set([u for u in self.graph if v in self.graph[u]])

    def outgoing(self, v):
        return self.graph[v]

    def delete(self, v):
        del self.graph[v]
        for s in self.graph.itervalues():
            s.discard(v)

    def isReachable(self, u, v, cache={}):
        k = self, u, v
        if k not in cache:
            cache[k] = False
            for vert in self.graph[u]:
                if v == vert or self.isReachable(vert, v):
                    cache[k] = True
                    break
        return cache[k]

    def closure(self, verts):
        closure = Poset()
        for u, v in combinations(verts, 2):
            if self.isReachable(u, v):
                closure.graph[u].add(v)
        return closure

    def reduce(self, verts):
        reduced = Poset()
        for u in verts:
            vs = self.graph[u].copy()
            for v1, v2 in combinations(vs, 2):
                if v2 in self.graph[v1]:
                    # u -> v1 -> v2, so discard u -> v2
                    vs.discard(v2)
                elif v1 in self.graph[v2]:
                    # u -> v2 -> v1, so discard u -> v1
                    vs.discard(v1)
            reduced.graph[u] = vs
        return reduced

    def toJSON(self, verts):
        acc = 0
        for i, (u, v) in enumerate(combinations(verts, 2)):
            if v in self.graph[u]:
                acc |= 1 << i
        return json.dumps([list(verts), acc])

    def toDOT(self, attr=None):
        pieces = []
        for k in sorted(self.graph.keys()):
            for v in sorted(self.graph[k]):
                if attr is None:
                    edge = '"%s" -> "%s";' % (k, v)
                else:
                    edge = '"%s" -> "%s" [%s];' % (k, v, attr)
                pieces.append(edge)
        return "\n".join(pieces)

def getPoset(filename):
    with open(filename, "rb") as handle:
        return Poset.fromText(handle.read())

def compile(rest):
    filename, = rest
    p = getPoset(filename)

    seen = set()
    components = p.tarjan()
    # Loop over SCCs. Tarjan's also returns everything in topo-sorted order, which
    # we'll need to reuse in order to do our transitive-reduction op later.
    for comp in components:
        if len(comp) < 2:
            continue
        fs = frozenset(comp)
        if fs in seen:
            continue
        seen.add(fs)
        new = " = ".join(sorted(fs))
        ins = set()
        outs = set()
        for v in fs:
            ins.update(p.incoming(v))
            outs.update(p.outgoing(v))
            p.delete(v)
        ins.difference_update(fs)
        outs.difference_update(fs)
        for i in ins:
            p.graph[i].add(new)
        p.graph[new] = outs

    topo = [" = ".join(sorted(c)) if len(c) > 1 else list(c)[0] for c in components]
    topo.reverse()

    # Build the transitive closure first.
    closure = p.closure(topo)

    # Now, build the transitive reduction.
    reduced = closure.reduce(topo)

    # Build a cheap succinct representation.
    with open(filename + ".json", "wb") as handle:
        handle.write(reduced.toJSON(topo))

    with open(filename + ".dot", "wb") as handle:
        handle.write("digraph {")
        handle.write(reduced.toDOT())
        handle.write("}")

def getFunctor(filename):
    d = {}
    with open(filename, "rb") as handle:
        text = handle.read()
        for line in text.split("\n"):
            if line.startswith("#") or not line:
                continue
            try:
                src, dest = line.split("→", 1)
            except ValueError:
                print "Bad line", line
                raise
            d[src.strip()] = dest.strip()
    return d

def doFunctor(rest):
    filename, = rest
    f = getFunctor(filename)
    src, dst, _ = filename.split(".", 2)
    a = getPoset(src + ".poset")
    b = getPoset(dst + ".poset")
    for u, v in a.iteredges():
        if not b.isReachable(f[u], f[v]):
            print u, "≤", v, "but not", f[u], "≤", f[v]
            raise ValueError((u, v))

    ga = a.toDOT("color=red")
    gb = b.toDOT("color=blue")

    with open(filename + ".dot", "wb") as handle:
        handle.write("digraph {")
        for k, v in f.iteritems():
            edge = '"%s" -> "%s" [style=dashed];\n' % (k, v)
            handle.write(edge)
        handle.write("subgraph {")
        handle.write(ga)
        handle.write("}\n")
        handle.write("subgraph {")
        handle.write(gb)
        handle.write("}\n")
        handle.write("}\n")

    with open(filename + ".json", "wb") as handle:
        handle.write(json.dumps(f))

if __name__ == "__main__":
    action = sys.argv[1]
    rest = sys.argv[2:]
    if action == "compile":
        print "Compiling poset", rest
        compile(rest)
    elif action == "functor":
        print "Compiling functor", rest
        doFunctor(rest)
    else:
        print "Don't know how to", action
        assert False
