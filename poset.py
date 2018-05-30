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

def isIso(u, v):
    return v in graph[u] and u in graph[v]

isos = {}
for u, v in combinations(verts(), 2):
    if isIso(u, v):
        if u in isos:
            s = isos[u]
            if v in isos:
                s |= isos[v]
            isos[v] = s
        else:
            isos[u] = isos[v] = set([u, v])

def incoming(v):
    return [u for u in graph if v in graph[u]]

def outgoing(v):
    return graph[v]

def delete(v):
    del graph[v]
    for s in graph.itervalues():
        s.discard(v)

seen = set()
for iso in isos.itervalues():
    fs = frozenset(iso)
    if fs in seen:
        continue
    seen.add(fs)
    new = " = ".join(fs)
    ins = set()
    outs = set()
    for v in iso:
        ins.update(incoming(v))
        outs.update(outgoing(v))
        delete(v)
    ins.difference_update(fs)
    outs.difference_update(fs)
    for i in ins:
        graph[i].add(new)
    graph[new] = outs

print "digraph {"
for k, v in graph.iteritems():
    for vert in v:
        print '"%s" -> "%s";' % (k, vert)
print "}"
