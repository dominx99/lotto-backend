current-dir := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

compose_file := "docker-compose.yml"
lotto-php-service := "lotto_php"
current-dir := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
lotto-bin-location := "./bin"
lotto-console-location := "./bin/console"

# 🐳 Docker Compose
.PHONY: upd
upd: CMD=up -d

.PHONY: stop
stop: CMD=stop

.PHONY: down
down: CMD=down

.PHONY: build
build: deps up

.PHONY: deps
deps: composer-install

.PHONY: composer
composer dump composer-install composer-update composer-require composer-require-module: composer-env-file
	@docker-compose exec $(lotto-php-service) \
		composer $(CMD) \
			--no-ansi

.PHONY: dump
dump: CMD=dump-autoload

.PHONY: composer-install
composer-install: CMD=install

.PHONY: composer-update
composer-update: CMD=update

.PHONY: composer-require
composer-require: CMD=require
composer-require: INTERACTIVE=-ti --interactive

.PHONY: composer-require-module
composer-require-module: CMD=require $(module)
composer-require-module: INTERACTIVE=-ti --interactive

# Usage: `make doco CMD="ps --services"`
# Usage: `make doco CMD="build --parallel --pull --force-rm --no-cache"`
.PHONY: doco
doco upd prod stop down: composer-env-file
	@docker-compose $(CMD)

.PHONY: rebuild
rebuild: composer-env-file
	docker-compose build --pull --force-rm --no-cache
	make deps
	make up

# 🐘 Composer
composer-env-file:
	@if [ ! -f .env.local ]; then echo '' > .env.local; fi

.PHONY: fix
fix:
	@docker-compose exec $(lotto-php-service) php vendor/bin/php-cs-fixer fix src --allow-risky=yes

clear:
	@docker-compose exec $(lotto-php-service) php $(lotto-console-location) cache:clear
	@docker-compose exec $(lotto-php-service) php $(lotto-console-location) doctrine:cache:clear-metadata
	@docker-compose exec $(lotto-php-service) php $(lotto-console-location) doctrine:cache:clear-query
	@docker-compose exec $(lotto-php-service) php $(lotto-console-location) doctrine:cache:clear-result

.PHONY: test
test: composer-env-file
	docker-compose exec $(lotto-php-service) php $(lotto-bin-location)/phpunit

test-lotto th: composer-env-file
	docker-compose exec $(lotto-php-service) php $(lotto-bin-location)/phpunit --testsuite lotto

test-shared ts: composer-env-file
	docker-compose exec $(lotto-php-service) php $(lotto-bin-location)/phpunit --testsuite shared

.PHONY: run-tests
run-tests: composer-env-file
	mkdir -p build/test_results/phpunit
	./vendor/bin/phpunit --exclude-group='disabled' --log-junit build/test_results/phpunit/junit.xml --testsuite lotto
	./vendor/bin/phpunit --exclude-group='disabled' --log-junit build/test_results/phpunit/junit.xml --testsuite shared

test-coverage tc:
	@docker-compose -f $(compose_file) exec $(lotto-php-service) $(lotto-bin-location)/phpunit --coverage-html .coverage $(CMD)
	@brave ".coverage/index.html"

migrate:
	@docker-compose exec $(lotto-php-service) php $(lotto-console-location) doctrine:migrations:migrate

diff:
	@docker-compose exec $(lotto-php-service) php $(lotto-console-location) doctrine:migrations:diff

.PHONY: static-analysis
static-analysis st: composer-env-file
	docker-compose exec $(lotto-php-service) ./vendor/bin/psalm $(CMD)

.PHONY: console
console:
	docker-compose exec $(lotto-php-service) $(lotto-console-location) $(CMD)

.PHONY: bash
bash:
	docker-compose exec $(lotto-php-service) bash

.PHONY: remove-database
remove-database:
	@docker-compose exec $(service) $(lotto-php-service) $(lotto-console-location) doctrine:database:drop --if-exists --force $(CMD)

.PHONY: create-database
create-database:
	@docker-compose exec $(service) $(lotto-php-service) $(lotto-console-location) doctrine:database:create $(CMD)

.PHONY: fixtures
fixtures:
	@docker-compose exec $(lotto-php-service) $(lotto-console-location) doctrine:fixtures:load

.PHONY: refresh-database
refresh-database: remove-database create-database migrate

.PHONY: refresh-repository
refresh-repository:
	git pull

update-permissions:
	chmod 777 ./var -R

.PHONY: deploy
deploy: down refresh-repository prod deps migrate clear update-permissions

restart: down up
