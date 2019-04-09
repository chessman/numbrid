
static/elm.js: src/ui.elm
	elm make src/ui.elm --output static/elm.js

deploy: static/elm.js
	git add -u
	git commit
	git push heroku master

.PHONY: deploy
