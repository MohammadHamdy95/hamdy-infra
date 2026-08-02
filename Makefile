.PHONY: dev dev-down dev-logs dev-ps prod prod-down update

dev: ## build + start the full local stack (http://hamdy.localhost etc.)
	docker compose -f compose/docker-compose.dev.yml up -d --build

dev-down:
	docker compose -f compose/docker-compose.dev.yml down

dev-logs:
	docker compose -f compose/docker-compose.dev.yml logs -f

dev-ps:
	docker compose -f compose/docker-compose.dev.yml ps

prod:
	docker compose -f compose/docker-compose.yml up -d --build

prod-down:
	docker compose -f compose/docker-compose.yml down

update: ## git pull every repo, then stop + rebuild + start (run on the server)
	@for repo in ../hamdy-app ../shortener-frontend ../shortener-backend ../paste-frontend ../paste-backend .; do \
		echo "==> git pull in $$repo"; \
		(cd $$repo && git pull) || exit 1; \
	done
	$(MAKE) prod-down
	$(MAKE) prod
