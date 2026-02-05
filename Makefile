.PHONY: readme readme-check help

README_RENDER=.github/scripts/render-readme.sh

readme:
	@echo "🔧 Rendering README..."
	@OWNER_OVERRIDE=natekspencer \
	HEADER=homeassistant \
	FOOTERS=support,star-history \
	$(README_RENDER)

readme-check:
	@echo "🔍 Checking README..."
	@OWNER_OVERRIDE=natekspencer \
	HEADER=homeassistant \
	CHECK=true \
	$(README_RENDER)

help:
	@echo "make readme       Render README locally"
	@echo "make readme-check Verify README matches generated output"
