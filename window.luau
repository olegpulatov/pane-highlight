--!strict
-- Highlights the active pane in split views: border, background tint, dimmed
-- inactive panes. Rules recolor the active pane while it works as a given
-- user or on a given host (ssh, su, sudo, Tern remoting).

-- Defaults; config.json in the plugin data folder overrides them.
local DEFAULT_TINT_LIGHT = 3 -- % of the color mixed into the terminal background
local DEFAULT_TINT_DARK = 5
local DEFAULT_BORDER = 1 -- px, 0 = none
local DEFAULT_DIM = 0.3 -- veil opacity over inactive panes, 0 = off
local DEFAULT_SINGLE = false -- also mark a pane shown alone: the only pane, or zoomed
local DEFAULT_COLOR = "var(--accent)"
local PALETTE: { [string]: string } = {
	amber = "#F2B04C",
	red = "#E85B5B",
	sage = "#6a9a6a",
	mint = "#35C28A",
	sky = "#6FB3FF",
	blue = "#5AA4FF",
	cyan = "#3FD3FF",
	rose = "#e5b4d4",
	magma = "#FF7A3D",
	ember = "#b84a2c",
}
type Rule = { user: string?, host: string?, color: string }
local DEFAULT_RULES: { Rule } = {
	{ user = "root", color = "ember" },
	{ host = "prod-*", color = "red" },
	{ host = "dev-*", color = "mint" },
}

local CONFIG_MAX_BYTES = 64 * 1024
local LOOKUP_TIMEOUT_MS = 1500
-- A directory change this soon after a command started or ended belongs to that command.
local CWD_GUARD_MS = 1000
local DUPLICATE_MS = 100 -- the same start reported again this soon is one start
local MAX_WINDOWS = 9 -- window keys tried by `tern process --window N`
-- An app started from the Dock may not have `tern` on its PATH.
local TERN_PROGRAMS = { "tern", "/Applications/Tern.app/Contents/MacOS/tern", "/usr/bin/tern" }
-- Options taking a value, so their value is not taken for the destination or command.
local SSH_VALUE_OPTS = "BbcDEeFIiJLlmOoPpQRSWw"
local SUDO_VALUE_OPTS: { [string]: boolean } = {
	["-u"] = true,
	["-g"] = true,
	["-p"] = true,
	["-C"] = true,
	["-D"] = true,
	["-h"] = true,
	["-R"] = true,
	["-T"] = true,
	["-U"] = true,
	["--user"] = true,
	["--group"] = true,
	["--prompt"] = true,
	["--host"] = true,
	["--chdir"] = true,
	["--chroot"] = true,
	["--other-user"] = true,
	["--close-from"] = true,
	["--command-timeout"] = true,
}

-- Config --------------------------------------------------------------------

local config_path = tern.plugin.data .. "/config.json"
local tint_light, tint_dark = DEFAULT_TINT_LIGHT, DEFAULT_TINT_DARK
local border, dim, single = DEFAULT_BORDER, DEFAULT_DIM, DEFAULT_SINGLE
local colors: { [string]: string } = table.clone(PALETTE)
local rules: { Rule } = DEFAULT_RULES

local function fail(message: string): never
	error(config_path .. ": " .. message)
end

local function expect(value: any, kind: string, what: string): any
	if value ~= nil and type(value) ~= kind then
		fail(what .. " must be a " .. kind)
	end
	return value
end

if tern.fs.exists(config_path) then
	local text = tern.fs.read(config_path, CONFIG_MAX_BYTES)
	local config = tern.json.decode(text)
	-- Arrays also decode to tables; require an object in the source.
	if type(config) ~= "table" or not text:match("^%s*{") then
		fail("expected a JSON object")
	end
	local tint = expect(config.tint, "table", "tint")
	if tint then
		tint_light = expect(tint.light, "number", "tint.light") or tint_light
		tint_dark = expect(tint.dark, "number", "tint.dark") or tint_dark
	end
	border = expect(config.border, "number", "border") or border
	dim = expect(config.dim, "number", "dim") or dim
	local user_single = expect(config.single, "boolean", "single")
	if user_single ~= nil then
		single = user_single
	end
	for name, value in expect(config.colors, "table", "colors") or {} do
		colors[name] = expect(value, "string", "colors." .. tostring(name))
	end
	local user_rules = expect(config.rules, "table", "rules")
	if user_rules then
		rules = {}
		for i, rule in user_rules do
			local what = "rules[" .. i .. "]"
			expect(rule, "table", what)
			local r: Rule = {
				user = expect(rule.user, "string", what .. ".user"),
				host = expect(rule.host, "string", what .. ".host"),
				color = expect(rule.color, "string", what .. ".color"),
			}
			if not r.color or not (r.user or r.host) then
				fail(what .. " needs color and user or host")
			end
			table.insert(rules, r)
		end
	end
