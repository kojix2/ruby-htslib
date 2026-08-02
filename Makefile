IMAGE = pandoc/latex:3.10.0

SOURCE = ruby-htslib.md
BIBLIOGRAPHY = ruby-htslib.bib
TARGET = ruby-htslib.pdf

PANDOC_ARGS = \
	$(SOURCE) \
	--standalone \
	--citeproc \
	--pdf-engine=lualatex \
	--metadata=link-citations:true \
	--variable=linkcolor:blue \
	--output=$(TARGET)

.PHONY: all clean

all: $(TARGET)

$(TARGET): $(SOURCE) $(BIBLIOGRAPHY)
	docker run --rm \
		--volume "$(CURDIR):/data" \
		--user "$$(id -u):$$(id -g)" \
		$(IMAGE) $(PANDOC_ARGS)

clean:
	rm -f $(TARGET)
