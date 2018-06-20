Hi! Let's tell Python how we're encoded.

```
# coding: utf-8
```

We need some tools, and it's polite to put them at the front.

```
from collections import defaultdict
from itertools import combinations
import json, sys
```

We're going to do some basic category theory. To start, we'll develop a notion
of a **partially-ordered set**, or **poset**, which is a simple kind of
mathematical structure. A poset has a set of **objects**, which can be labeled
arbitrarily, and a **less-than relation**, which lets us compare objects.
Suppose `X`, `Y`, and `Z` are valid labels, and we'll write the relation as
`≤`. Then:

* For any `X`, `X ≤ X`.
* For any `X` and `Y`, if `X ≤ Y` and `Y ≤ X` then `X = Y`.
* For any `X`, `Y`, and `Z`, if `X ≤ Y ≤ Z` then `X ≤ Z`.

```
class Poset(object):
    def __init__(self):
```

Note that directed acyclic graphs, or DAGs, which are a staple of computer
science (and thus will *not* be explained more!), are isomorphic to posets.
This beautiful fact lets us use graph techniques to represent our poset. We'll
use an **adjacency table**, a simple structure that answers whether, for two
vertices `u` and `v`, `u → v`. This adjacency relation `→` is not the same as
the less-than relation `≤` but they are clearly related; the former implies
the latter.

Note that, in the remainder of the code, `u` and `v` will generally be the
names of vertices. These are traditional names.

```
        self.graph = defaultdict(set)
```

We now present a simple DSL for posets. Recall that a **chain** `u → v → w → …
→ z` in a graph. We can thus add to a graph an entire chain at once.

```
    def addChain(self, chain):
        for u, v in zip(chain, chain[1:]):
            self.graph[u].add(v)
```

We can read in a text file.

```
    @classmethod
    def fromText(cls, text):
        self = cls()
```

Line by line.

```
        for line in text.split("\n"):
```

Lines starting with octothorpes are comments.

```
            if line.startswith("#"):
                continue
```

An example chain might be `"lion ≤ cat"`, if the user think that "cat" is more
general than "lion".

```
            chain = [w.strip() for w in line.split("≤")]
            self.addChain(chain)
        return self
```

We can also read in JSON. The encoding is relatively compact, using the fact
that a DAG's adjacency matrix only uses the upper triangle. I won't go more
into this, as it's not yet relevant.

```
    @classmethod
    def fromJSON(cls, text):
        labels, packed = json.loads(text)
        self = cls()
        for i, (u, v) in enumerate(combinations(labels, 2)):
            if packed & (1 << i):
                self.graph[u].add(v)
        return self
```

We'll often need to work with the set of all vertices of a graph.

```
    def verts(self):
        rv = set(self.graph.keys())
        for v in self.graph.itervalues():
            rv |= v
        return rv
```

