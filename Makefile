GIT_BRANCH=$(shell git rev-parse --abbrev-ref HEAD)
USER=$(shell whoami)

STAGING_URL="https://docs-mongodborg-staging.corp.mongodb.com"
STAGING_BUCKET=docs-mongodb-org-staging

PRODUCTION_URL="https://docs.mongodb.com"
PRODUCTION_BUCKET=docs-node-prod

COMMIT_HASH=$(shell git rev-parse --short HEAD)

PREFIX=node
PROJECT=node
REPO_DIR=$(shell pwd)
SNOOTY_DB_USR = $(shell printenv MONGO_ATLAS_USERNAME)
SNOOTY_DB_PWD = $(shell printenv MONGO_ATLAS_PASSWORD)

.PHONY: help stage fake-deploy deploy deploy-search-index publish remote-includes api-docs

help: ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo
	@echo 'Variables'
	@printf "  \033[36m%-18s\033[0m %s\n" 'ARGS' 'Arguments to pass to mut-publish'
	
next-gen-publish:
	@curl https://raw.githubusercontent.com/mongodb/docs-worker-pool/meta/publishedbranches/docs-node.yaml > ${REPO_DIR}/published-branches.yaml
	next-gen-html;
	echo "PATH_PREFIX=${PREFIX}/${GIT_BRANCH}" >> .env.production; \
	if [ ${GIT_BRANCH} = master ]; then mut-redirects config/redirects -o public/.htaccess; fi

next-gen-html:
	# snooty parse and then build-front-end
	@echo ${SNOOTY_DB_PWD} | snooty build "${REPO_DIR}" "mongodb+srv://${SNOOTY_DB_USR}:@cluster0-ylwlz.mongodb.net/snooty?retryWrites=true" --commit "${COMMIT_HASH}"; \
	if [ $$? -eq 1 ]; then \
		exit 1; \
	else \
		exit 0; \
	fi
	rsync -az --exclude '.git' ${REPO_DIR}/../../snooty ${REPO_DIR};
	cd snooty; \
	echo "GATSBY_SITE=${PROJECT}" > .env.production; \
	echo "GATSBY_PARSER_USER=${USER}" >> .env.production; \
	echo "GATSBY_PARSER_BRANCH=${GIT_BRANCH}" >> .env.production; \
	echo "COMMIT_HASH=${COMMIT_HASH}" >> .env.production; \
	npm run build; \
	cp -r "${REPO_DIR}/snooty/public" ${REPO_DIR};
	
next-gen-stage: ## Host online for review
	mut-publish public ${STAGING_BUCKET} --prefix="${COMMIT_HASH}/${PROJECT}" --stage ${ARGS}
	@echo "Hosted at ${STAGING_URL}/${COMMIT_HASH}/${PROJECT}/${USER}/${GIT_BRANCH}/"

html: ## Builds this branch's HTML under build/<branch>/html
	giza make html

next-gen-deploy:
	@yes | mut-publish public ${PRODUCTION_BUCKET} --prefix=${PROJECT} --deploy --deployed-url-prefix=https://docs.mongodb.com --json --all-subdirectories ${ARGS}

deploy-search-index: ## Update the search index for this branch
	@echo "Building search index"
	mut-index upload build/public -o ${PROJECT}-${GIT_BRANCH}.json -u ${PRODUCTION_URL}/${PROJECT} -g -s --exclude build/public/sdk/iOS

%:
	@:

test:
    if [ $(filter-out $@,$(MAKECMDGOALS)) = hi ]; \
        echo "WON"; \
    else \
        echo "LOST"; \
    fi
