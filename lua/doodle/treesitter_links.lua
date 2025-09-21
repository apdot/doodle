local M = {}

function M.generate_anchor(start_node, bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not start_node then return nil end

  -- climb up until we find a named node
  while start_node and not start_node:named() do
    start_node = start_node:parent()
  end
  if not start_node then return nil end

  -- collect ancestor chain (root → ... → target)
  local ancestors = {}
  local cur = start_node
  while cur do
    local entry = { type = cur:type() }
    local name_nodes = cur:field("name")
    if name_nodes and name_nodes[1] then
      local raw = vim.treesitter.get_node_text(name_nodes[1], bufnr) or ""
      entry.name = string.format("%q", raw) -- escape safely
    end
    table.insert(ancestors, 1, entry)
    cur = cur:parent()
  end

  -- build nested query, target node gets @doodle.link
  local child_pattern = nil
  for i = #ancestors, 1, -1 do
    local e = ancestors[i]
    local base
    if e.name then
      base = string.format("(%s name: (_) @name (#eq? @name %s)", e.type, e.name)
    else
      base = string.format("(%s", e.type)
    end

    if child_pattern then
      base = base .. " " .. child_pattern .. ")"
    else
      base = base .. ") @doodle.link"
    end

    child_pattern = base
  end

  return child_pattern
end

--- Resolve an anchor query to a line number.
-- @param bufnr integer buffer number
-- @param anchor_query string the Treesitter query generated earlier
-- @return integer|nil 1-based line number of the match
function M.find_line_by_anchor(bufnr, anchor_query)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not anchor_query or anchor_query == "" then return nil end

  local ok, query = pcall(vim.treesitter.query.parse, vim.bo[bufnr].filetype, anchor_query)
  if not ok or not query then return nil end

  local parser = vim.treesitter.get_parser(bufnr, vim.bo[bufnr].filetype)
  if not parser then return nil end
  local tree = parser:parse()[1]
  if not tree then return nil end

  local root = tree:root()
  for id, node in query:iter_captures(root, bufnr) do
    if query.captures[id] == "doodle.link" then
      local srow = select(1, node:range())
      return srow + 1
    end
  end

  return nil
end

return M
