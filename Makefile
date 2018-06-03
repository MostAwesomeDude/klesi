default: *.poset.png

%.png: %.dot
	dot -Tpng <$< >$@

%.poset.dot: %.poset
	python poset.py $<

%.poset.json: %.poset
	python poset.py $<
