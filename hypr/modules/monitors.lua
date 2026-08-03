local settings = require("modules.settings")

-- Safe fallback for an unknown or temporarily connected output.
hl.monitor({
    output = "",
    mode = "preferred",
    position = "auto",
    scale = "auto",
})

hl.monitor(settings.monitors.primary)
hl.monitor(settings.monitors.secondary)

hl.workspace_rule({
    workspace = "1",
    monitor = settings.monitors.primary.output,
    default = true,
    persistent = true,
})

hl.workspace_rule({
    workspace = "2",
    monitor = settings.monitors.secondary.output,
    default = true,
    persistent = true,
})
