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

# Reduce to the transitive reduction.
for u in verts():
    us = graph[u]
    vs = outgoing(u)
    for v1, v2 in combinations(vs, 2):
        if v2 in graph[v1]:
            # u -> v1 and u -> v1 -> v2, so discard u -> v2
            us.discard(v2)

print "digraph {"
for k, v in graph.iteritems():
    for vert in v:
        print '"%s" -> "%s";' % (k, vert)
print "}"
