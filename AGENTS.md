# Repository Guidelines

## Project Structure & Module Organization

This is a monorepo for Lost Miracle. `lost-miracle-client/` is the Godot 4.6.2 game client; open `project.godot` from that directory, not from the repo root. Client scripts live in `scripts/`, scenes in `scenes/`, and shared gameplay data in `data/*.json`. `lost-miracle-server/` is the Spring Boot 3 API; Java code is under `src/main/java/com/lostmiracle`, tests under `src/test/java`, Flyway migrations under `src/main/resources/db/migration`, and MyBatis XML under `src/main/resources/mapper`. `lost-miracle-admin/` is the Vite React GM console. `docs/` contains design and backend architecture references.

## Build, Test, and Development Commands

- `cd lost-miracle-server && docker compose up -d`: start local MySQL and Redis.
- `cd lost-miracle-server && mvn spring-boot:run`: run the API at `http://127.0.0.1:8080/api/v1`.
- `cd lost-miracle-server && mvn test`: run server unit and integration tests.
- `cd lost-miracle-admin && npm install`: install admin UI dependencies.
- `cd lost-miracle-admin && npm run dev`: run the GM console at `http://127.0.0.1:5173`.
- `cd lost-miracle-admin && npm run build`: type-check and build the admin UI.
- Godot client: open `lost-miracle-client/project.godot`, start the server first, then run `scenes/main/Main.tscn`.

## Coding Style & Naming Conventions

Use existing local style. Java uses 4-space indentation, constructor injection, package-by-module layout, and suffixes such as `Controller`, `Service`, `Mapper`, `Entity`, `Request`, and `Response`. GDScript uses tabs, `snake_case` functions/variables, and `PascalCase` autoload/class names. React TypeScript uses 2-space indentation, function components, `PascalCase` page/component files, and API helpers in `src/api/`.

## Testing Guidelines

Server tests use JUnit through Spring Boot test dependencies. Name tests `*Test.java` and place them beside the package they cover under `lost-miracle-server/src/test/java`. Add focused tests for save validation, conflict handling, combat/enhance rules, and API behavior that changes persistence. Run `mvn test` before submitting server changes. The admin app currently has no test runner; at minimum run `npm run build`. For Godot changes, run the relevant scene manually and verify online save/sync flows.

## Commit & Pull Request Guidelines

History favors concise, scoped summaries describing the completed change, often in an imperative style. Keep commits focused, for example `fix JWT auth filter` or `add GM spawn reset flow`. Pull requests should include a short description, affected areas (`client`, `server`, `admin`, `docs`), test/build results, linked issues when applicable, and screenshots or short recordings for UI changes.

## Security & Configuration Tips

Do not commit local secrets. Base local config on `lost-miracle-server/src/main/resources/application-local.yml.example`. Production deployments must replace default JWT and GM credentials in `lost-miracle.*` configuration.
