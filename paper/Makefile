IMAGE = pandoc/extra:latest-ubuntu
FONT_DIR ?= /usr/share/fonts/opentype/noto

SOURCE_EN = ruby-htslib.md
SOURCE_JA = ruby-htslib.ja.md
BIBLIOGRAPHY = ruby-htslib.bib
TARGET_EN = ruby-htslib.pdf
TARGET_JA = ruby-htslib-ja.pdf

PANDOC_ARGS = \
	--standalone \
	--citeproc \
	--template=eisvogel \
	--metadata=link-citations:true \
	--variable=linkcolor:blue \
	--variable=colorlinks:true

.PHONY: all check-fonts clean

all: $(TARGET_EN) $(TARGET_JA)

check-fonts:
	@test -d "$(FONT_DIR)" || \
		(echo "Noto CJK fonts not found at $(FONT_DIR)" >&2; exit 1)

$(TARGET_EN): $(SOURCE_EN) $(BIBLIOGRAPHY)
	docker run --rm \
		--volume "$(CURDIR):/data" \
		--user "$$(id -u):$$(id -g)" \
		$(IMAGE) $(SOURCE_EN) $(PANDOC_ARGS) \
		--pdf-engine=lualatex \
		--output=$(TARGET_EN)

$(TARGET_JA): $(SOURCE_JA) $(BIBLIOGRAPHY) | check-fonts
	docker run --rm \
		--volume "$(CURDIR):/data" \
		--volume "$(FONT_DIR):/usr/share/fonts/opentype/noto:ro" \
		--user "$$(id -u):$$(id -g)" \
		$(IMAGE) $(SOURCE_JA) $(PANDOC_ARGS) --pdf-engine=xelatex \
		--variable="CJKmainfont=Noto Sans CJK JP" \
		--output=$(TARGET_JA)

clean:
	rm -f $(TARGET_EN) $(TARGET_JA)
