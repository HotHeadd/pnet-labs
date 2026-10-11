# make            — собрать все отчёты (каждый */main.typ → */main.pdf)
# make lab1       — собрать один
# make watch-lab1 — пересобирать при сохранении
LABS := $(patsubst %/main.typ,%,$(filter-out mephi-labs/%,$(wildcard */main.typ */*/main.typ)))

all: $(LABS)

$(LABS):
	typst compile $@/main.typ

watch-%:
	typst watch $*/main.typ

.PHONY: all $(LABS)
