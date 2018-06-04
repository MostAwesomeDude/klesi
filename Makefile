default: danlu.animalia.monotone.png

%.png: %.dot
	dot -Tpng <$< >$@

%.poset.dot: %.poset
	python poset.py compile $<

%.poset.json: %.poset
	python poset.py compile $<

%.monotone.dot: %.monotone
	python poset.py functor $<

%.monotone.json: %.monotone
	python poset.py functor $<
