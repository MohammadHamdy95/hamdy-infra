.PHONY: dev dev-down dev-logs dev-ps prod prod-down

dev: ## build + start the full local stack (http://hamdy.localhost etc.)
	docker compose -f compose/docker-compose.dev.yml up -d --build

dev-down:
	docker compose -f compose/docker-compose.dev.yml down

dev-logs:
	docker compose -f compose/docker-compose.dev.yml logs -f

dev-ps:
	docker compose -f compose/docker-compose.dev.yml ps

prod:
	docker compose -f compose/docker-compose.yml up -d

prod-down:
	docker compose -f compose/docker-compose.yml down
