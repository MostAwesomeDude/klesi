default: danlu.animalia.monotone.png

poset.py: poset.py.md
	./lit.sh

%.png: %.dot
	dot -Tpng <$< >$@

%.poset.dot: %.poset poset.py
	python poset.py compile $<

%.poset.json: %.poset poset.py
	python poset.py compile $<

%.monotone.dot: %.monotone poset.py
	python poset.py functor $<

%.monotone.json: %.monotone poset.py
	python poset.py functor $<