end

-- Matching ------------------------------------------------------------------

-- Who and where a pane works as; nil fields are unknown. shell: the command opens an
-- interactive login (`ssh host`, `su`, `sudo -i`), not a one-off (`ssh host cmd`, `sudo apt`).
type Target = { user: string?, host: string?, shell: boolean? }

local function glob(pattern: string, text: string): boolean
	local lua = pattern:gsub("[%^%$%(%)%%%.%[%]%+%-]", "%%%0"):gsub("%*", ".*"):gsub("%?", ".")
	return text:match("^" .. lua .. "$") ~= nil
end

-- Program name without directory or Windows `.exe`: `C:\…\ssh.exe` -> `ssh`.
local function base(path: string): string
	local name = path:match("([^/\\]+)$") or path
	return (name:lower():gsub("%.exe$", ""))
end

-- ssh [opts] [user@]host | ssh://[user@]host[:port]; -l user.
local function ssh_target(argv: { string }, start: number): Target?
	local user: string? = nil
	local i = start
	while i <= #argv do
		local arg = argv[i]
		if arg == "-l" then
			user = argv[i + 1]
			i += 2
		elseif arg:sub(1, 2) == "-l" then
			user = arg:sub(3)
			i += 1
		elseif arg:sub(1, 1) == "-" then
			local flag = arg:sub(2, 2)
			i += if #arg == 2 and SSH_VALUE_OPTS:find(flag, 1, true) then 2 else 1
		else
			local dest = arg:gsub("^ssh://", "")
			local at_user, host = dest:match("^(.-)@(.+)$")
			host = (host or dest):gsub(":%d+$", "")
			return { user = at_user or user, host = host, shell = argv[i + 1] == nil }
		end
	end
	return nil
end

-- su [opts] [user] [-c cmd]: default root.
local function su_target(argv: { string }, start: number): Target
	local user: string? = nil
	local command = false
	local i = start
	while i <= #argv do
		local arg = argv[i]
		if arg == "-c" or arg == "--command" then
			command = true
			i += 2
		elseif arg == "-s" or arg == "-g" or arg == "-G" then
			i += 2
		elseif arg:sub(1, 1) == "-" then
			i += 1
		else
			user = user or arg
			i += 1
		end
	end
	return { user = user or "root", shell = not command }
end

local targets_of: (argv: { string }, start: number) -> Target?

-- sudo [opts] [command]: target -u user, default root; sudo su/ssh follows the command.
-- No command and no shell flag (`sudo -k`, `sudo -v`): nothing runs as anyone.
local function sudo_target(argv: { string }, start: number): Target?
	local user = "root"
	local shell = false
	local i = start
	while i <= #argv do
		local arg = argv[i]
		if SUDO_VALUE_OPTS[arg] then
			if arg == "-u" or arg == "--user" then
				user = argv[i + 1] or user
			end
			i += 2
		elseif arg:sub(1, 2) == "-u" then
			user = arg:sub(3)
			i += 1
		elseif arg:sub(1, 7) == "--user=" then
			user = arg:sub(8)
			i += 1
		elseif arg == "--" then
			i += 1
			break
		elseif arg:sub(1, 1) == "-" then
			shell = shell or arg == "-i" or arg == "-s" or arg == "--login" or arg == "--shell"
			i += 1
		else
			break
		end
	end
	if not argv[i] then
		return if shell then { user = user, shell = true } else nil
	end
	local prog = base(argv[i])
	if prog == "su" or prog == "ssh" then
		return targets_of(argv, i) or { user = user }
	end
	return { user = user }
end

targets_of = function(argv: { string }, start: number): Target?
	local prog = argv[start] and base(argv[start])
	if prog == "ssh" then
		return ssh_target(argv, start + 1)
	elseif prog == "tern" and argv[start + 1] == "ssh" then
		return ssh_target(argv, start + 2)
	elseif prog == "su" then
		return su_target(argv, start + 1)
	elseif prog == "sudo" then
		return sudo_target(argv, start + 1)
	end
	return nil
end

-- Stands between commands in the word list; a shell word never holds a NUL.
local SEPARATOR = "\0"

