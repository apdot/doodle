local SyncUtil = require("doodle.utils.sync_util")

local M = {}

---@param git_repo string
---@param git_remote string
---@return boolean
function M.ensure_main(git_repo, git_remote)
    local remote_setting = vim.split(git_remote, " ")

    local ok, out = SyncUtil.run(vim.list_extend({
        "git",
        "ls-remote", "--exit-code", "--heads"
    }, remote_setting), git_repo)

    SyncUtil.run({
        "git",
        "branch", "-M", remote_setting[2]
    }, git_repo)

    return ok
end

---@param git_repo string
---@param git_remote string
---@return boolean
---@return string
function M.pull(git_repo, git_remote)
    local remote_setting = vim.split(git_remote, " ")

    return SyncUtil.run(vim.list_extend({
        "git",
        "pull", "--rebase"
    }, remote_setting), git_repo)
end

---@param files string[]
---@param msg string
---@param git_repo string
---@param git_remote string
---@return boolean
function M.push(files, msg, git_repo, git_remote)
    local ok = true
    local err = nil
    local remote_setting = vim.split(git_remote, " ")

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

    ok, err = SyncUtil.run(vim.list_extend({
        "git",
        "push"
    }, remote_setting), git_repo)

    if not ok then
        return false
    end

    return true
end

return M
