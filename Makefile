run-dev:
	COMPOSE_BAKE=true docker compose up --build

clean-dev:
	docker compose down --remove-orphans
