local repo = require("bookmarks.repo")
local _mark_repo = require("bookmarks.repo.bookmark")
local _bookmark_list = require("bookmarks.domain").bookmark_list
local common = require("bookmarks.adapter.common")
local _sort_logic = require("bookmarks.adapter.sort-logic")
local _actions = require("bookmarks.adapter.actions")
local api = require("bookmarks.api")

-- TODO: check dependencies firstly
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local actions = require("telescope.actions")
local conf = require("telescope.config").values
local action_state = require("telescope.actions.state")
local previewers = require("telescope.previewers")

---@param opts? {prompt?: string, bookmark_list?: Bookmarks.BookmarkList, all?: boolean}
local function pick_bookmark(opts)
  opts = opts or {}
  local bookmarks
  local bookmark_list_name
  if opts.all then
    bookmarks = _mark_repo.read.find_all()
    bookmark_list_name = "All"
  else
    local bookmark_list = opts.bookmark_list or repo.bookmark_list.write.find_or_set_active()
    bookmark_list_name = bookmark_list.name
    bookmarks = _bookmark_list.get_all_marks(bookmark_list)
  end

  _sort_logic.sort_by(bookmarks)
  pickers
    .new(opts, {
      prompt_title = opts.prompt or ("Bookmarks: [" .. bookmark_list_name .. "]"),
      finder = finders.new_table({
        results = bookmarks,
        ---@param bookmark Bookmarks.Bookmark
        entry_maker = function(bookmark)
          local display = common.format(bookmark, bookmarks)
          return {
            value = bookmark,
            display = display,
            ordinal = display,
            filename = bookmark.location.path,
            col = bookmark.location.col,
            lnum = bookmark.location.line,
          }
        end,
      }),
      sorter = conf.generic_sorter(opts),
      previewer = conf.grep_previewer(opts),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          local selected = action_state.get_selected_entry().value
          api.goto_bookmark(selected) -- TODO: when going to bookmark, there shows Save to Untitled.
        end)
        map({ "n", "i" }, "<C-v>", function()
          local selected = action_state.get_selected_entry().value
          api.goto_bookmark(selected, { open_method = "vsplit" })
        end)
        map({ "n", "i" }, "<C-x>", function()
          local selected = action_state.get_selected_entry().value
          api.goto_bookmark(selected, { open_method = "split" })
        end)
        -- map({"n"}, "c", nil) # no one should create bookmark from telescope.
        map({ "n" }, "r", function()
          local selected = action_state.get_selected_entry().value
          _actions.rename_bookmark(selected, function()
            pick_bookmark(opts)
          end)
        end)
        map({ "n" }, "d", function()
          local selected = action_state.get_selected_entry().value
          _actions.delete_bookmark(selected)
          pick_bookmark(opts)
        end)
        return true
      end,
    })
    :find()
end

---@param cmds {name: string, callback: function}
---@param opts? {prompt?: string}
local function pick_commands(cmds, opts)
  opts = opts or {}
  local prompt = opts.prompt or "Select commands"

  pickers
    .new(opts, {
      prompt_title = prompt,
      finder = finders.new_table({
        results = cmds,
        ---@param cmd Bookmark.Command
        ---@return table
        entry_maker = function(cmd)
          return {
            value = cmd,
            display = cmd.name, -- TODO: add description
            ordinal = cmd.name,
          }
        end,
      }),
      sorter = conf.generic_sorter(opts),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selected = action_state.get_selected_entry().value
          selected.callback()
        end)
        return true
      end,
    })
    :find()
end

local function pick_bookmark_of_current_project(opts)
  local project_name = require("bookmarks.utils").find_project_name()
  local bookmarks = repo.mark.read.find_by_project(project_name)

  pickers
    .new(opts, {
      prompt_title = "Bookmark in current project",
      finder = finders.new_table({
        results = bookmarks,
        ---@param bookmark Bookmarks.Bookmark
        entry_maker = function(bookmark)
          local display = common.format(bookmark, bookmarks)
          return {
            value = bookmark,
            display = display,
            ordinal = display,
            filename = bookmark.location.path,
            col = bookmark.location.col,
            lnum = bookmark.location.line,
          }
        end,
      }),
      sorter = conf.generic_sorter(opts),
      previewer = conf.grep_previewer(opts),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          local selected = action_state.get_selected_entry().value
          api.goto_bookmark(selected, { open_method = "vsplit" })
        end)
        map({ "n" }, "r", function()
          local selected = action_state.get_selected_entry().value
          _actions.rename_bookmark(selected, function()
            pick_bookmark_of_current_project(opts)
          end)
        end)
        map({ "n" }, "d", function()
          local selected = action_state.get_selected_entry().value
          _actions.delete_bookmark(selected)
          pick_bookmark_of_current_project(opts)
        end)
        return true
      end,
    })
    :find()
end

---@param opts? {prompt?: string}
local function pick_bookmark_list(opts)
  local bookmark_lists = repo.bookmark_list.read.find_all()
  opts = opts or {}
  local prompt = opts.prompt or "Select bookmark list"

  -- Display bookmark list in previewer.
  local preview_maker = function(self, entry, status)
    local bookmarks = entry.value.bookmarks
    for _, bookmark in ipairs(bookmarks) do
      local line = common.format(bookmark, bookmarks)
      vim.api.nvim_buf_set_lines(self.state.bufnr, -1, -1, false, { line })
    end
  end

  -- TODO: Make fancier book mark list displayer more than name.
  local display_maker = function(bookmark_list)
    local sign = " [activated]"
    if not bookmark_list.is_active then
       sign = ""
    end
    return sign .. " " .. bookmark_list.name
  end

  pickers
    .new(opts, {
      prompt_title = prompt,
      finder = finders.new_table({
        results = bookmark_lists,
        ---@param bookmark_list Bookmarks.BookmarkList
        entry_maker = function(bookmark_list)
          return {
            value = bookmark_list,
            display = display_maker(bookmark_list),
            ordinal = bookmark_list.name,
          }
        end,
      }),
      sorter = conf.generic_sorter(opts),
      previewer = previewers.new_buffer_previewer({
        title = "BookmarkList Preview",
        define_preview = preview_maker,
      }),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          local selected = action_state.get_selected_entry().value
          pick_bookmark({ bookmark_lists = selected })
        end)
        map({ "n" }, "c", function()
          _actions.new_list(function()
            pick_bookmark_list(opts)
          end)
        end)
        map({ "n" }, "r", function()
          local selected = action_state.get_selected_entry().value
          _actions.rename_list(selected, function()
            pick_bookmark_list(opts)
          end)
        end)
        map({ "n" }, "d", function()
          local selected = action_state.get_selected_entry().value
          _actions.delete_list(selected)
          pick_bookmark_list(opts)
        end)
        map({ "n" }, "a", function()
          local selected = action_state.get_selected_entry().value
          _actions.set_active_list(selected)
          pick_bookmark_list(opts)
        end)
        return true
      end,
    })
    :find()

  -- vim.ui.select(bookmark_lists, {
  -- 	prompt = prompt,
  -- 	format_item = function(item)
  -- 		---@cast item Bookmarks.BookmarkList
  -- 		return item.name
  -- 	end,
  -- }, function(choice)
  -- 	---@cast choice Bookmarks.BookmarkList
  -- 	if not choice then
  -- 		return
  -- 	end
  -- 	callback(choice)
  -- end)
end

return {
  pick_bookmark_of_current_project = pick_bookmark_of_current_project,
  pick_bookmark_list = pick_bookmark_list,
  pick_bookmark = pick_bookmark,
  pick_commands = pick_commands,
}
