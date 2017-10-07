#!/usr/bin/env nix-shell
# encoding: utf-8
#! nix-shell -i python -p graphviz pythonPackages.attrs pythonPackages.click pythonPackages.jsonschema

from ast import literal_eval
from cmd import Cmd
from collections import defaultdict
import json
from pprint import pformat
import subprocess

import attr

import jsonschema

import click

# from nacl import secret, utils
# 
# def freshKey():
#     return utils.random(secret.SecretBox.KEY_SIZE)
# 
# # freshKey().encode("hex")
# 
# def sealCap(cap, key):
#     return secret.SecretBox(key).encrypt(cap)
# 
# def unsealCap(ciphertext, key):
#     return secret.SecretBox(key).decrypt(ciphertext)

# JS-flavored, for JSON Schema
capRegex = "URI:CHK:[a-z0-9]{26}:[a-z0-9]{52}(:\d+){3}"

def arrayOf(s):
    return {
        "type": "array",
        "items": s,
    }

def setOf(s):
    return {
        "type": "array",
        "items": s,
        "uniqueItems": True,
    }

def objOf(**kwargs):
    return {
        "type": "object",
        "properties": kwargs,
    }

def mapOf(s):
    return {
        "type": "object",
        "additionalProperties": s,
    }

string = { "type": "string" }
integer = { "type": "integer" }
# Categories as graphs.
mapOfStr = mapOf(string)
graph = objOf(vertices=mapOf(setOf(string)), edges=mapOf(mapOfStr),
              source=mapOfStr, target=mapOfStr)
path = objOf(source=string, target=string, edges=setOf(arrayOf(string)))
category = objOf(graph=graph, paths=setOf(path))

def askFor(template, note):
    body = "# I need: " + note + "\n" + pformat(template)
    while True:
        try:
            return literal_eval(click.edit(body, extension=".py"))
        except (IndentationError, SyntaxError) as e:
            click.echo("Syntax error: %s" % e)

def validateEdgeOnto(self, attribute, value):
    for edge in self.edges:
        while edge not in value:
            value = askFor(value, "Edge %s missing from %s" % (edge, attribute))
    setattr(self, attribute.name, value)

def validateArrows(self, attribute, value):
    with click.progressbar(self.edges, label=u"Validating arrows…") as edges:
        for edge in edges:
            source = set(self.getVertex(self.source[edge]))
            target = set(self.getVertex(self.target[edge]))
            arrow = self.edges[edge]
            while source > set(arrow.keys()) or target < set(arrow.values()):
                arrow = askFor(arrow, "Arrow needs domain %r and range %r" %
                        (source, target))
            self.edges[edge] = arrow

def validatePaths(self, _attr, value):
    with click.progressbar(value, label=u"Validating paths…") as paths:
        for i, path in enumerate(paths):
            source = set(self.getVertex(path["source"]))
            target = set(self.getVertex(path["target"]))
            again = True
            while again:
                again = False
                for edges in path["edges"]:
                    s = source
                    for edge in edges:
                        arrow = self.edges[edge]
                        s = {arrow[x] for x in s}
                    if not s <= target:
                        path = askFor(path, "Path doesn't commute")
                        again = True
            value[i] = path

@attr.s
class Category(object):

    vertices = attr.ib()
    edges = attr.ib(validator=validateArrows)
    source = attr.ib(validator=validateEdgeOnto)
    target = attr.ib(validator=validateEdgeOnto)
    paths = attr.ib(validator=validatePaths)

    @classmethod
    def new(cls, graph=None, paths=None):
        return cls(paths=paths, **graph)

    def freeze(self):
        return {
            "release": 0,
            "compatibility": 0,
            "category": {
                "paths": self.paths[:],
                "graph": {
                    "vertices": self.vertices.copy(),
                    "edges": self.edges.copy(),
                    "source": self.source.copy(),
                    "target": self.target.copy(),
                },
            },
        }

    def homset(self, source, target):
        return {edge for edge in self.edges
                if self.source[edge] == source and self.target[edge] == target}

    def endoset(self, vertex):
        return self.homset(vertex, vertex)

    def edgesFrom(self, vertex):
        return {edge for edge in self.edges if self.source[edge] == vertex}

    def edgesTo(self, vertex):
        return {edge for edge in self.edges if self.target[edge] == vertex}

    def dotSchema(self):
        lines = []
        colors = defaultdict(set)
        for path in self.paths:
            index = hash(path["source"] + path["target"]) % 8 + 1
            for edges in path["edges"]:
                for edge in edges:
                    colors[edge].add("/dark28/%d" % index)
        lines.append("digraph schema {")
        for vertex in self.vertices:
            lines.append('"%s" [shape=box];' % vertex)
        for edge in self.edges:
            attrs = ['edgetooltip=" %s "' % edge.split(":", 1)[0].strip()]
            # attrs = []
            if edge in colors:
                attrs.append('color="%s"' % ':'.join(colors[edge]))
            source = self.source[edge]
            target = self.target[edge]
            lines.append('"%s" -> "%s" [%s];' %
                    (source, target, ' '.join(attrs)))
        lines.append("}")
        return '\n'.join(lines)

    def getVertex(self, vertex):
        while True:
            try:
                return self.vertices[vertex]
            except KeyError:
                self.vertices = askFor(self.vertices, "Vertices including " +
                        vertex)

    def addEdge(self, edge, source, target, arrow):
        if edge in self.edges:
            self.edges[edge].update(arrow)
            if self.source[edge] != source:
                source = askFor([self.source[edge], source],
                    "Source for edge " + edge)
                self.source[edge] = source
            if self.target[edge] != target:
                target = askFor([self.target[edge], target],
                    "Target for edge " + edge)
                self.target[edge] = target
        else:
            self.edges[edge] = arrow
            self.source[edge] = source
            self.target[edge] = target
        attr.validate(self)

schema = objOf(compat=integer, release=integer, category=category)
schema["$schema"] = "http://json-schema.org/draft-04/schema#"

@click.group()
def cli():
    pass

def loadCat(handle):
    "Load a category from a file handle, checking JSON but not facts."
    db = json.load(handle)
    jsonschema.validate(db, schema)
    return Category.new(**db["category"])

class Shell(Cmd):

    prompt = u'ꗈ '.encode("utf-8")

    def __init__(self, cat):
        Cmd.__init__(self)
        self.cat = cat

    def emptyline(self):
        pass

    def postcmd(self, _stop, line):
        return line == "EOF"

    def do_EOF(self, _line):
        pass

@cli.command()
@click.argument("newdbfile", type=click.File("wb"))
def new(newdbfile):
    d = {
        "release": 0,
        "compatibility": 0,
        "category": {
            "paths": [],
            "graph": {
                "vertices": {},
                "edges": {},
                "source": {},
                "target": {},
            },
        },
    }
    json.dump(d, newdbfile)

@cli.command()
@click.argument("dbfile", type=click.File("rb"))
def shell(dbfile):
    cat = loadCat(dbfile)
    shell = Shell(cat)
    shell.cmdloop(u"Entering shell…".encode("utf-8"))

@cli.command()
@click.argument("dbfile", type=click.File("rb"))
@click.argument("svgfile", type=click.File("wb"))
def dot(dbfile, svgfile):
    cat = loadCat(dbfile)
    dot = cat.dotSchema().encode("utf-8")
    ps = subprocess.Popen(["dot", "-Tsvg"], stdin=subprocess.PIPE,
                          stdout=svgfile)
    ps.communicate(dot)

if __name__ == "__main__":
    cli()
