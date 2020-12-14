.PHONY: clean compile_translations coverage docs dummy_translations extract_translations \
	fake_translations help pull_translations push_translations quality requirements test test-all upgrade validate

.DEFAULT_GOAL := help

define BROWSER_PYSCRIPT
import os, webbrowser, sys
try:
	from urllib import pathname2url
except:
	from urllib.request import pathname2url

webbrowser.open("file://" + pathname2url(os.path.abspath(sys.argv[1])))
endef
export BROWSER_PYSCRIPT
BROWSER := python -c "$$BROWSER_PYSCRIPT"

help: ## display this help message
	@echo "Please use \`make <target>' where <target> is one of"
	@perl -nle'print $& if m{^[a-zA-Z_-]+:.*?## .*$$}' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m  %-25s\033[0m %s\n", $$1, $$2}'

clean: ## remove generated byte code, coverage reports, and build artifacts
	find . -name '*.pyc' -exec rm -f {} +
	find . -name '*.pyo' -exec rm -f {} +
	find . -name '*~' -exec rm -f {} +
	coverage erase
	rm -fr build/
	rm -fr dist/
	rm -fr *.egg-info

coverage: clean ## generate and view HTML coverage report
	py.test --cov-report html
	$(BROWSER) htmlcov/index.html

docs: ## generate Sphinx HTML documentation, including API docs
	tox -e docs
	$(BROWSER) docs/_build/html/index.html

upgrade: export CUSTOM_COMPILE_COMMAND=make upgrade
upgrade: ## update the requirements/*.txt files with the latest packages satisfying requirements/*.in
	pip install -q pip-tools
	pip-compile --rebuild  --upgrade -o requirements/base.txt requirements/base.in
	pip-compile --rebuild  --upgrade -o requirements/dev.txt requirements/dev.in requirements/quality.in
	pip-compile --rebuild  --upgrade -o requirements/doc.txt requirements/base.in requirements/doc.in
	pip-compile --rebuild  --upgrade -o requirements/quality.txt requirements/quality.in
	pip-compile --rebuild  --upgrade -o requirements/test.txt requirements/base.in requirements/test.in
	pip-compile --rebuild  --upgrade -o requirements/travis.txt requirements/travis.in
	# Let tox control the Django version for tests
	grep -e "^amqp==\|^anyjson==\|^billiard==\|^celery==\|^kombu==\|^click-didyoumean==\|^click-repl==\|^click==\|^prompt-toolkit==\|^vine==" requirements/base.txt > requirements/celery50.txt
	sed -i.tmp '/^[d|D]jango==/d' requirements/test.txt
	sed -i.tmp '/^djangorestframework==/d' requirements/test.txt
	sed -i.tmp '/^amqp==/d' requirements/test.txt
	sed -i.tmp '/^anyjson==/d' requirements/test.txt
	sed -i.tmp '/^billiard==/d' requirements/test.txt
	sed -i.tmp '/^celery==/d' requirements/test.txt
	sed -i.tmp '/^kombu==/d' requirements/test.txt
	sed -i.tmp '/^vine==/d' requirements/test.txt
	rm requirements/test.txt.tmp

quality: ## check coding style with pycodestyle and pylint
	tox -e quality

requirements: ## install development environment requirements
	pip install -qr requirements/dev.txt --exists-action w
	pip-sync requirements/base.txt requirements/dev.txt requirements/private.* requirements/test.txt

test: clean ## run tests in the current virtualenv
	py.test tests/ celery_utils/

diff_cover: test
	diff-cover coverage.xml

test-all: ## run tests on every supported Python/Django combination
	tox -e quality
	tox

validate: quality test ## run tests and quality checks

## Localization targets

extract_translations: ## extract strings to be translated, outputting .mo files
	rm -rf docs/_build
	cd edx-celeryutils && ../manage.py makemessages -l en -v1 -d django
	cd edx-celeryutils && ../manage.py makemessages -l en -v1 -d djangojs

compile_translations: ## compile translation files, outputting .po files for each supported language
	cd edx-celeryutils && ../manage.py compilemessages

detect_changed_source_translations:
	cd edx-celeryutils && i18n_tool changed

pull_translations: ## pull translations from Transifex
	tx pull -af

push_translations: ## push source translation files (.po) from Transifex
	tx push -s

dummy_translations: ## generate dummy translation (.po) files
	cd celery_utils && i18n_tool dummy

build_dummy_translations: extract_translations dummy_translations compile_translations ## generate and compile dummy translation files

validate_translations: build_dummy_translations detect_changed_source_translations ## validate translations
