# Repository Guidelines

## Project Structure & Module Organization

`init.lua` is the entry point: it sets global defaults and loads modules from
`lua/vle-roux/`. Keep responsibilities separated there: editor options belong in
`options.lua`, user commands and autocmds in `commands.lua`, mappings in
`remaps.lua`, reusable mapping helpers in `keymap.lua`, plugin specifications in
`lazy.lua`, C project workflows in `c_tools.lua`, and UI behavior in focused
modules such as `theme.lua` or `markdown_preview.lua`.

`plugin/stdheader.vim` provides the 42 header command. `autoload/plug.vim` is
vendored compatibility code; avoid editing it unless intentionally updating that
dependency. `lazy-lock.json` pins plugin revisions. The `after/` directory is
reserved for runtime overrides. Files such as `nvim.log` are diagnostics, not
source. `training/` contains disposable C/Make exercises; its launcher copies
fixtures to `/tmp` so practice never edits the canonical examples.

## Development and Validation Commands

- `nvim` starts the configuration for interactive smoke testing.
- `nvim --headless -u init.lua -i NONE "+qa"` verifies that startup completes without
  Lua or plugin-loading errors.
- `nvim --headless -u init.lua -i NONE "+lua dofile('tests/headless.lua')" "+qa"`
  checks the C toolchain, completion, task runner, and DAP wiring.
- `sh tests/training.sh` validates the intentionally failing training fixtures
  and their isolated launcher.
- `nvim --headless -u init.lua -i NONE "+checkhealth" "+qa"` runs Neovim health checks;
  inspect reported missing executables relevant to your change.
- `nvim --headless -u init.lua -i NONE "+Lazy! sync" "+qa"` installs or synchronizes
  plugins with `lazy-lock.json`. Run it after changing plugin specifications.

There is no separate build step. Exercise changed commands, mappings, autocmds,
and plugin events in an appropriate buffer.

## Coding Style & Naming Conventions

Use Lua for new configuration code and two-space indentation. Prefer `local`
bindings, `snake_case` names for functions and variables, and small modules that
return an `M` table when they expose an API. Use `vim.keymap.set` through the
helpers in `keymap.lua`, and give non-obvious mappings a `desc`. Keep plugin
configuration lazy-loaded where practical. Follow existing Vimscript style only
inside `.vim` files.

## Testing Guidelines

Run both headless checks for every change. For UI or event-driven changes, also
test interactively and confirm `:messages` contains no new errors. Test both the
normal path and missing-optional-tool behavior.

## Commit & Pull Request Guidelines

Git history is unavailable in this checkout, so use short, imperative subjects,
for example `Fix markdown preview refresh`. Keep commits focused. Pull requests
should explain user-visible behavior, list validation performed, mention new
external dependencies, and include screenshots only for visual changes.
