# coding: utf-8

from collections import defaultdict
from itertools import combinations
import sys

graph = defaultdict(set)

def addChain(chain):
    for u, v in zip(chain, chain[1:]):
        graph[u].add(v)

def verts():
    rv = set(graph.keys())
    for v in graph.itervalues():
        rv |= v
    return rv

for line in sys.stdin:
    if line.startswith("#"):
        continue
    chain = [w.strip() for w in line.split("≤")]
    addChain(chain)

def tarjan():
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

        for u in graph.get(v, []):
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

    for v in verts():
        go(v)

    return rv

def incoming(v):
    return set([u for u in graph if v in graph[u]])

def outgoing(v):
    return graph[v]

def delete(v):
    del graph[v]
    for s in graph.itervalues():
        s.discard(v)

seen = set()
components = tarjan()
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
        ins.update(incoming(v))
        outs.update(outgoing(v))
        delete(v)
    ins.difference_update(fs)
    outs.difference_update(fs)
    for i in ins:
        graph[i].add(new)
    graph[new] = outs

topo = [" = ".join(sorted(c)) if len(c) > 1 else list(c)[0] for c in components]
topo.reverse()

def isReachable(u, v, cache={}):
    if (u, v) not in cache:
        cache[u, v] = False
        for vert in graph[u]:
            if v == vert or isReachable(vert, v):
                cache[u, v] = True
                break
    return cache[u, v]

# Build the transitive closure first.
closure = defaultdict(set)
for u, v in combinations(topo, 2):
    if isReachable(u, v):
        closure[u].add(v)

# Now, build the transitive reduction.
reduced = defaultdict(set)
for u in topo:
    vs = closure[u].copy()
    for v1, v2 in combinations(vs, 2):
        if v2 in closure[v1]:
            # u -> v1 -> v2, so discard u -> v2
            vs.discard(v2)
        elif v1 in closure[v2]:
            # u -> v2 -> v1, so discard u -> v1
            vs.discard(v1)
    reduced[u] = vs

print "digraph {"
for k, v in reduced.iteritems():
    for vert in v:
        print '"%s" -> "%s";' % (k, vert)
print "}"
