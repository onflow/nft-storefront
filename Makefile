.PHONY: test
test:
	$(MAKE) test -C lib/go

.PHONY: ci
ci:
	$(MAKE) ci -C lib/go