-- Shell-like words: whitespace splits outside quotes; '…', "…" and `\ ` keep text together.
local function words_of(line: string): { string }
	local words: { string } = {}
	local word: string? = nil
	local quote: string? = nil
	local i = 1
	while i <= #line do
		local c = line:sub(i, i)
		if quote then
			if c == quote then
				quote = nil
			elseif c == "\\" and quote == '"' and line:sub(i + 1, i + 1):match('["\\]') then
				i += 1
				word = (word or "") .. line:sub(i, i)
			else
				word = (word or "") .. c
			end
		elseif c == "'" or c == '"' then
			quote = c
			word = word or ""
		elseif c == "\\" and line:sub(i + 1, i + 1):match("[%s'\"\\]") then
			-- Only before space, quote or backslash, so Windows paths keep their `\`.
			i += 1
			word = (word or "") .. line:sub(i, i)
		elseif c:match("[;|&]") then
			-- Command separators (`;`, `&&`, `||`, `|`) end the word and the command.
			if word then
				table.insert(words, word)
				word = nil
			end
			if words[#words] ~= SEPARATOR then
				table.insert(words, SEPARATOR)
			end
		elseif c:match("%s") then
			if word then
				table.insert(words, word)
				word = nil
			end
		else
			word = (word or "") .. c
		end
		i += 1
	end
	if word then
		table.insert(words, word)
	end
	return words
end

-- Every command of the line (`a; b && c | d`) can switch user or host.
local function line_targets(line: string): { Target }
	local targets: { Target } = {}
	local command: { string } = {}
	local function flush()
		local t = targets_of(command, 1)
		if t then
			table.insert(targets, t)
		end
		command = {}
	end
	for _, word in words_of(line) do
		if word == SEPARATOR then
			flush()
		else
			table.insert(command, word)
		end
	end
	flush()
	return targets
end

local function rule_matches(rule: Rule, t: Target): boolean
	if rule.user and rule.user ~= t.user then
		return false
	end
	if rule.host and not (t.host and glob(rule.host, t.host)) then
		return false
	end
	return true
end

-- The first target that matches a rule decides; targets come innermost first.
local function color_for(targets: { Target }): string?
	for _, t in targets do
		for _, rule in rules do
			if rule_matches(rule, t) then
				return colors[rule.color] or rule.color
			end
		end
	end
	return nil
end

-- Style ---------------------------------------------------------------------

-- tern.css replaces the whole sheet and restyles the window, so only on a change.
-- The tint is an opaque background: the active pane stands out of a translucent window.
-- Tern marks the active pane `.on`; `.multi` while the tab shows more than one pane.
local ACTIVE = if single then ".tn-stage .tn-pane.on" else ".tn-stage .tn-pane.on.multi"
local shown: string? = nil
local function set_style(color: string)
	if color == shown then
		return
	end
	shown = color
	local template = [[
		ACTIVE {
			--ph-border: %gpx;
			--ph-color: %s;
			--ph-bg: light-dark(
				color-mix(in srgb, var(--tv-bg), %s %g%%),
				color-mix(in srgb, var(--tv-bg), %s %g%%)
			);
		}
		ACTIVE:not(.headed) .tn-body {
			box-shadow: inset 0 0 0 var(--ph-border) var(--ph-color) !important;
			background: var(--ph-bg) !important;
		}
		ACTIVE.headed :is(.tn-head, .tn-body) {
			background: var(--ph-bg) !important;
		}
		ACTIVE.headed .tn-head {
			box-shadow:
				inset 0 var(--ph-border) 0 0 var(--ph-color),
				inset var(--ph-border) 0 0 0 var(--ph-color),
				inset calc(-1 * var(--ph-border)) 0 0 0 var(--ph-color),
				inset 0 -1px 0 var(--l1) !important;
		}
		ACTIVE.headed .tn-body {
			box-shadow:
				inset 0 calc(-1 * var(--ph-border)) 0 0 var(--ph-color),
				inset var(--ph-border) 0 0 0 var(--ph-color),
				inset calc(-1 * var(--ph-border)) 0 0 0 var(--ph-color) !important;
		}
		.tn-stage .tn-pane.dim .tn-veil {
			opacity: %g !important;
		}
	]]
	-- The selector goes in before the colors, so no color text is rewritten.
	local css =
		string.format((template:gsub("ACTIVE", ACTIVE)), border, color, color, tint_light, color, tint_dark, dim)
	tern.css("pane-highlight", css)
end

-- Panes ---------------------------------------------------------------------

local pane_color: { [number]: string } = {}
local generation: { [number]: number } = {}
-- Logins typed in the pane, outermost first; cwd is where each was typed.
type Login = { target: Target, cwd: string }
local logins: { [number]: { Login } } = {}
local active_at: { [number]: number } = {} -- last command start or end, tern.now() ms
-- The command started and not yet finished, and how many logins it added.
local open: { [number]: { line: string, pushed: number, at: number } } = {}
-- Panes `tern process` could not find: not asked again.
local unfound: { [number]: boolean } = {}
-- Panes where `exit` or `logout` just ran: the next directory is the shell below.
local leaving: { [number]: boolean } = {}

-- Only the focused pane is checked. Tern 0.7.2 rejects some ids it gives the window half
-- (`cx.session:pane(cx.session:focused())` is nil in some panes), but resolves "@focused".
local function focused_info(cx: WindowCx): PaneInfo?
	return cx.session:pane("@focused")
end

local function remember(cx: WindowCx, pane_id: number, line: string)
	local now = tern.now()
	-- Tern may report one start twice.
	if open[pane_id] and open[pane_id].line == line and now - open[pane_id].at < DUPLICATE_MS then
		return
	end
	active_at[pane_id] = now
	open[pane_id] = { line = line, pushed = 0, at = now }
	leaving[pane_id] = nil
	local stack = logins[pane_id] or {}
	logins[pane_id] = stack
	local first = line:match("^%s*(%S+)")
	if first == "exit" or first == "logout" then
		table.remove(stack)
		leaving[pane_id] = true
		return
	end
	-- Only a line that is one command: in `ssh a; ssh b` or `true || ssh b` a login may
	-- run later or never.
	local words = words_of(line)
	local t = if table.find(words, SEPARATOR) then nil else targets_of(words, 1)
	if t and t.shell then
		local info = focused_info(cx)
		table.insert(stack, { target = t, cwd = info and info.cwd or "" })
		open[pane_id].pushed = 1
	end
end

-- Ctrl-D or a dropped connection leave a login without a command line. The shell below
-- reports its directory again: back in a directory a login was typed in, with no command
-- running, started or ended just before, means that login and all inside it ended.
-- After `exit` the next directory is the shell below, already taken off the list.
local function returned(cx: WindowCx, pane_id: number, path: string)
	local stack = logins[pane_id]
	local after_exit = leaving[pane_id]
	leaving[pane_id] = nil
	local info = focused_info(cx)
	if
		not stack
		or after_exit
		or (info and info.running)
		or tern.now() - (active_at[pane_id] or -math.huge) < CWD_GUARD_MS
	then
		return
	end
	for k = #stack, 1, -1 do
		if stack[k].cwd == path then
			for _ = k, #stack do
				table.remove(stack)
			end
			return
		end
	end
end

-- Who the pane's machine logs in as: Tern remoting hop, else Tern's own user.
local function host_target(cx: WindowCx, pane_id: number): Target
	for _, host in cx.hosts:list() do
		if host.kind == "remote" and table.find(host.panes, pane_id) then
			local id: { [string]: any } = host.identity or {}
			local hop = if type(id.hops) == "table" and #id.hops > 0 then id.hops[#id.hops] else id
			return { user = type(hop) == "table" and hop.user or nil, host = host.name }
		end
	end
	return { user = tern.getenv("USER") or tern.getenv("LOGNAME") }
end

-- The pane's foreground program (`ssh deploy@web1` for a whole ssh session), from `tern process`.
-- The plugin cannot learn its window key, and `tern process` sees one window's panes,
-- so it asks the first window (no `--window`; its panes have an empty key), then keys
-- 1..MAX_WINDOWS, until one knows the pane. Bounded workaround: other keys are not reached.
-- Each window runs its own copy of this plugin, so all its panes share one key: the first
-- hit is remembered and asked first next time; a miss there scans again.
-- done gets the target and a fresh cx, and where the pane stands: "missing" (no window
-- knew it, or no `tern` can start), "own" (the pane's own program, its first shell, is in
-- front: no login runs), "other" (a program it started is in front).
type Lookup = "missing" | "own" | "other"
local known_window: number? = nil
local function foreground(pane_id: number, cx: WindowCx, done: (Target?, Lookup, WindowCx) -> ())
	local function ask(program: string, window: number, ask_cx: WindowCx, remembered: boolean): boolean
		local args = { program, "process", tostring(pane_id), "--json" }
		if window > 0 then
			table.insert(args, 2, "--window")
			table.insert(args, 3, tostring(window))
		end
		return pcall(
			tern.process.run,
			args :: { string },
			{ timeout_ms = LOOKUP_TIMEOUT_MS },
			function(res: ProcessResult, next_cx: WindowCx?)
				local now_cx = next_cx or ask_cx
				if res.status ~= 0 then
					local next_window = if remembered then 0 else window + 1
					if remembered then
						known_window = nil
					end
					if next_window > MAX_WINDOWS or not ask(program, next_window, now_cx, false) then
						done(nil, "missing", now_cx)
					end
					return
				end
				known_window = window
				local ok_json, data = pcall(tern.json.decode, res.stdout)
				local fg = ok_json and type(data) == "table" and data.foreground
				local child = ok_json and type(data) == "table" and data.child
				local argv = type(fg) == "table" and fg.argv
				local own = type(fg) == "table" and type(child) == "table" and fg.pid == child.pid
				done(if type(argv) == "table" then targets_of(argv, 1) else nil, if own then "own" else "other", now_cx)
			end
		)
	end
	for _, program in TERN_PROGRAMS do
		if
			(program == "tern" or tern.fs.exists(program)) and ask(program, known_window or 0, cx, known_window ~= nil)
		then
			return
		end
	end
	done(nil, "missing", cx)
end

local function apply(cx: WindowCx, pane_id: number, color: string)
	pane_color[pane_id] = color
	if cx.session:focused() == pane_id then
		set_style(color)
	end
end

-- Only the focused pane shows a rule color, so only it is checked; focus checks again.
-- line: the command line just started (event); nil reads the pane's running line.
local function update(cx: WindowCx, pane_id: number, line: string?)
	if cx.session:focused() ~= pane_id then
		return
	end
	generation[pane_id] = (generation[pane_id] or 0) + 1
	local gen = generation[pane_id]
	local info = focused_info(cx)
	if line == nil then
		line = info and info.running and info.running.line
	end
	-- A running `sudo -i` or `ssh root@…` decides at once.
	local color = line and color_for(line_targets(line))
	if color then
		apply(cx, pane_id, color)
		return
	end
	local function settle(found: Target?, settle_cx: WindowCx)
		local targets: { Target } = {}
		local stack: { Login } = logins[pane_id] or {}
		for _, login in stack do
			table.insert(targets, 1, login.target)
		end
		if found then
			table.insert(targets, found)
		end
		table.insert(targets, host_target(settle_cx, pane_id))
		apply(settle_cx, pane_id, color_for(targets) or DEFAULT_COLOR)
	end
	-- Only terminal, agent and plugin panes run a program; browser, file and the rest have no ssh.
	local runs = info and (info.kind == "terminal" or info.kind == "agent" or info.kind == "plugin")
	if not runs or unfound[pane_id] then
		settle(nil, cx)
		return
	end
	foreground(pane_id, cx, function(found, lookup, next_cx)
		if gen ~= generation[pane_id] then
			return
		end
		if lookup == "missing" then
			unfound[pane_id] = true
		elseif lookup == "own" then
			-- The pane's first shell is in front: every remembered login has ended.
			logins[pane_id] = nil
		end
		settle(found, next_cx)
	end)
end

local function focus(cx: WindowCx)
	local pane_id = cx.session:focused()
	set_style(pane_id and pane_color[pane_id] or DEFAULT_COLOR)
	if pane_id then
		update(cx, pane_id)
	end
end

tern.timer(0, function(cx)
	if cx then
		focus(cx)
	else
		set_style(DEFAULT_COLOR)
	end
end)

tern.on("focus", function(_ev, cx)
	focus(cx)
end)

-- Only the focused pane shows a rule color, so events of other panes are ignored.
tern.on("command_started", function(ev, cx)
	if cx.session:focused() == ev.pane then
		remember(cx, ev.pane, ev.line)
		update(cx, ev.pane, ev.line)
	end
end)

-- A login command that ends with an error either never logged in (`ssh typo-host`) or
-- its session just ended: drop the logins that command added.
tern.on("command_finished", function(ev, cx)
	if cx.session:focused() ~= ev.pane then
		return
	end
	active_at[ev.pane] = tern.now()
	local started = open[ev.pane]
	open[ev.pane] = nil
	local stack = logins[ev.pane]
	if stack and started and started.line == ev.line and ev.status ~= 0 then
		for _ = 1, started.pushed do
			table.remove(stack)
		end
	end
	update(cx, ev.pane)
end)

-- Leaving ssh may report no command_finished (the remote shell's commands replaced it);
-- the pane's directory changes back, so check again then.
tern.on("cwd", function(ev, cx)
	if cx.session:focused() == ev.pane then
		returned(cx, ev.pane, ev.path)
		update(cx, ev.pane)
	end
end)

tern.on("pane_closed", function(ev, cx)
	pane_color[ev.pane] = nil
	generation[ev.pane] = nil
	logins[ev.pane] = nil
	active_at[ev.pane] = nil
	open[ev.pane] = nil
	unfound[ev.pane] = nil
	leaving[ev.pane] = nil
	focus(cx)
end)