We want to apply [Tarjan's "strongly-connected components"
algorithm](https://en.wikipedia.org/wiki/Tarjan's_strongly_connected_components_algorithm)
to the graph. This algorithm does two things:

1. Each cycle in the graph will be converted to a single set of nodes.
1. A linear extension of the resulting graph is built for witnessing DAG-ness.

In DAG literature, linear extensions are often called "topological sorts" or
"topological orders".

```
    def tarjan(self):
```

Our bookkeeping. We have a stack of vertices, two annotations on vertices
called the "index" and "link", and our return value, which will be a list of
sets in topological order.

```
        stack = []
        indices = {}
        links = {}
        rv = []
```

Our main workhorse is a nested function which will visit every vertex.

As usual, I apologize for using the declare-define trick to create "static"
storage for the visitor; Tarjan's requires a counter which increments for
every visitation.

```
        def go(v, counter=[0]):
```

Here we use the counter to set our initial index and link.

```
            indices[v] = links[v] = counter[0]
            counter[0] += 1
```

The stack holds vertices which will be aggregated into components as
connections are found.

```
            stack.append(v)
```

Let's see if there are links which would give us a cycle. Our link number
needs to be compared to all of our reachable links. From our `v`, for each `v
→ u`, if we haven't visited `u`, then do that and see how cyclic we got.
Otherwise, if we *have* and it's in our stack, check their index. This might
be the hardest part of Tarjan's, and it took me a while to grok exactly why
this works; do not fret if it seems confusing for you too.

Also, I can't not read this delightful section as "If you not in indices? Go
you! Elif you in stack..."

```
            for u in self.graph.get(v, []):
                if u not in indices:
                    go(u)
                    links[v] = min(links[v], links[u])
                elif u in stack:
                    links[v] = min(links[v], indices[u])
```

If our link and index are the same, then we've found a cycle. We'll pop the
cycle off of the stack and into our return value.

```
            if links[v] == indices[v]:
                s = set()
                while True:
                    u = stack.pop()
                    s.add(u)
                    if u == v:
                        break
                rv.append(s)
```

Go.

```
        for v in self.verts():
            go(v)
        return rv
```

We will need some utilities now before we can reach the heart of the compiler.
First, a reachability relation. Recall that reachability in DAGs is the same
as less-than in posets, so this is an important building block.

I once again use the declare-define trick to allocate a static cache so that I
can memoize the relation.

```
    def isReachable(self, u, v, cache={}):
```

The cache key is the graph and vertices.

```
        k = self, u, v
        if k not in cache:
```

Assume that we aren't reachable, then look for a contradiction.

```
            cache[k] = False
```

For each vertex reachable from `u`, is it `v` or something reachable from `v`?
If so, then we have found reachability. Otherwise, this step recurses. The
cache *should* keep us from blowing too far down the stack, but I didn't
actually make this iterative.

```
            for vert in self.graph[u]:
                if v == vert or self.isReachable(vert, v):
                    cache[k] = True
                    break
        return cache[k]
```

The **transitive closure** of a DAG/poset has, for each `u` and `v`, an edge
`u → v` iff `u ≤ v`. As such, it is an extremely useful transitional structure
for fully representing the less-than relation. However, the transitive closure
also has the most edges of any representation, making it terrible for anything
other than temporary or intermediate work.

```
    def closure(self, verts):
        closure = Poset()
```

For each pair of vertices, if `u ≤ v` then `u → v`.

```
        for u, v in combinations(verts, 2):
            if self.isReachable(u, v):
                closure.graph[u].add(v)
        return closure
```

And the only reason we'll have for the transitive closure is building the
**transitive reduction**, which only has an edge between `u` and `v` if `u ≤
v` and also there isn't any vertex `w` in-between them so that `u ≤ w ≤ v`.

Informally, the transitive reduction doesn't have any "extra" or "spare"
edges; it has the fewest edges and tends to be the cleanest-looking.

```
    def reduce(self, verts):
        reduced = Poset()
        for u in verts:
```

As before, we assume that an edge will be required, and then search for
reasons to discard it.

```
            vs = self.graph[u].copy()
            for v1, v2 in combinations(vs, 2):
```

`u → v1 → v2`, so discard `u → v2`.

```
                if v2 in self.graph[v1]:
                    vs.discard(v2)
```

`u → v2 → v1`, so discard `u → v1`.

```
                elif v1 in self.graph[v2]:
                    vs.discard(v1)
            reduced.graph[u] = vs
        return reduced
```

Two more helpers. They will let us ask, for some `v`, which vertices `u` are
`u → v`, or `v → u`.

```
    def incoming(self, v):
        return set([u for u in self.graph if v in self.graph[u]])

    def outgoing(self, v):
        return self.graph[v]
```

An iterator over all edges.

```
    def iteredges(self):
        for u in self.graph.keys():
            for v in self.graph[u]:
                yield u, v
```

A helper for deleting vertices in-place.

```
    def delete(self, v):
        del self.graph[v]
        for s in self.graph.itervalues():
            s.discard(v)
```

This is as close as we'll get to a compilation step. We will go from a graph
which possibly has cycles, and hasn't been certified as a DAG, to a graph
which is in one-to-one correspondence with a poset by representing its
transitive reduction. It's important to reduce the number of edges because we
will later want to render the graph with DOT, and rendering a graph, like so
many other graph algorithms, is `O(|V|+|E|)`.

This is going to be an in-place algorithm, because that's how I originally
wrote the code.

```
    def compile(self):
```

We'll only visit each strongly-connected component once.

```
        seen = set()
        components = self.tarjan()
```

Here we'll loop over our strongly-connected components created by Tarjan's
algorithm. It is essential to note that the components are in topological
order. As we climb up the components, we'll replace any components with
multiple labels with a single combined-label vertex.

```
        for comp in components:
```

Skip components that don't need to be replaced.

```
            if len(comp) < 2:
                continue
```

Don't double-visit components.

```
            fs = frozenset(comp)
            if fs in seen:
                continue
            seen.add(fs)
```

Turn cycles like `u → v → u` into single vertices labeled `"u = v"`. It's
a…messy process. We must locate all of the edges adjacent to the component and
perform graph surgery.

```
            new = " = ".join(sorted(fs))
            ins = set()
            outs = set()
            for v in fs:
                ins.update(self.incoming(v))
                outs.update(self.outgoing(v))
                self.delete(v)
            ins.difference_update(fs)
            outs.difference_update(fs)
            for i in ins:
                self.graph[i].add(new)
            self.graph[new] = outs
```

But we can abstractly perform the relabeling directly from the list of
components, so that's nice.

```
        topo = [" = ".join(sorted(c)) if len(c) > 1 else list(c)[0] for c in components]
        topo.reverse()
```

Now we are ready to build the transitive reduction. We must first build the
transitive closure, and then build the reduction from that.

```
        closure = self.closure(topo)
        return closure.reduce(topo)
```

Our encoders. The JSON encoder just inverts our JSON decoding from earlier.

```
    def toJSON(self, verts):
        acc = 0
        for i, (u, v) in enumerate(combinations(verts, 2)):
            if v in self.graph[u]:
                acc |= 1 << i
        return json.dumps([list(verts), acc])
```

The DOT output is a little more interesting, but not by much. We don't emit a
full graph here but only the pieces, so that we can cleanly emit several
graphs into a single DOT file.

```
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
```

At this point, the rest of the file is the imperative goo to actually make
things work, and it's all in quite a bit of flux so it's not really worth
explaining in detail to me yet.

```
def getPoset(filename):
    with open(filename, "rb") as handle:
        return Poset.fromText(handle.read())

def compile(rest):
    filename, = rest
    p = getPoset(filename)
    reduced = p.compile()

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
```
