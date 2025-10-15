local SyncUtil = require("doodle.utils.sync_util")

local M = {}

---@param git_repo string
---@return boolean
function M.ensure_main(git_repo)
    local ok, out = SyncUtil.run({
        "git",
        "ls-remote", "--exit-code", "--heads", "origin", "main"
    }, git_repo)

    SyncUtil.run({
        "git",
        "branch", "-M", "main"
    }, git_repo)

    return ok
end

---@param git_repo string
---@return boolean
---@return string
function M.pull(git_repo)
    return SyncUtil.run({
        "git",
        "pull", "--rebase", "origin", "main"
    }, git_repo)
end

---@param files string[]
---@param msg string
---@param git_repo string
---@return boolean
function M.push(files, msg, git_repo)
    local ok = true
    local err = nil

    ok, err = SyncUtil.run(vim.list_extend(
        { "git", "add" },
        files
    ), git_repo)
    if not ok then
        return false
    end

    ok, err = SyncUtil.run({
        "git",
        "commit", "-m", msg
    }, git_repo)

    if not ok then
        return false
    end

    ok, err = SyncUtil.run({
        "git",
        "push", "origin", "main"
    }, git_repo)

    if not ok then
        return false
    end

    return true
end

return M
