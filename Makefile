default: jicmu.svg

%-cat.json: %-base.json
	<$< jq -f tax.jq >$@

%.svg: %-cat.json
	<$< jq -r 'include "cat"; dot' | dot -Tsvg >$@
