.PHONY: dev dev-down dev-logs dev-ps prod prod-down update game game-down game-logs game-ps

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
	@for repo in ../hamdy-app ../tiny-frontend ../tiny-backend ../paste-frontend ../paste-backend ../spec-frontend ../spec-backend .; do \
		echo "==> git pull in $$repo"; \
		(cd $$repo && git pull) || exit 1; \
	done
	$(MAKE) prod-down
	$(MAKE) prod

# --- Pterodactyl / game servers ---------------------------------------
# Separate stack on purpose: `update` above stops and restarts the whole
# platform, and that must not drop players out of a running game server.
# Wings itself is a systemd unit on the host (`systemctl status wings`),
# not part of this stack — see DEPLOY.md.

game: ## start the Pterodactyl panel stack
	docker compose -f compose/pterodactyl/compose.yaml up -d

game-down:
	docker compose -f compose/pterodactyl/compose.yaml down

game-logs:
	docker compose -f compose/pterodactyl/compose.yaml logs -f

game-ps:
	docker compose -f compose/pterodactyl/compose.yaml ps
