# Extracts the route table from lib/core/router/app_router.dart.
# A route block can build more than one page (a deep-link fallback branch),
# so every page widget named inside the block is collected, not just the first.
function flush(   i) {
  if (path == "") return
  printf("| `%s` | `%s` | `%s` |\n", path, name, (pages == "" ? "—" : pages))
  path = ""; name = ""; pages = ""
}
match($0, /path: .([^'"'"']*)./, p) {
  flush(); path = p[1]; next
}
path != "" && match($0, /RouteNames\.([A-Za-z0-9_]+)/, n) { name = n[1] }
path != "" {
  line = $0
  while (match(line, /([A-Z][A-Za-z0-9_]*(Page|Fallback))\(/, g)) {
    if (index(" " pages " ", " " g[1] " ") == 0)
      pages = (pages == "" ? g[1] : pages " / " g[1])
    line = substr(line, RSTART + RLENGTH)
  }
}
END { flush() }
